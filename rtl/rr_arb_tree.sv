// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2019 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Original authors: Michael Schaffner <schaffner@iis.ee.ethz.ch>, ETH Zurich
//                   Wolfgang Roenninger <wroennin@iis.ee.ethz.ch>, ETH Zurich
//
// Adapted from pulp-platform/common_cells (synchronous reset,
// port names without _i/_o suffixes to match project conventions).
//
// Description : Logarithmic arbitration tree with round robin arbitration scheme.
//
// The rr_arb_tree employs non-starving round robin-arbitration - i.e., the priorities
// rotate each cycle.
//
// ## Fair vs. unfair Arbitration
//
// This refers to fair throughput distribution when not all inputs have active requests.
// This module has an internal state `rr_q` which defines the highest priority input. (When
// `EXT_PRIO` is `1'b1` this state is provided from the outside.) The arbitration tree will
// choose the input with the same index as currently defined by the state if it has an active
// request. Otherwise a *random* other active input is selected. The parameter `FAIR_ARB` is used
// to distinguish between two methods of calculating the next state.
// * `1'b0`: The next state is calculated by advancing the current state by one. This leads to the
//           state being calculated without the context of the active request. Leading to an
//           unfair throughput distribution if not all inputs have active requests.
// * `1'b1`: The next state jumps to the next unserved request with higher index.
//           This is achieved by using two trailing-zero-counters (`lzc`). The upper has the masked
//           `req_i` signal with all indices which will have a higher priority in the next state.
//           The trailing zero count defines the input index with the next highest priority after
//           the current one is served. When the upper is empty the lower `lzc` provides the
//           wrapped index if there are outstanding requests with lower or same priority.
// The implication of throughput fairness on the module timing are:
// * The trailing zero counter (`lzc`) has a loglog relation of input to output timing. This means
//   that in this module the input to register path scales with Log(Log(`NUM_IN`)).
// * The `rr_arb_tree` data multiplexing scales with Log(`NUM_IN`). This means that the input to output
//   timing path of this module also scales scales with Log(`NUM_IN`).
// This implies that in this module the input to output path is always longer than the input to
// register path. As the output data usually also terminates in a register the parameter `FAIR_ARB`
// only has implications on the area. When it is `1'b0` a static plus one adder is instantiated.
// If it is `1'b1` two `lzc`, a masking logic stage and a two input multiplexer are instantiated.
// However these are small in respect of the data multiplexers needed, as the width of the `req_i`
// signal is usually less as than `WIDTH`.
//
// ========================================================================
//

module rr_arb_tree
 #(
   // Number of inputs to be arbitrated.
   parameter int NUM_IN     = 64,
   // Data width of the payload in bits.
   parameter int WIDTH      = 32,
   // The `EXT_PRIO` option allows to override the internal round robin counter via the
   // `req_prio` signal. This can be useful in case multiple arbiters need to have
   // rotating priorities that are operating in lock-step. If static priority arbitration
   // is needed, just connect `rr_i` to '0.
   //
   // Set to 1'b1 to enable.
   parameter bit EXT_PRIO   = 1'b0,
   // If `VLD_RDY` is set, the req/gnt signals are compliant with the AXI style vld/rdy
   // handshake. Namely, upstream vld (req) must not depend on rdy (gnt), as it can be deasserted
   // again even though vld is asserted. Enabling `VLD_RDY` leads to a reduction of arbiter
   // delay and area.
   //
   // Set to `1'b1` to treat req/gnt as vld/rdy.
   parameter bit VLD_RDY    = 1'b0,
   // The `LOCK_IN` option prevents the arbiter from changing the arbitration
   // decision when the arbiter is disabled. I.e., the index of the first request
   // that wins the arbitration will be locked in case the destination is not
   // able to grant the request in the same cycle.
   //
   // Set to `1'b1` to enable.
   parameter bit LOCK_IN    = 1'b0,
   // When set, ensures that throughput gets distributed evenly between all inputs.
   //
   // Set to `1'b0` to disable.
   parameter bit FAIR_ARB   = 1'b1,
   // Dependent parameter, do **not** overwrite.
   // Width of the arbitration priority signal and the arbitrated index.
   parameter int IDX_WIDTH  = (NUM_IN > 1) ? $clog2(NUM_IN) : 1
   )
  (
   // Clock, positive edge triggered.
   input  logic                             clk,
   // Asynchronous reset, active low.
   input  logic                             rst,
   // Clears the arbiter state. Only used if `EXT_PRIO` is `1'b0` or `LOCK_IN` is `1'b1`.
   input  logic                             flush,
   // External round-robin priority. Only used if `EXT_PRIO` is `1'b1.`
   input  logic             [IDX_WIDTH-1:0] req_prio, // spyglass disable W240 -- unused unless EXT_PRIO==1
   // Input requests arbitration.
   input  logic [NUM_IN-1:0]                req,
   // Input data for arbitration.
   input  logic [NUM_IN-1:0][    WIDTH-1:0] req_data,
   // Input request is granted.
   output logic [NUM_IN-1:0]                gnt_mask,
   // Output request is valid.
   output logic                             gnt_any,
   // Output request is granted.
   input  logic                             gnt_ack,
   // Output data.
   output logic             [    WIDTH-1:0] gnt_data,
   // Index from which input the data came from.
   output logic             [IDX_WIDTH-1:0] gnt_idx
   );

   // Dependent parameter, do **not** overwrite.
   // Type for defining the arbitration priority and arbitrated index signal.
   typedef logic [IDX_WIDTH-1:0]            idx_t;

   // Datatype used for data
   typedef logic [    WIDTH-1:0]            dat_t;

   // just pass through in this corner case
   generate
   if (NUM_IN == 1) begin : gen_pass_through
      assign gnt_any     = req[0];
      assign gnt_mask[0] = gnt_ack;
      assign gnt_data    = req_data[0];
      assign gnt_idx     = '0;
      // non-degenerate cases
   end
   else begin : gen_arbiter
      localparam int NUM_LEVELS = $clog2(NUM_IN);

      // verilator lint_off UNOPTFLAT
      // Tree-shaped combinational reduction: each node is driven from its two
      // children. Verilator's per-signal cycle check sees the array as a single
      // unit and flags a false-positive UNOPTFLAT — the per-bit dependency graph
      // is acyclic.
      idx_t [2**NUM_LEVELS-2:0] index_nodes; // used to propagate the indices
      dat_t [2**NUM_LEVELS-2:0] data_nodes;  // used to propagate the data
      logic [2**NUM_LEVELS-2:0] gnt_nodes;   // used to propagate the grant to masters
      logic [2**NUM_LEVELS-2:0] req_nodes;   // used to propagate the requests to slave
      // verilator lint_on UNOPTFLAT
      idx_t                     rr_q;
      logic [NUM_IN-1:0]        req_d;

      // the final arbitration decision can be taken from the root of the tree
      assign gnt_any  = req_nodes[0];
      assign gnt_data = data_nodes[0];
      assign gnt_idx  = index_nodes[0];

      if (EXT_PRIO) begin : gen_ext_rr
         assign rr_q  = req_prio;
         assign req_d = req;
      end
      else begin : gen_int_rr
         idx_t rr_d;

         // lock arbiter decision in case we got at least one req and no acknowledge
         if (LOCK_IN) begin : gen_lock
            logic [NUM_IN-1:0] req_q;
            logic              lock_d, lock_q;

            assign lock_d = gnt_any & ~gnt_ack;
            assign req_d  = (lock_q) ? req_q : req;

            always_ff @(posedge clk) begin : p_lock_reg
               if (rst) begin
                  lock_q <= '0;
               end
               else begin
                  if (flush) begin
                     lock_q <= '0;
                  end
                  else begin
                     lock_q <= lock_d;
                  end
               end
            end

            // synthesis translate_off
            ERR_LOCK: assert property (@(posedge clk) disable iff (rst !== 0)
                                       LOCK_IN |-> gnt_any &&
                                       (!gnt_ack && !flush) |=> gnt_idx == $past(gnt_idx))
              else $fatal (1, "Lock implies same arbiter decision in next cycle if output is not ready.");

            logic [NUM_IN-1:0] req_tmp;
            assign req_tmp = req_q & req;
            ERR_LOCK_REQ: assume property(@(posedge clk) disable iff (rst !== 0)
                                          LOCK_IN |-> lock_d |=> req_tmp == req_q)
              else $fatal (1, "It is disallowed to deassert unserved request signals when LOCK_IN is enabled.");
            // synthesis translate_on

            always_ff @(posedge clk) begin : p_req_regs
               if (rst) begin
                  req_q  <= '0;
               end
               else begin
                  if (flush) begin
                     req_q  <= '0;
                  end
                  else begin
                     req_q  <= req_d;
                  end
               end
            end
         end
         else begin : gen_no_lock
            assign req_d = req;
         end

         if (FAIR_ARB) begin : gen_fair_arb
            logic [NUM_IN-1:0] upper_mask,  lower_mask;
            idx_t              upper_idx,   lower_idx,   next_idx;
            logic              upper_empty, lower_empty;

            always_comb begin
               for (int i = 0; i < NUM_IN; i++) begin
                  upper_mask[i] = (idx_t'(i) >  rr_q) ? req_d[i] : 1'b0;
                  lower_mask[i] = (idx_t'(i) <= rr_q) ? req_d[i] : 1'b0;
               end
            end

            lzc #
              (.WIDTH ( NUM_IN ),
               .MODE  ( 1'b0   ))
            u_lzc_upper
              (.in    ( upper_mask  ),
               .cnt   ( upper_idx   ),
               .empty ( upper_empty )
               );

            lzc #
              (.WIDTH ( NUM_IN ),
               .MODE  ( 1'b0   ))
            u_lzc_lower
              (.in    ( lower_mask  ),
               .cnt   ( lower_idx   ),
               .empty (             ) // spyglass disable W287b -- unused
               );

            assign next_idx = upper_empty      ? lower_idx : upper_idx;
            assign rr_d     = (gnt_ack & gnt_any) ? next_idx  : rr_q;

         end
         else begin : gen_unfair_arb
            assign rr_d = (gnt_ack & gnt_any) ? ((rr_q == idx_t'(NUM_IN-1)) ? '0 : rr_q + 1'b1) : rr_q;
         end

         // this holds the highest priority
         always_ff @(posedge clk) begin : p_rr_regs
            if (rst) begin
               rr_q   <= '0;
            end
            else begin
               if (flush) begin
                  rr_q   <= '0;
               end
               else begin
                  rr_q   <= rr_d;
               end
            end
         end
      end // block: gen_int_rr

      assign gnt_nodes[0] = gnt_ack;

      // arbiter tree
      for (genvar level = 0; level < NUM_LEVELS; level++) begin : gen_levels
         for (genvar l = 0; l < 2**level; l++) begin : gen_level
            // local select signal
            logic sel;
            // index calcs
            localparam int IDX0 = 2**level-1+l;// current node
            localparam int IDX1 = 2**(level+1)-1+l*2;
            //////////////////////////////////////////////////////////////
            // uppermost level where data is fed in from the inputs
            if (level == NUM_LEVELS-1) begin : gen_first_level
               // if two successive indices are still in the vector...
               if (l * 2 < NUM_IN-1) begin : gen_reduce
                  assign req_nodes[IDX0]   = req_d[l*2] | req_d[l*2+1];

                  // arbitration: round robin
                  assign sel =  ~req_d[l*2] | req_d[l*2+1] & rr_q[NUM_LEVELS-1-level];

                  assign index_nodes[IDX0] = idx_t'(sel);
                  assign data_nodes[IDX0]  = (sel) ? req_data[l*2+1] : req_data[l*2];
                  assign gnt_mask[l*2]     = gnt_nodes[IDX0] & (VLD_RDY | req_d[l*2])   & ~sel;
                  assign gnt_mask[l*2+1]   = gnt_nodes[IDX0] & (VLD_RDY | req_d[l*2+1]) &  sel;
               end
               // if only the first index is still in the vector...
               if (l * 2 == NUM_IN-1) begin : gen_first
                  assign req_nodes[IDX0]   = req_d[l*2];
                  assign index_nodes[IDX0] = '0;// always zero in this case
                  assign data_nodes[IDX0]  = req_data[l*2];
                  assign gnt_mask[l*2]     = gnt_nodes[IDX0] & (VLD_RDY | req_d[l*2]);
               end
               // if index is out of range, fill up with zeros (will get pruned)
               if (l * 2 > NUM_IN-1) begin : gen_out_of_range
                  assign req_nodes[IDX0]   = 1'b0;
                  assign index_nodes[IDX0] = idx_t'('0);
                  assign data_nodes[IDX0]  = dat_t'('0);
               end
               //////////////////////////////////////////////////////////////
               // general case for other levels within the tree
            end // block: gen_first_level
            else begin : gen_other_levels
               assign req_nodes[IDX0]   = req_nodes[IDX1] | req_nodes[IDX1+1];

               // arbitration: round robin
               assign sel =  ~req_nodes[IDX1] | req_nodes[IDX1+1] & rr_q[NUM_LEVELS-1-level];

               assign index_nodes[IDX0] = (sel) ?
                                          idx_t'({1'b1, index_nodes[IDX1+1][NUM_LEVELS-level-2:0]}) :
                                          idx_t'({1'b0, index_nodes[IDX1][NUM_LEVELS-level-2:0]});

               assign data_nodes[IDX0]  = (sel) ? data_nodes[IDX1+1] : data_nodes[IDX1];
               assign gnt_nodes[IDX1]   = gnt_nodes[IDX0] & ~sel;
               assign gnt_nodes[IDX1+1] = gnt_nodes[IDX0] &  sel;
            end // block: gen_other_levels
            //////////////////////////////////////////////////////////////
         end // block: gen_level
      end // block: gen_levels

      // synthesis translate_off
      initial begin : p_assert
         assert(NUM_IN > 0)
           else $fatal(1, "Input must be at least one element wide.");
         assert(!(LOCK_IN && EXT_PRIO))
           else $fatal(1,"Cannot use LOCK_IN feature together with external EXT_PRIO.");
      end

      ERR_ONE_HOT : assert property(@(posedge clk) disable iff (rst !== 0)
                                    $onehot0(gnt_mask))
        else $fatal (1, "Grant signal must be one-hot or zero.");

      ERR_GNT0 : assert property(@(posedge clk) disable iff (rst !== 0)
                                 |gnt_mask |-> gnt_ack)
        else $fatal (1, "Grant out implies grant in.");

      ERR_GNT1 : assert property(@(posedge clk) disable iff (rst !== 0)
                                 gnt_any |-> gnt_ack |-> |gnt_mask)
        else $fatal (1, "Req out and grant in implies grant out.");

      ERR_GNT_IDX : assert property(@(posedge clk) disable iff (rst !== 0)
                                    gnt_any |-> gnt_ack |-> gnt_mask[gnt_idx])
        else $fatal (1, "gnt_idx / gnt_mask do not match.");

      ERR_REQ0 : assert property(@(posedge clk) disable iff (rst !== 0)
                                 |req |-> gnt_any)
        else $fatal (1, "Req in implies req out.");

      ERR_REQ1 : assert property(@(posedge clk) disable iff (rst !== 0)
                                 gnt_any |-> |req)
        else $fatal (1, "Req out implies req in.");
      // synthesis translate_on
   end // block: gen_arbiter
   endgenerate

endmodule : rr_arb_tree

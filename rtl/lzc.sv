// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2018 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Adapted from pulp-platform/common_cells (synchronous reset,
// port names without _i/_o suffixes to match project conventions).
//
// Description : A trailing zero counter / leading zero counter.
//
// Set MODE to 0 for trailing zero counter => cnt is the number of trailing zeros (from the LSB)
// Set MODE to 1 for leading zero counter  => cnt is the number of leading zeros  (from the MSB)
// If the input does not contain a zero, `empty` is asserted. Additionally `cnt` contains
// the maximum number of zeros - 1. For example:
//   in = 000_0000, empty = 1, cnt = 6 (mode = 0)
//   in = 000_0001, empty = 0, cnt = 0 (mode = 0)
//   in = 000_1000, empty = 0, cnt = 3 (mode = 0)
//

module lzc
 #(
   // The width of the input vector.
   parameter int WIDTH = 2,
   // Mode selection: 0 -> trailing zero, 1 -> leading zero
   parameter bit MODE  = 1'b0,
   // Dependent parameter. Do **not** change!
   //
   // Width of the output signal with the zero count.
   parameter int CNT_WIDTH = (WIDTH > 1) ? $clog2(WIDTH) : 1
   )
  (
   // Input vector to be counted.
   input  logic [WIDTH-1:0]     in,
   // Count of the leading / trailing zeros.
   output logic [CNT_WIDTH-1:0] cnt,
   // Counter is empty: Asserted if all bits in in are zero.
   output logic                 empty
   );

   typedef logic [CNT_WIDTH-1:0] cnt_t;

   generate
   if (WIDTH == 1) begin : gen_degenerate_lzc

      assign cnt[0] = ~in[0];
      assign empty  = ~in[0];

   end
   else begin : gen_lzc

      localparam int NUM_LEVELS = CNT_WIDTH;

      // synthesis translate_off
      initial begin
         assert(WIDTH > 0) else $fatal(1, "input must be at least one bit wide");
      end
      // synthesis translate_on

      logic [2**NUM_LEVELS-1:0][NUM_LEVELS-1:0] index_nodes;
      logic [WIDTH-1:0][NUM_LEVELS-1:0]         index_lut;
      logic [2**NUM_LEVELS-1:0]                 sel_nodes;

      logic [WIDTH-1:0]                         in_tmp;

      // reverse vector if required
      always_comb begin : flip_vector
         for (int i = 0; i < WIDTH; i++) begin
            in_tmp[i] = (MODE) ? in[WIDTH-1-i] : in[i];
         end
      end

      for (genvar j = 0; j < WIDTH; j++) begin : g_index_lut
         assign index_lut[j] = cnt_t'(j);
      end

      for (genvar level = 0; level < NUM_LEVELS; level++) begin : g_levels
         if (level == NUM_LEVELS - 1) begin : g_last_level
            for (genvar k = 0; k < 2 ** level; k++) begin : g_level
               // if two successive indices are still in the vector...
               if (k * 2 < WIDTH - 1) begin : g_reduce
                  assign sel_nodes[2 ** level - 1 + k] = in_tmp[k * 2] | in_tmp[k * 2 + 1];
                  assign index_nodes[2 ** level - 1 + k] = (in_tmp[k * 2] == 1'b1) ?
                                                           index_lut[k * 2] :
                                                           index_lut[k * 2 + 1];
               end
               // if only the first index is still in the vector...
               if (k * 2 == WIDTH - 1) begin : g_base
                  assign sel_nodes[2 ** level - 1 + k] = in_tmp[k * 2];
                  assign index_nodes[2 ** level - 1 + k] = index_lut[k * 2];
               end
               // if index is out of range
               if (k * 2 > WIDTH - 1) begin : g_out_of_range
                  assign sel_nodes[2 ** level - 1 + k] = 1'b0;
                  assign index_nodes[2 ** level - 1 + k] = '0;
               end
            end
         end
         else begin : g_not_last_level
            for (genvar l = 0; l < 2 ** level; l++) begin : g_level
               assign sel_nodes[2 ** level - 1 + l] = sel_nodes[2 ** (level + 1) - 1 + l * 2] |
                                                      sel_nodes[2 ** (level + 1) - 1 + l * 2 + 1];
               assign index_nodes[2 ** level - 1 + l] = (sel_nodes[2 ** (level + 1) - 1 + l * 2] == 1'b1) ?
                                                        index_nodes[2 ** (level + 1) - 1 + l * 2] :
                                                        index_nodes[2 ** (level + 1) - 1 + l * 2 + 1];
            end
         end
      end

      assign cnt   =  index_nodes[0];
      assign empty = ~sel_nodes[0];

   end : gen_lzc
   endgenerate

endmodule : lzc

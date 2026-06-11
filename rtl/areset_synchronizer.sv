// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2013-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : areset_synchronizer.v
// Author      : Steffen Persvold
// Created     : November 7, 2013
// ========================================================================
// Description : Parameterizable meta-stable async-reset synchronizer chain
// ========================================================================
//

// Apply embedded false path timing constraint
//
// reset_in is async to clk and asynchronously asserts every flop in
// the chain via its |clrn pin. False-path ONLY that arc so the analyzer
// skips recovery / removal on the deassertion edge.
(* altera_attribute = "-name SDC_STATEMENT \"set regs [get_registers -nowarn {*areset_synchronizer*syflp_*}]; if {[llength [query_collection -report -all $regs]] > 0} {foreach_in_collection r $regs {set p [get_pins -nowarn [get_node_info -name $r]|clrn]; if {[llength [query_collection -report -all $p]] > 0} {set_false_path -to $p}}}\"" *)

module areset_synchronizer
  (clk, reset_in, reset_out);

   parameter DEPTH       = 2; // Depth of the synchronizer chain
   parameter ACTIVE_HIGH = 0; // Positive or negative logic

   input  wire clk;
   (* altera_attribute = "suppress_da_rule_internal=R101" *)
   input  wire reset_in;
   output wire reset_out;

   // -----------------------------------------------
   // We omit the "preserve" attribute on the final
   // output register, so that the synthesis tool can
   // duplicate it where needed.
   // -----------------------------------------------
   (* altera_attribute  = "disable_da_rule=D103" *)
   (* ASYNC_REG = "TRUE" *) reg [DEPTH-1:0] syflp_chain /* synthesis preserve" */;
   (* altera_attribute  = "disable_da_rule=D103" *)
   (* ASYNC_REG = "TRUE" *) reg             syflp_out;

   // -----------------------------------------------
   // Assert asynchronously, deassert synchronously.
   // -----------------------------------------------
   generate
      // Check forbidden DEPTH parameter values
      if      (DEPTH <  2) begin : errblk
         $fatal("ERROR: Invalid DEPTH parameter value %d", DEPTH);
      end

      if (ACTIVE_HIGH == 1)
        begin:active_high
           always @(posedge clk or posedge reset_in) begin
              if (reset_in) begin
                 syflp_chain <= {DEPTH{1'b1}};
                 syflp_out <= 1'b1;
              end
              else begin
                 syflp_chain <= {syflp_chain[DEPTH-2:0], 1'b0};
                 syflp_out <= syflp_chain[DEPTH-1];
              end
           end
        end // block: active_high
      else
        begin:active_low
           always @(posedge clk or negedge reset_in) begin
              if (~reset_in) begin
                 syflp_chain <= {DEPTH{1'b0}};
                 syflp_out <= 1'b0;
              end
              else begin
                 syflp_chain <= {syflp_chain[DEPTH-2:0], 1'b1};
                 syflp_out <= syflp_chain[DEPTH-1];
              end
           end
        end // block: active_low
   endgenerate

   assign reset_out = syflp_out;

endmodule // areset_synchronizer

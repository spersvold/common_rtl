// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2021-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : synchronizer.sv
// Author      : Steffen Persvold
// Created     : April 15, 2021
// ========================================================================
// Description : Multi-stage synchronizer
// ========================================================================
//

// Apply embedded false path timing constraint
(* altera_attribute  = "-name SDC_STATEMENT \"set regs [get_registers -nowarn *synchronizer*syflp_chain[0]]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\"" *)

module synchronizer
 #(parameter DEPTH = 3) // Depth of the synchronizer chain
  (
   input  logic clk,
   input  logic d,
   output logic q);

   (* ASYNC_REG = "TRUE" *) reg [DEPTH-1:0] syflp_chain /* synthesis preserve" */;
   always @(posedge clk) begin
      syflp_chain <= {syflp_chain[DEPTH-2:0], d}; // spyglass disable ResetFlop-ML
   end

   assign q = syflp_chain[DEPTH-1];

endmodule // synchronizer

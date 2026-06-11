// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2015-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : signal_filter.sv
// Author      : Steffen Persvold
// Created     : October 6, 2015
// ========================================================================
// Description : Filter input, don't change states unless same state has
// been observed in N consecutive cycles.
// ========================================================================
//

module signal_filter
 #(parameter N = 3)
  (
   input  logic clk,
   input  logic unfiltered,
   output logic filtered,
   output logic stable
   );

   logic [N:0]  shifter;

   // spyglass disable_block ResetFlop-ML
   always_ff @(posedge clk) begin
      shifter <= {shifter[N-1:0], unfiltered};

      stable <= 1'b0;
      if (~(|shifter[N:1])) begin
         filtered <= 1'b0;
         stable <= 1'b1;
      end
      else if (&shifter[N:1]) begin
         filtered <= 1'b1;
         stable <= 1'b1;
      end
   end
   // spyglass enable_block ResetFlop-ML

endmodule // signal_filter

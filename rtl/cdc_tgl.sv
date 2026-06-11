// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2021-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : cdc_tgl.sv
// Author      : Steffen Persvold
// Created     : April 15, 2021
// ========================================================================
// Description : Cross Domain toggle transfer
// ========================================================================
//

module cdc_tgl
 #(parameter DEPTH = 3) // Depth of the synchronizer chain
  (
   input  logic clk_i,  //  input clock: source domain
   input  logic rst_i,  //  input reset: source domain
   input  logic clk_o,  // output clock: destination domain
   input  logic i,      //  input pulse: source domain
   output logic o       // output pulse: destination domain
   );

   // toggle reg when pulse received in source domain
   logic        toggle_i;
   always_ff @(posedge clk_i) begin
      toggle_i <= toggle_i ^ i;
      if (rst_i)
        toggle_i <= '0;
   end

   logic        toggle_s,  toggle_q;
   synchronizer #
     (.DEPTH (DEPTH))
   u_sync
     (.clk (clk_o),
      .d   (toggle_i),
      .q   (toggle_s));

   always_ff @(posedge clk_o) begin
      toggle_q <= toggle_s; // spyglass disable ResetFlop-ML
   end

   // output pulse when transition occurs
   assign o = toggle_q ^ toggle_s;

endmodule // cdc_tgl

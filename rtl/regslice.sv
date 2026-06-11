// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2017-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : regslice.sv
// Author      : Steffen Persvold
// Created     : November 1, 2017
// ========================================================================
// Description : A register with handshakes that completely cuts any
// combinational paths between the input and output.
//
// ========================================================================
//

module regslice
  #(
    parameter int WIDTH  = 4,
    parameter bit BYPASS = 1'b0   // make this register transparent
    )
   (
    input  logic             clk,
    input  logic             rst,
    input  logic [WIDTH-1:0] i_data,
    input  logic             i_valid,
    output logic             i_ready,
    output logic [WIDTH-1:0] o_data,
    output logic             o_valid,
    input  logic             o_ready
    );

   generate
   if (BYPASS) begin : gen_bypass
      assign o_valid = i_valid;
      assign i_ready = o_ready;
      assign o_data  = i_data;
   end
   else begin : gen_reg
      // The A register.
      logic [WIDTH-1:0] a_data_q;
      logic             a_full_q;
      logic             a_fill, a_drain;

      always_ff @(posedge clk) begin
         if (rst)
           a_data_q <= '0;
         else if (a_fill)
           a_data_q <= i_data;
      end

      always_ff @(posedge clk) begin
         if (rst)
           a_full_q <= '0;
         else if (a_fill | a_drain)
           a_full_q <= a_fill;
      end

      // The B register.
      logic [WIDTH-1:0] b_data_q;
      logic             b_full_q;
      logic             b_fill, b_drain;

      always_ff @(posedge clk) begin
         if (rst)
           b_data_q <= '0;
         else if (b_fill)
           b_data_q <= a_data_q;
      end

      always_ff @(posedge clk) begin
         if (rst)
           b_full_q <= '0;
         else if (b_fill | b_drain)
           b_full_q <= b_fill;
      end

      // Fill the A register when the A or B register is empty. Drain the A register
      // whenever it is full and being filled.
      assign a_fill = i_valid & i_ready;
      assign a_drain = (a_full_q & ~b_full_q);

      // Fill the B register whenever the A register is drained, but the downstream
      // circuit is not ready. Drain the B register whenever it is full and the
      // downstream circuit is ready.
      assign b_fill = a_drain & ~o_ready;
      assign b_drain = b_full_q & o_ready;

      // We can accept input as long as register B is not full.
      assign i_ready = ~a_full_q | ~b_full_q;

      // The unit provides output as long as one of the registers is filled.
      assign o_valid = a_full_q | b_full_q;

      // We empty the spill register before the slice register.
      assign o_data = b_full_q ? b_data_q : a_data_q;

   end // block: gen_reg
   endgenerate

endmodule // regslice

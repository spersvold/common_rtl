// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2021-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : bram_sdp.sv
// Author      : Steffen Persvold
// Created     : April 15, 2021
// ========================================================================
// Description : Simple Dual Port Block ram
// ========================================================================
//

module bram_sdp import bram_pkg::*;
  (clk_write, clk_read, we, re, addr_write, addr_read, data_in, data_out);

   parameter  WIDTH=8;
   parameter  DEPTH=512;
   parameter  RAM_STYLE = RAM_STYLE_AUTO;

   localparam ADDRW=$clog2(DEPTH);

   //

   input  logic             clk_write;
   input  logic             clk_read;
   input  logic             we;
   input  logic             re;
   input  logic [ADDRW-1:0] addr_write;
   input  logic [ADDRW-1:0] addr_read;
   input  logic [WIDTH-1:0] data_in;
   output logic [WIDTH-1:0] data_out;

   //

 `ifdef VENDOR_ALTERA
  `define BRAM_SDP_ATTR(s)    (* ramstyle = s *)
 `elsif VENDOR_XILINX
  `define BRAM_SDP_ATTR(s)    (* ram_style = s *)
 `else
  `define BRAM_SDP_ATTR(s)
 `endif

   `BRAM_SDP_ATTR(RAM_STYLE) logic [WIDTH-1:0] memory [DEPTH];

   always_ff @(posedge clk_write) begin
      if (we) memory[addr_write] <= data_in;
   end

   always_ff @(posedge clk_read) begin
      if (re) data_out <= memory[addr_read];
   end

endmodule // bram_sdp

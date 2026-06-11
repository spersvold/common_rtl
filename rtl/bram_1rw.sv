// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2021-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : bram_1rw.sv
// Author      : Steffen Persvold
// Created     : April 15, 2021
// ========================================================================
// Description : Single Port Block ram
// ========================================================================
//

module bram_1rw import bram_pkg::*;
  (clk, we, addr, data_in, data_out);

   parameter  WIDTH=8;
   parameter  DEPTH=512;
   parameter  RAM_STYLE = RAM_STYLE_AUTO;

   localparam ADDRW=$clog2(DEPTH);

   //

   input  logic             clk;
   input  logic             we;
   input  logic [ADDRW-1:0] addr;
   input  logic [WIDTH-1:0] data_in;
   output logic [WIDTH-1:0] data_out;

   //

 `ifdef VENDOR_ALTERA
  `define BRAM_1RW_ATTR(s)    (* ramstyle = s *)
 `elsif VENDOR_XILINX
  `define BRAM_1RW_ATTR(s)    (* ram_style = s *)
 `else
  `define BRAM_1RW_ATTR(s)
 `endif

   `BRAM_1RW_ATTR(RAM_STYLE) logic [WIDTH-1:0] memory [DEPTH];

   always_ff @(posedge clk) begin
      if (we) memory[addr] <= data_in;
      data_out <= memory[addr];
   end

endmodule // bram_1rw

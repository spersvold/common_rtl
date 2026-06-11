// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2021-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : sfifo.sv
// Author      : Steffen Persvold
// Created     : April 15, 2021
// ========================================================================
// Description : Single clock FIFO
// ========================================================================
//

module scfifo
 #(
   parameter  int  WIDTH = 8,
   parameter  int  LGSIZ = 4,
   //
   localparam type data_t = logic [WIDTH-1:0],
   localparam type fill_t = logic [LGSIZ  :0]
   )
  (
   input  logic    clk,
   input  logic    rst,
   // Write interface
   input  logic    wen,
   input  data_t   din,
   output logic    full,
   output fill_t   fill,
   // Read interface
   input  logic    ren,
   output data_t   dout,
   output logic    empty
   );

   //
   data_t          mem[0:(2**LGSIZ)-1];
   fill_t          wr_addr, rd_addr;

   // Overflow/Underflow protection
   wire            w_wr = wen & ~full;
   wire            w_rd = ren & ~empty;

   // FIFO Write
   always_ff @(posedge clk)
     if (w_wr) mem[wr_addr[LGSIZ-1:0]] <= din;

   // Async FIFO read
   assign dout = mem[rd_addr[LGSIZ-1:0]];

   // Write addres
   always_ff @(posedge clk)
     if (rst)       wr_addr <= '0;
     else if (w_wr) wr_addr <= wr_addr + 1'b1;

   // Read address
   always_ff @(posedge clk)
     if (rst)       rd_addr <= '0;
     else if (w_rd) rd_addr <= rd_addr + 1'b1;

   // FIFO fill
   always_ff @(posedge clk)
     if (rst) fill <= '0;
     else
       unique case({w_wr, w_rd})
         2'b01:   fill <= fill - 1'b1;
         2'b10:   fill <= fill + 1'b1;
         default: fill <= wr_addr - rd_addr;
       endcase

   // Full flag
   always_ff @(posedge clk)
     if (rst) full <= 1'b0;
     else
       unique case({w_wr, w_rd})
         2'b01:   full <= 1'b0;
         2'b10:   full <= (fill == { 1'b0, {LGSIZ{1'b1}} });
         default: full <= (fill == { 1'b1, {LGSIZ{1'b0}} });
       endcase

   // Empty flag
   always_ff @(posedge clk)
     if (rst) empty <= 1'b1;
     else
       unique case ({w_wr, w_rd})
         2'b01:   empty <= (fill <= fill_t'(1));
         2'b10:   empty <= 1'b0;
         default: ;
       endcase

endmodule // scfifo

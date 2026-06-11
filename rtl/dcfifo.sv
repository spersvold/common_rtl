// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2017-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : dcfifo.sv
// Author      : Steffen Persvold
// Created     : November 1, 2017
// ========================================================================
// Description : Dual clock FIFO
// ========================================================================
//

module dcfifo
 #(
   parameter AWIDTH = 7,                // Address width
   parameter DWIDTH = 16,               // Data width
   parameter FWFT   = 0                 // First Word Fall Through mode
   )
  (
   input  logic               wclk,     // Write clock
   input  logic               wclr,     // Active high synchronous clear
   input  logic               wen,      // Write enable
   input  logic [DWIDTH -1:0] din,      // Data input
   output logic               wempty,   // FIFO is empty (write side),
   output logic               wfull,    // FIFO is full (write side),

   input  logic               rclk,     // Read domain clock
   input  logic               rclr,     // Active high synchronous clear
   input  logic               ren,      // Read enable
   output logic [DWIDTH -1:0] dout,     // Data output
   output logic               rempty,   // FIFO is empty (read side)
   output logic               rfull     // FIFO is full (read side)
   );

   // variable declarations
   typedef logic [AWIDTH -1:0] adr_t;

   adr_t                      rptr, wptr, rptr_gray, wptr_gray;
   logic                      rrst, wrst, ssrclr, sswclr;
   adr_t                      rptr_plus1, wptr_plus1;
   adr_t                      rptr_minus1, wptr_plus2;

   //
   //

   function automatic logic [AWIDTH-1:0] bin2gray(input logic [AWIDTH-1:0] bin);
      return (bin >> 1) ^ bin;
   endfunction

   function automatic logic [AWIDTH-1:0] gray2bin(input logic [AWIDTH-1:0] gray);
      logic [AWIDTH-1:0] bin;
      bin = gray;
      for (int ii=0 ; ii<$clog2(AWIDTH); ii++)
        bin = (bin >> (2**ii)) ^ bin;
      return bin;
   endfunction

   // generate synchronized resets
   synchronizer #(2) wclr_sync (.clk(rclk), .d(wclr), .q(sswclr));

   always_ff @(posedge rclk)
     rrst   <= rclr | sswclr;

   synchronizer #(2) rclr_sync (.clk(wclk), .d(rclr), .q(ssrclr));

   always_ff @(posedge wclk)
     wrst   <= wclr | ssrclr;

   // update read pointers
   always_ff @(posedge rclk)
     if (rrst) begin
        rptr       <= '0;
        rptr_plus1 <= adr_t'(1);
        rptr_minus1<= '1;
        rptr_gray  <= '0;
     end
     else if (ren) begin
        rptr       <= rptr_plus1;
        rptr_plus1 <= rptr_plus1 + adr_t'(1);
        rptr_minus1<= rptr_minus1 + adr_t'(1);
        rptr_gray  <= bin2gray(rptr_plus1);
     end

   // update write pointers
   always @(posedge wclk)
     if (wrst) begin
        wptr       <= '0;
        wptr_plus1 <= adr_t'(1);
        wptr_plus2 <= (AWIDTH == 1) ? adr_t'(0) : adr_t'(2);
        wptr_gray  <= '0;
     end
     else if (wen) begin
        wptr       <= wptr_plus1;
        wptr_plus1 <= wptr_plus1 + adr_t'(1);
        wptr_plus2 <= wptr_plus2 + adr_t'(1);
        wptr_gray  <= bin2gray(wptr_plus1);
     end

   // synchronize pointers from one clock domain, to the other
   logic [AWIDTH-1:0] ssrptr_gray;
   logic [AWIDTH-1:0] sswptr_gray;

   synchronizer #(2) wptr_gray_sync[AWIDTH-1:0]
     (.clk(rclk), .d(wptr_gray), .q(sswptr_gray));

   synchronizer #(2) rptr_gray_sync[AWIDTH-1:0]
     (.clk(wclk), .d(rptr_gray), .q(ssrptr_gray));

   //
   // status flags
   //

   always @(posedge rclk)
     if      (rrst) rempty <= 1'b1;
     else if (ren)  rempty <= (bin2gray(rptr_plus1) == sswptr_gray);
     else           rempty <= rempty & (rptr_gray == sswptr_gray);

   always @(posedge rclk)
     if      (rrst) rfull <= 1'b0;
     else           rfull <= ~ren & (bin2gray(rptr_minus1) == sswptr_gray);

   always @(posedge wclk)
     if      (wrst) wfull <= 1'b0;
     else if (wen)  wfull <= bin2gray(wptr_plus2) == ssrptr_gray;
     else           wfull <= wfull & (bin2gray(wptr_plus1) == ssrptr_gray);

   always @(posedge wclk)
     if      (wrst) wempty <= 1'b1;
     else           wempty <= ~wen & (wptr_gray == ssrptr_gray);

   // Manage First-Word-Fall-Through mode if enabled
   adr_t              ram_rptr;
   logic              ram_ren;
   generate if (FWFT > 0) begin: g_fwft
      assign ram_rptr = rempty ? rptr : rptr_plus1;
      assign ram_ren  = rempty ? 1'b1 : ren;
   end
   else begin: g_norm
      assign ram_rptr = rptr;
      assign ram_ren  = ren;
   end endgenerate

   // hookup generic dual ported memory
   bram_sdp #
     (.WIDTH (DWIDTH),
      .DEPTH (2**AWIDTH))
   u_mem
     (.clk_read   (rclk),
      .re         (ram_ren),
      .addr_read  (ram_rptr),
      .data_out   (dout),
      .clk_write  (wclk),
      .addr_write (wptr),
      .we         (wen),
      .data_in    (din));

endmodule // dcfifo

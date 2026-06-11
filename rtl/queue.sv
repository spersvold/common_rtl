// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2017-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : queue.sv
// Author      : Steffen Persvold
// Created     : November 1, 2017
// ========================================================================
// Description : Fall-through Queue (FIFO)
//
// Parameterized Fall-Through Queue
// This is a stack of registers of level 'DEPTH'.
// The output always points to level 0
// As new data is written to the next higher available stack level
// As data is read, the old data 'falls-through' to the next lower level
//
// 'afull' is a user configurable 'full' signal.
// Its threshold is set by the AFULL parameter
//
// ========================================================================
//

module queue
 #(
   parameter DEPTH  = 2,
   parameter WIDTH  = 32,
   parameter AFULL  = DEPTH
   )
  (
   input  logic                       clk,          // Rising edge triggered clock
   input  logic                       rst,          // Synchronous reset

   input  logic                       clr,          // Clear all queue entries

   input  logic [WIDTH-1:0]           din,          // Queue write data
   input  logic                       wen,          // Queue write enable

   output logic [WIDTH-1:0]           dout,         // Queue read data
   input  logic                       ren,          // Queue read enable

   // Status signals
   output logic [$clog2(DEPTH+1)-1:0] count,
   output logic                       empty,        // Queue is empty
   output logic                       full,         // Queue is full
   output logic                       afull         // Programmable almost full
   );

   // ========================================================================
   // Local variable declarations
   // ========================================================================

   localparam EMPTY_THRESHOLD = 1;
   localparam FULL_THRESHOLD  = DEPTH -1;
   localparam AFULL_THRESHOLD_CHECK = AFULL >= DEPTH ? FULL_THRESHOLD : AFULL -1;
   localparam CNT_WIDTH = $clog2(DEPTH+1) > 0 ? $clog2(DEPTH+1) : 1;
   localparam IDX_WIDTH = $clog2(DEPTH) > 0 ? $clog2(DEPTH) : 1;

   typedef logic [CNT_WIDTH-1:0] queue_cnt_t;
   typedef logic [IDX_WIDTH-1:0] queue_idx_t;

   logic [DEPTH-1:0][WIDTH-1:0] queue_data;
   queue_cnt_t                  queue_cnt;
   queue_idx_t                  queue_idx,
                                prev_idx;

   // ========================================================================
   // ========================================================================

   // Write Address
   always @(posedge clk)
     if (rst | clr) queue_cnt <= '0;
     else
       unique case ({wen,ren})
         2'b01  : queue_cnt <= queue_cnt - 1'b1;
         2'b10  : queue_cnt <= queue_cnt + 1'b1;
         default: ;
       endcase

   assign queue_idx = queue_idx_t'(queue_cnt);
   assign prev_idx = (~|queue_idx) ? queue_idx_t'(DEPTH-1) : queue_idx - 1'b1;

   // Queue Data
   always @(posedge clk)
     if (rst | clr) queue_data <= '0; // clear all entries
     else
       unique case ({wen,ren})
         2'b01  : begin // read only
            for (int n=0; n<DEPTH-1; n++)
              queue_data[n] <= queue_data[n+1];
            queue_data[DEPTH-1] <= '0;
         end

         2'b10  : begin // write only
            queue_data[queue_idx] <= din;
         end

         2'b11  : begin // read and write
            for (int n=0; n<DEPTH-1; n++)
              queue_data[n] <= queue_data[n+1];

            queue_data[DEPTH-1] <= '0;
            queue_data[prev_idx] <= din;
         end

         default: ;
       endcase

   // Queue Empty
   always @(posedge clk)
     if (rst | clr) empty <= 1'b1;
     else
       unique case ({wen,ren})
         2'b01  : empty <= (queue_cnt == queue_cnt_t'(EMPTY_THRESHOLD));
         2'b10  : empty <= 1'b0;
         default: ;
       endcase

   // Queue Almost Full
   generate if (DEPTH > 1) begin : gt_1
      always @(posedge clk)
        if (rst | clr) afull <= 1'b0;
        else
          unique case ({wen,ren})
            2'b01  : afull <=~(queue_cnt <= queue_cnt_t'(AFULL_THRESHOLD_CHECK+1));
            2'b10  : afull <= (queue_cnt >= queue_cnt_t'(AFULL_THRESHOLD_CHECK));
            default: ;
          endcase
   end else begin : eq_1
      assign afull = 1'b1;
   end endgenerate

   // Queue Full
   always @(posedge clk)
     if (rst | clr) full <= 1'b0;
     else
       unique case ({wen,ren})
         2'b01  : full <= 1'b0;
         2'b10  : full <= (queue_cnt == queue_cnt_t'(FULL_THRESHOLD));
         default: ;
      endcase

   // Queue output data
   assign dout  = queue_data[0];
   assign count = queue_cnt;

   // synthesis translate_off
   ERR_QUEUE_OVERFLOW: assert property (@(posedge clk) disable iff (rst !== '0)
                                        wen |-> (~full | ren))
     else $display("ERROR %t: queue (%m) overflow!", $time);

   ERR_FIFO_UNDERFLOW: assert property (@(posedge clk) disable iff (rst !== '0)
                                        ren |-> (~empty | wen))
     else $display("ERROR %t: queue (%m) underflow!", $time);
   // synthesis translate_on

endmodule // queue

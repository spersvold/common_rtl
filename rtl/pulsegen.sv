// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2013-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : pulsegen.sv
// Author      : Steffen Persvold
// Created     : January 26, 2013
// ========================================================================
// Description : Pulse generator
//  - generate pulses on rising and falling edge
// ========================================================================
//

module pulsegen
  (clk, d, q, pulse);

   input  logic            clk;
   input  logic            d;
   output logic            q;
   output logic            pulse;

   //

   always_ff @(posedge clk)
     q <= d;

   assign pulse = q ^ d;

endmodule // pulsegen

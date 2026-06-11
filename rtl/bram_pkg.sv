// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2021-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : bram_pkg.vh
// Author      : Steffen Persvold
// Created     : April 15, 2021
// ========================================================================
// Description : Vendor specific BRAM attributes (for synthesis)
// ========================================================================
//

package bram_pkg;

`ifdef VENDOR_ALTERA
   localparam RAM_STYLE_AUTO = "no_rw_check";
   localparam RAM_STYLE_BLCK = "no_rw_check, M20K";
   localparam RAM_STYLE_DIST = "no_rw_check, MLAB";
 `elsif VENDOR_XILINX
   localparam RAM_STYLE_AUTO = "auto";
   localparam RAM_STYLE_BLCK = "block";
   localparam RAM_STYLE_DIST = "distributed";
 `else
   localparam RAM_STYLE_AUTO = "";
   localparam RAM_STYLE_BLCK = "";
   localparam RAM_STYLE_DIST = "";
 `endif

endpackage // bram_pkg

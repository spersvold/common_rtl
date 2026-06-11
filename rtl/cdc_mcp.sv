// -*- mode: verilog; mode: font-lock; indent-tabs-mode: nil -*-
// vi: set et ts=3 sw=3 sts=3:
//
// Copyright 2013-2026 Steffen Persvold
// SPDX-License-Identifier: Apache-2.0
//
// ========================================================================
// File        : cdc_mcp.sv
// Author      : Steffen Persvold
// Created     : January 26, 2013
// ========================================================================
// Description : Clock Domain Crossing using MCP formulation
//
// This designs does CDC via a 2-phase acknowledge handshake protocol
// ========================================================================

// Apply embedded false path timing constraint
(* altera_attribute  = "-name SDC_STATEMENT \"set regs [get_registers -nowarn *cdc_mcp*rdata[*]]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\"" *)

module cdc_mcp
  #(
    parameter WIDTH = 32
    )
   (
    input  logic              wclk,
    input  logic              wrst,

    input  logic              wsend,
    output logic              wready,
    input  logic [WIDTH-1:0]  wdata,

    input  logic              rclk,
    input  logic              rrst,

    output logic              rvalid,
    input  logic              rload,
    output logic [WIDTH-1:0]  rdata
    );

   // =============================================================================
   // =============================================================================

   logic                      wsync_ack;
   logic                      wsync_ack_pulse;
   logic [WIDTH-1:0]          wdata_d1;

   logic                      rsync_req;
   logic                      rsync_req_pulse;

   logic                      send_data;
   logic                      ack_data;

   // Don't reset these flip-flops, they are edge generators and if reset when 1
   // they generate a false transaction.
   // To avoid X at init of simulation, they are declared as a 2-state variable "bit"
   // and their initial value randomized.
   bit                        wreq;
   bit                        rack;

   // synopsys translate_off
`ifdef SIMULATION
   initial begin
      #0;
      wreq = $random();
      rack = $random();
   end
`endif
   // synopsys translate_on

   //
   // Write side logic
   //

   // Synchronize the read acknowledge signal into wite clock domain and generate a transition pulse
   synchronizer #(2) u_rack_sync  (.clk(wclk), .d(rack), .q(wsync_ack));
   pulsegen          u_rack_pulse (.clk(wclk), .d(wsync_ack), .q(), .pulse(wsync_ack_pulse));

   // Controlling wready
   always_ff @(posedge wclk) begin
      if (wready & wsend)
        wready <= 1'b0;

      if (~wready & wsync_ack_pulse)
        wready <= 1'b1;

      if (wrst)
        wready <= 1'b1;
   end

   assign send_data = wready & wsend;

   // NB: We can't use always_ff here because we have our initial statements for simulation
   always @(posedge wclk) // spyglass disable UseSVAlways-ML
     wreq <= send_data ^ wreq; // spyglass disable ResetFlop-ML

   // Hold register for wr data to ensure it is stable for
   // read domain to capture it.
   always_ff @(posedge wclk)
     if      (wrst)      wdata_d1 <= '0; // spyglass disable ResetName
     else if (send_data) wdata_d1 <= wdata;

   //
   // Read side logic
   //

   // Synchronize the write request signal into read clock domain and generate a transition pulse
   synchronizer #(2) u_wreq_sync  (.clk(rclk), .d(wreq), .q(rsync_req));
   pulsegen          u_wreq_pulse (.clk(rclk), .d(rsync_req), .q(), .pulse(rsync_req_pulse));

   // Controlling rvalid
   always_ff @(posedge rclk) begin
      if (~rvalid & rsync_req_pulse)
        rvalid <= 1'b1;

      if ( rvalid & rload)
        rvalid <= 1'b0;

      if (rrst)
        rvalid <= 1'b0;
   end

   assign ack_data = rvalid & rload;

   // NB: We can't use always_ff here because we have our initial statements for simulation
   always @(posedge rclk) // spyglass disable UseSVAlways-ML
      rack <= ack_data ^ rack; // spyglass disable ResetFlop-ML

   // Capture the data from the write domain into the read domain.
   // Data from write domain is guaranteed to be stable when it is
   // sampled, thanks to the handshake protocol.
   always_ff @(posedge rclk)
     if      (rrst)            rdata <= '0; // spyglass disable ResetName
     else if (rsync_req_pulse) rdata <= wdata_d1;

endmodule // cdc_mcp

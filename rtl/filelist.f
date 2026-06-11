// common_rtl compile file list
//
// File names are relative to this directory (rtl/). Either run your tool from
// inside rtl/, or use a flag that resolves paths relative to the filelist
// (e.g. Verilator's -F instead of -f). Examples:
//   cd rtl && verilator --lint-only --sv -f filelist.f
//   verilator --lint-only --sv -F rtl/filelist.f
//   vlog -F rtl/filelist.f
//
// Remember to also pass a vendor define for synthesis, e.g. +define+VENDOR_XILINX
// or +define+VENDOR_ALTERA (omit both for generic/simulation builds).
//
// Listed in dependency order so tools that require it (package and
// submodule definitions before their users) see definitions first.

// --- leaf modules and packages (no internal dependencies) ---
bram_pkg.sv
synchronizer.sv
pulsegen.sv
lzc.sv
areset_synchronizer.sv
signal_filter.sv
regslice.sv

// --- block RAM (import bram_pkg) ---
bram_sdp.sv
bram_1rw.sv

// --- CDC (use synchronizer / pulsegen) ---
cdc_tgl.sv
cdc_mcp.sv

// --- FIFOs / queues ---
scfifo.sv
queue.sv
dcfifo.sv

// --- arbitration (uses lzc) ---
rr_arb_tree.sv

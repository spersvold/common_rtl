# common_rtl

A small, dependency-free library of reusable SystemVerilog building blocks:
clock-domain-crossing primitives, FIFOs, block-RAM wrappers, arbitration, and
assorted glue logic. The modules are written to be vendor-neutral: they
synthesize cleanly on both Intel/Altera (Quartus) and AMD/Xilinx (Vivado) flows,
and are also linted/simulated with open-source tools (see
[Toolchain support](#toolchain-support)).

All source lives under [`rtl/`](rtl).

## Modules

### Clock-domain crossing

| Module | Description | Parameters | Depends on |
| --- | --- | --- | --- |
| `synchronizer` | Multi-stage flip-flop synchronizer for a single bit. Carries an embedded false-path SDC constraint for Quartus and `ASYNC_REG`/`preserve` attributes. | `DEPTH` (chain length, default 3) | — |
| `areset_synchronizer` | Reset synchronizer: asynchronous assert, synchronous de-assert. False-paths only the async-clear arc. | `DEPTH` (≥2), `ACTIVE_HIGH` | — |
| `cdc_tgl` | Single-pulse crossing using the toggle method. A pulse in the source domain produces one pulse in the destination domain. | `DEPTH` | `synchronizer` |
| `cdc_mcp` | Multi-bit data crossing using the MCP (multi-cycle path) 2-phase request/acknowledge handshake. Includes a `wready`/`rvalid` flow-control interface. | `WIDTH` | `synchronizer`, `pulsegen` |

### FIFOs and queues

| Module | Description | Parameters | Depends on |
| --- | --- | --- | --- |
| `sfifo` | Single-clock synchronous FIFO with `full`/`empty`/`fill` status and overflow/underflow protection. Read data is combinational (look-ahead). | `WIDTH`, `LGSIZ` (log2 depth) | — |
| `dcfifo` | Dual-clock (asynchronous) FIFO with Gray-coded pointers and synchronized clears. Optional first-word-fall-through. Status flags on both write and read sides. | `AWIDTH`, `DWIDTH`, `FWFT` | `synchronizer`, `bram_sdp` |
| `queue` | Fall-through register queue; output always presents level 0. Includes a programmable almost-full and built-in over/underflow assertions. | `DEPTH`, `WIDTH`, `AFULL` | — |

### Block RAM

| Module | Description | Parameters | Depends on |
| --- | --- | --- | --- |
| `bram_pkg` | Package of vendor-specific RAM-style attribute strings selected by the `VENDOR_*` define. | — | — |
| `bram_1rw` | Single-port (1 read/write) block RAM with registered output. | `WIDTH`, `DEPTH`, `RAM_STYLE` | `bram_pkg` |
| `bram_sdp` | Simple dual-port block RAM (one write port, one read port), independent clocks. | `WIDTH`, `DEPTH`, `RAM_STYLE` | `bram_pkg` |

### Arbitration and utility

| Module | Description | Parameters | Depends on |
| --- | --- | --- | --- |
| `rr_arb_tree` | Logarithmic round-robin arbitration tree with fair/unfair, lock-in, external-priority, and AXI-style vld/rdy options. | `NUM_IN`, `WIDTH`, `EXT_PRIO`, `VLD_RDY`, `LOCK_IN`, `FAIR_ARB` | `lzc` |
| `lzc` | Leading / trailing zero counter with an `empty` flag for the all-zero case. | `WIDTH`, `MODE` (0 = trailing, 1 = leading) | — |
| `regslice` | Pipeline register slice (spill register) with valid/ready handshake; fully cuts both forward and backward combinational paths. Optional zero-latency bypass. | `WIDTH`, `BYPASS` | — |
| `pulsegen` | Edge-to-pulse generator: emits a one-cycle pulse on any transition of the input. | — | — |
| `signal_filter` | Glitch/debounce filter: output changes only after the input is stable for `N` consecutive cycles. Provides a `stable` flag. | `N` | — |

## Dependency graph

```
cdc_tgl       -> synchronizer
cdc_mcp       -> synchronizer, pulsegen
dcfifo        -> synchronizer, bram_sdp
bram_1rw      -> bram_pkg
bram_sdp      -> bram_pkg
rr_arb_tree   -> lzc
```

When compiling, make sure `bram_pkg.sv` is analyzed before the modules that
import it (`bram_1rw`, `bram_sdp`, and therefore `dcfifo`).

## Vendor / build defines

Several modules adapt to the target technology through preprocessor defines.
Set exactly one vendor define for synthesis; leaving both unset compiles to
generic, inferred logic (useful for simulation and lint).

| Define | Effect |
| --- | --- |
| `VENDOR_ALTERA` | Selects Intel/Altera RAM-style strings and `ramstyle` attributes. |
| `VENDOR_XILINX` | Selects AMD/Xilinx RAM-style strings and `ram_style` attributes. |
| `SIMULATION` | Enables randomized initialization of the edge-generator flops in `cdc_mcp` to avoid `X` propagation at time 0. |

The embedded Quartus SDC false-path constraints are applied automatically via
`altera_attribute` pragmas and require no extra `.sdc` entries.

## Usage

There is no build system or package manifest. A ready-made compile list is
provided at [`rtl/filelist.f`](rtl/filelist.f), with the files in dependency
order (packages and submodules before their users). File names in it are
relative to `rtl/`, so either run your tool from inside `rtl/` or use a
filelist-relative flag (e.g. Verilator's `-F`):

```
# from the repository root
verilator --lint-only --sv -F rtl/filelist.f --top-module dcfifo

# or from inside rtl/
cd rtl && verilator --lint-only --sv -f filelist.f --top-module dcfifo
```

Add a vendor define for synthesis (`+define+VENDOR_XILINX` or
`+define+VENDOR_ALTERA`); omit both for a generic simulation/lint build. You can
also cherry-pick individual files instead of using the filelist — just keep
`bram_pkg.sv` and any instantiated submodules ahead of the modules that use
them.

## Toolchain support

The code is plain synthesizable SystemVerilog with no vendor-only constructs in
the logic itself — the only vendor-specific content is the synthesis attributes
and SDC pragmas, which other tools ignore.

| Toolchain | Status | Notes |
| --- | --- | --- |
| Quartus (Intel/Altera) | Supported | Use `+define+VENDOR_ALTERA`. Embedded SDC false-path constraints applied automatically. |
| Vivado (AMD/Xilinx) | Supported | Use `+define+VENDOR_XILINX`. |
| Verilator | Lint/sim clean | Verified `--lint-only` clean on Verilator 5.048 with no warnings, including `dcfifo`, `cdc_mcp`, `rr_arb_tree`, and `scfifo`. |
| Yosys (+ slang) | Elaborates clean | Verified: every module reads and passes `hierarchy -check` via [yosys-slang](https://github.com/povik/yosys-slang) (`yosys -m slang -p "read_slang ..."`). The built-in `read_verilog -sv` frontend is *not* sufficient — the modules use packages, parameterized-type ports (`localparam type`), and packed multidimensional arrays that require the slang (or Surelog/UHDM) frontend. |

Example invocations against the provided filelist:

```
# Verilator lint
verilator --lint-only --sv -F rtl/filelist.f --top-module rr_arb_tree

# Yosys read + hierarchy check, via the slang frontend
yosys -m slang -p "read_slang -F rtl/filelist.f --top dcfifo; hierarchy -check"
```

The simulation-only constructs (SVA assertions, `$random` initialization) are
guarded by `synthesis translate_off`/`translate_on` and the `SIMULATION` define,
so they are skipped during synthesis.

## License

Most files are © Steffen Persvold and released under the **Apache License 2.0**
(see [`LICENSE`](LICENSE)). Each file carries an SPDX identifier in its header.

Two modules are adapted from
[pulp-platform/common_cells](https://github.com/pulp-platform/common_cells) and
are licensed under the **Solderpad Hardware License v0.51** (`SHL-0.51`):

- `lzc.sv`
- `rr_arb_tree.sv`

Always consult the SPDX/`Copyright` header in each individual file for its
authoritative license.

# Minimal UVM-style Testbench Example (FIFO)

A simple, Verilator-compatible SystemVerilog verification example using a FIFO design.

## What
This example demonstrates a minimal class-based testbench with:
- driver (random stimulus generation)
- monitor (cycle-aligned observation)
- scoreboard (self-checking reference model)

## Why
BlackParrot currently lacks a lightweight verification reference.

This example provides a starting point for building verification environments for future modules (e.g., ALU, cache, BP-Stream).

## Features
- Simple FIFO DUT (8-depth)
- Randomized stimulus
- Self-checking PASS/FAIL output
- Verilator-compatible
- Waveform generation (VCD)

## How to Run

### Option 1 (recommended)
```bash
chmod +x run.sh
./run.sh
```

### Option 2 (manual)
```bash
verilator --sv --timing --trace --cc top.sv --exe sim_main.cpp
make -C obj_dir -f Vtop.mk
./obj_dir/Vtop
```
## Output

The simulation prints:
WRITE transactions
PASS / FAIL checks
Final summary (PASS / FAIL count)
Example:
```
WRITE: 3b
PASS: 3b
PASS=85 FAIL=0
```
## Waveform Viewing:
```bash
gtkwave waveform.vcd
```

## Notes
FIFO read has 1-cycle latency, handled in the monitor
Designed to be minimal and easy to understand
Not a full UVM implementation (no factory, sequences, coverage)

## File Structure
```
fifo.sv         - FIFO RTL
fifo_if.sv      - Interface with clocking blocks
tb_classes.sv   - Driver, Monitor, Scoreboard
top.sv          - Testbench top
sim_main.cpp    - Verilator simulation harness
run.sh          - Build and run script
```

# Verilog Projects Collection

This repository contains a collection of Verilog/SystemVerilog projects, including a RISC-V processor implementation and various digital design modules. Each project is designed to be simulated using **Verilator + C++ test-benches** with waveform visualization in **GTKWave**.

## Projects Overview

1. **FemtoRV32**: A compact RISC-V processor implementation
   - Basic RV32I instruction set support
   - Pipeline stages visualization
   - Detailed waveform analysis available

2. **ALU**: Arithmetic Logic Unit implementation
   - Basic arithmetic operations
   - Logic operations
   - Testbench included

3. **Counter**: Simple counter implementation
   - Configurable bit width
   - Up-counting functionality

4. **Up/Down Counter**: Bidirectional counter
   - Configurable counting direction
   - Reset functionality

## Directory Structure

```
verilfiles/                # Top-level workspace
├── femtorv_project/      # RISC-V processor implementation
│   ├── src/              # Verilog source files
│   ├── tb/               # Testbench files
│   └── images/           # Documentation images
├── alu/                  # ALU module
│   ├── Makefile         # Module-specific build script
│   ├── src/             # SystemVerilog source(s)
│   │   └── alu.sv
│   ├── tb/             # C++ testbench
│   │   └── tb_alu.cpp
│   └── waveform.vcd    # Generated after `make sim`
├── counter/             # Counter implementation
└── updown/             # Up/Down counter implementation
```

*Each module directory is independent: you can zip it, clone it, or build it in CI without affecting the others.*

## Build and Simulation Guide

### Dependencies

```bash
sudo apt install verilator gtkwave
# optional for netlist graphics
sudo apt install yosys
sudo npm install -g netlistsvg
```

### Module Makefile Structure

Each module contains a Makefile with the following targets:

| Target          | Purpose                                                      |
|-----------------|--------------------------------------------------------------|
| `make sim`      | Verilates, builds, runs simulation, writes `waveform.vcd`    |
| `make waves`    | Opens GTKWave with `waveform.vcd`                            |
| `make lint`     | Verilator lint only (no simulation)                          |
| `make clean`    | Deletes `obj_dir`, stamp file, and waveform                  |
| `make verilate` | Generates C++ netlist only (no compile/run)                  |
| `make build`    | Compiles the generated C++ netlist                           |

### Typical Workflow

```bash
cd verilfiles/<module_name>

# 1. Reset build, then simulate
make clean
make sim VERILATOR_ARGS=+rand-init=all   # optional random init

# 2. View results
make waves           # launches GTKWave

# 3. Static lint check
make lint

# 4. Iterate: edit code → `make sim` → reload GTKWave (Shift-R)
```

### Creating a New Module

1. **Copy the template**
```bash
cp -r verilfiles/alu verilfiles/newmod
mv verilfiles/newmod/src/alu.sv verilfiles/newmod/src/newmod.sv
mv verilfiles/newmod/tb/tb_alu.cpp verilfiles/newmod/tb/tb_newmod.cpp
```

2. **Update Makefile**
```makefile
MODULE := newmod
```

3. **Write RTL** in `src/newmod.sv`
4. **Adapt testbench** in `tb/tb_newmod.cpp`
5. **Simulate and verify**
```bash
cd verilfiles/newmod
make sim
make waves
```

### Netlist Visualization

Generate an SVG of the synthesized RTL:

```bash
yosys -p "read_verilog -sv src/newmod.sv; proc; opt; write_json netlist.json"
netlistsvg netlist.json -o netlist.svg
xdg-open netlist.svg
```

## Waveform Analysis

The repository includes waveform visualizations for various modules, particularly detailed ones for the FemtoRV32 processor. These can be found in the `images/` directory of respective projects.

## Contributing

Dear collaborators, feel free to contribute by:
1. Creating new modules
2. Improving existing implementations
3. Enhancing documentation
4. Adding test cases



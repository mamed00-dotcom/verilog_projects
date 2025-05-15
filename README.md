# Verilog Projects Collection

This repository contains a collection of Verilog/SystemVerilog projects, including a RISC-V processor implementation.

## Projects

### 1. FemtoRV32 (RISC-V Processor)
- A compact implementation of the RISC-V RV32I base integer instruction set
- Features Physical Memory Protection (PMP)
- Includes testbench and waveform visualization
- [View Project Details](femtorv_project/README.md)

### 2. ALU
- Arithmetic Logic Unit implementation
- Supports basic arithmetic and logical operations
- Includes testbench for verification

### 3. Counter
- Basic counter implementation
- Includes testbench for verification

### 4. Up/Down Counter
- Bidirectional counter implementation
- Supports counting up and down
- Includes testbench for verification

## Building and Testing

Each project contains its own Makefile and can be built independently. Common build commands:

```bash
# Clean build artifacts
make clean

# Build and run simulation
make

# View waveforms (where applicable)
make waves
```

## Requirements

- Verilator (for simulation)
- C++ compiler
- GTKWave (for waveform viewing)
- Yosys (for synthesis)

## Project Structure
```
verilfiles/
├── alu/                  # ALU implementation
├── count/                # Basic counter
├── femtorv_project/      # RISC-V processor
├── updown/               # Up/down counter
└── README.md            # This file
```

## Contributing

Feel free to contribute to any of these projects by:
- Adding new features
- Improving documentation
- Fixing bugs
- Enhancing test coverage 
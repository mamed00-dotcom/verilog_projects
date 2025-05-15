# Set your top module name here
MODULE := FemtoRV32
TOP    := $(MODULE)

# Directory structure
SRC_DIR  := src
TB_DIR   := tb
OBJ_DIR  := obj_dir

# Source files
VSRC    := $(SRC_DIR)/$(TOP).v
TB_SRC  := $(TB_DIR)/FemtoRV_tb.cpp

# Verilator output and simulation artifacts
VEXE    := $(OBJ_DIR)/V$(TOP)
VCD     := waveform.vcd
VERILATE_STAMP := .stamp.verilate

# Verilator flags
VERILATOR_FLAGS := -Wall --trace -cc -Wno-UNUSEDSIGNAL -Wno-LATCH
VERILATOR_INCLUDES := -I$(SRC_DIR) -I$(TB_DIR)
VERILATOR_CFLAGS := "-DVL_DEBUG"

.PHONY: all sim verilate build waves lint clean

# Default target
all: sim

# Main simulation target
sim: $(VCD)

# Run simulation and produce waveform
$(VCD): $(VEXE)
	@echo "### SIMULATING ###"
	@$(VEXE)

# Build simulator binary
$(VEXE): $(VERILATE_STAMP)
	@echo "### BUILDING SIM ###"
	@make -C $(OBJ_DIR) -f V$(TOP).mk V$(TOP)

# Run Verilator to generate simulation build files
$(VERILATE_STAMP): $(VSRC) $(TB_SRC)
	@echo "### VERILATING ###"
	verilator $(VERILATOR_FLAGS) $(VSRC) --exe $(TB_SRC) --build $(VERILATOR_CFLAGS)
	@touch $(VERILATE_STAMP)

# View waveform
waves: $(VCD)
	@echo "### WAVES ###"
	gtkwave $(VCD)

# Lint only
lint: $(VSRC)
	verilator --lint-only $(VSRC)

# Clean all generated files
clean:
	rm -rf $(VERILATE_STAMP) $(VCD) $(OBJ_DIR)

# Create directory structure
setup:
	@mkdir -p $(SRC_DIR) $(TB_DIR) $(OBJ_DIR)

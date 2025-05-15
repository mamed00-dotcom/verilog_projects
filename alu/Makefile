# Set your top module name here
MODULE := alu
TOP     := $(MODULE)
TB      := tb_$(MODULE)

# Verilator output and simulation artifacts
VEXE    := ./obj_dir/V$(TOP)
VCD     := waveform.vcd
VERILATE_STAMP := .stamp.verilate
VERILATOR_ARGS ?=

.PHONY: sim verilate build waves lint clean

# Main simulation target
sim: $(VCD)

# Run simulation and produce waveform
$(VCD): $(VEXE)
	@echo
	@echo "### SIMULATING ###"
	@$(VEXE) $(VERILATOR_ARGS)

# Build simulator binary
$(VEXE): $(VERILATE_STAMP)
	@echo
	@echo "### BUILDING SIM ###"
	@make -C obj_dir -f V$(TOP).mk V$(TOP)

# Run Verilator to generate simulation build files
$(VERILATE_STAMP): src/$(TOP).sv tb/$(TB).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace -cc src/$(TOP).sv --exe tb/$(TB).cpp --build -CFLAGS "-DVL_DEBUG"
	@touch $(VERILATE_STAMP)

# View waveform
waves: $(VCD)
	@echo
	@echo "### WAVES ###"
	gtkwave $(VCD)

# Lint only
lint: src/$(TOP).sv
	verilator --lint-only src/$(TOP).sv

# Clean all generated files
clean:
	rm -rf $(VERILATE_STAMP) $(VCD) obj_dir


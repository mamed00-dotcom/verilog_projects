#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vcounter.h"

// Define max simulation time
#define MAX_SIM_TIME 100

// Global simulation time
vluint64_t sim_time = 0;

int main(int argc, char **argv) {
    // Initialize Verilator and handle command line arguments
    Verilated::commandArgs(argc, argv);

    // Create an instance of the compiled DUT module
    Vcounter *dut = new Vcounter;

    // --- Waveform tracing setup ---
    Verilated::traceEverOn(true); // Enable tracing globally
    VerilatedVcdC *m_trace = new VerilatedVcdC; // Create VCD trace object
    dut->trace(m_trace, 5); // Attach trace to DUT (5 levels deep)
    m_trace->open("waveform.vcd"); // Open the VCD file for writing
    // --- End waveform tracing setup ---

    // Simulation loop
    while (sim_time < MAX_SIM_TIME) {
        // Clock generation: 10 time unit period
        dut->clk = (sim_time % 10) < 5;

        // --- Stimulus ---
        dut->reset  = (sim_time < 20);  // Apply reset for first 20 time units
        dut->enable = (sim_time >= 30); // Enable after time 30

        // Evaluate DUT
        dut->eval();

        // Monitoring: check on positive clock edges after enable
        if (dut->clk == 1 && sim_time % 10 == 0 && sim_time >= 30) {
            std::cout << "Time " << sim_time << ": count = " << (int)dut->count << std::endl;
        }

        // Dump waveform
        m_trace->dump(sim_time);

        // Increment time
        sim_time++;
    }

    // Cleanup
    m_trace->close();
    delete dut;

    std::cout << "Simulation finished." << std::endl;
    return 0;
}


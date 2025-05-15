#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vupdown_counter.h"

#define MAX_SIM_TIME 200
vluint64_t sim_time = 0;

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vupdown_counter* dut = new Vupdown_counter;

    Verilated::traceEverOn(true);
    VerilatedVcdC* trace = new VerilatedVcdC;
    dut->trace(trace, 5);
    trace->open("waveform.vcd");

    while (sim_time < MAX_SIM_TIME) {
        // Generate clock: 10 unit period
        dut->clk = (sim_time % 10) < 5;

        // Reset for first 20 time units
        dut->reset = (sim_time < 20);

        // Enable after 30 time units
        dut->enable = (sim_time >= 30);

        // Switch between up/down every 50 units
        dut->up_down = (sim_time / 50) % 2;

        dut->eval();

        if (dut->clk && sim_time % 10 == 0 && sim_time >= 30) {
            std::cout << "Time " << sim_time << ": count = " << (int)dut->count
                      << " (up_down = " << dut->up_down << ")\n";
        }

        trace->dump(sim_time);
        sim_time++;
    }

    trace->close();
    delete dut;
    std::cout << "Simulation finished." << std::endl;
    return 0;
}


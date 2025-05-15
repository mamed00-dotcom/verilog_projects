#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <vector>
#include <iomanip>
#include <cstdlib>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VFemtoRV32.h"

#define MAX_SIM_TIME 1000
vluint64_t sim_time = 0;
vluint64_t posedge_cnt = 0;

// Memory contents
std::vector<uint32_t> memory;

// Debug function to print instruction details
void print_instruction(uint32_t instr) {
    std::cout << "Instruction: 0x" << std::hex << std::setw(8) << std::setfill('0') << instr << " (";
    
    uint32_t opcode = instr & 0x7F;
    uint32_t rd = (instr >> 7) & 0x1F;
    uint32_t rs1 = (instr >> 15) & 0x1F;
    uint32_t rs2 = (instr >> 20) & 0x1F;
    uint32_t funct3 = (instr >> 12) & 0x7;
    
    switch(opcode) {
        case 0x13: // I-type
            std::cout << "I-type, rd=x" << std::dec << rd << ", rs1=x" << rs1;
            break;
        case 0x33: // R-type
            std::cout << "R-type, rd=x" << std::dec << rd << ", rs1=x" << rs1 << ", rs2=x" << rs2;
            break;
        case 0x23: // S-type
            std::cout << "S-type, rs1=x" << std::dec << rs1 << ", rs2=x" << rs2;
            break;
        case 0x63: // B-type
            std::cout << "B-type, rs1=x" << std::dec << rs1 << ", rs2=x" << rs2;
            break;
        case 0x37: // LUI
            std::cout << "LUI, rd=x" << std::dec << rd;
            break;
        case 0x17: // AUIPC
            std::cout << "AUIPC, rd=x" << std::dec << rd;
            break;
        case 0x6F: // JAL
            std::cout << "JAL, rd=x" << std::dec << rd;
            break;
        case 0x67: // JALR
            std::cout << "JALR, rd=x" << std::dec << rd << ", rs1=x" << rs1;
            break;
        default:
            std::cout << "Unknown opcode";
    }
    std::cout << ")" << std::endl;
}

// Load memory from hex file
void load_memory(const std::string& filename) {
    std::ifstream file(filename);
    std::string line;
    
    if (!file.is_open()) {
        std::cerr << "Warning: Could not open " << filename << ". Using default memory contents." << std::endl;
        // Add some default instructions
        memory = {
            0x00000013,  // nop
            0x00500113,  // addi x2, x0, 5
            0x00300193,  // addi x3, x0, 3
            0x003100b3   // add x4, x2, x3
        };
        return;
    }
    
    while (std::getline(file, line)) {
        // Skip empty lines and comments
        if (line.empty() || line[0] == '#') continue;
        
        // Convert hex string to integer
        uint32_t value = std::stoul(line, nullptr, 16);
        memory.push_back(value);
        std::cout << "Loaded instruction: 0x" << std::hex << std::setw(8) << std::setfill('0') << value << std::endl;
    }
    
    // Pad memory to at least 1024 words
    while (memory.size() < 1024) {
        memory.push_back(0x00000013);  // nop
    }
}

int main(int argc, char** argv, char** env) {
    // Load memory contents
    load_memory("memory.hex");
    
    Verilated::commandArgs(argc, argv);
    VFemtoRV32 *dut = new VFemtoRV32;

    // Initialize all signals to known states
    dut->clk = 0;
    dut->reset = 0;  // Start in reset
    dut->mem_rdata = 0x00000013;  // NOP
    dut->mem_rbusy = 0;
    dut->mem_wbusy = 0;
    
    Verilated::traceEverOn(true);
    VerilatedVcdC *m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    std::cout << "\nStarting simulation...\n" << std::endl;

    // Reset sequence
    for(int i = 0; i < 10; i++) {
        dut->clk = !dut->clk;
        dut->eval();
        m_trace->dump(sim_time++);
    }
    dut->reset = 1;  // Release reset

    while (sim_time < MAX_SIM_TIME) {
        // Toggle clock
        dut->clk ^= 1;
        
        // Evaluate DUT
        dut->eval();

        if (dut->clk == 1) {
            posedge_cnt++;
            
            // Debug output
            std::cout << "\nCycle " << std::dec << posedge_cnt 
                     << " (sim_time=" << sim_time << "):" << std::endl;
            std::cout << "  PC: 0x" << std::hex << dut->mem_addr << std::endl;
            std::cout << "  Reset: " << std::dec << (int)dut->reset << std::endl;
            std::cout << "  mem_rstrb: " << std::dec << (int)dut->mem_rstrb << std::endl;
            
            // Handle memory reads
            if (dut->mem_rstrb) {
                uint32_t addr = dut->mem_addr >> 2;
                if (addr < memory.size()) {
                    dut->mem_rdata = memory[addr];
                    std::cout << "  Memory read at 0x" << std::hex << dut->mem_addr 
                             << " = 0x" << std::setw(8) << std::setfill('0') << dut->mem_rdata << std::endl;
                    print_instruction(dut->mem_rdata);
                } else {
                    dut->mem_rdata = 0x00000013;  // NOP for out-of-bounds
                    std::cout << "  Memory read out of bounds at 0x" << std::hex << dut->mem_addr 
                             << ", returning NOP" << std::endl;
                }
            }

            // Handle memory writes
            if (dut->mem_wmask) {
                uint32_t addr = dut->mem_addr >> 2;
                if (addr < memory.size()) {
                    uint32_t mask = 0;
                    for (int i = 0; i < 4; i++) {
                        if (dut->mem_wmask & (1 << i)) {
                            mask |= 0xFF << (8 * i);
                        }
                    }
                    memory[addr] = (memory[addr] & ~mask) | (dut->mem_wdata & mask);
                    std::cout << "  Memory write at 0x" << std::hex << dut->mem_addr 
                             << " = 0x" << std::setw(8) << std::setfill('0') << dut->mem_wdata 
                             << " (mask: 0x" << std::setw(1) << dut->mem_wmask << ")" << std::endl;
                }
            }

            // Check for traps
            if (dut->trap) {
                std::cout << "\nTrap occurred at cycle " << std::dec << posedge_cnt << std::endl;
                std::cout << "Trap Cause: 0x" << std::hex << (int)dut->trap_cause << std::endl;
                std::cout << "Current PC: 0x" << std::hex << dut->mem_addr << std::endl;
                break;
            }
        }

        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    
    std::cout << "\nSimulation finished after " << std::dec << posedge_cnt << " cycles" << std::endl;
    exit(EXIT_SUCCESS);
}

// Firmware generation flags for this processor 

`define NRV_ARCH  "rv32i"
`define NRV_ABI   "ilp32"
`define NRV_OPTIMIZE  "-OS"


module FemtoRV32(
	input clk,
	
	output reg [31:0] mem_addr, //adress bus 
	output [31:0] mem_wdata, //data to be written
	output reg [3:0] mem_wmask, // write mask for the 4 bytes of each word
	input [31:0] mem_rdata, //input lines for both data and instr
	output reg mem_rstrb, //active to initiate memory read (used by IO)
	input mem_rbusy, //asseted if memory is busy reading value 
	input mem_wbusy, //asserted if memory is busy writing value
	
	input reset, // set to 0 to reset the processor 
	
	// Trap output signals
	output reg trap,
	output reg [3:0] trap_cause
	);
	
	parameter RESET_ADDR = 32'h00000000;
	
	// PMP Configuration
	parameter NUM_PMP_ENTRIES = 4; // Number of PMP entries (typically 4, 8, or 16)
	
	// PMP CSRs
	reg [31:0] pmpcfg    [0:0];  // PMP configuration registers (only using first entry)
	reg [31:0] pmpaddr   [3:0];  // PMP address registers (4 entries)
	
	// PMP entry configuration fields
	wire [7:0] pmpcfg_entry [3:0];  // 4 entries
	
	genvar i;
	integer j, k;  // Declare loop variables at the module level for all uses
	
	generate
		for(i = 0; i < 4; i = i + 1) begin : PMP_CFG_DECODE
			assign pmpcfg_entry[i] = pmpcfg[0][8*i +: 8];
		end
	endgenerate
	
	// PMP Configuration bits per entry
	// pmpcfg_entry[i][7]    = Lock (L)
	// pmpcfg_entry[i][6:5]  = Reserved
	// pmpcfg_entry[i][4:3]  = Address matching mode (A)
	// pmpcfg_entry[i][2]    = Execute permission (X)
	// pmpcfg_entry[i][1]    = Write permission (W)
	// pmpcfg_entry[i][0]    = Read permission (R)
	
	// PMP address matching logic
	reg [2:0] pmp_priv;
	
	always @(*) begin
		// Default values
		pmp_priv = 3'b000; // No permissions by default
		
		for(j = 0; j < NUM_PMP_ENTRIES; j = j + 1) begin
			// Check if address matches this PMP entry
			case(pmpcfg_entry[j][4:3]) // A field
				2'b00: begin // OFF - Null region
					// No address matching
				end
				2'b01: begin // TOR - Top of range
					if(mem_addr >= (j == 0 ? 32'h0 : pmpaddr[j-1]) && 
					   mem_addr < pmpaddr[j]) begin
						pmp_priv = pmpcfg_entry[j][2:0];
					end
				end
				2'b10: begin // NA4 - Naturally aligned 4-byte region
					if(mem_addr[31:2] == pmpaddr[j][31:2]) begin
						pmp_priv = pmpcfg_entry[j][2:0];
					end
				end
				2'b11: begin // NAPOT - Naturally aligned power-of-two region
					// Calculate mask based on trailing zeros
					reg [31:0] mask;
					reg [4:0] trailing_zeros;
					
					// Count trailing zeros and build mask
					mask = 32'hFFFFFFFC; // Default 4-byte alignment
					trailing_zeros = 2;   // Start with minimum 4-byte alignment
					
					for(k = 2; k < 30 && pmpaddr[j][k] == 1'b0; k = k + 1) begin
						trailing_zeros = trailing_zeros + 1;
						mask = {mask[30:0], 1'b0};
					end
					
					// Check if address matches the masked region
					if((mem_addr & mask) == (pmpaddr[j] & mask)) begin
						pmp_priv = pmpcfg_entry[j][2:0];
					end
				end
				default: begin
					// No change to pmp_priv
				end
			endcase
		end
	end
	
	// PMP access control
	wire pmp_access_fault = 
		!reset && (  // Disable PMP checks during reset
			(state == FETCH_INSTR && !pmp_priv[2]) || // Execute fault
			(state == LOAD && !pmp_priv[0]) ||        // Read fault
			(state == STORE && !pmp_priv[1])          // Write fault
		);
	
	// CSR handling for PMP
	localparam CSR_PMPCFG0  = 12'h3A0;
	localparam CSR_PMPADDR0 = 12'h3B0;
	
	// Add to existing CSR handling logic in SYSTEM instruction
	wire [11:0] csr_addr = instr[31:20];
	wire csr_write = isSYSTEM && (funct3Is[1] || funct3Is[2] || funct3Is[3]);
	wire [31:0] csr_wdata = funct3Is[1] ? rs1 :           // CSRRW
				funct3Is[2] ? (rs1 | csr_rdata) :  // CSRRS
				funct3Is[3] ? (~rs1 & csr_rdata) : // CSRRC
				32'b0;
	
	// CSR read logic
	wire [31:0] csr_rdata = 
		(csr_addr == CSR_PMPCFG0) ? pmpcfg[0] :
		(csr_addr >= CSR_PMPADDR0 && 
		 csr_addr < CSR_PMPADDR0 + NUM_PMP_ENTRIES) ? 
			pmpaddr[csr_addr[1:0]] :  // Fixed index width
		32'b0;
	
	// CSR write logic
	always @(posedge clk) begin
		if (!reset) begin
			// Initialize PMP with basic permissions for instruction memory
			// Set first PMP entry to cover entire memory with RWX permissions using NAPOT mode
			pmpcfg[0] <= {24'b0, 8'b00011111};  // RWX permissions, NAPOT mode
			pmpaddr[0] <= 32'hFFFFFFFF;  // Cover entire address space
			for(k = 1; k < NUM_PMP_ENTRIES; k = k + 1)
				pmpaddr[k] <= 32'b0;
			for(k = 1; k < NUM_PMP_ENTRIES/4; k = k + 1)
				pmpcfg[k] <= 32'b0;
		end else if (csr_write) begin
			if(csr_addr == CSR_PMPCFG0)
				pmpcfg[0] <= csr_wdata;
			else if(csr_addr >= CSR_PMPADDR0 && 
				csr_addr < CSR_PMPADDR0 + NUM_PMP_ENTRIES)
				pmpaddr[csr_addr[1:0]] <= csr_wdata;  // Fixed index width
		end
	end

	// Modify memory access to check PMP permissions
	always @(*) begin
		// Default values
		mem_rstrb = ((state == FETCH_INSTR) || (state == LOAD)) && reset;
		mem_wmask =
			(state == STORE && reset) ?
			(funct3Is[0] ? (4'b0001 << aluPlus[1:0]) :  // SB
			 funct3Is[1] ? (4'b0011 << aluPlus[1:0]) :  // SH
			 funct3Is[2] ? 4'b1111 :                     // SW
			 4'b0000) : 4'b0000;
	end
	
	/*******************************************************************************************/
	// Instruction decoding.
	/*******************************************************************************************/
	
	//Extract rd,rs1,rs2,funct3,imm and opcode from instruction.
	// reference : table page 104 of : 
	// https://content.riscv.org/wp-content/uploads/2017/05/riscv-spec-v2.2.pdf
	
	// The destination register 
	
	wire [4:0] rdId = instr[11:7];
	
	//The ALU function, decoded in 1-hot form (doing so reduces LUT count)
	// It is used as follows: funtcIs[val] <=> funct3 == val
	
	(* onehot *)
	wire [7:0] funct3Is = 8'b00000001 << instr[14:12];
	
	// THE five immediate formats see, Riscv reference (link above), fig 2.4 p.12
	
	wire [31:0] Uimm = {	instr[31],	instr[30:12], {12{1'b0}}};
	wire [31:0] Iimm = {{21{instr[31]}},	instr[30:20]};
	/* verilator lint_off UNUSED */ // MSBs of SBJimms are not used by addr adder.
	
	wire [31:0] Simm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
	wire [31:0] Bimm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
	wire [31:0] Jimm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
	/* verilator lint_on UNUSED */
	
	// Base RISC-V (RV32I) has only 10 different instructions!
	wire isLoad    = (instr[6:2] == 5'b00000); // rd <- mem[rs1 + Iimm]
	wire isALUimm  = (instr[6:2] == 5'b00100); // rd <- rs1 OP Iimm
	wire isStore   = (instr[6:2] == 5'b01000); // mem[rs1 + Simm] <- rs2
	wire isALUreg  = (instr[6:2] == 5'b01100); // rd <- rs1 OP rs2
	wire isSYSTEM  = (instr[6:2] == 5'b11100); // rd <- cycles
	wire isJAL     = (instr[6:2] == 5'b11011); // rd <- PC+4; PC <- PC + Jimm
	wire isJALR    = (instr[6:2] == 5'b11001); // rd <- PC+4; PC <- rs1 + Iimm
	wire isLUI     = (instr[6:2] == 5'b01101); // rd <- Uimm
	wire isAUIPC   = (instr[6:2] == 5'b00101); // rd <- PC + Uimm
	wire isBranch  = (instr[6:2] == 5'b11000); // if (rs1 OP rs2) PC <- PC + Bimm

	wire isALU = isALUimm | isALUreg;
	
	/********************************************/
	// The register file.
	/********************************************/

	reg [31:0] rs1;
	reg [31:0] rs2;

	(* no_rw_check *)
	reg [31:0] registerFile [31:0];

	always @(posedge clk) begin
	    if (writeBack)
		if (rdId != 0)
		    registerFile[rdId] <= writeBackData;
	end
	
	/*********************************************/
	// The ALU. Does operations and tests combinatorially, except shifts.
	/*********************************************/

	// First ALU source, always rs1
	wire [31:0] aluIn1 = rs1;

	// Second ALU source, depends on opcode:
	//    ALUreg, Branch: rs2
	//    ALUimm, Load, JALR: Iimm
	wire [31:0] aluIn2 = isALUreg | isBranch ? rs2 : Iimm;

	reg  [31:0] aluReg;     // The internal shift register
	reg  [4:0]  aluShamt;   // Current shift amount

	wire aluBusy = |aluShamt; // ALU is busy if shifting
	wire aluWr;               // ALU write strobe, starts shifting

	// The adder is used by both arithmetic instructions and JALR
	wire [31:0] aluPlus = aluIn1 + aluIn2;

	// Use a single 33-bit subtract to do subtraction and all comparisons
	// (trick borrowed from swapforth/J1)
	wire [32:0] aluMinus = {1'b1, ~aluIn2} + {1'b0, aluIn1} + 33'b1;

	wire        LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
	wire        LTU = aluMinus[32];
	wire        EQ  = (aluMinus[31:0] == 0);

	// Notes:
	// - instr[30] is 1 for SUB and 0 for ADD
	// - for SUB, need to test also instr[5] to discriminate ADDI:
	//   (1 for ADD/SUB, 0 for ADDI, and Iimm used by ADDI overlaps bit 30!)
	// - instr[30] is 1 for SRA (do sign extension) and 0 for SRL

	wire [31:0] aluOut =
	    (funct3Is[0] ? (instr[30] & instr[5] ? aluMinus[31:0] : aluPlus) : 32'b0) |
	    (funct3Is[2] ? {31'b0, LT}  : 32'b0) |
	    (funct3Is[3] ? {31'b0, LTU} : 32'b0) |
	    (funct3Is[4] ? aluIn1 ^ aluIn2 : 32'b0) |
	    (funct3Is[6] ? aluIn1 | aluIn2 : 32'b0) |
	    (funct3Is[7] ? aluIn1 & aluIn2 : 32'b0) |
	    (funct3IsShift ? aluReg : 32'b0);

	wire funct3IsShift = funct3Is[1] | funct3Is[5];

	// ALU shift operation
	assign aluWr = (state == EXECUTE) && isALU && funct3IsShift;

	always @(posedge clk) begin
		if (aluWr) begin
			aluReg   <= aluIn1;
			aluShamt <= aluIn2[4:0];
		end else if (aluShamt != 0) begin
			aluShamt <= aluShamt - 1;
			case (1'b1)
				funct3Is[1]: aluReg <= {aluReg[30:0], 1'b0};                    // SLL
				funct3Is[5]: aluReg <= {(instr[30] & aluReg[31]), aluReg[31:1]}; // SRA/SRL
				default: aluReg <= aluReg;  // No change
			endcase
		end
	end

	// Program Counter and Instruction Fetch Logic
	reg [31:0] PC;
	reg [31:0] instr;
	
	// State machine
	reg [2:0] state;
	
	localparam FETCH_INSTR = 0;
	localparam WAIT_INSTR = 1;
	localparam DECODE     = 2;
	localparam EXECUTE    = 3;
	localparam WAIT_ALU   = 4;
	localparam LOAD       = 5;
	localparam WAIT_LOAD  = 6;
	localparam STORE      = 7;

	// Next PC computation
	wire [31:0] nextPC = (isJAL || isBranch) ? PC + (isJAL ? Jimm : Bimm) :
			     isJALR ? {aluPlus[31:1], 1'b0} :
			     PC + 4;

	// Branch condition
	wire takeBranch = isBranch && (
		(funct3Is[0] &&  EQ)  || // BEQ
		(funct3Is[1] && !EQ)  || // BNE
		(funct3Is[4] &&  LT)  || // BLT
		(funct3Is[5] && !LT)  || // BGE
		(funct3Is[6] &&  LTU) || // BLTU
		(funct3Is[7] && !LTU)    // BGEU
	);

	// State machine and control
	always @(posedge clk) begin
		if (!reset) begin
			PC    <= RESET_ADDR;
			state <= FETCH_INSTR;
			trap <= 0;
			trap_cause <= 4'b0;
			// Initialize PMP with basic permissions for instruction memory
			// Set first PMP entry to cover entire memory with RWX permissions using NAPOT mode
			pmpcfg[0] <= {24'b0, 8'b00011111};  // RWX permissions, NAPOT mode
			pmpaddr[0] <= 32'hFFFFFFFF;  // Cover entire address space
			for(k = 1; k < NUM_PMP_ENTRIES; k = k + 1)
				pmpaddr[k] <= 32'b0;
			for(k = 1; k < NUM_PMP_ENTRIES/4; k = k + 1)
				pmpcfg[k] <= 32'b0;
		end else begin
			case (state)
				FETCH_INSTR: begin
					mem_addr <= PC;
					if (!mem_rbusy) begin
						state <= WAIT_INSTR;
						trap <= 0;  // Clear any previous traps
					end
				end
				
				WAIT_INSTR: begin
					if (!mem_rbusy) begin
						instr <= mem_rdata;
						state <= DECODE;
					end
				end
				
				DECODE: begin
					rs1 <= registerFile[instr[19:15]];
					rs2 <= registerFile[instr[24:20]];
					state <= EXECUTE;
				end
				
				EXECUTE: begin
					if (isALU && funct3IsShift) begin
						state <= WAIT_ALU;
					end else if (isLoad) begin
						state <= LOAD;
					end else if (isStore) begin
						state <= STORE;
					end else begin
						if (isBranch && takeBranch || isJAL || isJALR) begin
							PC <= nextPC;
						end else if (!isBranch) begin
							PC <= nextPC;
						end
						state <= FETCH_INSTR;
					end
				end
				
				WAIT_ALU: begin
					if (!aluBusy) begin
						PC <= nextPC;
						state <= FETCH_INSTR;
					end
				end
				
				LOAD: begin
					mem_addr <= aluPlus;
					if (!mem_rbusy) begin
						state <= WAIT_LOAD;
					end
				end
				
				WAIT_LOAD: begin
					if (!mem_rbusy) begin
						PC <= nextPC;
						state <= FETCH_INSTR;
					end
				end
				
				STORE: begin
					if (!mem_wbusy) begin
						PC <= nextPC;
						state <= FETCH_INSTR;
					end
				end
				
				default: begin
					state <= FETCH_INSTR;
				end
			endcase
			
			// Handle PMP faults
			if (pmp_access_fault) begin
				trap <= 1;
				trap_cause <= (state == FETCH_INSTR) ? 4'h1 :  // Instruction access fault
							 (state == LOAD)         ? 4'h5 :  // Load access fault
							 (state == STORE)        ? 4'h7 :  // Store access fault
													4'h0;
				state <= FETCH_INSTR;  // Return to fetch on fault
			end
		end
	end

	// Memory interface signals
	assign mem_rstrb = ((state == FETCH_INSTR) || (state == LOAD)) && reset;
	
	// Load control
	wire [31:0] loadData =
		funct3Is[0] ? {{24{mem_rdata[7]}},  mem_rdata[7:0]} :  // LB
		funct3Is[1] ? {{16{mem_rdata[15]}}, mem_rdata[15:0]} : // LH
		funct3Is[2] ? mem_rdata :                               // LW
		funct3Is[4] ? {24'b0, mem_rdata[7:0]} :                // LBU
		funct3Is[5] ? {16'b0, mem_rdata[15:0]} :               // LHU
		32'b0;

	// Store control
	assign mem_wmask =
		(state == STORE && reset) ?
		(funct3Is[0] ? (4'b0001 << aluPlus[1:0]) :  // SB
		 funct3Is[1] ? (4'b0011 << aluPlus[1:0]) :  // SH
		 funct3Is[2] ? 4'b1111 :                     // SW
		 4'b0000) : 4'b0000;

	wire [31:0] storeData = 
		funct3Is[0] ? {4{rs2[7:0]}} :   // SB
		funct3Is[1] ? {2{rs2[15:0]}} :  // SH
		rs2;                            // SW

	assign mem_wdata = storeData << (8 * aluPlus[1:0]);

	// Write back data multiplexer
	wire [31:0] writeBackData =
		isLoad ? loadData :
		isJAL || isJALR ? PC + 4 :
		isLUI ? Uimm :
		isAUIPC ? PC + Uimm :
		isSYSTEM ? cycles :
		aluOut;

	wire writeBack = (state == EXECUTE && !isStore && !isLoad && !isBranch) ||
			(state == WAIT_ALU && !aluBusy) ||
			(state == WAIT_LOAD && !mem_rbusy);

	// Cycle counter (for SYSTEM instruction)
	reg [31:0] cycles;
	always @(posedge clk) begin
		cycles <= cycles + 1;
	end

	// Add to FemtoRV.v
`ifdef VERILATOR
  assert property (@(posedge clk) reset || !pmp_access_fault);
`endif

endmodule




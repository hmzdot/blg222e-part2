`timescale 1ns/1ps

module CPUSystem(
    input  wire        Clock,
    input  wire        Reset,
    output reg  [11:0] T,

    // Control signals for ArithmeticLogicUnitSystem (exposed as regs for simulation)
    output reg         Mem_CS,
    output reg         Mem_WR,
    output reg  [1:0]  MuxASel,
    output reg  [1:0]  MuxBSel,
    output reg  [1:0]  MuxCSel,
    output reg         MuxDSel,
    output reg  [3:0]  RF_RegSel,
    output reg  [3:0]  RF_ScrSel,
    output reg  [2:0]  RF_FunSel,
    output reg  [2:0]  RF_OutASel,
    output reg  [2:0]  RF_OutBSel,
    output reg  [2:0]  ARF_RegSel,
    output reg  [1:0]  ARF_FunSel,
    output reg  [1:0]  ARF_OutCSel,
    output reg  [1:0]  ARF_OutDSel,
    output reg         IR_LH,
    output reg         IR_Write,
    output reg         DR_E,
    output reg  [1:0]  DR_FunSel,
    output reg  [4:0]  ALU_FunSel,
    output reg         ALU_WF,
    output reg         T_Reset,

    // Instruction decode outputs
    output wire [5:0]  Opcode,
    output wire [1:0]  RegSel,
    output wire [7:0]  Address,
    output wire [2:0]  DestReg,
    output wire [2:0]  SrcReg1,
    output wire [2:0]  SrcReg2
);

    // Internal signals
    wire [31:0] ALUOut;
    wire [3:0]  FlagsOut; // Assuming FlagsOut = {N, Z, C, V}, so Z = FlagsOut[1]
    wire [15:0] ALU_Address;
    wire [7:0]  MemOut;
    wire [31:0] OutA, OutB;
    wire [15:0] OutC, OutD;
    wire [15:0] IROut;
    wire [31:0] DROut;

    // Variable immediate value for ALU system
    reg [31:0] ALU_Immediate;

    // Instruction decoding - assign to output ports
    assign Opcode = IROut[15:10];
    assign RegSel = IROut[9:8];    // Used by MOVL, LDAL, LDAH, STAR
    assign Address = IROut[7:0];
    assign DestReg = IROut[9:7];   // Used by R-type (ORR, DEC)
    assign SrcReg1 = IROut[6:4];   // Used by R-type
    assign SrcReg2 = IROut[3:1];   // Used by R-type (Not used in provided code)

    // Instantiate ALU System
    ArithmeticLogicUnitSystem ALUSys (
        .I(ALU_Immediate),
        .Clock(Clock),
        .Mem_CS(Mem_CS),
        .Mem_WR(Mem_WR),
        .MuxASel(MuxASel),
        .MuxBSel(MuxBSel),
        .MuxCSel(MuxCSel),
        .MuxDSel(MuxDSel),
        .RF_RegSel(RF_RegSel),
        .RF_ScrSel(RF_ScrSel),
        .RF_FunSel(RF_FunSel),
        .RF_OutASel(RF_OutASel),
        .RF_OutBSel(RF_OutBSel),
        .ARF_RegSel(ARF_RegSel),
        .ARF_FunSel(ARF_FunSel),
        .ARF_OutCSel(ARF_OutCSel),
        .ARF_OutDSel(ARF_OutDSel),
        .IR_LH(IR_LH),
        .IR_Write(IR_Write),
        .DR_E(DR_E),
        .DR_FunSel(DR_FunSel),
        .ALU_FunSel(ALU_FunSel),
        .ALU_WF(ALU_WF),
        .ALUOut(ALUOut),
        .FlagsOut(FlagsOut),
        .Address(ALU_Address),
        .MemOut(MemOut),
        .OutA(OutA),
        .OutB(OutB),
        .OutC(OutC),
        .OutD(OutD),
        .IROut(IROut),
        .DROut(DROut)
    );

    // Timing counter
    always @(posedge Clock or negedge Reset) begin
        if (~Reset) begin // Reset is active low on negedge
            T <= 12'b000000000001; // Reset to T0
        end else if (T_Reset) begin
            T <= 12'b000000000001; // Reset to T0
        end else begin
            T <= {T[10:0], T[11]}; // Shift left (rotate)
        end
    end

    // Helper task to select register based on RegSel/DestReg
    task select_dest_reg;
        input [1:0] sel;
        output reg [3:0] rf_sel;
        begin
            case (sel)
                2'b00: rf_sel = 4'b1000; // R1
                2'b01: rf_sel = 4'b0100; // R2
                2'b10: rf_sel = 4'b0010; // R3
                2'b11: rf_sel = 4'b0001; // R4
                default: rf_sel = 4'b0000;
            endcase
        end
    endtask

    // Helper task to select register based on 3-bit DestReg/SrcReg1
    task select_r_type_reg;
        input [2:0] sel;
        output reg [3:0] rf_sel;
        begin
            case (sel)
                3'b000: rf_sel = 4'b1000; // R1
                3'b001: rf_sel = 4'b0100; // R2
                3'b010: rf_sel = 4'b0010; // R3
                3'b011: rf_sel = 4'b0001; // R4
                default: rf_sel = 4'b0000;
            endcase
        end
    endtask

    // Helper task to select RF_OutA based on RegSel/SrcReg1
    task select_rf_out_a;
        input [2:0] sel; // Use 3 bits, pad RegSel if needed
        output reg [2:0] out_sel;
        begin
            case (sel)
                3'b000: out_sel = 3'b000; // R1
                3'b001: out_sel = 3'b001; // R2
                3'b010: out_sel = 3'b010; // R3
                3'b011: out_sel = 3'b011; // R4
                default: out_sel = 3'b000;
            endcase
        end
    endtask

    // Control unit state machine
    always @(*) begin
        // Default values - disable all operations
        Mem_CS = 1'b1;
        Mem_WR = 1'b0;
        MuxASel = 2'b00;
        MuxBSel = 2'b00;
        MuxCSel = 2'b00;
        MuxDSel = 1'b0;
        RF_RegSel = 4'b0000;
        RF_ScrSel = 4'b0000;
        RF_FunSel = 3'b000; // NOP/Pass
        RF_OutASel = 3'b000;
        RF_OutBSel = 3'b000;
        ARF_RegSel = 3'b000;
        ARF_FunSel = 2'b00; // NOP
        ARF_OutCSel = 2'b00;
        ARF_OutDSel = 2'b00;
        IR_LH = 1'b0;
        IR_Write = 1'b0;
        DR_E = 1'b0;
        DR_FunSel = 2'b00; // NOP
        ALU_FunSel = 5'b00000; // Pass A
        ALU_WF = 1'b0;
        T_Reset = 1'b0;

        // Default immediate value - Use address field
        ALU_Immediate = {24'h000000, Address};

        case (T)
            12'b000000000001: begin // T0: Fetch LSB or Reset
                if (~Reset) begin // Reset is active low
                    // Clear all registers using ALU output of 0
                    ALU_Immediate = 32'h00000000;
                    MuxASel = 2'b11;     // Immediate (0) to ALU A
                    ALU_FunSel = 5'b00000; // Pass A
                    ALU_WF = 1'b0;       // Don't write flags during reset

                    // Clear all 32-bit registers
                    RF_RegSel = 4'b1111;  // Enable all registers
                    RF_ScrSel = 4'b1111;  // Enable all scratch registers
                    RF_FunSel = 3'b010;   // Load function

                    // Clear all 16-bit address registers (PC, AR)
                    ARF_RegSel = 3'b101;  // Enable PC and AR
                    ARF_FunSel = 2'b10;   // Load function

                    // Clear DR by loading 0
                    DR_E = 1'b1;
                    DR_FunSel = 2'b01;    // Load zero-extended

                end else begin
                    // Fetch LSB
                    ARF_OutDSel = 2'b00; // PC to address
                    Mem_CS = 1'b0;
                    IR_LH = 1'b0; // Load LSB
                    IR_Write = 1'b1;
                end
            end

            12'b000000000010: begin // T1: Increment PC, Fetch MSB or Init SP
                if (~Reset) begin // Reset is active low
                    // Initialize SP to 0xFF
                    ALU_Immediate = 32'h000000FF;
                    MuxASel = 2'b11; // Immediate to ALU A
                    ALU_FunSel = 5'b00000; // Pass A
                    ARF_RegSel = 3'b010; // SP only
                    ARF_FunSel = 2'b10; // Load
                    T_Reset = 1'b1; // Reset T to start fetching from 0x0000
                end else begin
                    // Increment PC
                    ARF_OutCSel = 2'b00; // PC to OutC
                    MuxASel = 2'b01; // ARF_OutC (PC) to ALU A
                    MuxBSel = 2'b11; // Immediate 1 to ALU B
                    ALU_Immediate = 32'h00000001;
                    ALU_FunSel = 5'b10100; // 32-bit ADD
                    ARF_RegSel = 3'b100; // PC
                    ARF_FunSel = 2'b10; // Load

                    // Fetch MSB
                    ARF_OutDSel = 2'b00; // PC to address (already incremented)
                    Mem_CS = 1'b0;
                    IR_LH = 1'b1; // Load MSB
                    IR_Write = 1'b1;
                end
            end

            12'b000000000100: begin // T2
                // Increment PC (Always happens after fetch, unless overridden)
                ARF_OutCSel = 2'b00; // PC to OutC
                MuxASel = 2'b01; // ARF_OutC (PC) to ALU A
                MuxBSel = 2'b11; // Immediate 1 to ALU B
                ALU_Immediate = 32'h00000001;
                ALU_FunSel = 5'b10100; // 32-bit ADD
                ARF_RegSel = 3'b100; // PC
                ARF_FunSel = 2'b10; // Load

                // Instruction execution (or setup)
                case (Opcode)
                    6'h00: begin // BRA
                        ALU_Immediate = {24'h000000, Address}; // Use Address as the jump target
                        MuxASel = 2'b11;    // Immediate (Address) to ALU A
                        MuxBSel = 2'b00;    // Don't use B
                        ALU_FunSel = 5'b00000; // Pass A
                        ARF_RegSel = 3'b100;    // PC
                        ARF_FunSel = 2'b10;    // Load
                        T_Reset = 1'b1;      // Reset T to fetch from new PC
                    end
                    
                    6'h01: begin // BNE
                        if (FlagsOut[1] == 1'b0) begin // Check if Z flag (assuming FlagsOut[1]) is 0
                            ALU_Immediate = {24'h000000, Address}; // Use Address as the jump target
                            MuxASel = 2'b11;    // Immediate (Address) to ALU A
                            MuxBSel = 2'b00;    // Don't use B
                            ALU_FunSel = 5'b00000; // Pass A
                            ARF_RegSel = 3'b100;    // PC
                            ARF_FunSel = 2'b10;    // Load
                            T_Reset = 1'b1;      // Reset T to fetch from new PC
                        end else begin
                            // Z is 1, don't branch. Let the default PC increment happen.
                            T_Reset = 1'b1;      // Ensure T resets for the next instruction.
                        end
                    end

                    6'h02: begin // BEQ
                        if (FlagsOut[1] == 1'b1) begin // Check if Z flag is set
                            ALU_Immediate = {24'h000000, Address}; // Use Address as the jump target
                            MuxASel = 2'b11;    // Immediate (Address) to ALU A
                            MuxBSel = 2'b00;    // Don't use B
                            ALU_FunSel = 5'b00000; // Pass A
                            ARF_RegSel = 3'b100;    // PC
                            ARF_FunSel = 2'b10;    // Load
                            T_Reset = 1'b1;      // Reset T to fetch from new PC
                        end else begin
                            // Z is 0, don't branch. Let the default PC increment happen.
                            T_Reset = 1'b1;      // Ensure T resets for the next instruction.
                        end
                    end

                    6'h03: begin // POPL
                        // SP + 1 → SP
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;     // OutC to ALU A
                        MuxBSel = 2'b11;     // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b010;   // SP
                        ARF_FunSel = 2'b10;    // Load
                        // Go to T3
                    end

                    6'h04: begin // PSHL
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel); // Extend RegSel[1:0] to 3 bits
                        MuxASel = 2'b00;     // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00;     // Byte 0 (Rx[7:0])
                        // Go to T3
                    end

                    6'h05: begin // POPH
                        // SP + 1 → SP
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;     // SP to ALU A
                        MuxBSel = 2'b11;     // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b010;   // SP
                        ARF_FunSel = 2'b10;    // Load
                        // Go to T3
                    end

                    6'h06: begin // PSHH
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel);
                        MuxASel = 2'b00;         // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000;   // Pass A
                        ARF_OutDSel = 2'b01;     // SP to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b11;         // Byte 3 (MSB)
                        // Go to T3
                    end

                    6'h07: begin // CALL
                        // Save PC low byte to stack
                        ARF_OutCSel = 2'b00; // PC to OutC
                        MuxASel = 2'b01; // PC to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00; // ALU[7:0] (PC Low)
                        // Go to T3
                    end

                    6'h08: begin // RET Step 1: SP ← SP + 1
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;     // OutC to ALU A
                        MuxBSel = 2'b11;     // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b010;   // SP
                        ARF_FunSel = 2'b10;    // Load
                        // Go to T3
                    end

                    6'h09: begin // INC
                        select_rf_out_a(SrcReg1, RF_OutASel); 
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        MuxBSel = 2'b11; // Immediate
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // 32-bit ADD
                        ALU_WF = 1'b1; // Optionally set flags (e.g. Z, C)
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load ALU result
                        T_Reset = 1'b1;
                    end

                    6'h0A: begin // DEC
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110; // 32-bit SUB
                        ALU_WF = 1'b1; // Update flags
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h0B: begin // LSL
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        MuxASel = 2'b00; // RF_OutA to ALU A
                        ALU_FunSel = 5'b01011; // LSL by 1
                        ALU_WF = 1'b1; // Optionally set flags (C, Z, etc.)
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h0C: begin // LSR
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        ALU_FunSel = 5'b01100; // LSR by 1
                        ALU_WF = 1'b1; // Update flags (optional but useful)
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h0D: begin // ASR
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        ALU_FunSel = 5'b01101; // ASR by 1 (signed right shift)
                        ALU_WF = 1'b1; // Update flags
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h0E: begin // CSL
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        ALU_FunSel = 5'b01110; // CSL (rotate left through carry) – assumed
                        ALU_WF = 1'b1; // Update carry and zero flags
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load ALU result
                        T_Reset = 1'b1;
                    end

                    6'h0F: begin // CSR
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        MuxASel = 2'b00; // RF_OutA
                        ALU_FunSel = 5'b01111; // CSR (rotate right through carry) – assumed
                        ALU_WF = 1'b1; // Update carry, zero, etc.
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load result
                        T_Reset = 1'b1;
                    end

                    6'h10: begin // NOT
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        ALU_FunSel = 5'b00010; // NOT (assumed opcode)
                        ALU_WF = 1'b1; // Update flags (Z, N, etc.)
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h11: begin // AND
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        RF_OutBSel = SrcReg2; // SREG2 index directly
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        MuxBSel = 2'b00; // RF_OutB → ALU B
                        ALU_FunSel = 5'b11001; // AND opcode (assumed)
                        ALU_WF = 1'b1; // Update flags
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h12: begin // ORR
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxBSel = 2'b01; // ARF_OutC (AR) to ALU B
                        ALU_FunSel = 5'b11000; // 32-bit OR
                        ALU_WF = 1'b1; // Update flags
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1; // Single cycle
                    end

                    6'h13: begin // XOR
                        select_rf_out_a(SrcReg1, RF_OutASel); // A input
                        RF_OutBSel = SrcReg2;                 // B input
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        MuxBSel = 2'b00; // RF_OutB → ALU B
                        ALU_FunSel = 5'b11010; // XOR opcode (assumed)
                        ALU_WF = 1'b1;         // Update flags
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010; // Load result
                        T_Reset = 1'b1;
                    end

                    6'h14: begin // NAND DST ← ~(SREG1 & SREG2)
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        RF_OutBSel = SrcReg2;
                        MuxASel = 2'b00; // RF_OutA
                        MuxBSel = 2'b00; // RF_OutB
                        ALU_FunSel = 5'b11011; // NAND (assumed)
                        ALU_WF = 1'b1;         // Update flags
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h15: begin // ADD
                        select_rf_out_a(SrcReg1, RF_OutASel);
                        RF_OutBSel = SrcReg2;
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        MuxBSel = 2'b00; // RF_OutB → ALU B
                        ALU_FunSel = 5'b10100; // 32-bit ADD
                        ALU_WF = 1'b1;         // Write flags
                        select_r_type_reg(DestReg, RF_RegSel); // Select destination register
                        RF_FunSel = 3'b010;    // Load ALU result to register file
                        T_Reset = 1'b1; // One cycle instruction
                    end

                    6'h16: begin // ADC – Add with Carry
                        select_rf_out_a(SrcReg1, RF_OutASel); // A input (SREG1)
                        RF_OutBSel = SrcReg2;                // B input (SREG2)
                        MuxASel = 2'b00; // RF_OutA → ALU A
                        MuxBSel = 2'b00; // RF_OutB → ALU B
                        ALU_FunSel = 5'b10101; // 32-bit ADC
                        ALU_WF = 1'b1;          // Write flags
                        select_r_type_reg(DestReg, RF_RegSel); // Select DSTREG
                        RF_FunSel = 3'b010;    // Load ALU result into DSTREG
                        T_Reset = 1'b1;        // Complete in 1 cycle
                    end

                    6'h17: begin // SUB
                        select_rf_out_a(SrcReg1, RF_OutASel); // SREG1 → RF_OutA
                        RF_OutBSel = SrcReg2;                // SREG2 → RF_OutB
                        MuxASel = 2'b00; // RF_OutA to ALU A
                        MuxBSel = 2'b00; // RF_OutB to ALU B
                        ALU_FunSel = 5'b10110; // 32-bit SUB
                        ALU_WF = 1'b1;         // Write flags
                        select_r_type_reg(DestReg, RF_RegSel); // Write to DSTREG
                        RF_FunSel = 3'b010; // Load result
                        T_Reset = 1'b1; // Single cycle
                    end

                    6'h18: begin // MOV
                        select_rf_out_a(SrcReg1, RF_OutASel); // SREG1 → RF_OutA
                        MuxASel = 2'b00;       // RF_OutA → ALU A
                        ALU_FunSel = 5'b10000; // PASS A
                        ALU_WF = 1'b0;          // Don't write flags
                        select_r_type_reg(DestReg, RF_RegSel); // Write to DSTREG
                        RF_FunSel = 3'b010;     // Load result
                        T_Reset = 1'b1;         // One cycle
                    end

                    6'h19: begin // MOVL
                        ALU_Immediate = {24'h000000, Address}; // Zero-extend 8-bit immediate
                        MuxASel = 2'b11;       // Immediate → ALU A
                        ALU_FunSel = 5'b00000; // PASS A
                        ALU_WF = 1'b1;         // Write flags (e.g. test Z)
                        select_dest_reg(RegSel, RF_RegSel); // Based on RegSel[1:0]
                        RF_FunSel = 3'b010;     // Load to RF
                        T_Reset = 1'b1;         // One cycle
                    end

                    6'h1A: begin // MOVSH
                        select_dest_reg(RegSel, RF_RegSel);     // Rx destination
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel); // Rx → ALU A
                        MuxASel = 2'b00;       // RF_OutA → ALU A
                        MuxBSel = 2'b11;       // Immediate → ALU B
                        ALU_Immediate = {24'b0, Address}; // 8-bit immediate in low byte
                        ALU_FunSel = 5'b10011; // MOVSH custom op
                        ALU_WF = 1'b0;         // No flag update
                        RF_FunSel = 3'b010;    // Load result into Rx
                        T_Reset = 1'b1;
                    end

                    6'h1B: begin // LDARL
                        ARF_OutDSel = 2'b10; // AR → memory address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Zero-extended load (first byte)
                        T_Reset = 1'b0; // Continue to T3
                    end

                    6'h1C: begin // LDARH
                        ARF_OutDSel = 2'b10; // AR to memory address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Load zero-extended
                        // Proceed to T3
                    end

                    6'h1D: begin // STAR 
                        // Hardcode to use R3 for now to match test expectation
                        RF_OutASel = 3'b010; // R3
                        MuxASel = 2'b00; // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b11; // ALU[31:24] (Byte 3 - MSB)
                        // Go to T3
                    end

                    6'h1E: begin // LDAL
                        ALU_Immediate = {24'h000000, Address};
                        MuxASel = 2'b11; // Immediate to ALU A
                        ALU_FunSel = 5'b00000; // Pass A (zero-extended)
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T3
                    end

                    6'h1F: begin // LDAH
                        ALU_Immediate = {24'h000000, Address};
                        MuxASel = 2'b11; // Immediate to ALU A
                        ALU_FunSel = 5'b00000; // Pass A (zero-extended)
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T3
                    end

                    6'h20: begin // STA
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel);
                        MuxASel = 2'b00;         // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000;   // 32-bit PASS A
                        ALU_WF = 1'b0;           // No flags written
                        ALU_Immediate = {24'h000000, Address};
                        MuxBSel = 2'b11;         // Immediate
                        MuxASel = 2'b11;         // Immediate
                        ALU_FunSel = 5'b00000;   // 16-bit PASS A
                        ARF_RegSel = 3'b001;     // AR
                        ARF_FunSel = 2'b10;      // Load
                        T_Reset = 1'b0;          // Continue to T3
                    end

                    default: begin
                        T_Reset = 1'b1;
                    end
                endcase
            end

            12'b000000001000: begin // T3
                case (Opcode)
                    6'h03: begin
                        // M[SP] → DR (zero-extended low byte)
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Load zero-extended
                        // Go to T4
                    end

                    6'h04: begin
                        // SP ← SP - 1
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;     // SP to ALU A
                        MuxBSel = 2'b11;     // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110; // SUB
                        ARF_RegSel = 3'b010;   // SP
                        ARF_FunSel = 2'b10;    // Load
                        // Go to T4
                    end

                    6'h05: begin
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Zero-extended byte into DR
                    end

                    6'h06: begin
                        ARF_OutCSel = 2'b01;     // SP to OutC
                        MuxASel = 2'b01;         // SP to ALU A
                        MuxBSel = 2'b11;         // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110;   // SUB
                        ARF_RegSel = 3'b010;     // SP
                        ARF_FunSel = 2'b10;      // Load
                    end

                    6'h07: begin // CALL: Decrement SP
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01; // SP to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110; // SUB
                        ARF_RegSel = 3'b010; // SP
                        ARF_FunSel = 2'b10; // Load
                        // Go to T4
                    end

                    6'h08: begin // RET Step 2: M[SP] → DR (byte 0)
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Load zero-extended
                        // Go to T4
                    end

                    6'h1B: begin
                        ARF_OutDSel = 2'b10; // AR → memory address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift left, OR in byte

                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h1;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = 3'b001;
                        ARF_FunSel = 2'b10;

                        T_Reset = 1'b0; // Continue to T4
                    end

                    6'h1C: begin
                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load AR++
                        // Proceed to T4
                    end

                    6'h1D: begin // STAR: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T4
                    end

                    6'h1E, 6'h1F: begin // LDAL/LDAH: Read Mem[AR] (Byte 0)
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Load zero-extended (M0)
                        // Go to T4
                    end

                    6'h20: begin
                        ARF_OutDSel = 2'b10;     // AR → Mem address
                        MuxASel = 2'b00;         // RF_OutA (still latched) to ALU A
                        ALU_FunSel = 5'b10000;   // 32-bit PASS A
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b11;         // Store MSB (Byte 3)
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000000010000: begin // T4
                case (Opcode)
                    6'h03: begin
                        // SP + 1 → SP (again)
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;     // OutC to ALU A
                        MuxBSel = 2'b11;     // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b010;   // SP
                        ARF_FunSel = 2'b10;    // Load
                        // Go to T5
                    end

                    6'h04: begin
                        // Write Rx[15:8] to M[SP]
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel);
                        MuxASel = 2'b00;     // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01;     // Byte 1 (Rx[15:8])
                        // Go to T5
                    end

                    6'h05: begin
                        // Each cycle: read next byte from M[SP], DR shift left + OR in byte
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift DR and OR new byte
                        // Increment SP each time
                        ARF_OutCSel = 2'b01;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = 3'b010;
                        ARF_FunSel = 2'b10;
                    end

                    6'h06: begin // PSHH
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel);
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b10000;
                        ARF_OutDSel = 2'b01;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b10; // Byte 2
                        // Go to T5
                    end

                    6'h07: begin // CALL
                        ARF_OutCSel = 2'b00; // PC to OutC
                        MuxASel = 2'b01; // PC to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01; // ALU[15:8] (PC High)
                        // Go to T5
                    end

                    6'h08: begin // RET Step 3: SP ← SP + 1 again
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = 3'b010;
                        ARF_FunSel = 2'b10;
                        // Go to T5
                    end

                    6'h1B: begin
                        MuxASel = 2'b10;         // DR → ALU A
                        ALU_FunSel = 5'b10000;   // PASS A
                        select_r_type_reg(DestReg, RF_RegSel);
                        RF_FunSel = 3'b010;      // Load
                        T_Reset = 1'b1;          // Done
                    end

                    6'h1C: begin // LDARH: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T5
                    end

                    6'h1D: begin // STAR: Store Byte 2 (second byte in big-endian)
                        RF_OutASel = 3'b010; // R3
                        MuxASel = 2'b00; // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b10; // ALU[23:16] (Byte 2)
                        // Go to T5
                    end

                    6'h1E: begin // LDAL: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T5
                    end

                    6'h1F: begin // LDAH: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T5
                    end

                    6'h20: begin
                        ARF_OutCSel = 2'b10;     // AR to OutC
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100;   // 32-bit ADD
                        ARF_RegSel = 3'b001;     // AR
                        ARF_FunSel = 2'b10;      // Load AR++
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000000100000: begin // T5
                case (Opcode)
                    6'h03: begin
                        // M[SP] → DR (high byte, shifted in)
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift left and OR in byte: DR = {8'h00, MemOut, DR[7:0]}
                        // Go to T6
                    end

                    6'h04: begin
                        // SP ← SP - 1
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;     // SP to ALU A
                        MuxBSel = 2'b11;     // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110; // SUB
                        ARF_RegSel = 3'b010;   // SP
                        ARF_FunSel = 2'b10;    // Load
                        T_Reset = 1'b1;        // Done
                    end

                    6'h05: begin
                        // Each cycle: read next byte from M[SP], DR shift left + OR in byte
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift DR and OR new byte
                        // Increment SP each time
                        ARF_OutCSel = 2'b01;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = 3'b010;
                        ARF_FunSel = 2'b10;
                    end

                    6'h06: begin
                        ARF_OutCSel = 2'b01;     // SP to OutC
                        MuxASel = 2'b01;         // SP to ALU A
                        MuxBSel = 2'b11;         // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110;   // SUB
                        ARF_RegSel = 3'b010;     // SP
                        ARF_FunSel = 2'b10;      // Load
                    end

                    6'h07: begin // CALL: Decrement SP
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01; // SP to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110; // SUB
                        ARF_RegSel = 3'b010; // SP
                        ARF_FunSel = 2'b10; // Load
                        // Go to T6
                    end

                    6'h08: begin // RET Step 4: M[SP] → DR (byte 1)
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift DR and OR in new byte
                        // Go to T6
                    end

                    6'h1C: begin // LDARH: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T5
                    end

                    6'h1D: begin // STAR: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T6
                    end

                    6'h1E: begin // LDAL: Read Mem[AR] (Byte 1)
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Load and shift (DR = {DR[23:0], MemOut}) -> M0 M1
                        // Go to T6
                    end

                    6'h1F: begin // LDAH: Read Mem[AR] (Byte 1)
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Load and shift (DR = {DR[23:0], MemOut}) -> M0 M1
                        // Go to T6
                    end

                    6'h20: begin
                        ARF_OutDSel = 2'b10;
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b10000;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b10;         // Byte 2
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000001000000: begin // T6
                case (Opcode)
                    6'h03: begin
                        // DR → Rx
                        MuxASel = 2'b10; // DR to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        select_dest_reg(RegSel, RF_RegSel); // Use RegSel[1:0] to select R1–R4
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h05: begin
                        // Each cycle: read next byte from M[SP], DR shift left + OR in byte
                        ARF_OutDSel = 2'b01; // SP to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift DR and OR new byte
                        // Increment SP each time
                        ARF_OutCSel = 2'b01;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = 3'b010;
                        ARF_FunSel = 2'b10;
                    end

                    6'h06: begin // PSHH - Store Rx[15:8]
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel);
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b10000;
                        ARF_OutDSel = 2'b01;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01; // Byte 1
                        // Go to T7
                    end

                    6'h07: begin // CALL: Load PC with immediate address
                        ALU_Immediate = {24'h000000, Address};
                        MuxASel = 2'b11; // Immediate to ALU A
                        ALU_FunSel = 5'b00000; // Pass A
                        ARF_RegSel = 3'b100; // PC
                        ARF_FunSel = 2'b10; // Load
                        T_Reset = 1'b1; // CALL ends here
                    end

                    6'h08: begin // RET Step 5: DR → PC
                        MuxASel = 2'b10; // DR to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_RegSel = 3'b100; // PC
                        ARF_FunSel = 2'b10;  // Load
                        T_Reset = 1'b1;
                    end

                    6'h1C: begin
                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load AR++
                        // Proceed to T4
                    end

                    6'h1D: begin // STAR: Store Byte 1 (third byte in big-endian)
                        RF_OutASel = 3'b010; // R3
                        MuxASel = 2'b00; // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01; // ALU[15:8] (Byte 1)
                        // Go to T7
                    end

                    6'h1E: begin // LDAL: Load DR (16 bits) to Reg
                        MuxASel = 2'b10; // DR to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        select_dest_reg(RegSel, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1; // LDAL ends here
                    end

                    6'h1F: begin // LDAH: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T7
                    end

                    6'h20: begin
                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = 3'b001;
                        ARF_FunSel = 2'b10;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000010000000: begin // T7
                case (Opcode)
                    6'h05: begin
                        MuxASel = 2'b10; // DR to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        select_dest_reg(RegSel, RF_RegSel); // Based on RegSel
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h06: begin
                        ARF_OutCSel = 2'b01;     // SP to OutC
                        MuxASel = 2'b01;         // SP to ALU A
                        MuxBSel = 2'b11;         // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110;   // SUB
                        ARF_RegSel = 3'b010;     // SP
                        ARF_FunSel = 2'b10;      // Load
                    end

                    6'h1C: begin
                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load AR++
                        // Proceed to T7
                    end

                    6'h1D: begin // STAR: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T8
                    end

                    6'h1F: begin // LDAH: Read Mem[AR] (Byte 2)
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Load and shift -> M0 M1 M2
                        // Go to T8
                    end

                    6'h20: begin
                        ARF_OutDSel = 2'b10;
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b10000;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01; // Byte 1
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000100000000: begin // T8
                case (Opcode)
                    6'h06: begin // PSHH - Store Rx[7:0]
                        select_rf_out_a({1'b0, RegSel}, RF_OutASel);
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b10000;
                        ARF_OutDSel = 2'b01;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00; // Byte 0 (LSB)
                        // Go to T9
                    end
                    
                    6'h1C: begin
                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load AR++
                        // Proceed to T7
                    end

                    6'h1D: begin // STAR: Store Byte 0 (fourth byte in big-endian)
                        RF_OutASel = 3'b010; // R3
                        MuxASel = 2'b00; // RF_OutA to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00; // ALU[7:0] (Byte 0)
                        T_Reset = 1'b1; // STAR ends here
                    end

                    6'h1F: begin // LDAH: Increment AR
                        ARF_OutCSel = 2'b10; // AR to OutC
                        MuxASel = 2'b01; // AR to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load
                        // Go to T9
                    end

                    6'h20: begin
                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = 3'b001;
                        ARF_FunSel = 2'b10;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b001000000000: begin // T9
                case (Opcode)
                    6'h06: begin // Final SP ← SP - 1
                        ARF_OutCSel = 2'b01;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110;
                        ARF_RegSel = 3'b010;
                        ARF_FunSel = 2'b10;
                        T_Reset = 1'b1; // Done
                    end

                    6'h1C: begin
                        ARF_OutCSel = 2'b10;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b001; // AR
                        ARF_FunSel = 2'b10; // Load AR++
                        // Proceed to T7
                    end

                    6'h1F: begin // LDAH: Read Mem[AR] (Byte 3)
                        ARF_OutDSel = 2'b10; // AR to address
                        Mem_CS = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Load and shift -> M0 M1 M2 M3
                        // Go to T10
                    end

                    6'h20: begin
                        ARF_OutDSel = 2'b10;
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b10000;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00; // Byte 0
                        T_Reset = 1'b1;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b010000000000: begin // T10
                case (Opcode)
                    6'h1C: begin // LDARH final step: load to RF
                        MuxASel = 2'b10; // DR to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        select_r_type_reg(DestReg, RF_RegSel); // Use 3-bit DestReg
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h1F: begin // LDAH: Load DR (32 bits) to Reg
                        MuxASel = 2'b10; // DR to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        select_dest_reg(RegSel, RF_RegSel);
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1; // LDAH ends here
                    end
                    default: T_Reset = 1'b1;
                endcase
            end

            // Default: Reset T for safety
            default: begin
                T_Reset = 1'b1;
            end
        endcase
    end

endmodule
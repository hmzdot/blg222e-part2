`timescale 1ns/1ps

`define ARF_IN_PC 3'b100
`define ARF_IN_SP 3'b010
`define ARF_IN_AR 3'b001

`define ARF_OUT_PC 2'b00
`define ARF_OUT_SP 2'b01
`define ARF_OUT_AR 2'b10

`define RF_IN_R1 4'b1000
`define RF_IN_R2 4'b0100
`define RF_IN_R3 4'b0010
`define RF_IN_R4 4'b0001

`define RF_IN_S1 4'b1000
`define RF_IN_S2 4'b0100
`define RF_IN_S3 4'b0010
`define RF_IN_S4 4'b0001

`define RF_OUT_R1 3'b000
`define RF_OUT_R2 3'b001
`define RF_OUT_R3 3'b010
`define RF_OUT_R4 3'b011

`define RF_OUT_S1 3'b100
`define RF_OUT_S2 3'b101
`define RF_OUT_S3 3'b110
`define RF_OUT_S4 3'b111

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

    task select_dst_reg(input [2:0] input_register);
        begin
            case (input_register)
                3'b000: begin  // PC
                    ARF_RegSel = 3'b100;
                end
                3'b001: begin  // SP
                    ARF_RegSel = 3'b010;
                end
                3'b010,
                3'b011: begin  // AR
                    ARF_RegSel = 3'b001;
                end
                3'b100: begin  // R1
                    RF_RegSel = 4'b1000;
                end
                3'b101: begin  // R2
                    RF_RegSel = 4'b0100;
                end
                3'b110: begin  // R3
                    RF_RegSel = 4'b0010;
                end
                3'b111: begin  // R4
                    RF_RegSel = 4'b0001;
                end
            endcase
        end
    endtask

    task select_src_reg(input [2:0] input_register);
        begin
            case (input_register)
                3'b000: begin  // PC
                    ARF_OutCSel = 2'b00;
                    MuxASel = 2'b01;
                end
                3'b001: begin  // SP
                    ARF_OutCSel = 2'b01;
                    MuxASel = 2'b01;
                end
                3'b010,
                3'b011: begin  // AR
                    ARF_OutCSel = 2'b10;
                    MuxASel = 2'b01;
                end
                3'b100: begin  // R1
                    RF_OutASel = 3'b000;
                    MuxBSel = 2'b00;
                end
                3'b101: begin  // R2
                    RF_OutASel = 3'b001;
                    MuxBSel = 2'b00;
                end
                3'b110: begin  // R3
                    RF_OutASel = 3'b010;
                    MuxBSel = 2'b00;
                end
                3'b111: begin  // R4
                    RF_OutASel = 3'b011;
                    MuxBSel = 2'b00;
                end
                default: begin end
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
        RF_FunSel = 3'b000;
        RF_OutASel = 3'b000;
        RF_OutBSel = 3'b000;
        ARF_RegSel = 3'b000;
        ARF_FunSel = 2'b00;
        ARF_OutCSel = 2'b00;
        ARF_OutDSel = 2'b00;
        IR_LH = 1'b0;
        IR_Write = 1'b0;
        DR_E = 1'b0;
        DR_FunSel = 2'b00;
        ALU_FunSel = 5'b00000;
        ALU_WF = 1'b0;
        T_Reset = 1'b0;

        // Default immediate value - Use address field
        ALU_Immediate = {24'h000000, Address};

        case (T)
            12'b000000000001: begin
                if (~Reset) begin
                    ALU_Immediate = 32'h00000000;
                    MuxASel = 2'b11;        // Immediate (0) to ALU A
                    ALU_FunSel = 5'b00000;  // Pass A
                    ALU_WF = 1'b0;          // Don't write flags during reset

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

            // @todo: reset muxbsel each time?
            12'b000000000100: begin // T2
                ARF_OutCSel = 2'b00;            // ARF C <- PC
                MuxASel = 2'b01;                // Mux A <- ARF C
                MuxBSel = 2'b11;                // Mux B <- IROut[7:0]
                ALU_Immediate = 32'h00000001;   // ALU I <- 1
                ALU_FunSel = 5'b10100;          // 32-bit Add
                ARF_RegSel = 3'b100;            // PC
                ARF_FunSel = 2'b10;             // Load

                case (Opcode)
                    6'h00: begin // BRA @ T2
                        ALU_Immediate = {24'h000000, Address};  
                        MuxASel = 2'b11;                        
                        ALU_FunSel = 5'b00000;                  
                        ARF_RegSel = 3'b100;                    
                        ARF_FunSel = 2'b10;                     
                        T_Reset = 1'b1;                         
                    end
                    
                    6'h01: begin // BNE @ T2
                        if (FlagsOut[3] == 1'b0) begin 
                            ALU_Immediate = {24'h000000, Address}; 
                            MuxASel = 2'b11;
                            MuxBSel = 2'b00;
                            ALU_FunSel = 5'b00000;
                            ARF_RegSel = `ARF_IN_PC;
                            ARF_FunSel = 2'b10; // Load
                        end 
                        T_Reset = 1'b1;
                    end

                    6'h02: begin // BEQ @ T2
                        if (FlagsOut[3] == 1'b1) begin
                            ALU_Immediate = {24'h000000, Address};
                            MuxASel = 2'b11;            
                            ALU_FunSel = 5'b00000; // Pass A
                            ARF_RegSel = `ARF_IN_PC;
                            ARF_FunSel = 2'b10;
                        end
                        T_Reset = 1'b1;
                    end

                    6'h03: begin // POPL @ T2
                        // SP + 1 → SP
                        ARF_OutCSel = 2'b01; // ARF C <- SP
                        MuxASel = 2'b01; // ALU A <- ARF C
                        MuxBSel = 2'b11; // Mux B <- IROut[7:0]
                        ALU_Immediate = 32'h00000001; // ALU I <- 1
                        ALU_FunSel = 5'b10100; // 32-bit Add
                        ARF_RegSel = 3'b010; // SP
                        ARF_FunSel = 2'b10; // Load
                    end

                    6'h04: begin // PSHL @ T2
                        // Load Rx → ALU → DR (high byte)
                        select_dst_reg({ 1'b1, RegSel }); // assign RF_RegSel
                        MuxASel = 2'b00; // RF_OutA to ALU A
                        ALU_FunSel = 5'b00000; // Pass A
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Zero-extend load
                    end

                    6'h05: begin // POPH @ T2
                        // SP + 1 → SP
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01; // SP to ALU A
                        MuxBSel       = 2'b11; // Immediate 1
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100; // 32-bit add
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                    end

                    6'h06: begin // PSHH @ T2
                        // Rx[31:24] -> DR, write -> M[SP]
                        select_src_reg({1'b1, RegSel});
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b00000;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b11; // Load left (MSB)

                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b11; // ALUOut[31:24]
                    end

                    6'h07: begin // CALL @ T2
                        // PC[7:0] -> DR, write -> M[SP] (Store PC low byte first)
                        ARF_OutCSel = `ARF_OUT_PC;
                        MuxASel = 2'b01; // PC → ALU A
                        ALU_FunSel = 5'b10000; // 32-bit pass A
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00; // ALUOut[7:0] (PC Low)
                    end

                    6'h08: begin // RET @ T2
                        // SP <- SP + 1
                        ARF_OutCSel = `ARF_OUT_SP;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10100; // 32-bit add
                        ARF_RegSel = `ARF_IN_SP;
                        ARF_FunSel = 2'b10;
                    end

                    6'h09: begin // INC @ T2
                        select_src_reg(SrcReg1); // Select source register → ALU A
                        select_dst_reg(DestReg); // Select destination register

                        MuxBSel = 2'b11; // Immediate → ALU B
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10100; // 32-bit add
                        ALU_WF = 1'b1; // Enable flag write
                        RF_FunSel = 3'b010; // Load result into DSTREG
                        T_Reset = 1'b1; 
                    end

                    6'h0A: begin // DEC @ T2
                        select_src_reg(SrcReg1); // Select source register → ALU A
                        select_dst_reg(DestReg); // Select destination register

                        MuxBSel = 2'b11; // Immediate → ALU B
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10110; // 32-bit sub
                        ALU_WF = 1'b1; // Enable flag write
                        RF_FunSel = 3'b010; // Load result into DSTREG
                        T_Reset = 1'b1; 
                    end

                    6'h0B: begin // LSL @ T2
                        select_src_reg(SrcReg1); 
                        select_dst_reg(DestReg);

                        ALU_FunSel = 5'b11011; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h0C: begin // LSR @ T2
                        select_src_reg(SrcReg1); 
                        select_dst_reg(DestReg);

                        ALU_FunSel = 5'b11100; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h0D: begin // ASR @ T2
                        select_src_reg(SrcReg1); 
                        select_dst_reg(DestReg);

                        ALU_FunSel = 5'b11101; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h0E: begin // CSL @ T2
                        select_src_reg(SrcReg1); 
                        select_dst_reg(DestReg);

                        ALU_FunSel = 5'b11110; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h0F: begin // CSR @ T2
                        select_src_reg(SrcReg1); 
                        select_dst_reg(DestReg);

                        ALU_FunSel = 5'b11111; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h10: begin // NOT @ T2
                        select_src_reg(SrcReg1); 
                        select_dst_reg(DestReg);

                        ALU_FunSel = 5'b00010; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h11: begin // AND @ T2
                        select_src_reg(SrcReg1);

                        // If SREG2 is PC/SP/AR, move to scratch reg first
                        if (SrcReg2 <= 3'b011) begin 
                            // select ARF output
                            case (SrcReg2)
                                3'b000: ARF_OutCSel = `ARF_OUT_PC;
                                3'b001: ARF_OutCSel = `ARF_OUT_SP;
                                3'b010, 3'b011: ARF_OutCSel = `ARF_OUT_AR;
                            endcase

                            MuxASel = 2'b01; 
                            ALU_FunSel = 5'b00000;
                            RF_ScrSel = `RF_IN_S1;
                            RF_FunSel = 3'b010;
                        end else begin
                            begin
                                case (SrcReg2)
                                    3'b100: RF_OutBSel = 3'b000; // R1
                                    3'b101: RF_OutBSel = 3'b001; // R2
                                    3'b110: RF_OutBSel = 3'b010; // R3
                                    3'b111: RF_OutBSel = 3'b011; // R4
                                    default: RF_OutBSel = 3'b000; // fallback
                                endcase
                            end
                            select_dst_reg(DestReg);

                            MuxBSel = 2'b00; // RF OutB
                            ALU_FunSel = 5'b10111; // AND
                            RF_FunSel = 3'b010;
                            T_Reset = 1'b1;
                        end
                    end

                    6'h12: begin // ORR @ T2
                        select_src_reg(SrcReg1);

                        // If SREG2 is PC/SP/AR, move to scratch reg first
                        if (SrcReg2 <= 3'b011) begin 
                            // select ARF output
                            case (SrcReg2)
                                3'b000: ARF_OutCSel = `ARF_OUT_PC;
                                3'b001: ARF_OutCSel = `ARF_OUT_SP;
                                3'b010, 3'b011: ARF_OutCSel = `ARF_OUT_AR;
                            endcase

                            MuxASel = 2'b01; 
                            ALU_FunSel = 5'b00000;
                            RF_ScrSel = `RF_IN_S1;
                            RF_FunSel = 3'b010;
                        end else begin
                            begin
                                case (SrcReg2)
                                    3'b100: RF_OutBSel = 3'b000; // R1
                                    3'b101: RF_OutBSel = 3'b001; // R2
                                    3'b110: RF_OutBSel = 3'b010; // R3
                                    3'b111: RF_OutBSel = 3'b011; // R4
                                    default: RF_OutBSel = 3'b000; // fallback
                                endcase
                            end
                            select_dst_reg(DestReg);

                            MuxBSel = 2'b00; // RF OutB
                            ALU_FunSel = 5'b11000; // OR
                            RF_FunSel = 3'b010;
                            T_Reset = 1'b1;
                        end
                    end

                    6'h13: begin // XOR @ T2
                        select_src_reg(SrcReg1);

                        // If SREG2 is PC/SP/AR, move to scratch reg first
                        if (SrcReg2 <= 3'b011) begin 
                            // select ARF output
                            case (SrcReg2)
                                3'b000: ARF_OutCSel = `ARF_OUT_PC;
                                3'b001: ARF_OutCSel = `ARF_OUT_SP;
                                3'b010, 3'b011: ARF_OutCSel = `ARF_OUT_AR;
                            endcase

                            MuxASel = 2'b01; 
                            ALU_FunSel = 5'b00000;
                            RF_ScrSel = `RF_IN_S1;
                            RF_FunSel = 3'b010;
                        end else begin
                            begin
                                case (SrcReg2)
                                    3'b100: RF_OutBSel = 3'b000; // R1
                                    3'b101: RF_OutBSel = 3'b001; // R2
                                    3'b110: RF_OutBSel = 3'b010; // R3
                                    3'b111: RF_OutBSel = 3'b011; // R4
                                    default: RF_OutBSel = 3'b000; // fallback
                                endcase
                            end
                            select_dst_reg(DestReg);

                            MuxBSel = 2'b00; // RF OutB
                            ALU_FunSel = 5'b11001; // OR
                            RF_FunSel = 3'b010;
                            T_Reset = 1'b1;
                        end
                    end

                    6'h14: begin // NAND @ T2
                        select_src_reg(SrcReg1);

                        // If SREG2 is PC/SP/AR, move to scratch reg first
                        if (SrcReg2 <= 3'b011) begin 
                            // select ARF output
                            case (SrcReg2)
                                3'b000: ARF_OutCSel = `ARF_OUT_PC;
                                3'b001: ARF_OutCSel = `ARF_OUT_SP;
                                3'b010, 3'b011: ARF_OutCSel = `ARF_OUT_AR;
                            endcase

                            MuxASel = 2'b01; 
                            ALU_FunSel = 5'b00000;
                            RF_ScrSel = `RF_IN_S1;
                            RF_FunSel = 3'b010;
                        end else begin
                            begin
                                case (SrcReg2)
                                    3'b100: RF_OutBSel = 3'b000; // R1
                                    3'b101: RF_OutBSel = 3'b001; // R2
                                    3'b110: RF_OutBSel = 3'b010; // R3
                                    3'b111: RF_OutBSel = 3'b011; // R4
                                    default: RF_OutBSel = 3'b000; // fallback
                                endcase
                            end
                            select_dst_reg(DestReg);

                            MuxBSel = 2'b00; // RF OutB
                            ALU_FunSel = 5'b11010; // NAND
                            RF_FunSel = 3'b010;
                            T_Reset = 1'b1;
                        end
                    end

                    6'h15: begin // ADD @ T2
                        select_src_reg(SrcReg1);

                        // If SREG2 is PC/SP/AR, move to scratch reg first
                        if (SrcReg2 <= 3'b011) begin 
                            // select ARF output
                            case (SrcReg2)
                                3'b000: ARF_OutCSel = `ARF_OUT_PC;
                                3'b001: ARF_OutCSel = `ARF_OUT_SP;
                                3'b010, 3'b011: ARF_OutCSel = `ARF_OUT_AR;
                            endcase

                            MuxASel = 2'b01; 
                            ALU_FunSel = 5'b00000;
                            RF_ScrSel = `RF_IN_S1;
                            RF_FunSel = 3'b010;
                        end else begin
                            begin
                                case (SrcReg2)
                                    3'b100: RF_OutBSel = 3'b000; // R1
                                    3'b101: RF_OutBSel = 3'b001; // R2
                                    3'b110: RF_OutBSel = 3'b010; // R3
                                    3'b111: RF_OutBSel = 3'b011; // R4
                                    default: RF_OutBSel = 3'b000; // fallback
                                endcase
                            end
                            select_dst_reg(DestReg);

                            MuxBSel = 2'b00; // RF OutB
                            ALU_FunSel = 5'b10100; // ADD
                            RF_FunSel = 3'b010;
                            T_Reset = 1'b1;
                        end
                    end

                    6'h16: begin // ADC @ T2
                        select_src_reg(SrcReg1);

                        if (SrcReg2 <= 3'b011) begin
                            case (SrcReg2)
                                3'b000: ARF_OutCSel = `ARF_OUT_PC;
                                3'b001: ARF_OutCSel = `ARF_OUT_SP;
                                3'b010, 3'b011: ARF_OutCSel = `ARF_OUT_AR;
                            endcase

                            MuxASel = 2'b01;
                            ALU_FunSel = 5'b00000;
                            RF_ScrSel = `RF_IN_S1;
                            RF_FunSel = 3'b010;
                        end else begin 
                            case (SrcReg2)
                                3'b100: RF_OutBSel = 3'b000;
                                3'b101: RF_OutBSel = 3'b001;
                                3'b110: RF_OutBSel = 3'b010;
                                3'b111: RF_OutBSel = 3'b011;
                                default: RF_OutBSel = 3'b000;
                            endcase

                            select_dst_reg(DestReg);
                            MuxBSel = 2'b00;
                            ALU_FunSel = 5'b10101; // ADD with Carry
                            RF_FunSel = 3'b010;
                            T_Reset = 1'b1;
                        end
                    end

                    6'h17: begin // SUB @ T2
                        select_src_reg(SrcReg1);

                        if (SrcReg2 <= 3'b011) begin 
                            case (SrcReg2)
                                3'b000: ARF_OutCSel = `ARF_OUT_PC;
                                3'b001: ARF_OutCSel = `ARF_OUT_SP;
                                3'b010, 3'b011: ARF_OutCSel = `ARF_OUT_AR;
                            endcase

                            MuxASel = 2'b01; 
                            ALU_FunSel = 5'b00000;
                            RF_ScrSel = `RF_IN_S1;
                            RF_FunSel = 3'b010;
                        end else begin
                            begin
                                case (SrcReg2)
                                    3'b100: RF_OutBSel = 3'b000; // R1
                                    3'b101: RF_OutBSel = 3'b001; // R2
                                    3'b110: RF_OutBSel = 3'b010; // R3
                                    3'b111: RF_OutBSel = 3'b011; // R4
                                    default: RF_OutBSel = 3'b000; // fallback
                                endcase
                            end
                            select_dst_reg(DestReg);

                            MuxBSel = 2'b00; // RF OutB
                            ALU_FunSel = 5'b10110; // SUB
                            RF_FunSel = 3'b010;
                            T_Reset = 1'b1;
                        end
                    end

                    6'h18: begin // MOV @ T2
                        select_src_reg(SrcReg1);
                        select_dst_reg(DestReg);

                        ALU_FunSel = 5'b00000;
                        RF_FunSel = 3'b010;
                        ARF_FunSel = 2'b10;
                        T_Reset = 1'b1;
                    end

                    6'h19: begin // MOVL @ T2
                        select_dst_reg({1'b1, RegSel});

                        ALU_Immediate = {24'h000000, IROut[7:0]}; // Zero extend
                        MuxASel = 2'b11;
                        ALU_FunSel = 5'b00000;
                        ALU_WF = 1'b1; // Enable flag write
                        RF_FunSel = 3'b100; 
                        T_Reset = 1'b1;
                    end

                    6'h1A: begin // MOVSH @ T2
                        select_dst_reg({1'b1, RegSel});

                        ALU_Immediate = {24'h000000, IROut[7:0]};
                        MuxASel = 2'b11;
                        ALU_FunSel = 5'b00000;
                        RF_FunSel = 3'b110;
                        T_Reset = 1'b1;
                    end

                    6'h1B: begin // LDARL @ T2
                        // Read byte 0
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01;
                    end

                    6'h1C: begin // LDARH @ T2
                        // Read byte 0
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01;
                    end

                    6'h1D: begin // STAR @ T2
                        // Write byte 3 from SrcReg1[31:24]
                        select_src_reg(SrcReg1);
                        MuxASel = 2'b00;
                        ALU_Immediate = 32'h00000000;
                        ALU_FunSel = 5'b10000; // Pass A (32-bit)
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b11; // ALUOut[31:24]
                        
                        // Override default T2 behavior
                        ARF_RegSel = 3'b000;
                        ARF_FunSel = 2'b00;
                    end

                    6'h1E: begin // LDAL @ T2
                        // Load address into AR, read byte 0
                        ALU_Immediate = {24'h000000, Address};
                        MuxASel = 2'b11;
                        ALU_FunSel = 5'b00000;
                        ARF_FunSel = 2'b10;
                        ARF_RegSel = `ARF_IN_AR;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01;
                    end

                    6'h1F: begin // LDAH @ T2
                        // Load byte 0 
                        ALU_Immediate = {24'h000000, Address};
                        MuxASel = 2'b11;
                        ALU_FunSel = 5'b00000;
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01;
                    end

                    6'h20: begin // STA @ T2
                        // Load byte 0
                        ALU_Immediate = {24'h000000, Address};
                        MuxASel       = 2'b11;
                        ALU_FunSel    = 5'b00000;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        select_src_reg({1'b1, RegSel});
                        MuxASel     = 2'b00;
                        ALU_FunSel  = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b00; // ALUOut[7:0]
                    end

                    6'h21: begin // LDDRL @ T2
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01;
                    end

                    6'h22: begin // LDDRH @ T2
                        // Load byte 0
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01;
                    end

                    6'h23: begin // STDR @ T2
                        // DSTREG <- DR
                        select_dst_reg(DestReg);
                        
                        MuxASel = 2'b10;
                        ALU_FunSel = 5'b00000;
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h24: begin // STRIM @ T2
                        // AR <- AR + Offset
                        ARF_OutCSel = `ARF_OUT_AR;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = {24'h000000, Address};
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b10;
                    end

                    default: begin
                        T_Reset = 1'b1;
                    end
                endcase
            end

            12'b000000001000: begin // T3
                case (Opcode)
                    6'h03: begin // POPL @ T3
                        // M[SP] -> DR (zero-extended low byte)
                        ARF_OutDSel = `ARF_OUT_SP; // SP to address
                        Mem_CS = 1'b0; // Enable memory
                        Mem_WR = 1'b0; // Read
                        DR_E = 1'b1; // Enable DR
                        DR_FunSel = 2'b01; // Load zero-extended
                    end

                    6'h04: begin // PSHL @ T3
                        // SP -> Addr, M[SP] <- DR[15:8]
                        ARF_OutDSel = `ARF_OUT_SP; // SP -> memory address
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b01; // Load ALUOut[15:8]
                    end

                    6'h05: begin // POPH @ T3
                        // DR <- M[SP] (byte 0)
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b01; // Zero-extend → load to lowest byte
                    end

                    6'h06: begin // PSHH @ T3
                        // SP <- SP - 1
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10110; // 32-bit sub
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                    end

                    6'h07: begin // CALL @ T3
                        // SP <- SP - 1
                        ARF_OutCSel = `ARF_OUT_SP;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10110; // 32-bit sub
                        ARF_RegSel = `ARF_IN_SP;
                        ARF_FunSel = 2'b10;
                    end

                    6'h08: begin // RET @ T3
                        // DR <- M[SP] (low byte)
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01; // Load low byte (zero-extend)
                    end

                    6'h11: begin // AND @ T3
                        select_src_reg(SrcReg1);
                        RF_OutBSel = `RF_OUT_S1;
                        select_dst_reg(DestReg);

                        MuxBSel = 2'b00;
                        ALU_FunSel = 5'b10111; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h12: begin // ORR @ T3
                        select_src_reg(SrcReg1);
                        RF_OutBSel = `RF_OUT_S1;
                        select_dst_reg(DestReg);

                        MuxBSel = 2'b00;
                        ALU_FunSel = 5'b11000; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h13: begin // XOR @ T3
                        select_src_reg(SrcReg1);
                        RF_OutBSel = `RF_OUT_S1;
                        select_dst_reg(DestReg);

                        MuxBSel = 2'b00;
                        ALU_FunSel = 5'b11001; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h14: begin // NAND @ T3
                        select_src_reg(SrcReg1);
                        RF_OutBSel = `RF_OUT_S1;
                        select_dst_reg(DestReg);

                        MuxBSel = 2'b00;
                        ALU_FunSel = 5'b11010; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h15: begin // ADD @ T3
                        select_src_reg(SrcReg1);
                        RF_OutBSel = `RF_OUT_S1;
                        select_dst_reg(DestReg);

                        MuxBSel = 2'b00;
                        ALU_FunSel = 5'b10100; 
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h16: begin // ADC @ T3
                        select_src_reg(SrcReg1);
                        RF_OutBSel = `RF_OUT_S1; 
                        select_dst_reg(DestReg);

                        MuxBSel    = 2'b00;
                        ALU_FunSel = 5'b10101; // ADD with Carry
                        RF_FunSel  = 3'b010;
                        T_Reset    = 1'b1;
                    end

                    6'h17: begin // SUB @ T3
                        select_src_reg(SrcReg1);
                        RF_OutBSel = `RF_OUT_S1; 
                        select_dst_reg(DestReg);

                        MuxBSel    = 2'b00;
                        ALU_FunSel = 5'b10110; // SUB
                        RF_FunSel  = 3'b010;
                        T_Reset    = 1'b1;
                    end

                    6'h1B: begin // LDARL @ T3
                        // Read high byte from M[AR+1]
                        ARF_OutCSel = `ARF_OUT_AR;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10100;  // ADD
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; 
                    end

                    6'h1C: begin // LDARH @ T3
                        // AR+1, read byte 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100; // ADD
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10; // Insert as byte 1
                    end

                    6'h1D: begin // STAR @ T3
                        // Increment AR: AR + 1 (from 0008 to 0009)
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b01; // Increment
                    end

                    6'h1E: begin // LDAL @ T3
                        // Increment AR only
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;
                    end

                    6'h1F: begin // LDAH @ T3
                        // Load byte 1, AR ← AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10; // shift in as byte 1
                    end

                    6'h20: begin // STA @ T3
                        // Load byte 1, AR <- AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        select_src_reg({1'b1, RegSel});
                        MuxASel     = 2'b00;
                        ALU_FunSel  = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b01; // ALUOut[15:8]
                    end

                    6'h21: begin // LDDRL @ T3
                        // Load byte 1, AR <- AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10; // Shift in high byte
                        T_Reset     = 1'b1;
                    end

                    6'h22: begin // LDDRH @ T3
                        // Load byte 1, AR ← AR + 1
                        ARF_OutCSel = `ARF_OUT_AR;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10;
                    end

                    6'h24: begin // STRIM @ T3
                        // Write byte 0, AR <- AR + 1
                        select_src_reg({1'b1, RegSel});
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00; 
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000000010000: begin // T4
                case (Opcode)
                    6'h03: begin // POPL @ T4
                        // SP + 1 → SP (again)
                        ARF_OutCSel = 2'b01; // SP to OutC
                        MuxASel = 2'b01;     // OutC to ALU A
                        MuxBSel = 2'b11;     // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10100; // ADD
                        ARF_RegSel = 3'b010;   // SP
                        ARF_FunSel = 2'b10;    // Load
                    end

                    6'h04: begin // PSHL @ T4
                        // SP - 1 -> SP
                        ARF_OutCSel = `ARF_OUT_SP; // SP to OutC
                        MuxASel = 2'b01; // SP to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'h00000001;
                        ALU_FunSel = 5'b10110; // 32-bit sub
                        ARF_RegSel = `ARF_IN_SP; // SP
                        ARF_FunSel = 2'b10; // Load
                    end

                    6'h05: begin // POPH @ T4
                        // SP + 1 -> SP
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01; // SP to ALU A
                        MuxBSel       = 2'b11; // Immediate 1
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100; // 32-bit add
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                    end

                    6'h06: begin // PSHH @ T4
                        // Rx[23:16] -> DR, write -> M[SP]
                        select_src_reg({1'b1, RegSel});
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b00000;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10;

                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b10;
                    end

                    6'h07: begin // CALL @ T4
                        // PC[15:8] -> DR, write -> M[SP] (Store PC high byte)
                        ARF_OutCSel = `ARF_OUT_PC;
                        MuxASel = 2'b01;
                        ALU_FunSel = 5'b10000; // 32-bit pass A
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01; // ALUOut[15:8] (PC High)
                    end

                    6'h08: begin // RET @ T4
                        // SP <- SP + 1
                        ARF_OutCSel = `ARF_OUT_SP;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10100; // 32-bit add
                        ARF_RegSel = `ARF_IN_SP;
                        ARF_FunSel = 2'b10;
                    end

                    6'h1B: begin // LDARL @ T4
                        select_dst_reg(DestReg);

                        MuxASel = 2'b10;
                        ALU_FunSel = 5'b00000;
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h1C: begin // LDARH @ T4
                        // AR+1, read byte 2 
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10;
                    end

                    6'h1D: begin // STAR @ T4
                        // Write byte 2 from SrcReg1[23:16] at AR (0009)
                        select_src_reg(SrcReg1);
                        ALU_Immediate = 32'h00000000;
                        ALU_FunSel = 5'b10000; // Pass A (32-bit)
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b10; // ALUOut[23:16]
                        
                        // Increment AR: AR + 1 (from 0009 to 000A)
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b01; // Increment
                    end

                    6'h1E: begin // LDAL @ T4
                        // Read byte 1 from incremented AR
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10; // shift into high byte
                    end

                    6'h1F: begin // LDAH @ T4
                        // Load byte 2, AR <- AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10; // shift in as byte 2
                    end

                    6'h20: begin // STA @ T4
                        // Write byte 2, AR <- AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        select_src_reg({1'b1, RegSel});
                        MuxASel     = 2'b00;
                        ALU_FunSel  = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b10; // ALUOut[23:16]
                    end

                    6'h22: begin // LDDRH @ T4
                        // Load byte 2, AR <- AR + 1
                        ARF_OutCSel = `ARF_OUT_AR;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10;
                    end

                    6'h24: begin // STRIM @ T4
                        // Write byte 1, AR <- AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        select_src_reg({1'b1, RegSel});
                        MuxASel     = 2'b00;
                        ALU_FunSel  = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b01; // ALUOut[15:8]
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000000100000: begin // T5
                case (Opcode)
                    6'h03: begin // POPL @ T5
                        // M[SP] → DR (high byte, shifted in)
                        ARF_OutDSel = 2'b01;    // SP to address
                        Mem_CS = 1'b0;          // Enable memory
                        Mem_WR = 1'b0;          // Read
                        DR_E = 1'b1;            // Enable DR
                        DR_FunSel = 2'b10;      // Shift left and load
                    end

                    6'h04: begin // PSHL @ T5
                        select_src_reg({1'b1, RegSel}); // Assign RF_OutASel
                        MuxASel      = 2'b00; // ALUOut
                        ALU_FunSel   = 5'b00000; // Pass A
                        DR_E         = 1'b1;
                        DR_FunSel    = 2'b01; // Zero extend load
                    end

                    6'h05: begin // POPH @ T5
                        // DR <- M[SP] (byte 1)
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10; // Shift in next byte to right
                    end

                    6'h06: begin // PSHH @ T5
                        // SP <- SP - 1
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10110; // 32-bit sub
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                    end

                    6'h07: begin // CALL @ T5
                        // SP <- SP - 1
                        ARF_OutCSel = `ARF_OUT_SP;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10110; // 32-bit sub
                        ARF_RegSel = `ARF_IN_SP;
                        ARF_FunSel = 2'b10;
                    end

                    6'h08: begin // RET @ T5
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift in as upper byte
                    end

                    6'h1C: begin // LDARH @ T5
                        // AR+1, read byte 3
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10;
                    end

                    6'h1D: begin // STAR @ T5
                        // Write byte 1 from SrcReg1[15:8] at AR (000A)
                        select_src_reg(SrcReg1);
                        ALU_Immediate = 32'h00000000;
                        ALU_FunSel = 5'b10000; // Pass A (32-bit)
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01; // ALUOut[15:8]
                        
                        // Increment AR: AR + 1 (from 000A to 000B)
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b01; // Increment
                    end

                    6'h1F: begin // LDAH @ T5
                        // Load byte 3, AR <- AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel = 2'b01;
                        MuxBSel = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10100;
                        ARF_RegSel = `ARF_IN_AR;
                        ARF_FunSel = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // shift in as byte 3
                    end

                    6'h20: begin // STA @ T5
                        // Write byte 3, AR <- AR + 1
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        select_src_reg({1'b1, RegSel});
                        MuxASel     = 2'b00;
                        ALU_FunSel  = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b11; // ALUOut[31:24]

                        T_Reset     = 1'b1;
                    end

                    6'h22: begin // LDDRH @ T5
                        // Load byte 3
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b0;
                        DR_E        = 1'b1;
                        DR_FunSel   = 2'b10;

                        T_Reset     = 1'b1;
                    end

                    6'h24: begin // STRIM @ T5
                        // Write byte 2
                        ARF_OutCSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        select_src_reg({1'b1, RegSel});
                        MuxASel     = 2'b00;
                        ALU_FunSel  = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b10; // ALUOut[23:16]
                    end

                    6'h1E: begin // LDAL @ T5
                        // Transfer DR to destination register
                        select_dst_reg({1'b1, RegSel}); // RSEL → Rx
                        MuxASel    = 2'b10;      // DR to ALU A
                        ALU_FunSel = 5'b00000;   // pass-through
                        RF_FunSel  = 3'b010;     // write to Rx
                        T_Reset    = 1'b1;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000001000000: begin // T6 (actual bit 6)
                case (Opcode)
                    6'h1D: begin // STAR @ T6
                        // Write byte 0 from SrcReg1[7:0] at AR (000B)
                        select_src_reg(SrcReg1);
                        ALU_Immediate = 32'h00000000;
                        ALU_FunSel = 5'b10000; // Pass A (32-bit)
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00; // ALUOut[7:0]
                        
                        T_Reset = 1'b1;
                    end

                    6'h1F: begin // LDAH @ T6
                        // Do nothing - just transition to T7
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000010000000: begin // T7 (was incorrectly labeled T6)
                case (Opcode)
                    6'h1F: begin // LDAH @ T7
                        // Read byte 3
                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10; // Shift in high byte
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000100000000: begin // T8 (was incorrectly labeled T7)
                case (Opcode)
                    6'h1F: begin // LDAH @ T8
                        // Transfer DR to destination register
                        select_dst_reg({1'b1, RegSel});
                        MuxASel = 2'b10;     // DR to ALU A
                        ALU_FunSel = 5'b10000; // 32-bit Pass A
                        RF_FunSel = 3'b010;   // Load
                        T_Reset = 1'b1;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000010000000: begin // T6
                case (Opcode)
                    6'h03: begin // POPL @ T6
                        // DR → Rx
                        select_dst_reg({1'b1, RegSel}); // assign RF_RegSel 
                        MuxASel = 2'b10; // DR to ALU A
                        ALU_FunSel = 5'b10000; // Pass A
                        RF_FunSel = 3'b010; // Load
                        T_Reset = 1'b1;
                    end

                    6'h04: begin // PSHL @ T6
                        // T6: M[SP] <- DR[7:0]
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b00; // ALUOut[7:0]
                    end

                    6'h05: begin // POPH @ T6
                        // SP + 1 -> SP
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01; // SP to ALU A
                        MuxBSel       = 2'b11; // Immediate 1
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100; // 32-bit add
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                    end

                    6'h06: begin // PSHH @ T6
                        // Rx[15:8] -> DR, write -> M[SP]
                        select_src_reg({1'b1, RegSel});
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b00000;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10;

                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b01;
                    end

                    6'h07: begin // CALL @ T6
                        // PC <- VALUE
                        ALU_Immediate = {24'h000000, Address};
                        MuxASel = 2'b11; // Immediate to ALU A
                        ALU_FunSel = 5'b10000; // 32-bit pass A
                        ARF_RegSel = `ARF_IN_PC;
                        ARF_FunSel = 2'b10;
                        T_Reset = 1'b1;
                    end

                    6'h08: begin // RET @ T6
                        MuxASel = 2'b10; // DR → ALU A
                        ALU_FunSel = 5'b00000; // Pass A
                        ARF_RegSel = `ARF_IN_PC;
                        ARF_FunSel = 2'b10; // Load PC
                        T_Reset = 1'b1;
                    end

                    6'h1C: begin // LDARH @ T6
                        // DSTREG <- DR
                        select_dst_reg(DestReg);
                        MuxASel = 2'b10;
                        ALU_FunSel = 5'b00000;
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h1F: begin // LDAH @ T6
                        // Rx <- DR
                        select_dst_reg({1'b1, RegSel});

                        MuxASel = 2'b10;     // DR to ALU A
                        ALU_FunSel = 5'b00000;
                        RF_FunSel = 3'b010;
                        T_Reset = 1'b1;
                    end

                    6'h24: begin // STRIM @ T6
                        // Write byte 3
                        ARF_OutDSel   = `ARF_OUT_AR;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100;
                        ARF_RegSel    = `ARF_IN_AR;
                        ARF_FunSel    = 2'b10;

                        select_src_reg({1'b1, RegSel});
                        MuxASel     = 2'b00;
                        ALU_FunSel  = 5'b00000;

                        ARF_OutDSel = `ARF_OUT_AR;
                        Mem_CS      = 1'b0;
                        Mem_WR      = 1'b1;
                        MuxCSel     = 2'b11; // ALUOut[31:24]

                        T_Reset     = 1'b1;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000100000000: begin // T7
                case (Opcode)
                    6'h04: begin // PSHL @ T7
                        // SP - 1 -> SP
                        ARF_OutCSel = `ARF_OUT_SP; // SP to OutC
                        MuxASel = 2'b01; // SP to ALU A
                        MuxBSel = 2'b11; // Immediate 1
                        ALU_Immediate = 32'd1;
                        ALU_FunSel = 5'b10110; // 32-bit sub
                        ARF_RegSel = `ARF_IN_SP; // SP
                        ARF_FunSel = 2'b10; // Load
                        T_Reset = 1'b1;
                    end
        
                    6'h05: begin // POPH @ T7
                        // DR <- M[SP] (byte 2)
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10;
                    end

                    6'h06: begin // PSHH @ T7
                        // SP <- SP - 1
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10110; // 32-bit sub
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b001000000000: begin // T8
                case (Opcode)
                    6'h05: begin // POPH @ T8
                        // SP + 1 -> SP
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01; // SP to ALU A
                        MuxBSel       = 2'b11; // Immediate 1
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10100; // 32-bit add
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                    end

                    6'h06: begin // PSHH @ T8
                        // Rx[7:0] -> DR, write -> M[SP]
                        select_src_reg({1'b1, RegSel});
                        MuxASel = 2'b00;
                        ALU_FunSel = 5'b00000;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b01;

                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b1;
                        MuxCSel = 2'b00;
                    end

                    6'h1F: begin // LDAH @ T8
                        // Transfer DR to destination register
                        select_dst_reg({1'b1, RegSel});
                        MuxASel = 2'b10;     // DR to ALU A
                        ALU_FunSel = 5'b00000; // Pass A
                        RF_FunSel = 3'b010;   // Load
                        T_Reset = 1'b1;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b010000000000: begin // T9
                case (Opcode)
                    6'h05: begin // POPH @ T9
                        // DR <- M[SP] (byte 3)
                        ARF_OutDSel = `ARF_OUT_SP;
                        Mem_CS = 1'b0;
                        Mem_WR = 1'b0;
                        DR_E = 1'b1;
                        DR_FunSel = 2'b10;
                    end

                    6'h06: begin // PSHH @ T9
                        // SP <- SP - 1
                        ARF_OutCSel   = `ARF_OUT_SP;
                        MuxASel       = 2'b01;
                        MuxBSel       = 2'b11;
                        ALU_Immediate = 32'd1;
                        ALU_FunSel    = 5'b10110; // 32-bit sub
                        ARF_RegSel    = `ARF_IN_SP;
                        ARF_FunSel    = 2'b10;
                        T_Reset = 1'b1;
                    end

                    default: T_Reset = 1'b1;
                endcase
            end

            12'b000000000001: begin
                if (~Reset) begin
                    ALU_Immediate = 32'h00000000;
                    MuxASel = 2'b11;        // Immediate (0) to ALU A
                    ALU_FunSel = 5'b00000;  // Pass A
                    ALU_WF = 1'b0;          // Don't write flags during reset

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

            // Default: Reset T for safety
            default: begin
                T_Reset = 1'b1;
            end
        endcase
    end

endmodule


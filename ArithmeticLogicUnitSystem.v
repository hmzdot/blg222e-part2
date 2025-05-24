`timescale 1ns/1ps

module ArithmeticLogicUnitSystem(
    input  wire [31:0] I,
    input  wire        Clock,

    // memory interface control
    input  wire        Mem_CS,
    input  wire        Mem_WR,

    // top‑level multiplexers
    input  wire [1:0]  MuxASel,
    input  wire [1:0]  MuxBSel,
    input  wire [1:0]  MuxCSel,
    input  wire        MuxDSel,

    // register‑file controls
    input  wire [3:0]  RF_RegSel,
    input  wire [3:0]  RF_ScrSel,
    input  wire [2:0]  RF_FunSel,
    input  wire [2:0]  RF_OutASel,
    input  wire [2:0]  RF_OutBSel,

    // address‑register‑file controls
    input  wire [2:0]  ARF_RegSel,
    input  wire [1:0]  ARF_FunSel,
    input  wire [1:0]  ARF_OutCSel,
    input  wire [1:0]  ARF_OutDSel,

    // IR / DR
    input  wire        IR_LH,
    input  wire        IR_Write,
    input  wire        DR_E,
    input  wire [1:0]  DR_FunSel,

    // ALU
    input  wire [4:0]  ALU_FunSel,
    input  wire        ALU_WF,

    output wire [31:0] ALUOut,
    output wire [3:0]  FlagsOut,
    output wire [15:0] Address,
    output wire [7:0]  MemOut,
    output wire [31:0] OutA,
    output wire [31:0] OutB,
    output wire [15:0] OutC,
    output wire [15:0] OutD,
    output wire [15:0] IROut,
    output wire [31:0] DROut,
    output reg  [31:0] MuxAOut,
    output reg  [31:0] MuxBOut,
    output reg  [31:0] MuxDOut,
    output reg  [7:0]  MuxCOut
);

    wire [31:0] RF_OutA_int, RF_OutB_int;
    wire [15:0] ARF_OutC_int, ARF_OutD_int;
    wire [3:0]  Flags_ALU_int;

    reg  [31:0] ALU_A_bus, ALU_B_bus;

    AddressRegisterFile ARF (
        .I(ALUOut),
        .OutCSel(ARF_OutCSel),
        .OutDSel(ARF_OutDSel),
        .RegSel(ARF_RegSel),
        .FunSel(ARF_FunSel),
        .Clock(Clock),
        .OutC(ARF_OutC_int),
        .OutD(ARF_OutD_int)
    );

    RegisterFile RF (
        .I(ALUOut),
        .Clock(Clock),
        .RegSel(RF_RegSel),
        .ScrSel(RF_ScrSel),
        .FunSel(RF_FunSel),
        .OutASel(RF_OutASel),
        .OutBSel(RF_OutBSel),
        .OutA(RF_OutA_int),
        .OutB(RF_OutB_int)
    );

    ArithmeticLogicUnit ALU (
        .A(ALU_A_bus),
        .B(ALU_B_bus),
        .FunSel(ALU_FunSel),
        .WF(ALU_WF),
        .Clock(Clock),
        .ALUOut(ALUOut),
        .FlagsOut(Flags_ALU_int)
    );

    InstructionRegister IR (
        .I(MemOut),
        .LH(IR_LH),
        .Write(IR_Write),
        .Clock(Clock),
        .IROut(IROut)
    );

    DataRegister DR (
        .I(MemOut),
        .E(DR_E),
        .FunSel(DR_FunSel),
        .Clock(Clock),
        .DROut(DROut)
    );

    Memory MEM (
        .Address(ARF_OutD_int),
        .Data(MuxCOut),
        .MemOut(MemOut),
        .CS(Mem_CS),
        .WR(Mem_WR),
        .Clock(Clock)
    );

    always @(*) begin
        case (MuxASel)
            2'b00: ALU_A_bus = RF_OutA_int;
            2'b01: ALU_A_bus = {16'h0000, ARF_OutC_int};
            2'b10: ALU_A_bus = DROut;
            2'b11: ALU_A_bus = I;
        endcase
    end

    always @(*) begin
        case (MuxBSel)
            2'b00: ALU_B_bus = RF_OutB_int;
            2'b01: ALU_B_bus = {16'h0000, ARF_OutC_int};
            2'b10: ALU_B_bus = DROut;
            2'b11: ALU_B_bus = I;
        endcase
    end

    always @(*) begin
        case (MuxASel)
            2'b00: MuxAOut = ALUOut;
            2'b01: MuxAOut = {16'h0000, ARF_OutC_int};
            2'b10: MuxAOut = DROut;
            2'b11: MuxAOut = I;
            default: MuxAOut = 32'hxxxxxxxx;
        endcase
    end

    always @(*) begin
        case (MuxBSel)
            2'b00: MuxBOut = ALUOut;
            2'b01: MuxBOut = {16'h0000, ARF_OutC_int};
            2'b10: MuxBOut = DROut;
            2'b11: MuxBOut = I;
            default: MuxBOut = 32'hxxxxxxxx;
        endcase
    end

    always @(*) begin
        case (MuxCSel)
            2'b00: MuxCOut = ALUOut[7:0];
            2'b01: MuxCOut = ALUOut[15:8];
            2'b10: MuxCOut = ALUOut[23:16];
            2'b11: MuxCOut = ALUOut[31:24];
            default: MuxCOut = 8'hxx;
        endcase
    end

    always @(*) begin
        case (MuxDSel)
            1'b0:  MuxDOut = RF_OutA_int;
            1'b1:  MuxDOut = {16'h0000, ARF_OutC_int};
            default: MuxDOut = 32'hxxxxxxxx;
        endcase
    end

    assign OutA     = RF_OutA_int;
    assign OutB     = RF_OutB_int;
    assign OutC     = ARF_OutC_int;
    assign OutD     = ARF_OutD_int;
    assign Address  = ARF_OutD_int;
    assign FlagsOut = Flags_ALU_int;

endmodule

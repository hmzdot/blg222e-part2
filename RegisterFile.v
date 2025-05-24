`timescale 1ns/1ps

module RegisterFile (
    input Clock,
    input [31:0] I,
    input [3:0] RegSel,
    input [3:0] ScrSel,
    input [2:0] FunSel,
    input [2:0] OutASel,
    input [2:0] OutBSel,
    output [31:0] OutA,
    output [31:0] OutB
);
    wire [31:0] R1_out, R2_out, R3_out, R4_out;
    wire [31:0] S1_out, S2_out, S3_out, S4_out;

    Register32bit R1 ( .I(I), .E(RegSel[3]), .FunSel(FunSel), .Clock(Clock), .Q(R1_out) );
    Register32bit R2 ( .I(I), .E(RegSel[2]), .FunSel(FunSel), .Clock(Clock), .Q(R2_out) );
    Register32bit R3 ( .I(I), .E(RegSel[1]), .FunSel(FunSel), .Clock(Clock), .Q(R3_out) );
    Register32bit R4 ( .I(I), .E(RegSel[0]), .FunSel(FunSel), .Clock(Clock), .Q(R4_out) );

    Register32bit S1 ( .I(I), .E(ScrSel[3]), .FunSel(FunSel), .Clock(Clock), .Q(S1_out) );
    Register32bit S2 ( .I(I), .E(ScrSel[2]), .FunSel(FunSel), .Clock(Clock), .Q(S2_out) );
    Register32bit S3 ( .I(I), .E(ScrSel[1]), .FunSel(FunSel), .Clock(Clock), .Q(S3_out) );
    Register32bit S4 ( .I(I), .E(ScrSel[0]), .FunSel(FunSel), .Clock(Clock), .Q(S4_out) );

    assign OutA = (OutASel == 3'b000) ? R1_out :
                  (OutASel == 3'b001) ? R2_out :
                  (OutASel == 3'b010) ? R3_out :
                  (OutASel == 3'b011) ? R4_out :
                  (OutASel == 3'b100) ? S1_out :
                  (OutASel == 3'b101) ? S2_out :
                  (OutASel == 3'b110) ? S3_out :
                  (OutASel == 3'b111) ? S4_out :
                  32'bx;

    assign OutB = (OutBSel == 3'b000) ? R1_out :
                  (OutBSel == 3'b001) ? R2_out :
                  (OutBSel == 3'b010) ? R3_out :
                  (OutBSel == 3'b011) ? R4_out :
                  (OutBSel == 3'b100) ? S1_out :
                  (OutBSel == 3'b101) ? S2_out :
                  (OutBSel == 3'b110) ? S3_out :
                  (OutBSel == 3'b111) ? S4_out :
                  32'bx;

endmodule
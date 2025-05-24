`timescale 1ns/1ps

module InstructionRegister(
    input [7:0] I,
    input LH,
    input Write,
    input Clock,
    output reg [15:0] IROut
);

    always @(posedge Clock) begin
        if (Write == 1'b1) begin
            if (LH == 1'b0) begin
                IROut[7:0] <= I;
            end else begin
                IROut[15:8] <= I;
            end
        end
    end

endmodule
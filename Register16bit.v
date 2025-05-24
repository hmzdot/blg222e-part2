`timescale 1ns/1ps

module Register16bit(
    input [15:0] I,
    input E,
    input [1:0] FunSel,
    input Clock,
    output reg [15:0] Q
);

    always @(posedge Clock) begin
        if (E == 1'b1) begin
            case (FunSel)
                2'b00: Q <= Q - 1;
                2'b01: Q <= Q + 1;
                2'b10: Q <= I;
                2'b11: Q <= 16'b0;
                default: Q <= Q;
            endcase
        end
    end

endmodule
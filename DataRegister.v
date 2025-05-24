`timescale 1ns/1ps

module DataRegister(
    input  [7:0]  I,
    input         E,
    input  [1:0]  FunSel,
    input         Clock,
    output reg [31:0] DROut
);

    always @(posedge Clock) begin
        if (E) begin
            case (FunSel)
                2'b00:  DROut <= { {24{I[7]}}, I };
                2'b01:  DROut <= { 24'h0, I };
                2'b10:  DROut <= { DROut[23:0], I };
                2'b11:  DROut <= { I, DROut[31:8] };
                default: ;
            endcase
        end
    end

endmodule

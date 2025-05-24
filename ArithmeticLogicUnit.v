`timescale 1ns/1ps

module ArithmeticLogicUnit(
    input  wire [31:0] A,
    input  wire [31:0] B,
    input  wire [4:0]  FunSel,
    input  wire        WF,
    input  wire        Clock,
    output reg  [31:0] ALUOut,
    output reg  [3:0]  FlagsOut // 3:Z, 2:C, 1:N, 0:O
);
    reg [3:0]  next_flags;
    reg        carry_calc;
    reg        overflow_calc;
    reg [32:0] temp_sum;
    reg [32:0] temp_diff;
    reg [16:0] temp_sum_16;
    reg [16:0] temp_diff_16;

    always @(*) begin
        ALUOut       = 32'hxxxxxxxx;
        carry_calc   = FlagsOut[2];
        overflow_calc= FlagsOut[0];

        case (FunSel)
            5'b00000: ALUOut = {16'd0, A[15:0]};
            5'b00001: ALUOut = {16'd0, B[15:0]};
            5'b00010: ALUOut = {16'd0, ~A[15:0]};
            5'b00011: ALUOut = {16'd0, ~B[15:0]};

            // add, addc
            5'b00100: begin
                temp_sum_16 = {1'b0, A[15:0]} + {1'b0, B[15:0]};
                ALUOut      = {16'd0, temp_sum_16[15:0]};
                carry_calc  = temp_sum_16[16];
                overflow_calc = (A[15]==B[15]) && (ALUOut[15]!=A[15]);
            end
            5'b00101: begin
                temp_sum_16 = {1'b0, A[15:0]} + {1'b0, B[15:0]} + {15'd0, FlagsOut[2]};
                ALUOut      = {16'd0, temp_sum_16[15:0]};
                carry_calc  = temp_sum_16[16];
                overflow_calc = (A[15]==B[15]) && (ALUOut[15]!=A[15]);
            end

            // subtract
            5'b00110: begin
                temp_diff   = {1'b0, A[15:0]} - {1'b0, B[15:0]};
                ALUOut      = {16'd0, temp_diff[15:0]};
                carry_calc  = ~temp_diff[16];
                overflow_calc = (A[15]!=B[15]) && (ALUOut[15]==B[15]);
            end

            // --- 16‑bit logical operations ---
            5'b00111: ALUOut = {16'd0, A[15:0] & B[15:0]};
            5'b01000: ALUOut = {16'd0, A[15:0] | B[15:0]};
            5'b01001: ALUOut = {16'd0, A[15:0] ^ B[15:0]};
            5'b01010: ALUOut = {16'd0, ~(A[15:0] & B[15:0])};

            // --- 16‑bit shifts ---
            5'b01011: begin ALUOut = {16'd0, A[15:0] << 1}; carry_calc = A[15]; end
            5'b01100: begin ALUOut = {16'd0, A[15:0] >> 1}; carry_calc = A[0];  end
            5'b01101: begin ALUOut = {16'd0, $signed(A[15:0]) >>> 1}; carry_calc = A[0]; end
            5'b01110: begin ALUOut = {16'd0, {A[14:0],A[15]}}; carry_calc = A[15]; end
            5'b01111: begin ALUOut = {16'd0, {A[0],A[15:1]}}; carry_calc = A[0];  end

            // --- 32‑bit ops ---
            5'b10000: ALUOut = A;
            5'b10001: ALUOut = B;
            5'b10010: ALUOut = ~A;
            5'b10011: ALUOut = ~B;
            5'b10100: begin
                temp_sum   = {1'b0,A} + {1'b0,B};
                ALUOut     = temp_sum[31:0];
                carry_calc = temp_sum[32];
                overflow_calc = (A[31]==B[31]) && (ALUOut[31]!=A[31]);
            end
            5'b10101: begin
                temp_sum   = {1'b0,A} + {1'b0,B} + FlagsOut[2];
                ALUOut     = temp_sum[31:0];
                carry_calc = temp_sum[32];
                overflow_calc = (A[31]==B[31]) && (ALUOut[31]!=A[31]);
            end
            5'b10110: begin
                temp_diff  = {1'b0,A} - {1'b0,B};
                ALUOut     = temp_diff[31:0];
                carry_calc = ~temp_diff[32];
                overflow_calc = (A[31]!=B[31]) && (ALUOut[31]==B[31]);
            end

            5'b10111: ALUOut = A & B;
            5'b11000: ALUOut = A | B;
            5'b11001: ALUOut = A ^ B;
            5'b11010: ALUOut = ~(A & B);

            // shifts 32‑bit, 8‑bit
            5'b11011: begin ALUOut = A << 8; carry_calc = A[31]; end
            5'b11100: begin ALUOut = A >> 8; carry_calc = A[0];  end
            5'b11101: begin ALUOut = $signed(A) >>> 8; carry_calc = A[0]; end
            5'b11110: begin ALUOut = {A[23:0],A[31:24]}; carry_calc = A[31]; end
            5'b11111: begin ALUOut = {A[7:0], A[31:8]};    carry_calc = A[0];  end

            default: ALUOut = 32'hxxxxxxxx;
        endcase

        // zero flag
        next_flags[3] = (ALUOut == 32'd0);
        // carry flag
        next_flags[2] = carry_calc;
        // negative flag (MSB of result)
        if (FunSel < 5'b10000)
            next_flags[1] = ALUOut[15];
        else
            next_flags[1] = ALUOut[31];
        // overflow flag
        next_flags[0] = overflow_calc;
    end

    always @(posedge Clock) begin
        if (WF)
            FlagsOut <= next_flags;
    end

endmodule

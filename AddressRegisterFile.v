`timescale 1ns/1ps

module AddressRegisterFile(
    input  wire [31:0] I,
    input  wire [1:0]  OutCSel,
    input  wire [1:0]  OutDSel,
    input  wire [2:0]  RegSel,
    input  wire [1:0]  FunSel,
    input  wire        Clock,
    output wire [15:0] OutC,
    output wire [15:0] OutD
);
  wire [15:0] pc_val;
  wire [15:0] ar_val;
  wire [15:0] sp_val;

  Register16bit PC (
      .I(I[15:0]),
      .FunSel(FunSel),
      .E(RegSel[2]),
      .Clock(Clock),
      .Q(pc_val)
  );

  Register16bit AR (
      .I(I[15:0]),
      .FunSel(FunSel),
      .E(RegSel[0]),
      .Clock(Clock),
      .Q(ar_val)
  );

  Register16bit SP (
      .I(I[15:0]),
      .FunSel(FunSel),
      .E(RegSel[1]),
      .Clock(Clock),
      .Q(sp_val)
  );

  assign OutC = (OutCSel == 2'b00) ? pc_val :
              (OutCSel == 2'b01) ? sp_val :
                                   ar_val ;

  assign OutD = (OutDSel == 2'b00) ? pc_val :
                (OutDSel == 2'b01) ? sp_val :
                                    ar_val ;

endmodule

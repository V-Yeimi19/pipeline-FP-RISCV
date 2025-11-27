module aludec(input  opb5,
              input  [2:0] funct3,
              input  funct7b5,
              input  [1:0] ALUOp,
              input  [6:0] funct7,
              output [2:0] ALUControl);

  wire RtypeSub;
  reg [2:0] ALUControl_reg;

  assign RtypeSub = funct7b5 & opb5;
  assign ALUControl = ALUControl_reg;

  always @* case(ALUOp)
      2'b00: ALUControl_reg = 3'b000;
      2'b01: ALUControl_reg = 3'b001;
      default: case(funct3)
                 3'b000: if (RtypeSub)
                            ALUControl_reg = 3'b001;
                          else if (funct7 == 7'b0000000)
                            ALUControl_reg = 3'b000;
                          else if (funct7 == 7'b0000001)
                            ALUControl_reg = 3'b001;
                          else
                            ALUControl_reg = 3'b000;
                 3'b001: ALUControl_reg = 3'b110;
                 3'b010: if (funct7 == 7'b0000010)
                            ALUControl_reg = 3'b010;
                          else
                            ALUControl_reg = 3'b101;
                 3'b011: ALUControl_reg = 3'b011;
                 3'b100: ALUControl_reg = 3'b100;
                 3'b101: ALUControl_reg = 3'b111;
                 3'b110: ALUControl_reg = 3'b011;
                 3'b111: ALUControl_reg = 3'b010;
                 default: ALUControl_reg = 3'bxxx;
               endcase
    endcase
endmodule
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
      2'b00: ALUControl_reg = 3'b000;  // Load/Store - ADD
      2'b01: ALUControl_reg = 3'b001;  // Branch - SUB
      2'b10: begin  // R-type (enteros)
        case(funct3)
          3'b000: if (RtypeSub)
                     ALUControl_reg = 3'b001;  // SUB
                   else if (funct7 == 7'b0000000)
                     ALUControl_reg = 3'b000;  // ADD
                   else if (funct7 == 7'b0000001)
                     ALUControl_reg = 3'b001;  // SUB
                   else
                     ALUControl_reg = 3'b000;  // ADD por defecto
          3'b001: ALUControl_reg = 3'b110;  // SLL
          3'b010: if (funct7 == 7'b0000010)
                     ALUControl_reg = 3'b010;  // AND
                   else
                     ALUControl_reg = 3'b101;  // SLT
          3'b011: ALUControl_reg = 3'b011;  // OR
          3'b100: ALUControl_reg = 3'b100;  // XOR
          3'b101: ALUControl_reg = 3'b111;  // SRL
          3'b110: ALUControl_reg = 3'b011;  // OR
          3'b111: ALUControl_reg = 3'b010;  // AND
          default: ALUControl_reg = 3'bxxx;
        endcase
      end
      2'b11: begin  // ALUOp = 11 -> Operaciones FP (nuevo)
        // Para operaciones FP, usamos funct7[6:2] para determinar la operación
        // FADD.S: funct7 = 0000000 -> ALUControl = 000
        // FSUB.S: funct7 = 0000100 -> ALUControl = 001
        // FMUL.S: funct7 = 0001000 -> ALUControl = 010
        // FDIV.S: funct7 = 0001100 -> ALUControl = 011
        case(funct7[6:2])
          5'b00000: ALUControl_reg = 3'b000;  // FADD.S
          5'b00001: ALUControl_reg = 3'b001;  // FSUB.S
          5'b00010: ALUControl_reg = 3'b010;  // FMUL.S
          5'b00011: ALUControl_reg = 3'b011;  // FDIV.S
          default:  ALUControl_reg = 3'b000;  // FADD por defecto
        endcase
      end
      default: ALUControl_reg = 3'bxxx;
    endcase
endmodule
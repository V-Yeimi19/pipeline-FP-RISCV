module maindec(input  [6:0] op,
               output [1:0] ResultSrc,
               output MemWrite,
               output Branch, ALUSrc,
               output RegWrite, Jump,
               output [1:0] ImmSrc,
               output [1:0] ALUOp,
               output RegWriteFP,  // Señal para escritura en registro FP
               output FPOp);        // Señal para operación FP

  reg [12:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump, RegWriteFP, FPOp} = controls; 

  always @* case(op)
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump_RegWriteFP_FPOp
      7'b0000011: controls = 13'b1_00_1_0_01_0_00_0_0_0; // lw
      7'b0100011: controls = 13'b0_01_1_1_00_0_00_0_0_0; // sw
      7'b0110011: controls = 13'b1_xx_0_0_00_0_10_0_0_0; // R-type (enteros)
      7'b1100011: controls = 13'b0_10_0_0_00_1_01_0_0_0; // beq
      7'b0010011: controls = 13'b1_00_1_0_00_0_10_0_0_0; // I-type ALU
      7'b1101111: controls = 13'b1_11_0_0_10_0_00_1_0_0; // jal

      // Instrucciones FP - Extensión F de RISC-V
      7'b0000111: controls = 13'b0_00_1_0_01_0_00_0_1_0; // flw (FP load word) - escribe en FRF
      7'b0100111: controls = 13'b0_01_1_1_00_0_00_0_0_1; // fsw (FP store word) - lee de FRF
      7'b1010011: controls = 13'b0_xx_0_0_00_0_11_0_1_1; // FP R-type (fadd, fsub, fmul, fdiv) - ALUOp=11, escribe en FRF

      default:    controls = 13'bx_xx_x_x_xx_x_xx_x_x_x; // non-implemented instruction
    endcase
endmodule
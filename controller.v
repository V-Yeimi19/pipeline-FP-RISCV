module controller(input  [6:0] op,
                  input  [2:0] funct3,
                  input        funct7b5,
                  input        Zero,
                  output [1:0] ResultSrc,
                  output MemWrite,
                  output PCSrc, ALUSrc,
                  output RegWrite, Jump,
                  output Branch,
                  output [1:0] ImmSrc,
                  output [2:0] ALUControl,
                  output RegWriteFP,  // Nueva señal para escritura en FP regfile
                  output FPOp);       // Nueva señal para identificar operación FP

  wire [1:0] ALUOp;

  maindec md(
    .op(op),
    .ResultSrc(ResultSrc),
    .MemWrite(MemWrite),
    .Branch(Branch),
    .ALUSrc(ALUSrc),
    .RegWrite(RegWrite),
    .Jump(Jump),
    .ImmSrc(ImmSrc),
    .ALUOp(ALUOp),
    .RegWriteFP(RegWriteFP),
    .FPOp(FPOp)
  ); 

  aludec ad(
    .opb5(op[5]),
    .funct3(funct3),
    .funct7b5(funct7b5),
    .ALUOp(ALUOp),
    .funct7({funct7b5, 6'b0}),
    .ALUControl(ALUControl)
  ); 

  assign PCSrc = Branch & Zero | Jump; 
endmodule
module controller(
    input  [6:0] op,
    input  [2:0] funct3,
    input  [6:0] funct7,
    input        Zero,
    output [1:0] ResultSrc, 
    output MemWrite,
    output PCSrc, ALUSrc,
    output RegWrite, Jump,
    output Branch,
    output [2:0] ImmSrc,         // ← Cambio: de 2 bits a 3 bits
    output [2:0] ALUControl
);
  
    wire [1:0] ALUOp; 
  
    maindec md(
        .op(op), 
        .ResultSrc(ResultSrc), 
        .MemWrite(MemWrite), 
        .Branch(Branch),
        .ALUSrc(ALUSrc), 
        .RegWrite(RegWrite), 
        .Jump(Jump), 
        .ImmSrc(ImmSrc),           // ← Ahora es 3 bits
        .ALUOp(ALUOp)
    ); 
    
    aludec ad(
        .opb5(op[5]), 
        .funct3(funct3), 
        .funct7(funct7), 
        .ALUOp(ALUOp),
        .opcode(op),
        .ALUControl(ALUControl)
    ); 
    
    assign PCSrc = Branch & Zero | Jump; 
endmodule
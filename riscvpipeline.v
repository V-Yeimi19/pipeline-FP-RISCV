module riscvpipeline(
    input  clk, reset,
    output [31:0] PCF,
    input  [31:0] InstrF,
    output MemWriteM,
    output [31:0] ALUResultM, WriteDataM,
    input  [31:0] ReadDataM
);
    wire [1:0]  ResultSrcD;
    wire ALUSrcD;
    wire RegWriteD;
    wire MemWriteD;
    wire JumpD;
    wire BranchD;
    wire [2:0] ImmSrcD;        // ← CAMBIO: de [1:0] a [2:0]
    wire [2:0] ALUControlD;
    wire ZeroM;
    wire [31:0] InstrD;
    wire PCSrcM_unused;

    controller c(
        .op(InstrD[6:0]),
        .funct3(InstrD[14:12]),
        .funct7(InstrD[31:25]),
        .Zero(ZeroM),
        .ResultSrc(ResultSrcD),
        .MemWrite(MemWriteD),
        .PCSrc(PCSrcM_unused),
        .ALUSrc(ALUSrcD),
        .RegWrite(RegWriteD),
        .Jump(JumpD),
        .Branch(BranchD),
        .ImmSrc(ImmSrcD),
        .ALUControl(ALUControlD)
    );

    datapath_pipeline dp(
        .clk(clk),
        .reset(reset),
        .ResultSrcD(ResultSrcD),
        .ALUSrcD(ALUSrcD),
        .RegWriteD(RegWriteD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ImmSrcD(ImmSrcD),        // ← Ahora [2:0]
        .ALUControlD(ALUControlD),
        .ZeroM(ZeroM),
        .PCF(PCF),
        .InstrF(InstrF),
        .InstrD(InstrD),
        .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM),
        .ReadDataM(ReadDataM),
        .MemWriteM(MemWriteM)
    );
endmodule
// Pipelined Datapath - Integración completa de FP y LUI
module datapath_pipeline(
  input  clk, reset,
  // Señales de control(Decode)
  input  [1:0]  ResultSrcD,
  input  ALUSrcD,
  input  RegWriteD,
  input  MemWriteD,
  input  JumpD,
  input  BranchD,
  input  [2:0]  ImmSrcD,      // ← CAMBIO: de [1:0] a [2:0]
  input  [2:0]  ALUControlD,

  output MemWriteM,
  output ZeroM,

  // Señales de Data
  input  [31:0] InstrF,
  input  [31:0] ReadDataM,
  
  output [31:0] PCF,
  output [31:0] InstrD,
  output [31:0] ALUResultM, WriteDataM
);

  localparam WIDTH = 32;

  // Internal control signals for pipeline stages
  wire [1:0] ResultSrcE, ResultSrcM, ResultSrcW;
  wire ALUSrcE;
  wire RegWriteE, RegWriteM, RegWriteW;
  wire MemWriteE;
  wire JumpE, JumpM;
  wire BranchE, BranchM;
  wire [2:0] ALUControlE;
  wire ZeroE;

  // Señales internas de cada etapa del pipeline
  // Fetch
  wire [31:0] PCPlus4F, PCNextF;

  // Decode
  wire [31:0] PCD, PCPlus4D;
  wire [31:0] RD1D, RD2D, ImmExtD;
  wire is_lui_D;

  // Execute
  wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
  wire [31:0] SrcAE, SrcBE, ALUResultE, WriteDataE;
  wire [31:0] PCTargetE;
  wire [4:0] Rs1E, Rs2E, RdE;
  wire is_lui_E;

  // Memory
  wire [31:0] PCPlus4M, PCTargetM;
  wire [4:0] RdM;

  // Writeback
  wire [31:0] ALUResultW, ReadDataW, PCPlus4W;
  wire [31:0] ResultW;
  wire [4:0] RdW;

  // Forwarding signals
  wire [1:0] ForwardAE, ForwardBE;
  wire [31:0] SrcAE_forwarded, SrcBE_forwarded;
  
  // Stalling and flushing signals
  wire StallF, StallD, FlushD, FlushE;
  
  // Control hazard signals
  wire PCSrcE;

  // ===== Señales para FP ALU =====
  wire [31:0] FP_result;
  wire [4:0] FP_flags;
  wire FP_enable;
  wire [31:0] ALUResultE_int;
  wire is_fp_op;
  
  assign FP_enable = !StallF;
  assign is_fp_op = ALUControlE[2];

  // ===== FETCH =====
  flopenr #(WIDTH) pcreg(
    .clk(clk),
    .reset(reset),
    .en(!StallF),
    .d(PCNextF),
    .q(PCF)
  );

  adder pcadd4(
    .a(PCF),
    .b(32'd4),
    .y(PCPlus4F)
  );

  mux2 #(WIDTH) pcmux(
    .d0(PCPlus4F),
    .d1(PCTargetE),
    .s(PCSrcE),
    .y(PCNextF)
  );

  ifid_reg ifid(
    .clk(clk),
    .reset(reset),
    .StallD(StallD),
    .FlushD(FlushD),
    .InstrF(InstrF),
    .PCF(PCF),
    .PCPlus4F(PCPlus4F),
    .InstrD(InstrD),
    .PCD(PCD),
    .PCPlus4D(PCPlus4D)
  );

  // ===== DECODE =====
  
  assign is_lui_D = (InstrD[6:0] == 7'b0110111);
  
  regfile rf(
    .clk(clk),
    .we3(RegWriteW),
    .a1(InstrD[19:15]),
    .a2(InstrD[24:20]),
    .a3(RdW),
    .wd3(ResultW),
    .rd1(RD1D),
    .rd2(RD2D)
  );

  extend ext(
    .instr(InstrD[31:7]),
    .immsrc(ImmSrcD),    // ← Ahora es [2:0]
    .immext(ImmExtD)
  );

  idex_reg idex(
    .clk(clk),
    .reset(reset),
    .FlushE(FlushE),
    .RD1D(RD1D),
    .RD2D(RD2D),
    .PCD(PCD),
    .Rs1D(InstrD[19:15]),
    .Rs2D(InstrD[24:20]),
    .RdD(InstrD[11:7]),
    .ImmExtD(ImmExtD),
    .PCPlus4D(PCPlus4D),
    .RegWriteD(RegWriteD),
    .MemWriteD(MemWriteD),
    .JumpD(JumpD),
    .BranchD(BranchD),
    .ALUSrcD(ALUSrcD),
    .ResultSrcD(ResultSrcD),
    .ALUControlD(ALUControlD),
    .is_lui_D(is_lui_D),
    .RD1E(RD1E),
    .RD2E(RD2E),
    .PCE(PCE),
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdE(RdE),
    .ImmExtE(ImmExtE),
    .PCPlus4E(PCPlus4E),
    .RegWriteE(RegWriteE),
    .MemWriteE(MemWriteE),
    .JumpE(JumpE),
    .BranchE(BranchE),
    .ALUSrcE(ALUSrcE),
    .ResultSrcE(ResultSrcE),
    .ALUControlE(ALUControlE),
    .is_lui_E(is_lui_E)
  );

  // ===== EXECUTE =====
  assign PCSrcE = (BranchE && ZeroE) || JumpE;
  
  hazard_unit hu(
    .Rs1E(Rs1E),
    .Rs2E(Rs2E),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    .Rs1D(InstrD[19:15]),
    .Rs2D(InstrD[24:20]),
    .RdE(RdE),
    .ResultSrcE(ResultSrcE),
    .PCSrcE(PCSrcE),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .StallF(StallF),
    .StallD(StallD),
    .FlushD(FlushD),
    .FlushE(FlushE)
  );

  mux3 #(WIDTH) forwardAmux(
    .d0(RD1E),
    .d1(ResultW),
    .d2(ALUResultM),
    .s(ForwardAE),
    .y(SrcAE_forwarded)
  );

  mux3 #(WIDTH) forwardBmux(
    .d0(RD2E),
    .d1(ResultW),
    .d2(ALUResultM),
    .s(ForwardBE),
    .y(SrcBE_forwarded)
  );

  wire [31:0] SrcAE_final;
  assign SrcAE_final = is_lui_E ? 32'b0 : SrcAE_forwarded;
  
  assign SrcAE = SrcAE_final;
  assign WriteDataE = SrcBE_forwarded;

  mux2 #(WIDTH) srcbmux(
    .d0(SrcBE_forwarded),
    .d1(ImmExtE),
    .s(ALUSrcE),
    .y(SrcBE)
  );

  alu alu(
    .a(SrcAE_final),
    .b(SrcBE),
    .alucontrol(ALUControlE),
    .result(ALUResultE_int),
    .zero(ZeroE)
  );

  aluf aluf(
    .op_a(SrcAE),
    .op_b(SrcBE),
    .op_code(ALUControlE[1:0]),
    .mode_fp(1'b1),
    .round_mode(2'b00),
    .result(FP_result),
    .flags(FP_flags)
  );
  
  mux2 #(WIDTH) alu_select_mux(
    .d0(ALUResultE_int),
    .d1(FP_result),
    .s(is_fp_op),
    .y(ALUResultE)
  );
  
  adder pcaddbranch(
    .a(PCE),
    .b(ImmExtE),
    .y(PCTargetE)
  );

  exmem_reg exmem(
    .clk(clk),
    .reset(reset),
    .ALUResultE(ALUResultE),
    .WriteDataE(WriteDataE),
    .PCPlus4E(PCPlus4E),
    .PCTargetE(PCTargetE),
    .RdE(RdE),
    .RegWriteE(RegWriteE),
    .MemWriteE(MemWriteE),
    .JumpE(JumpE),
    .BranchE(BranchE),
    .ZeroE(ZeroE),
    .ResultSrcE(ResultSrcE),
    .ALUResultM(ALUResultM),
    .WriteDataM(WriteDataM),
    .PCPlus4M(PCPlus4M),
    .PCTargetM(PCTargetM),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .MemWriteM(MemWriteM),
    .JumpM(JumpM),
    .BranchM(BranchM),
    .ZeroM(ZeroM),
    .ResultSrcM(ResultSrcM)
  );

  memwb_reg memwb(
    .clk(clk),
    .reset(reset),
    .ALUResultM(ALUResultM),
    .ReadDataM(ReadDataM),
    .PCPlus4M(PCPlus4M),
    .RdM(RdM),
    .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .ALUResultW(ALUResultW),
    .ReadDataW(ReadDataW),
    .PCPlus4W(PCPlus4W),
    .RdW(RdW),
    .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW)
  );

  mux3 #(WIDTH) resultmux(
    .d0(ALUResultW),
    .d1(ReadDataW),
    .d2(PCPlus4W),
    .s(ResultSrcW),
    .y(ResultW)
  );

endmodule
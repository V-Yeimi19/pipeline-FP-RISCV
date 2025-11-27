// IF/ID Pipeline Register con Stall y Flush
module ifid_reg(input clk, reset,
                input StallD,  // Señal de stall
                input FlushD,  // Señal de flush (para control hazards)
                input [31:0] InstrF, PCF, PCPlus4F,
                output reg [31:0] InstrD, PCD, PCPlus4D);

  always @(posedge clk) begin
    if (reset || FlushD) begin  // Reset o Flush = insertar NOP
      InstrD <= 32'h00000013;  // NOP (addi x0, x0, 0)
      PCD <= 0;
      PCPlus4D <= 0;
    end else if (!StallD) begin  // Solo avanzar si no hay stall
      InstrD <= InstrF;
      PCD <= PCF;
      PCPlus4D <= PCPlus4F;
    end
    // Si StallD = 1, mantener valores actuales (no hacer nada)
  end
endmodule

// ID/EX Pipeline Register con Flush
module idex_reg(input clk, reset,
                input FlushE,  // Señal de flush (insertar burbuja)
                input [31:0] RD1D, RD2D, PCD,
                input [4:0] Rs1D, Rs2D, RdD,
                input [31:0] ImmExtD, PCPlus4D,
                input RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD,
                input [1:0] ResultSrcD,
                input [2:0] ALUControlD,
                input RegWriteFPD, FPOpD,  // Nuevas señales FP
                output reg [31:0] RD1E, RD2E, PCE,
                output reg [4:0] Rs1E, Rs2E, RdE,
                output reg [31:0] ImmExtE, PCPlus4E,
                output reg RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE,
                output reg [1:0] ResultSrcE,
                output reg [2:0] ALUControlE,
                output reg RegWriteFPE, FPOpE);  // Nuevas señales FP

  always @(posedge clk) begin
    if (reset || FlushE) begin  // Reset o Flush = insertar NOP
      RD1E <= 0;
      RD2E <= 0;
      PCE <= 0;
      Rs1E <= 0;
      Rs2E <= 0;
      RdE <= 0;
      ImmExtE <= 0;
      PCPlus4E <= 0;
      RegWriteE <= 0;  // Deshabilita escritura
      MemWriteE <= 0;  // Deshabilita escritura a memoria
      JumpE <= 0;
      BranchE <= 0;
      ALUSrcE <= 0;
      ResultSrcE <= 0;
      ALUControlE <= 0;
      RegWriteFPE <= 0;  // Deshabilita escritura FP
      FPOpE <= 0;
    end else begin
      RD1E <= RD1D;
      RD2E <= RD2D;
      PCE <= PCD;
      Rs1E <= Rs1D;
      Rs2E <= Rs2D;
      RdE <= RdD;
      ImmExtE <= ImmExtD;
      PCPlus4E <= PCPlus4D;
      RegWriteE <= RegWriteD;
      MemWriteE <= MemWriteD;
      JumpE <= JumpD;
      BranchE <= BranchD;
      ALUSrcE <= ALUSrcD;
      ResultSrcE <= ResultSrcD;
      ALUControlE <= ALUControlD;
      RegWriteFPE <= RegWriteFPD;
      FPOpE <= FPOpD;
    end
  end
endmodule

// EX/MEM
module exmem_reg(input clk, reset,
                 input [31:0] ALUResultE, WriteDataE, PCPlus4E, PCTargetE,
                 input [4:0] RdE,
                 input RegWriteE, MemWriteE, JumpE, BranchE, ZeroE,
                 input [1:0] ResultSrcE,
                 input RegWriteFPE, FPOpE,  // Nuevas señales FP
                 output reg [31:0] ALUResultM, WriteDataM, PCPlus4M, PCTargetM,
                 output reg [4:0] RdM,
                 output reg RegWriteM, MemWriteM, JumpM, BranchM, ZeroM,
                 output reg [1:0] ResultSrcM,
                 output reg RegWriteFPM, FPOpM);  // Nuevas señales FP

  always @(posedge clk) begin
    if (reset) begin
      ALUResultM <= 0;
      WriteDataM <= 0;
      PCPlus4M <= 0;
      PCTargetM <= 0;
      RdM <= 0;
      RegWriteM <= 0;
      MemWriteM <= 0;
      JumpM <= 0;
      BranchM <= 0;
      ZeroM <= 0;
      ResultSrcM <= 0;
      RegWriteFPM <= 0;
      FPOpM <= 0;
    end else begin
      ALUResultM <= ALUResultE;
      WriteDataM <= WriteDataE;
      PCPlus4M <= PCPlus4E;
      PCTargetM <= PCTargetE;
      RdM <= RdE;
      RegWriteM <= RegWriteE;
      MemWriteM <= MemWriteE;
      JumpM <= JumpE;
      BranchM <= BranchE;
      ZeroM <= ZeroE;
      ResultSrcM <= ResultSrcE;
      RegWriteFPM <= RegWriteFPE;
      FPOpM <= FPOpE;
    end
  end
endmodule

// MEM/WB
module memwb_reg(input clk, reset,
                 input [31:0] ALUResultM, ReadDataM, PCPlus4M,
                 input [4:0] RdM,
                 input RegWriteM,
                 input [1:0] ResultSrcM,
                 input RegWriteFPM, FPOpM,  // Nuevas señales FP
                 output reg [31:0] ALUResultW, ReadDataW, PCPlus4W,
                 output reg [4:0] RdW,
                 output reg RegWriteW,
                 output reg [1:0] ResultSrcW,
                 output reg RegWriteFPW, FPOpW);  // Nuevas señales FP

  always @(posedge clk) begin
    if (reset) begin
      ALUResultW <= 0;
      ReadDataW <= 0;
      PCPlus4W <= 0;
      RdW <= 0;
      RegWriteW <= 0;
      ResultSrcW <= 0;
      RegWriteFPW <= 0;
      FPOpW <= 0;
    end else begin
      ALUResultW <= ALUResultM;
      ReadDataW <= ReadDataM;
      PCPlus4W <= PCPlus4M;
      RdW <= RdM;
      RegWriteW <= RegWriteM;
      ResultSrcW <= ResultSrcM;
      RegWriteFPW <= RegWriteFPM;
      FPOpW <= FPOpM;
    end
  end
endmodule

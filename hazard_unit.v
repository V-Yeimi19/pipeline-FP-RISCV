// Hazard Unit con Forwarding Logic, Load-Use Stall Detection y Control Hazards
module hazard_unit(
  // Entradas desde Decode (ID)
  input [4:0] Rs1D, Rs2D,
  
  // Entradas desde Execute (EX)
  input [4:0] Rs1E, Rs2E, RdE,
  input [1:0] ResultSrcE,  // Para detectar lw (ResultSrcE[0] = 1)
  input PCSrcE,            // Para detectar saltos tomados
  
  // Entradas desde Memory (MEM)
  input [4:0] RdM,
  input RegWriteM,
  
  // Entradas desde Writeback (WB)
  input [4:0] RdW,
  input RegWriteW,
  
  // Salidas de control de forwarding
  output [1:0] ForwardAE,
  output [1:0] ForwardBE,
  
  // Salidas de control de stalling y flushing
  output StallF,   // Stall Fetch stage
  output StallD,   // Stall Decode stage
  output FlushD,   // Flush Decode stage (control hazards)
  output FlushE    // Flush Execute stage (data hazards y control hazards)
);

  // ===== FORWARDING LOGIC (Lógica Modificada) =====

  // Condición de Forwarding desde EX/MEM (Máxima Prioridad: 10)
  // Data está en el registro EX/MEM y está a punto de entrar a MEM
  wire FwdExMemA = (Rs1E == RdM) && RegWriteM && (Rs1E != 5'b0);
  wire FwdExMemB = (Rs2E == RdM) && RegWriteM && (Rs2E != 5'b0);

  // Condición de Forwarding desde MEM/WB (Prioridad Media: 01)
  // Data está en el registro MEM/WB y está a punto de entrar a WB.
  // IMPORTANTE: SOLO se activa si la condición EX/MEM NO se cumple.
  wire FwdMemWbA = (Rs1E == RdW) && RegWriteW && (Rs1E != 5'b0) && !FwdExMemA;
  wire FwdMemWbB = (Rs2E == RdW) && RegWriteW && (Rs2E != 5'b0) && !FwdExMemB;


  // Forwarding para SrcA (Rs1E)
  assign ForwardAE =
    FwdExMemA ? 2'b10 : // Prioridad más alta
    FwdMemWbA ? 2'b01 : // Solo si no hay FwdExMem
    2'b00;

  // Forwarding para SrcB (Rs2E)
  assign ForwardBE =
    FwdExMemB ? 2'b10 : // Prioridad más alta
    FwdMemWbB ? 2'b01 : // Solo si no hay FwdExMem
    2'b00;

  // 

  // ===== LOAD-USE HAZARD DETECTION (Sin Modificar) =====
  // Detectar si la instrucción en EX es un lw (load word)
  // ResultSrcE[0] = 1 indica que es una instrucción lw
  wire lwStall;
  
  assign lwStall = ResultSrcE[0] &&  // La instrucción en EX es lw
                   ((Rs1D == RdE) || (Rs2D == RdE)) &&  // Dependencia RAW
                   (RdE != 5'b0);  // No hacer stall para x0
  
  // ===== CONTROL HAZARD HANDLING (Sin Modificar) =====
  
  assign StallF = lwStall;            // Solo stall en load-use
  assign StallD = lwStall;            // Solo stall en load-use
  assign FlushD = PCSrcE;             // Flush ID cuando hay salto tomado
  assign FlushE = lwStall | PCSrcE;   // Flush EX en load-use o salto tomado

endmodule
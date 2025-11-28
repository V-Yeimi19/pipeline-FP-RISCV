module testbench;

  // Señales de Clock/Reset
  reg clk;
  reg reset;
  
  // Señales de la Interfaz de Memoria de Datos (desde la etapa MEM)
  wire [31:0] WriteData;
  wire [31:0] DataAdr;
  wire MemWrite;
  
  // =======================================================
  // INSTANCIACIÓN DEL DISPOSITIVO BAJO PRUEBA (DUT)
  // Nota: Asume que 'top' contiene 'rvpipeline' que a su vez contiene 'dp'
  // =======================================================
  
  top dut(
    .clk(clk),
    .reset(reset),
    .WriteData(WriteData),
    .DataAdr(DataAdr),
    .MemWrite(MemWrite)
  );
  
  // =======================================================
  // GENERACIÓN DE CLOCK Y RESET
  // =======================================================
  
  // Generar Clock (Período de 10ns)
  always begin
    clk = 1;
    #5;
    clk = 0;
    #5;
  end
  
  // Inicializar y Resetear
  initial begin
    reset = 1;
    #15; // Mantener reset por 1.5 ciclos
    reset = 0;
    $display("--- SIMULATION START ---");
  end
  
  // =======================================================
  // MONITOREO Y VERIFICACIÓN DETALLADA POR CICLO
  // =======================================================
  
  reg [31:0] cycle_count;
  initial cycle_count = 0;
  
  // Monitoreo en el borde positivo del clock
  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      
      $display("\n==============================================");
      $display("=== Cycle %0d (POST-CLK) ===", cycle_count);
      $display("==============================================");

      // --- Etapa IF ---
      $display("\n--- IF Stage (Fetch) ---");
      // Asume que PCF e InstrF están disponibles en la interfaz de 'dut' o 'dut.rvpipeline.dp'
      $display("  PCF (PC Actual)    = %h", dut.rvpipeline.dp.PCF);
      $display("  InstrF (Next Inst) = %h", dut.rvpipeline.dp.InstrF);
      $display("  PCPlus4F           = %h", dut.rvpipeline.dp.PCPlus4F);
      $display("  PCNextF            = %h", dut.rvpipeline.dp.PCNextF);

      // --- Señales de Hazard Unit ---
      $display("\n--- HAZARD & CONTROL Signals (HU) ---");
      $display("  PCSrcE (Jump/Branch Taken) = %b", dut.rvpipeline.dp.PCSrcE);
      $display("  StallF (Freeze PC)         = %b", dut.rvpipeline.dp.StallF);
      $display("  StallD (Freeze IF/ID)      = %b", dut.rvpipeline.dp.StallD);
      $display("  FlushD (NOP in ID)         = %b", dut.rvpipeline.dp.FlushD);
      $display("  FlushE (NOP in EX)         = %b", dut.rvpipeline.dp.FlushE);
      
      // --- Etapa ID (Decode) ---
      $display("\n--- ID Stage (Decode) ---");
      $display("  InstrD (ID/EX Input) = %h", dut.rvpipeline.dp.InstrD);
      $display("  PCD                  = %h", dut.rvpipeline.dp.PCD);
      $display("  RD1D / RD2D          = %h / %h", dut.rvpipeline.dp.RD1D, dut.rvpipeline.dp.RD2D);
      $display("  RdD (Dest Reg)       = %d", dut.rvpipeline.dp.InstrD[11:7]);
      $display("  ImmExtD              = %h", dut.rvpipeline.dp.ImmExtD);
      $display("  RegWriteD            = %b", dut.rvpipeline.RegWriteD);
      
      // --- Etapa EX (Execute) ---
      $display("\n--- EX Stage (Execute) ---");
      $display("  RdE (Dest Reg)       = %d", dut.rvpipeline.dp.RdE);
      $display("  Rs1E / Rs2E          = %d / %d", dut.rvpipeline.dp.Rs1E, dut.rvpipeline.dp.Rs2E);
      $display("  ForwardAE / ForwardBE= %b / %b", dut.rvpipeline.dp.ForwardAE, dut.rvpipeline.dp.ForwardBE);
      $display("  SrcAE_final / SrcBE  = %h / %h", dut.rvpipeline.dp.SrcAE_final, dut.rvpipeline.dp.SrcBE);
      $display("  ALUControlE          = %b", dut.rvpipeline.dp.ALUControlE);
      $display("  ALUResultE           = %h", dut.rvpipeline.dp.ALUResultE);
      $display("  BranchE / ZeroE      = %b / %b", dut.rvpipeline.dp.BranchE, dut.rvpipeline.dp.ZeroE);
      $display("  PCTargetE (Target PC)= %h", dut.rvpipeline.dp.PCTargetE);

      // --- Etapa MEM (Memory) ---
      $display("\n--- MEM Stage (Memory Access) ---");
      $display("  RdM (Dest Reg)       = %d", dut.rvpipeline.dp.RdM);
      $display("  ALUResultM (Addr)    = %h", dut.rvpipeline.dp.ALUResultM);
      $display("  RegWriteM / MemWriteM= %b / %b", dut.rvpipeline.dp.RegWriteM, dut.rvpipeline.dp.MemWriteM);
      if (MemWrite) begin
        $display("  *** MEMORY WRITE: MEM[%h] = %h ***", DataAdr, WriteData);
      end
      
      // --- Etapa WB (Writeback) ---
      $display("\n--- WB Stage (Writeback) ---");
      $display("  RdW (Dest Reg)       = %d", dut.rvpipeline.dp.RdW);
      $display("  ResultW (Data to Reg)= %h", dut.rvpipeline.dp.ResultW);
      $display("  RegWriteW            = %b", dut.rvpipeline.dp.RegWriteW);
      
      // --- Registros (Solo unos pocos para referencia) ---
      $display("\n--- REGISTERS ---");
      $display("  x2 = %d (0x%h)", dut.rvpipeline.dp.rf.rf[2], dut.rvpipeline.dp.rf.rf[2]);
      $display("  x4 = %d (0x%h)", dut.rvpipeline.dp.rf.rf[4], dut.rvpipeline.dp.rf.rf[4]);
      $display("  x7 = %d (0x%h)", dut.rvpipeline.dp.rf.rf[7], dut.rvpipeline.dp.rf.rf[7]);
      $display("  x9 = %d (0x%h)", dut.rvpipeline.dp.rf.rf[9], dut.rvpipeline.dp.rf.rf[9]);

      // --- Condición de Éxito y Timeout ---
      if (MemWrite && DataAdr == 32'd100 && WriteData == 32'd25) begin
        $display("\n***************************************************");
        $display("SUCCESS! Wrote 25 to memory address 100 on Cycle %0d.", cycle_count);
        $display("***************************************************");
        #20;
        $finish;
      end
      
      if (cycle_count == 100) begin
        $display("\nERROR: Test timeout - did not write 25 to address 100");
        $finish;
      end
    end
  end
  
  // Generar archivos VCD para visualización de ondas
  initial begin
    $dumpfile("testbench.vcd");
    // Asegúrate de que 'dut' sea el módulo superior donde están anidados los componentes.
    $dumpvars(0, dut);
  end
endmodule
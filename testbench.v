// Testbench Unificado - Pipeline RISC-V con soporte FP
// Ejecuta pruebas de:
//   1. ALU de enteros (tests unitarios)
//   2. ALU de punto flotante (tests unitarios)
//   3. Pipeline completo (integración)

`timescale 1ns / 1ps

module testbench_unified;

  // SECCIÓN 1: TEST DE ALUs UNITARIAS
  reg clk;
  reg [31:0] alu_a, alu_b;
  reg [2:0] alu_ctrl;
  wire [31:0] result_int, result_fp;
  wire zero_int;

  // Instanciar ALUs para pruebas unitarias
  alu_int alu_int_test(
    .a(alu_a),
    .b(alu_b),
    .alucontrol(alu_ctrl),
    .result(result_int),
    .zero(zero_int)
  );

  alu_fp alu_fp_test(
    .a(alu_a),
    .b(alu_b),
    .alucontrol(alu_ctrl),
    .result(result_fp)
  );
  
  // SECCIÓN 2: TEST DEL PIPELINE COMPLETO
  reg reset;
  wire [31:0] WriteData;
  wire [31:0] DataAdr;
  wire MemWrite;

  top dut(
    .clk(clk),
    .reset(reset),
    .WriteData(WriteData),
    .DataAdr(DataAdr),
    .MemWrite(MemWrite)
  );

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Variables de control y contadores
  integer test_num;
  integer passed_int, passed_fp, failed_int, failed_fp;
  reg [31:0] cycle_count;
  reg alu_tests_done;
  reg pipeline_tests_started;

  // Función auxiliar para mostrar FP
  task display_fp;
    input [31:0] value;
    input [50*8:1] label;
    begin
      $display("    %s: S=%b Exp=%03d (0x%02X) Mant=0x%06X => 0x%08X",
               label, value[31], value[30:23], value[30:23], value[22:0], value);
    end
  endtask

  // TESTS DE ALUs UNITARIAS
  initial begin
    $display("\n   TESTBENCH UNIFICADO - PIPELINE RISC-V FP             \n");

    // Inicialización
    test_num = 0;
    passed_int = 0;
    passed_fp = 0;
    failed_int = 0;
    failed_fp = 0;
    alu_tests_done = 0;
    pipeline_tests_started = 0;

    #10;
    $display("  PARTE 1: PRUEBAS UNITARIAS - ALU DE ENTEROS\n");

    // Test 1: ADD
    test_num = test_num + 1;
    alu_a = 32'd10;
    alu_b = 32'd20;
    alu_ctrl = 3'b000;
    #10;
    $display("[Test %0d] INT ADD: %0d + %0d = %0d", test_num, alu_a, alu_b, result_int);
    if (result_int == 32'd30) begin
      $display("          ✓ PASS (esperado: 30)\n");
      passed_int = passed_int + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 30, obtenido: %0d)\n", result_int);
      failed_int = failed_int + 1;
    end

    // Test 2: SUB
    test_num = test_num + 1;
    alu_a = 32'd50;
    alu_b = 32'd15;
    alu_ctrl = 3'b001;
    #10;
    $display("[Test %0d] INT SUB: %0d - %0d = %0d", test_num, alu_a, alu_b, result_int);
    if (result_int == 32'd35) begin
      $display("          ✓ PASS (esperado: 35)\n");
      passed_int = passed_int + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 35, obtenido: %0d)\n", result_int);
      failed_int = failed_int + 1;
    end

    // Test 3: AND
    test_num = test_num + 1;
    alu_a = 32'hF0F0F0F0;
    alu_b = 32'h0F0F0F0F;
    alu_ctrl = 3'b010;
    #10;
    $display("[Test %0d] INT AND: 0x%08X & 0x%08X = 0x%08X", test_num, alu_a, alu_b, result_int);
    if (result_int == 32'h00000000) begin
      $display("          ✓ PASS (esperado: 0x00000000)\n");
      passed_int = passed_int + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x00000000)\n");
      failed_int = failed_int + 1;
    end

    // Test 4: OR
    test_num = test_num + 1;
    alu_a = 32'hF0F0F0F0;
    alu_b = 32'h0F0F0F0F;
    alu_ctrl = 3'b011;
    #10;
    $display("[Test %0d] INT OR: 0x%08X | 0x%08X = 0x%08X", test_num, alu_a, alu_b, result_int);
    if (result_int == 32'hFFFFFFFF) begin
      $display("          ✓ PASS (esperado: 0xFFFFFFFF)\n");
      passed_int = passed_int + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0xFFFFFFFF)\n");
      failed_int = failed_int + 1;
    end

    // Test 5: XOR
    test_num = test_num + 1;
    alu_a = 32'hAAAAAAAA;
    alu_b = 32'h55555555;
    alu_ctrl = 3'b100;
    #10;
    $display("[Test %0d] INT XOR: 0x%08X ^ 0x%08X = 0x%08X", test_num, alu_a, alu_b, result_int);
    if (result_int == 32'hFFFFFFFF) begin
      $display("          ✓ PASS (esperado: 0xFFFFFFFF)\n");
      passed_int = passed_int + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0xFFFFFFFF)\n");
      failed_int = failed_int + 1;
    end

    // Test 6: SLL
    test_num = test_num + 1;
    alu_a = 32'h00000001;
    alu_b = 32'd4;
    alu_ctrl = 3'b110;
    #10;
    $display("[Test %0d] INT SLL: 0x%08X << %0d = 0x%08X", test_num, alu_a, alu_b, result_int);
    if (result_int == 32'h00000010) begin
      $display("          ✓ PASS (esperado: 0x00000010)\n");
      passed_int = passed_int + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x00000010)\n");
      failed_int = failed_int + 1;
    end

    $display("\nPARTE 2: PRUEBAS UNITARIAS - ALU DE PUNTO FLOTANTE\n");

    // Test 7: FADD (2.0 + 3.0 = 5.0)
    test_num = test_num + 1;
    alu_a = 32'h40000000; // 2.0
    alu_b = 32'h40400000; // 3.0
    alu_ctrl = 3'b000;
    #10;
    $display("[Test %0d] FP ADD: 2.0 + 3.0 = 5.0", test_num);
    display_fp(alu_a, "A (2.0)");
    display_fp(alu_b, "B (3.0)");
    display_fp(result_fp, "Result");
    if (result_fp == 32'h40A00000) begin
      $display("          ✓ PASS (esperado: 0x40A00000)\n");
      passed_fp = passed_fp + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x40A00000)\n");
      failed_fp = failed_fp + 1;
    end

    // Test 8: FSUB (5.0 - 2.0 = 3.0)
    test_num = test_num + 1;
    alu_a = 32'h40A00000; // 5.0
    alu_b = 32'h40000000; // 2.0
    alu_ctrl = 3'b001;
    #10;
    $display("[Test %0d] FP SUB: 5.0 - 2.0 = 3.0", test_num);
    display_fp(alu_a, "A (5.0)");
    display_fp(alu_b, "B (2.0)");
    display_fp(result_fp, "Result");
    if (result_fp == 32'h40400000) begin
      $display("          ✓ PASS (esperado: 0x40400000)\n");
      passed_fp = passed_fp + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x40400000)\n");
      failed_fp = failed_fp + 1;
    end

    // Test 9: FMUL (2.0 * 3.0 = 6.0)
    test_num = test_num + 1;
    alu_a = 32'h40000000; // 2.0
    alu_b = 32'h40400000; // 3.0
    alu_ctrl = 3'b010;
    #10;
    $display("[Test %0d] FP MUL: 2.0 * 3.0 = 6.0", test_num);
    display_fp(alu_a, "A (2.0)");
    display_fp(alu_b, "B (3.0)");
    display_fp(result_fp, "Result");
    if (result_fp == 32'h40C00000) begin
      $display("          ✓ PASS (esperado: 0x40C00000)\n");
      passed_fp = passed_fp + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x40C00000)\n");
      failed_fp = failed_fp + 1;
    end

    // Test 10: FDIV (6.0 / 2.0 = 3.0)
    test_num = test_num + 1;
    alu_a = 32'h40C00000; // 6.0
    alu_b = 32'h40000000; // 2.0
    alu_ctrl = 3'b011;
    #10;
    $display("[Test %0d] FP DIV: 6.0 / 2.0 = 3.0", test_num);
    display_fp(alu_a, "A (6.0)");
    display_fp(alu_b, "B (2.0)");
    display_fp(result_fp, "Result");
    if (result_fp == 32'h40400000) begin
      $display("          ✓ PASS (esperado: 0x40400000)\n");
      passed_fp = passed_fp + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x40400000)\n");
      failed_fp = failed_fp + 1;
    end

    // Test 11: División por cero
    test_num = test_num + 1;
    alu_a = 32'h40000000; // 2.0
    alu_b = 32'h00000000; // 0.0
    alu_ctrl = 3'b011;
    #10;
    $display("[Test %0d] FP DIV/0: 2.0 / 0.0 = +Inf", test_num);
    display_fp(alu_a, "A (2.0)");
    display_fp(alu_b, "B (0.0)");
    display_fp(result_fp, "Result");
    if (result_fp == 32'h7F800000) begin
      $display("          ✓ PASS (esperado: 0x7F800000 = +Inf)\n");
      passed_fp = passed_fp + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x7F800000 = +Inf)\n");
      failed_fp = failed_fp + 1;
    end

    // Test 12: Negativos
    test_num = test_num + 1;
    alu_a = 32'hC0000000; // -2.0
    alu_b = 32'h40400000; // 3.0
    alu_ctrl = 3'b000;
    #10;
    $display("[Test %0d] FP ADD: -2.0 + 3.0 = 1.0", test_num);
    display_fp(alu_a, "A (-2.0)");
    display_fp(alu_b, "B (3.0)");
    display_fp(result_fp, "Result");
    if (result_fp == 32'h3F800000) begin
      $display("          ✓ PASS (esperado: 0x3F800000 = 1.0)\n");
      passed_fp = passed_fp + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x3F800000 = 1.0)\n");
      failed_fp = failed_fp + 1;
    end

    // Test 13: Multiplicación por cero
    test_num = test_num + 1;
    alu_a = 32'h40000000; // 2.0
    alu_b = 32'h00000000; // 0.0
    alu_ctrl = 3'b010;
    #10;
    $display("[Test %0d] FP MUL: 2.0 * 0.0 = 0.0", test_num);
    display_fp(alu_a, "A (2.0)");
    display_fp(alu_b, "B (0.0)");
    display_fp(result_fp, "Result");
    if (result_fp == 32'h00000000) begin
      $display("          ✓ PASS (esperado: 0x00000000 = 0.0)\n");
      passed_fp = passed_fp + 1;
    end else begin
      $display("          ✗ FAIL (esperado: 0x00000000 = 0.0)\n");
      failed_fp = failed_fp + 1;
    end

    $display("\n  RESUMEN - TESTS UNITARIOS DE ALUs\n");
    $display("  Total pruebas: %0d", test_num);
    $display("");
    $display("  ALU Enteros:");
    $display("    ✓ Pasadas: %0d", passed_int);
    $display("    ✗ Falladas: %0d", failed_int);
    $display("");
    $display("  ALU Punto Flotante:");
    $display("    ✓ Pasadas: %0d", passed_fp);
    $display("    ✗ Falladas: %0d", failed_fp);
    $display("");
    $display("  TOTAL: %0d/%0d PASADAS", passed_int + passed_fp, test_num);
    $display("\n");

    if (failed_int + failed_fp == 0)
      $display("  ★★★ TODOS LOS TESTS UNITARIOS PASARON ★★★\n");
    else
      $display("  ⚠ ALGUNOS TESTS FALLARON ⚠\n");

    alu_tests_done = 1;

    $display("\nPARTE 3: PRUEBAS DE INTEGRACIÓN - PIPELINE COMPLETO\n");
    $display("  Iniciando pipeline con programa de prueba...\n");

    // Iniciar pipeline
    reset = 1;
    cycle_count = 0;
    #15;
    reset = 0;
    pipeline_tests_started = 1;
  end

  always @(posedge clk) begin
    if (pipeline_tests_started && !reset) begin
      cycle_count = cycle_count + 1;

      $display("┌────────────────────────────────────────────────────────────┐");
      $display("│ CICLO %0d", cycle_count);
      $display("├────────────────────────────────────────────────────────────┤");
      $display("│ PC      : 0x%08X", dut.PC);
      $display("│ Instr   : 0x%08X", dut.Instr);
      $display("│ MemWrite: %b  DataAdr: 0x%08X  WriteData: 0x%08X",
               MemWrite, DataAdr, WriteData);
      $display("├────────────────────────────────────────────────────────────┤");

      $display("│ INT Regs: x1=0x%08X x2=0x%08X x3=0x%08X",
               dut.rvpipeline.dp.rf.rf[1],
               dut.rvpipeline.dp.rf.rf[2],
               dut.rvpipeline.dp.rf.rf[3]);
      $display("│           x4=0x%08X x5=0x%08X",
               dut.rvpipeline.dp.rf.rf[4],
               dut.rvpipeline.dp.rf.rf[5]);

      $display("│ FP  Regs: f0=0x%08X f1=0x%08X f2=0x%08X",
               dut.rvpipeline.dp.frf.frf[0],
               dut.rvpipeline.dp.frf.frf[1],
               dut.rvpipeline.dp.frf.frf[2]);
      $display("│           f3=0x%08X f4=0x%08X",
               dut.rvpipeline.dp.frf.frf[3],
               dut.rvpipeline.dp.frf.frf[4]);

      $display("├────────────────────────────────────────────────────────────┤");
      $display("│ Control : RegW=%b RegWFP=%b FPOp=%b ALUCtrl=%03b",
               dut.rvpipeline.c.RegWrite,
               dut.rvpipeline.c.RegWriteFP,
               dut.rvpipeline.c.FPOp,
               dut.rvpipeline.c.ALUControl);

      $display("│ Pipeline: E[Rd=%02d RW=%b FP=%b] M[Rd=%02d RW=%b] W[Rd=%02d RW=%b]",
               dut.rvpipeline.dp.RdE, dut.rvpipeline.dp.RegWriteE,
               dut.rvpipeline.dp.FPOpE,
               dut.rvpipeline.dp.RdM, dut.rvpipeline.dp.RegWriteM,
               dut.rvpipeline.dp.RdW, dut.rvpipeline.dp.RegWriteW);

      $display("│ Hazards : FwdA=%b FwdB=%b Stall=%b Flush=%b",
               dut.rvpipeline.dp.ForwardAE, dut.rvpipeline.dp.ForwardBE,
               dut.rvpipeline.dp.StallD, dut.rvpipeline.dp.FlushE);

      $display("│ ALU     : A=0x%08X B=0x%08X R=0x%08X (FP=%b)",
               dut.rvpipeline.dp.SrcAE, dut.rvpipeline.dp.SrcBE,
               dut.rvpipeline.dp.ALUResultE, dut.rvpipeline.dp.FPOpE);

      $display("└────────────────────────────────────────────────────────────┘\n");

      if (cycle_count == 50) begin
        $display("  RESUMEN FINAL - PIPELINE");
        $display("\n  Registros Finales de Enteros:");
        $display("    x1 = 0x%08X", dut.rvpipeline.dp.rf.rf[1]);
        $display("    x2 = 0x%08X", dut.rvpipeline.dp.rf.rf[2]);
        $display("    x3 = 0x%08X", dut.rvpipeline.dp.rf.rf[3]);
        $display("    x4 = 0x%08X", dut.rvpipeline.dp.rf.rf[4]);
        $display("    x5 = 0x%08X", dut.rvpipeline.dp.rf.rf[5]);

        $display("\n  Registros Finales de Punto Flotante:");
        $display("    f0 = 0x%08X", dut.rvpipeline.dp.frf.frf[0]);
        $display("    f1 = 0x%08X", dut.rvpipeline.dp.frf.frf[1]);
        $display("    f2 = 0x%08X", dut.rvpipeline.dp.frf.frf[2]);
        $display("    f3 = 0x%08X", dut.rvpipeline.dp.frf.frf[3]);
        $display("    f4 = 0x%08X", dut.rvpipeline.dp.frf.frf[4]);

        $display("  ★ SIMULACIÓN COMPLETADA ★\n");
        $finish;
      end
    end
  end

  initial begin
    $dumpfile("testbench_unified.vcd");
    $dumpvars(0, testbench_unified);
  end

endmodule

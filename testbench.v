module testbench;
  reg clk;
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
    reset = 1;
    #15;
    reset = 0;
  end

  always begin
    clk = 1; #5;
    clk = 0; #5;
  end

  reg [31:0] cycle_count;
  initial cycle_count = 0;

  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;

      $display("\n===== CYCLE %0d =====", cycle_count);
      $display("PC=%h | Instr=%h | MemWrite=%b | DataAdr=%h | WriteData=%h",
               dut.PC, dut.Instr, MemWrite, DataAdr, WriteData);

      $display("INT Registers: x1=%h x2=%h x3=%h x4=%h x5=%h",
               dut.rvpipeline.dp.rf.rf[1], dut.rvpipeline.dp.rf.rf[2],
               dut.rvpipeline.dp.rf.rf[3], dut.rvpipeline.dp.rf.rf[4],
               dut.rvpipeline.dp.rf.rf[5]);

      $display("FP  Registers: f0=%h f1=%h f2=%h f3=%h f4=%h",
               dut.rvpipeline.dp.frf.frf[0], dut.rvpipeline.dp.frf.frf[1],
               dut.rvpipeline.dp.frf.frf[2], dut.rvpipeline.dp.frf.frf[3],
               dut.rvpipeline.dp.frf.frf[4]);

      $display("Control: RegWrite=%b RegWriteFP=%b FPOp=%b ALUControl=%b",
               dut.rvpipeline.c.RegWrite, dut.rvpipeline.c.RegWriteFP,
               dut.rvpipeline.c.FPOp, dut.rvpipeline.c.ALUControl);

      $display("Pipeline: RdE=%d RegWriteE=%b FPOpE=%b | RdM=%d RegWriteM=%b | RdW=%d RegWriteW=%b",
               dut.rvpipeline.dp.RdE, dut.rvpipeline.dp.RegWriteE, dut.rvpipeline.dp.FPOpE,
               dut.rvpipeline.dp.RdM, dut.rvpipeline.dp.RegWriteM,
               dut.rvpipeline.dp.RdW, dut.rvpipeline.dp.RegWriteW);

      $display("Hazards: ForwardAE=%b ForwardBE=%b | Stall=%b Flush=%b",
               dut.rvpipeline.dp.ForwardAE, dut.rvpipeline.dp.ForwardBE,
               dut.rvpipeline.dp.StallD, dut.rvpipeline.dp.FlushE);

      $display("ALU: SrcA=%h SrcB=%h Result=%h fp_op=%b",
               dut.rvpipeline.dp.SrcAE, dut.rvpipeline.dp.SrcBE,
               dut.rvpipeline.dp.ALUResultE, dut.rvpipeline.dp.FPOpE);

      if (cycle_count == 50) begin
        $display("\n========== TEST SUMMARY ==========");
        $display("Final INT Registers:");
        $display("  x1=%h x2=%h x3=%h x4=%h x5=%h",
                 dut.rvpipeline.dp.rf.rf[1], dut.rvpipeline.dp.rf.rf[2],
                 dut.rvpipeline.dp.rf.rf[3], dut.rvpipeline.dp.rf.rf[4],
                 dut.rvpipeline.dp.rf.rf[5]);
        $display("Final FP Registers:");
        $display("  f0=%h f1=%h f2=%h f3=%h f4=%h",
                 dut.rvpipeline.dp.frf.frf[0], dut.rvpipeline.dp.frf.frf[1],
                 dut.rvpipeline.dp.frf.frf[2], dut.rvpipeline.dp.frf.frf[3],
                 dut.rvpipeline.dp.frf.frf[4]);
        $display("==================================\n");
        $finish;
      end
    end
  end

  initial begin
    $dumpfile("testbench.vcd");
    $dumpvars(0, dut);
  end
endmodule

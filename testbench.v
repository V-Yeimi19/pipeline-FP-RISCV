module testbench;
  reg          clk;
  reg          reset;
  wire [31:0]  WriteData;
  wire [31:0]  DataAdr;
  wire         MemWrite;
  
  // instantiate device to be tested
  top dut(
    .clk(clk), 
    .reset(reset), 
    .WriteData(WriteData), 
    .DataAdr(DataAdr), 
    .MemWrite(MemWrite)
  );

  // initialize test
  initial begin
    reset = 1; 
    # 15;
    reset = 0;
  end

  // generate clock to sequence tests
  always begin
    clk = 1;
    # 5; clk = 0; # 5;
  end

  // check results - For simple ADDI instructions, we just monitor
  reg [31:0] cycle_count;
  initial cycle_count = 0;

  always @(posedge clk) begin
    if (!reset) begin
      cycle_count = cycle_count + 1;
      $display("Cycle %0d: PC=%h, Instr=%h, MemWrite=%b, ALUResult=%h, WriteData=%h",
               cycle_count, dut.PC, dut.Instr, MemWrite, DataAdr, WriteData);
      
      // Display register file and pipeline debug for first cycles
      if (cycle_count <= 20) begin
        $display("  Registers: x1=%h, x2=%h, x3=%h, x4=%h, x5=%h, x6=%h, x7=%h, x8=%h",
                 dut.rvpipeline.dp.rf.rf[1], dut.rvpipeline.dp.rf.rf[2],
                 dut.rvpipeline.dp.rf.rf[3], dut.rvpipeline.dp.rf.rf[4],
                 dut.rvpipeline.dp.rf.rf[5], dut.rvpipeline.dp.rf.rf[6],
                 dut.rvpipeline.dp.rf.rf[7], dut.rvpipeline.dp.rf.rf[8]);
        if (cycle_count <= 15) begin
          $display("  Forwarding: ForwardAE=%b, ForwardBE=%b | Rs1E=%d, Rs2E=%d, RdM=%d, RdW=%d",
                   dut.rvpipeline.dp.ForwardAE, dut.rvpipeline.dp.ForwardBE,
                   dut.rvpipeline.dp.Rs1E, dut.rvpipeline.dp.Rs2E,
                   dut.rvpipeline.dp.RdM, dut.rvpipeline.dp.RdW);
          $display("  Stalling: StallF=%b, StallD=%b, FlushE=%b | lwStall=%b | ResultSrcE=%b",
                   dut.rvpipeline.dp.StallF, dut.rvpipeline.dp.StallD,
                   dut.rvpipeline.dp.FlushE, dut.rvpipeline.dp.hu.lwStall,
                   dut.rvpipeline.dp.ResultSrcE);
          $display("  Flushing: FlushD=%b, PCSrcE=%b | BranchE=%b, JumpE=%b, ZeroE=%b",
                   dut.rvpipeline.dp.FlushD, dut.rvpipeline.dp.PCSrcE,
                   dut.rvpipeline.dp.BranchE, dut.rvpipeline.dp.JumpE, dut.rvpipeline.dp.ZeroE);
          $display("  Pipeline: RdE=%d, RegWriteE=%b, MemWriteE=%b | RdM=%d, RegWriteM=%b, MemWriteM=%b",
                   dut.rvpipeline.dp.RdE, dut.rvpipeline.dp.RegWriteE, dut.rvpipeline.dp.MemWriteE,
                   dut.rvpipeline.dp.RdM, dut.rvpipeline.dp.RegWriteM, dut.rvpipeline.dp.MemWriteM);
          $display("  ALU: ALUResultE=%h, ALUResultM=%h, ALUResultW=%h",
                   dut.rvpipeline.dp.ALUResultE, dut.rvpipeline.dp.ALUResultM, dut.rvpipeline.dp.ALUResultW);
          $display("  ALU inputs: SrcAE=%h, SrcBE=%h, RD1E=%h, ImmExtE=%h",
                   dut.rvpipeline.dp.SrcAE, dut.rvpipeline.dp.SrcBE,
                   dut.rvpipeline.dp.RD1E, dut.rvpipeline.dp.ImmExtE);
        end
      end
      
      // Stop after n cycles
      if (cycle_count == 25) begin
        $display("\n=== Branch/Jump Test Completed ===");
        $finish;
      end
    end
  end

  // waves
  initial begin
    $dumpfile("testbench.vcd");
    $dumpvars(0, dut);
  end
endmodule
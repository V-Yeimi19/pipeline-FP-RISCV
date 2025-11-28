module aludec(
    input  opb5,
    input  [2:0] funct3,
    input  [6:0] funct7,
    input  [1:0] ALUOp,
    input  [6:0] opcode,
    output [2:0] ALUControl
);
  
    wire RtypeSub; 
    reg [2:0] ALUControl_reg; 
    
    assign RtypeSub = funct7[5] & opb5;
    assign ALUControl = ALUControl_reg;
    
    wire is_fp_op = (opcode == 7'b1010011);
    
    always @* begin
        case(ALUOp)
            2'b00: ALUControl_reg = 3'b000; // ADD (LW/SW/LUI)
            2'b01: ALUControl_reg = 3'b001; // SUB (BEQ)
            
            default: begin
                if (is_fp_op) begin
                    case(funct7[4:2])
                        3'b000: ALUControl_reg = 3'b100; // FADD/FSUB
                        3'b010: ALUControl_reg = 3'b101; // FMUL
                        3'b011: ALUControl_reg = 3'b110; // FDIV
                        default: ALUControl_reg = 3'b100;
                    endcase
                end
                else begin
                    case(funct3)
                        3'b000: ALUControl_reg = RtypeSub ? 3'b001 : 3'b000; // ADD/SUB
                        3'b001: ALUControl_reg = 3'b110; // SLL
                        3'b010: ALUControl_reg = 3'b101; // SLT ← CORREGIDO
                        3'b011: ALUControl_reg = 3'b101; // SLTU
                        3'b100: ALUControl_reg = 3'b100; // XOR ← CORREGIDO
                        3'b101: ALUControl_reg = 3'b111; // SRL/SRA
                        3'b110: ALUControl_reg = 3'b011; // OR ← CORREGIDO
                        3'b111: ALUControl_reg = 3'b010; // AND ← CORREGIDO
                        default: ALUControl_reg = 3'bxxx;
                    endcase
                end
            end
        endcase
    end
endmodule
module extend(
    input  [31:7] instr,
    input  [2:0]  immsrc,      // ← Cambio: de 2 bits a 3 bits
    output [31:0] immext
);
  
    reg [31:0] immext_reg; 
    assign immext = immext_reg;
    
    always @* case(immsrc) 
        // I-type 
        3'b000: immext_reg = {{20{instr[31]}}, instr[31:20]}; 
        
        // S-type (stores)
        3'b001: immext_reg = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
        
        // B-type (branches)
        3'b010: immext_reg = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
        
        // J-type (jal)
        3'b011: immext_reg = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0}; 
        
        // ===== NUEVO: U-type (LUI, AUIPC) =====
        3'b100: immext_reg = {instr[31:12], 12'b0};  // Upper 20 bits, lower 12 = 0
        
        default: immext_reg = 32'bx;
    endcase             
endmodule
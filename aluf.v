`timescale 1ns / 1ps

// Wrapper combinacional para las 3 ALUs de punto flotante
module aluf(
    input  wire [31:0] op_a,
    input  wire [31:0] op_b,
    input  wire [1:0]  op_code,      // 00=ADD, 01=MUL, 10=DIV, 11=reserved
    input  wire        mode_fp,      // 1=FP operation, 0=pass-through
    input  wire [1:0]  round_mode,   // Modo de redondeo
    
    output reg  [31:0] result,
    output reg  [4:0]  flags
);

    // Señales de descomposición de operandos
    wire s_a, s_b;
    wire [7:0] exp_a, exp_b;
    wire [22:0] mant_a, mant_b;
    
    assign s_a = op_a[31];
    assign exp_a = op_a[30:23];
    assign mant_a = op_a[22:0];
    assign s_b = op_b[31];
    assign exp_b = op_b[30:23];
    assign mant_b = op_b[22:0];
    
    // Resultados de cada ALU
    wire [31:0] add_result, mul_result, div_result;
    wire [4:0] add_flags, mul_flags, div_flags;
    wire s_add, s_mul, s_div;
    wire [7:0] exp_add, exp_mul, exp_div;
    wire [22:0] mant_add, mant_mul, mant_div;
    
    // Instanciar ALU de suma
    alu_add_pipelined alu_add(
        .s_a(s_a),
        .s_b(s_b),
        .exp_a(exp_a),
        .exp_b(exp_b),
        .mantisa_a(mant_a),
        .mantisa_b(mant_b),
        .mode_r(round_mode),
        .s_c(s_add),
        .exp_c(exp_add),
        .mantisa_c(mant_add),
        .flags(add_flags)
    );
    
    assign add_result = {s_add, exp_add, mant_add};
    
    // Instanciar ALU de multiplicación
    alu_mul_pipelined #(
        .WIDTH(32),
        .EXP_BITS(8),
        .MANT_BITS(23)
    ) alu_mul(
        .op_a(op_a),
        .op_b(op_b),
        .round_mode(round_mode),
        .result(mul_result),
        .flags(mul_flags)
    );
    
    // Instanciar ALU de división
    alu_div_pipelined #(
        .WIDTH(32),
        .EXP_BITS(8),
        .MANT_BITS(23)
    ) alu_div(
        .s_a(s_a),
        .s_b(s_b),
        .exp_a(exp_a),
        .exp_b(exp_b),
        .mantisa_a(mant_a),
        .mantisa_b(mant_b),
        .mode_r(round_mode),
        .s_c(s_div),
        .exp_c(exp_div),
        .mantisa_c(mant_div),
        .flags(div_flags)
    );
    
    assign div_result = {s_div, exp_div, mant_div};
    
    // Multiplexor de salida según operación
    always @(*) begin
        if (!mode_fp) begin
            // Pass-through si no es operación FP
            result = op_a;
            flags = 5'b0;
        end else begin
            case (op_code)
                2'b00: begin  // ADD
                    result = add_result;
                    flags = add_flags;
                end
                2'b01: begin  // MUL
                    result = mul_result;
                    flags = mul_flags;
                end
                2'b10: begin  // DIV
                    result = div_result;
                    flags = div_flags;
                end
                default: begin  // Reserved
                    result = 32'h7FC00000;  // qNaN
                    flags = 5'b00010;  // Invalid operation
                end
            endcase
        end
    end

endmodule
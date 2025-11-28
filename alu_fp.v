// ALU de Punto Flotante para pipeline RISC-V
// Soporta operaciones básicas: ADD, SUB, MUL, DIV en formato IEEE 754 single precision

module alu_fp(
  input  [31:0] a,           // Operando A (FP32)
  input  [31:0] b,           // Operando B (FP32)
  input  [2:0]  alucontrol,  // Control de operación
  output [31:0] result       // Resultado (FP32)
);

  // Decodificación del control:
  // 3'b000: FADD  (suma FP)
  // 3'b001: FSUB  (resta FP)
  // 3'b010: FMUL  (multiplicación FP)
  // 3'b011: FDIV  (división FP)

  wire [31:0] fp_add_result, fp_sub_result, fp_mul_result, fp_div_result;

  // Instanciar módulos de operaciones FP
  fp_add_sub fp_add_inst(
    .a(a),
    .b(b),
    .add_sub(1'b0),
    .result(fp_add_result)
  );

  fp_add_sub fp_sub_inst(
    .a(a),
    .b(b),
    .add_sub(1'b1),
    .result(fp_sub_result)
  );

  fp_mul fp_mul_inst(
    .a(a),
    .b(b),
    .result(fp_mul_result)
  );

  fp_div fp_div_inst(
    .a(a),
    .b(b),
    .result(fp_div_result)
  );

  // Multiplexor para seleccionar resultado
  reg [31:0] result_reg;

  always @(*) begin
    case (alucontrol)
      3'b000:  result_reg = fp_add_result;  // FADD
      3'b001:  result_reg = fp_sub_result;  // FSUB
      3'b010:  result_reg = fp_mul_result;  // FMUL
      3'b011:  result_reg = fp_div_result;  // FDIV
      default: result_reg = fp_add_result;  // Default: FADD
    endcase
  end

  assign result = result_reg;

endmodule


// Módulo de suma/resta FP
module fp_add_sub(
    input [31:0] a, b,
    input add_sub,  // 0=suma, 1=resta
    output reg [31:0] result
);
    wire sign_a = a[31];
    wire sign_b_eff = b[31] ^ add_sub;  // Invierte signo de B si es resta
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [22:0] mant_a = a[22:0];
    wire [22:0] mant_b = b[22:0];

    wire a_is_zero = (exp_a == 0) && (mant_a == 0);
    wire b_is_zero = (exp_b == 0) && (mant_b == 0);

    reg [23:0] mant_a_norm, mant_b_norm;
    reg [7:0] exp_larger, exp_diff;
    reg [47:0] mant_a_aligned, mant_b_aligned;
    reg [48:0] mant_sum;
    reg sign_result;
    reg [7:0] exp_result;
    reg [22:0] mant_result;
    integer i, shift_cnt;

    always @(*) begin
        if (a_is_zero && b_is_zero) begin
            result = 32'b0;
        end else if (a_is_zero) begin
            result = {sign_b_eff, b[30:0]};
        end else if (b_is_zero) begin
            result = a;
        end else begin
            mant_a_norm = {1'b1, mant_a};
            mant_b_norm = {1'b1, mant_b};

            // Alinear exponentes
            if (exp_a > exp_b) begin
                exp_larger = exp_a;
                exp_diff = exp_a - exp_b;
                mant_a_aligned = {mant_a_norm, 24'b0};
                mant_b_aligned = ({mant_b_norm, 24'b0} >> exp_diff);
            end else begin
                exp_larger = exp_b;
                exp_diff = exp_b - exp_a;
                mant_a_aligned = ({mant_a_norm, 24'b0} >> exp_diff);
                mant_b_aligned = {mant_b_norm, 24'b0};
            end

            // Sumar o restar según signos
            if (sign_a == sign_b_eff) begin
                mant_sum = {1'b0, mant_a_aligned} + {1'b0, mant_b_aligned};
                sign_result = sign_a;
            end else begin
                if (mant_a_aligned >= mant_b_aligned) begin
                    mant_sum = {1'b0, (mant_a_aligned - mant_b_aligned)};
                    sign_result = sign_a;
                end else begin
                    mant_sum = {1'b0, (mant_b_aligned - mant_a_aligned)};
                    sign_result = sign_b_eff;
                end
            end

            exp_result = exp_larger;

            // Normalizar resultado
            if (mant_sum[48]) begin
                mant_result = mant_sum[47:25];
                exp_result = exp_result + 1;
                result = {sign_result, exp_result, mant_result};
            end else if (mant_sum[47]) begin
                mant_result = mant_sum[46:24];
                result = {sign_result, exp_result, mant_result};
            end else if (mant_sum == 0) begin
                result = {sign_result, 31'b0};
            end else begin
                // Normalizar hacia la izquierda
                shift_cnt = 0;
                for (i = 47; i >= 1; i = i - 1) begin
                    if (mant_sum[i] == 0)
                        shift_cnt = shift_cnt + 1;
                    else
                        i = 0;
                end

                if (shift_cnt >= exp_result) begin
                    result = {sign_result, 31'b0};
                end else begin
                    exp_result = exp_result - shift_cnt;
                    mant_sum = mant_sum << shift_cnt;
                    mant_result = mant_sum[46:24];
                    result = {sign_result, exp_result, mant_result};
                end
            end
        end
    end
endmodule


// Módulo de multiplicación FP
module fp_mul(
    input [31:0] a, b,
    output reg [31:0] result
);
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [22:0] mant_a = a[22:0];
    wire [22:0] mant_b = b[22:0];

    wire a_is_zero = (exp_a == 0) && (mant_a == 0);
    wire b_is_zero = (exp_b == 0) && (mant_b == 0);

    reg [47:0] mant_product;
    reg [9:0] exp_sum;
    reg sign_result;
    reg [8:0] exp_result;
    reg [22:0] mant_result;
    reg [23:0] mant_a_norm, mant_b_norm;

    always @(*) begin
        sign_result = sign_a ^ sign_b;

        if (a_is_zero || b_is_zero) begin
            result = {sign_result, 31'b0};
        end else begin
            mant_a_norm = {1'b1, mant_a};
            mant_b_norm = {1'b1, mant_b};
            mant_product = mant_a_norm * mant_b_norm;
            exp_sum = {2'b0, exp_a} + {2'b0, exp_b} - 10'd127;

            // Normalizar
            if (mant_product[47]) begin
                exp_result = exp_sum[8:0] + 1;
                mant_result = mant_product[46:24];
            end else begin
                exp_result = exp_sum[8:0];
                mant_result = mant_product[45:23];
            end

            // Detectar overflow/underflow
            if (exp_result >= 9'd255) begin
                result = {sign_result, 8'hFF, 23'b0};  // Infinito
            end else if (exp_result == 0) begin
                result = {sign_result, 31'b0};  // Cero
            end else begin
                result = {sign_result, exp_result[7:0], mant_result};
            end
        end
    end
endmodule


// Módulo de división FP
module fp_div(
    input [31:0] a, b,
    output reg [31:0] result
);
    wire sign_a = a[31];
    wire sign_b = b[31];
    wire [7:0] exp_a = a[30:23];
    wire [7:0] exp_b = b[30:23];
    wire [22:0] mant_a = a[22:0];
    wire [22:0] mant_b = b[22:0];

    wire a_is_zero = (exp_a == 0) && (mant_a == 0);
    wire b_is_zero = (exp_b == 0) && (mant_b == 0);

    reg [47:0] mant_quotient;
    reg signed [9:0] exp_result_temp;
    reg sign_result;
    reg [8:0] exp_result;
    reg [22:0] mant_result;
    reg [23:0] mant_a_norm, mant_b_norm;

    always @(*) begin
        sign_result = sign_a ^ sign_b;

        if (b_is_zero) begin
            result = {sign_result, 8'hFF, 23'b0};  // División por cero = Infinito
        end else if (a_is_zero) begin
            result = {sign_result, 31'b0};  // 0 / x = 0
        end else begin
            mant_a_norm = {1'b1, mant_a};
            mant_b_norm = {1'b1, mant_b};
            mant_quotient = ({mant_a_norm, 23'b0}) / mant_b_norm;
            exp_result_temp = $signed({2'b0, exp_a}) - $signed({2'b0, exp_b}) + $signed(10'd127);

            // Normalizar
            if (mant_quotient[23]) begin
                exp_result = exp_result_temp[8:0];
                mant_result = mant_quotient[22:0];
            end else begin
                mant_quotient = mant_quotient << 1;
                exp_result = exp_result_temp[8:0] - 1;
                mant_result = mant_quotient[22:0];
            end

            // Detectar overflow/underflow
            if (exp_result >= 9'd255 || exp_result_temp >= 10'd255) begin
                result = {sign_result, 8'hFF, 23'b0};  // Infinito
            end else if (exp_result_temp <= 0) begin
                result = {sign_result, 31'b0};  // Cero
            end else begin
                result = {sign_result, exp_result[7:0], mant_result};
            end
        end
    end
endmodule

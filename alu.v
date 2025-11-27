module alu(
    input [31:0] a, b,
    input [2:0] alucontrol,
    input fp_op,
    output [31:0] result,
    output zero
);
    wire [31:0] int_result, fp_result;
    wire [31:0] fp_add_result, fp_sub_result, fp_mul_result, fp_div_result;

    wire [31:0] condinvb = alucontrol[0] ? ~b : b;
    wire [31:0] sum = a + condinvb + alucontrol[0];
    wire v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]);

    reg [31:0] int_result_reg;
    always @(*) case (alucontrol)
        3'b000: int_result_reg = sum;
        3'b001: int_result_reg = sum;
        3'b010: int_result_reg = a & b;
        3'b011: int_result_reg = a | b;
        3'b100: int_result_reg = a ^ b;
        3'b101: int_result_reg = sum[31] ^ v;
        3'b110: int_result_reg = a << b[4:0];
        3'b111: int_result_reg = a >> b[4:0];
        default: int_result_reg = 32'bx;
    endcase
    assign int_result = int_result_reg;

    fp_add_sub fp_add_inst(.a(a), .b(b), .add_sub(1'b0), .result(fp_add_result));
    fp_add_sub fp_sub_inst(.a(a), .b(b), .add_sub(1'b1), .result(fp_sub_result));
    fp_mul fp_mul_inst(.a(a), .b(b), .result(fp_mul_result));
    fp_div fp_div_inst(.a(a), .b(b), .result(fp_div_result));

    reg [31:0] fp_result_reg;
    always @(*) case (alucontrol[1:0])
        2'b00: fp_result_reg = fp_add_result;
        2'b01: fp_result_reg = fp_sub_result;
        2'b10: fp_result_reg = fp_mul_result;
        2'b11: fp_result_reg = fp_div_result;
    endcase
    assign fp_result = fp_result_reg;

    assign result = fp_op ? fp_result : int_result;
    assign zero = (result == 0);
endmodule

module fp_add_sub(
    input [31:0] a, b,
    input add_sub,
    output reg [31:0] result
);
    wire sign_a = a[31];
    wire sign_b_eff = b[31] ^ add_sub;
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

            if (mant_product[47]) begin
                exp_result = exp_sum[8:0] + 1;
                mant_result = mant_product[46:24];
            end else begin
                exp_result = exp_sum[8:0];
                mant_result = mant_product[45:23];
            end

            if (exp_result >= 9'd255) begin
                result = {sign_result, 8'hFF, 23'b0};
            end else if (exp_result == 0) begin
                result = {sign_result, 31'b0};
            end else begin
                result = {sign_result, exp_result[7:0], mant_result};
            end
        end
    end
endmodule

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
            result = {sign_result, 8'hFF, 23'b0};
        end else if (a_is_zero) begin
            result = {sign_result, 31'b0};
        end else begin
            mant_a_norm = {1'b1, mant_a};
            mant_b_norm = {1'b1, mant_b};
            mant_quotient = ({mant_a_norm, 23'b0}) / mant_b_norm;
            exp_result_temp = $signed({2'b0, exp_a}) - $signed({2'b0, exp_b}) + $signed(10'd127);

            if (mant_quotient[23]) begin
                exp_result = exp_result_temp[8:0];
                mant_result = mant_quotient[22:0];
            end else begin
                mant_quotient = mant_quotient << 1;
                exp_result = exp_result_temp[8:0] - 1;
                mant_result = mant_quotient[22:0];
            end

            if (exp_result >= 9'd255 || exp_result_temp >= 10'd255) begin
                result = {sign_result, 8'hFF, 23'b0};
            end else if (exp_result_temp <= 0) begin
                result = {sign_result, 31'b0};
            end else begin
                result = {sign_result, exp_result[7:0], mant_result};
            end
        end
    end
endmodule

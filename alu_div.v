`timescale 1ns / 1ps

module alu_div_pipelined #(
    parameter integer WIDTH = 32,
    parameter integer EXP_BITS  = (WIDTH==32)?8:5,
    parameter integer MANT_BITS = (WIDTH==32)?23:10
)(
    input  wire s_a,
    input  wire s_b,
    input  wire [EXP_BITS-1:0] exp_a,
    input  wire [EXP_BITS-1:0] exp_b,
    input  wire [MANT_BITS-1:0] mantisa_a,
    input  wire [MANT_BITS-1:0] mantisa_b,
    input  wire [1:0] mode_r,
    
    output reg s_c,
    output reg [EXP_BITS-1:0] exp_c,
    output reg [MANT_BITS-1:0] mantisa_c,
    output reg [4:0] flags
);

    // =========================================================
    // CONSTANTS
    // =========================================================
    localparam integer BIAS = (1 << (EXP_BITS-1)) - 1;
    localparam [EXP_BITS-1:0] EXP_MAX = {EXP_BITS{1'b1}};
    localparam [EXP_BITS-1:0] EXP_HI = EXP_MAX - {{(EXP_BITS-1){1'b0}}, 1'b1};
    localparam integer MANT_TMP_W = (MANT_BITS + 3);
    localparam [MANT_BITS-1:0] QNAN_PAYLOAD = {{1'b1}, {(MANT_BITS-1){1'b0}}};
    localparam integer SHIFT = MANT_BITS + 3;
    localparam integer EXP_HI_INT = (1 << EXP_BITS) - 2;
    
    localparam integer FLAG_OVERFLOW  = 4;
    localparam integer FLAG_UNDERFLOW = 3;
    localparam integer FLAG_DIV_ZERO  = 2;
    localparam integer FLAG_INVALID   = 1;
    localparam integer FLAG_INEXACT   = 0;

    // =========================================================
    // SPECIAL CASE DETECTION
    // =========================================================
    wire a_is_zero;
    wire b_is_zero;
    wire a_is_inf;
    wire b_is_inf;
    wire a_is_nan;
    wire b_is_nan;
    wire a_is_finite;
    wire b_is_finite;
    
    assign a_is_zero = (exp_a == {EXP_BITS{1'b0}}) && (mantisa_a == {MANT_BITS{1'b0}});
    assign b_is_zero = (exp_b == {EXP_BITS{1'b0}}) && (mantisa_b == {MANT_BITS{1'b0}});
    assign a_is_inf = (exp_a == EXP_MAX) && (mantisa_a == {MANT_BITS{1'b0}});
    assign b_is_inf = (exp_b == EXP_MAX) && (mantisa_b == {MANT_BITS{1'b0}});
    assign a_is_nan = (exp_a == EXP_MAX) && (mantisa_a != {MANT_BITS{1'b0}});
    assign b_is_nan = (exp_b == EXP_MAX) && (mantisa_b != {MANT_BITS{1'b0}});
    assign a_is_finite = !(a_is_nan || a_is_inf);
    assign b_is_finite = !(b_is_nan || b_is_inf);

    // =========================================================
    // INTERNAL SIGNALS
    // =========================================================
    reg is_nan;
    reg is_inf;
    reg is_zero;
    reg is_div_zero;
    reg sign_res;
    reg [MANT_BITS:0] mant_a_exp;
    reg [MANT_BITS:0] mant_b_exp;
    reg signed [EXP_BITS+2:0] exp_tmp;
    reg signed [EXP_BITS+2:0] exp_a_eff;
    reg signed [EXP_BITS+2:0] exp_b_eff;
    reg [MANT_BITS+SHIFT:0] quotient;
    reg [MANT_BITS+SHIFT:0] q_temp;
    reg signed [EXP_BITS+2:0] exp_adjusted;
    reg [MANT_TMP_W-1:0] mantisa_temp;
    reg guard;
    reg round_bit;
    reg sticky;
    reg [MANT_BITS+1:0] mant_1g;
    reg round_up;
    reg [MANT_BITS+2:0] mant_sum;
    reg signed [EXP_BITS+2:0] exp_final;

    // =========================================================
    // COMBINATIONAL LOGIC
    // =========================================================
    always @(*) begin
        // Initialize outputs
        s_c = 1'b0;
        exp_c = {EXP_BITS{1'b0}};
        mantisa_c = {MANT_BITS{1'b0}};
        flags = 5'b0;
        
        // Initialize internal signals
        is_nan = 1'b0;
        is_inf = 1'b0;
        is_zero = 1'b0;
        is_div_zero = 1'b0;
        sign_res = s_a ^ s_b;
        
        // =========================================================
        // STEP 1: Special Cases Detection
        // =========================================================
        if (a_is_nan || b_is_nan) begin
            // NaN input
            is_nan = 1'b1;
            s_c = 1'b0;
            exp_c = EXP_MAX;
            mantisa_c = QNAN_PAYLOAD;
            flags[FLAG_INVALID] = 1'b1;
        end
        else if (a_is_inf && b_is_inf) begin
            // Inf / Inf = NaN
            is_nan = 1'b1;
            s_c = 1'b0;
            exp_c = EXP_MAX;
            mantisa_c = QNAN_PAYLOAD;
            flags[FLAG_INVALID] = 1'b1;
        end
        else if (a_is_zero && b_is_zero) begin
            // 0 / 0 = NaN
            is_nan = 1'b1;
            s_c = 1'b0;
            exp_c = EXP_MAX;
            mantisa_c = QNAN_PAYLOAD;
            flags[FLAG_INVALID] = 1'b1;
        end
        else if (b_is_zero) begin
            // a / 0 = Inf (with div by zero flag)
            is_div_zero = 1'b1;
            s_c = sign_res;
            exp_c = EXP_MAX;
            mantisa_c = {MANT_BITS{1'b0}};
            flags[FLAG_DIV_ZERO] = 1'b1;
        end
        else if (a_is_zero) begin
            // 0 / b = 0
            is_zero = 1'b1;
            s_c = sign_res;
            exp_c = {EXP_BITS{1'b0}};
            mantisa_c = {MANT_BITS{1'b0}};
        end
        else if (a_is_inf && b_is_finite) begin
            // Inf / finite = Inf
            is_inf = 1'b1;
            s_c = sign_res;
            exp_c = EXP_MAX;
            mantisa_c = {MANT_BITS{1'b0}};
        end
        else if (a_is_finite && b_is_inf) begin
            // finite / Inf = 0
            is_zero = 1'b1;
            s_c = sign_res;
            exp_c = {EXP_BITS{1'b0}};
            mantisa_c = {MANT_BITS{1'b0}};
        end
        else begin
            // =========================================================
            // STEP 2: Prepare Mantissas and Exponents
            // =========================================================
            
            // Effective exponents (subnormals use 1 instead of 0)
            exp_a_eff = (exp_a == 0) ? $signed(1) : $signed({1'b0, exp_a});
            exp_b_eff = (exp_b == 0) ? $signed(1) : $signed({1'b0, exp_b});
            exp_tmp = exp_a_eff - exp_b_eff + $signed(BIAS);
            
            // Add implicit bit (1 for normal, 0 for subnormal)
            mant_a_exp = {(exp_a != 0), mantisa_a};
            mant_b_exp = {(exp_b != 0), mantisa_b};
            
            // =========================================================
            // STEP 3: Perform Division
            // =========================================================
            
            // Division with shift for extra precision
            q_temp = (mant_a_exp << SHIFT) / mant_b_exp;
            exp_adjusted = exp_tmp;
            
            // =========================================================
            // STEP 4: Normalize if needed
            // =========================================================
            if (!q_temp[SHIFT]) begin
                q_temp = q_temp << 1;
                exp_adjusted = exp_adjusted - $signed(1);
            end
            
            quotient = q_temp;
            
            // =========================================================
            // STEP 5: Extract Mantissa and Rounding Bits
            // =========================================================
            
            // Extract mantissa and rounding bits
            mantisa_temp = quotient[SHIFT:1];  // [1 | mantisa | G | R]
            guard = mantisa_temp[1];
            round_bit = mantisa_temp[0];
            sticky = quotient[0];
            mant_1g = mantisa_temp[MANT_BITS+2:1];  // {1 | mantisa | G}
            
            // Set inexact flag
            if (guard | round_bit | sticky)
                flags[FLAG_INEXACT] = 1'b1;
            
            // =========================================================
            // STEP 6: Determine Rounding Direction
            // =========================================================
            round_up = 1'b0;
            case (mode_r)
                2'b00: begin  // Round to nearest even
                    if (guard && (round_bit | sticky | mantisa_temp[2]))
                        round_up = 1'b1;
                end
                2'b01: begin  // Round toward zero
                    round_up = 1'b0;
                end
                2'b10: begin  // Round toward +inf
                    if (sign_res == 1'b0 && (guard | round_bit | sticky))
                        round_up = 1'b1;
                end
                2'b11: begin  // Round toward -inf
                    if (sign_res == 1'b1 && (guard | round_bit | sticky))
                        round_up = 1'b1;
                end
            endcase
            
            // =========================================================
            // STEP 7: Apply Rounding
            // =========================================================
            mant_sum = {1'b0, mant_1g} + (round_up ? 1'b1 : 1'b0);
            exp_final = exp_adjusted;
            
            // Check for carry from rounding
            if (mant_sum[MANT_BITS+2]) begin
                mant_1g = mant_sum[MANT_BITS+2:1];
                exp_final = exp_final + $signed(1);
            end else begin
                mant_1g = mant_sum[MANT_BITS+1:0];
            end
            
            // =========================================================
            // STEP 8: Check for Overflow/Underflow
            // =========================================================
            s_c = sign_res;
            
            if (exp_final > $signed(EXP_HI_INT)) begin
                // Overflow to infinity
                exp_c = EXP_MAX;
                mantisa_c = {MANT_BITS{1'b0}};
                flags[FLAG_OVERFLOW] = 1'b1;
            end
            else if (exp_final < 1) begin
                // Underflow to zero
                exp_c = {EXP_BITS{1'b0}};
                mantisa_c = {MANT_BITS{1'b0}};
                flags[FLAG_UNDERFLOW] = 1'b1;
            end
            else begin
                // Normal range
                exp_c = exp_final[EXP_BITS-1:0];
                mantisa_c = mant_1g[MANT_BITS:1];
            end
        end
    end

endmodule
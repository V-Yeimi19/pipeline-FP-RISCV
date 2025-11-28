`timescale 1ns / 1ps

module alu_mul_pipelined #(
    parameter integer WIDTH = 32,
    parameter integer EXP_BITS  = (WIDTH==32)?8:5,
    parameter integer MANT_BITS = (WIDTH==32)?23:10
)(
    input  wire [WIDTH-1:0] op_a,
    input  wire [WIDTH-1:0] op_b,
    input  wire [1:0] round_mode,
    
    output reg  [WIDTH-1:0] result, 
    output reg  [4:0] flags
);

    // =========================================================
    // CONSTANTS
    // =========================================================
    localparam integer BIAS = (WIDTH==32) ? 127 : 15;
    localparam integer EXP_MAX = (1<<EXP_BITS) - 1;
    localparam integer FLAG_OVERFLOW  = 4;
    localparam integer FLAG_UNDERFLOW = 3;
    localparam integer FLAG_DIV_ZERO  = 2; 
    localparam integer FLAG_INVALID   = 1;
    localparam integer FLAG_INEXACT   = 0;
    
    localparam [1:0] RM_NEAREST = 2'b00;
    localparam [1:0] RM_TRUNC   = 2'b01;
    localparam [1:0] RM_CEIL    = 2'b10;
    localparam [1:0] RM_FLOOR   = 2'b11;

    // =========================================================
    // INPUT DECODE
    // =========================================================
    wire sign_a;
    wire [EXP_BITS-1:0] exp_a;
    wire [MANT_BITS-1:0] frac_a;
    wire sign_b;
    wire [EXP_BITS-1:0] exp_b;
    wire [MANT_BITS-1:0] frac_b;
    
    assign sign_a = op_a[WIDTH-1];
    assign exp_a = op_a[WIDTH-2 -: EXP_BITS];
    assign frac_a = op_a[MANT_BITS-1:0];
    assign sign_b = op_b[WIDTH-1];
    assign exp_b = op_b[WIDTH-2 -: EXP_BITS];
    assign frac_b = op_b[MANT_BITS-1:0];
    
    // Special case detection
    wire a_is_zero;
    wire b_is_zero;
    wire a_is_inf;
    wire b_is_inf;
    wire a_is_nan;
    wire b_is_nan;
    
    assign a_is_zero = (exp_a == {EXP_BITS{1'b0}}) && (frac_a == {MANT_BITS{1'b0}});
    assign b_is_zero = (exp_b == {EXP_BITS{1'b0}}) && (frac_b == {MANT_BITS{1'b0}});
    assign a_is_inf  = (exp_a == {EXP_BITS{1'b1}}) && (frac_a == {MANT_BITS{1'b0}});
    assign b_is_inf  = (exp_b == {EXP_BITS{1'b1}}) && (frac_b == {MANT_BITS{1'b0}});
    assign a_is_nan  = (exp_a == {EXP_BITS{1'b1}}) && (frac_a != {MANT_BITS{1'b0}});
    assign b_is_nan  = (exp_b == {EXP_BITS{1'b1}}) && (frac_b != {MANT_BITS{1'b0}});

    // =========================================================
    // INTERNAL SIGNALS
    // =========================================================
    reg is_nan;
    reg is_inf;
    reg is_zero;
    reg sign_res;
    reg [MANT_BITS:0] mant_a;
    reg [MANT_BITS:0] mant_b;
    reg signed [EXP_BITS+2:0] exp_eff_a;
    reg signed [EXP_BITS+2:0] exp_eff_b;
    reg [2*MANT_BITS+1:0] mant_prod;
    reg signed [EXP_BITS+2:0] exp_sum;
    reg [2*MANT_BITS+1:0] mant_norm;
    reg signed [EXP_BITS+2:0] exp_biased;
    reg [MANT_BITS-1:0] frac_norm;
    reg guard;
    reg round_bit;
    reg sticky;
    reg inc;
    reg [MANT_BITS:0] frac_add;
    reg carry;
    reg [EXP_BITS+2:0] shift_amt;
    reg [2*MANT_BITS+1:0] mant_shifted;
    reg [MANT_BITS-1:0] frac_sub;
    reg guard_s;
    reg round_s;
    reg sticky_s;
    reg inc_s;
    reg carry_s;
    reg [MANT_BITS:0] frac_add_s;
    reg inexact_sub;

    // =========================================================
    // COMBINATIONAL LOGIC
    // =========================================================
    always @(*) begin
        // Initialize outputs
        result = {WIDTH{1'b0}};
        flags = 5'b0;
        
        // Initialize internal signals
        is_nan = 1'b0;
        is_inf = 1'b0;
        is_zero = 1'b0;
        sign_res = sign_a ^ sign_b;
        
        // =========================================================
        // STEP 1: Special Cases Detection
        // =========================================================
        if (a_is_nan || b_is_nan || ((a_is_inf && b_is_zero) || (b_is_inf && a_is_zero))) begin
            // NaN: invalid operation (NaN input or inf*0)
            is_nan = 1'b1;
            result = {1'b0, {EXP_BITS{1'b1}}, {1'b1, {MANT_BITS-1{1'b0}}}};
            flags[FLAG_INVALID] = 1'b1;
        end
        else if (a_is_inf || b_is_inf) begin
            // Infinity result
            is_inf = 1'b1;
            result = {sign_res, {EXP_BITS{1'b1}}, {MANT_BITS{1'b0}}};
        end
        else if (a_is_zero || b_is_zero) begin
            // Zero result
            is_zero = 1'b1;
            result = {sign_res, {EXP_BITS{1'b0}}, {MANT_BITS{1'b0}}};
        end
        else begin
            // =========================================================
            // STEP 2: Prepare Mantissas and Exponents
            // =========================================================
            
            // Add implicit bit for normalized numbers
            if (exp_a == {EXP_BITS{1'b0}})
                mant_a = {1'b0, frac_a};
            else
                mant_a = {1'b1, frac_a};
            
            if (exp_b == {EXP_BITS{1'b0}})
                mant_b = {1'b0, frac_b};
            else
                mant_b = {1'b1, frac_b};
            
            // Calculate effective exponents (unbiased)
            if (exp_a == {EXP_BITS{1'b0}})
                exp_eff_a = $signed(1) - $signed(BIAS);
            else
                exp_eff_a = $signed({1'b0, exp_a}) - $signed(BIAS);
            
            if (exp_b == {EXP_BITS{1'b0}})
                exp_eff_b = $signed(1) - $signed(BIAS);
            else
                exp_eff_b = $signed({1'b0, exp_b}) - $signed(BIAS);
            
            // =========================================================
            // STEP 3: Multiply Mantissas
            // =========================================================
            mant_prod = mant_a * mant_b;
            exp_sum = exp_eff_a + exp_eff_b;
            
            // =========================================================
            // STEP 4: Normalize Product
            // =========================================================
            if (mant_prod[2*MANT_BITS+1]) begin
                // Product >= 2.0, shift right
                mant_norm = mant_prod >> 1;
                exp_biased = exp_sum + $signed(1) + $signed(BIAS);
            end
            else if (mant_prod[2*MANT_BITS]) begin
                // Product in [1.0, 2.0), already normalized
                mant_norm = mant_prod;
                exp_biased = exp_sum + $signed(BIAS);
            end
            else begin
                // Product < 1.0, shift left
                mant_norm = mant_prod << 1;
                exp_biased = exp_sum - $signed(1) + $signed(BIAS);
            end
            
            // =========================================================
            // STEP 5: Check for Overflow/Underflow and Round
            // =========================================================
            
            // Check for overflow
            if (exp_biased >= $signed(EXP_MAX)) begin
                result = {sign_res, {EXP_BITS{1'b1}}, {MANT_BITS{1'b0}}};
                flags[FLAG_OVERFLOW] = 1'b1;
            end
            // Normal result
            else if (exp_biased > 0) begin
                // Extract fraction and rounding bits
                frac_norm = mant_norm[2*MANT_BITS-1 : MANT_BITS];
                guard = mant_norm[MANT_BITS-1];
                round_bit = mant_norm[MANT_BITS-2];
                sticky = |mant_norm[MANT_BITS-3:0];
                
                // Determine if we need to round up
                case (round_mode)
                    RM_NEAREST: inc = guard & (round_bit | sticky | frac_norm[0]);
                    RM_TRUNC:   inc = 1'b0;
                    RM_CEIL:    inc = (~sign_res) & (guard | round_bit | sticky);
                    RM_FLOOR:   inc = (sign_res) & (guard | round_bit | sticky);
                    default:    inc = 1'b0;
                endcase
                
                // Apply rounding
                frac_add = {1'b0, frac_norm} + inc;
                carry = frac_add[MANT_BITS];
                
                // Check for overflow after rounding
                if ((exp_biased + carry) >= $signed(EXP_MAX)) begin
                    result = {sign_res, {EXP_BITS{1'b1}}, {MANT_BITS{1'b0}}};
                    flags[FLAG_OVERFLOW] = 1'b1;
                end else begin
                    result = {sign_res, 
                             (exp_biased[EXP_BITS-1:0] + {{(EXP_BITS-1){1'b0}}, carry}),
                             (carry ? {MANT_BITS{1'b0}} : frac_add[MANT_BITS-1:0])};
                end
                
                // Set inexact flag
                if (guard | round_bit | sticky)
                    flags[FLAG_INEXACT] = 1'b1;
            end
            // Subnormal or zero result
            else begin
                // Calculate shift amount
                shift_amt = $unsigned($signed(1) - exp_biased);
                
                if (shift_amt >= (2*MANT_BITS+2)) begin
                    mant_shifted = {(2*MANT_BITS+2){1'b0}};
                    inexact_sub = 1'b1;
                end else begin
                    mant_shifted = mant_norm >> shift_amt;
                    inexact_sub = (mant_shifted << shift_amt) != mant_norm;
                end
                
                frac_sub = mant_shifted[2*MANT_BITS-1 : MANT_BITS];
                guard_s = mant_shifted[MANT_BITS-1];
                round_s = mant_shifted[MANT_BITS-2];
                sticky_s = |mant_shifted[MANT_BITS-3:0];
                
                inexact_sub = inexact_sub | guard_s | round_s | sticky_s;
                
                // Rounding for subnormal
                case (round_mode)
                    RM_NEAREST: inc_s = guard_s & (round_s | sticky_s | frac_sub[0]);
                    RM_TRUNC:   inc_s = 1'b0;
                    RM_CEIL:    inc_s = (~sign_res) & (guard_s | round_s | sticky_s);
                    RM_FLOOR:   inc_s = (sign_res) & (guard_s | round_s | sticky_s);
                    default:    inc_s = 1'b0;
                endcase
                
                frac_add_s = {1'b0, frac_sub} + inc_s;
                carry_s = frac_add_s[MANT_BITS];
                
                // Build result
                if (mant_shifted == {(2*MANT_BITS+2){1'b0}} && !inc_s) begin
                    result = {sign_res, {EXP_BITS{1'b0}}, {MANT_BITS{1'b0}}};
                end else if (carry_s) begin
                    // Rounded up to normal minimum
                    result = {sign_res, {{(EXP_BITS-1){1'b0}}, 1'b1}, {MANT_BITS{1'b0}}};
                end else begin
                    result = {sign_res, {EXP_BITS{1'b0}}, frac_add_s[MANT_BITS-1:0]};
                end
                
                // Set underflow flag
                if (exp_biased <= 0 && inexact_sub)
                    flags[FLAG_UNDERFLOW] = 1'b1;
                
                // Set inexact flag for subnormals
                if (inexact_sub)
                    flags[FLAG_INEXACT] = 1'b1;
            end
        end
    end

endmodule
`timescale 1ns / 1ps

module alu_add_pipelined(
  // Inputs
  input  s_a,
  input  s_b,
  input  [7:0] exp_a,
  input  [7:0] exp_b,
  input  [22:0] mantisa_a,
  input  [22:0] mantisa_b,
  input  [1:0] mode_r,
  
  // Outputs
  output reg s_c,
  output reg [7:0] exp_c,
  output reg [22:0] mantisa_c,
  output reg [4:0] flags
);

  // Internal signals
  reg is_nan, is_inf;
  reg s_result;
  reg [26:0] mant_a_exp, mant_b_exp;
  reg [26:0] mant_a_aligned, mant_b_aligned;
  reg [7:0] exp_aligned;
  reg [7:0] diff;
  reg sticky_bit;
  reg [27:0] suma;
  reg [7:0] exp_temp;
  reg [23:0] mantisa_temp;
  reg guard, round, sticky;
  integer i;

  always @(*) begin
    // Initialize outputs
    s_c = 1'b0;
    exp_c = 8'd0;
    mantisa_c = 23'd0;
    flags = 5'b0;
    
    // Initialize internal signals
    is_nan = 1'b0;
    is_inf = 1'b0;
    s_result = 1'b0;
    
    // =========================================================
    // STEP 1: Special cases detection
    // =========================================================
    
    if ((exp_a == 8'hFF && mantisa_a != 23'b0) || 
        (exp_b == 8'hFF && mantisa_b != 23'b0)) begin
      // NaN detected
      is_nan = 1'b1;
      s_c = 1'b0;
      exp_c = 8'hFF;
      mantisa_c = 23'h400000;
      flags[1] = 1'b1; // invalid
    end
    else if ((exp_a == 8'hFF) && (exp_b == 8'hFF) && (s_a != s_b)) begin
      // Inf - Inf = NaN
      is_nan = 1'b1;
      s_c = 1'b0;
      exp_c = 8'hFF;
      mantisa_c = 23'h400000;
      flags[1] = 1'b1; // invalid
    end
    else if (exp_a == 8'hFF) begin
      // A is Inf
      is_inf = 1'b1;
      s_c = s_a;
      exp_c = 8'hFF;
      mantisa_c = 23'd0;
    end
    else if (exp_b == 8'hFF) begin
      // B is Inf
      is_inf = 1'b1;
      s_c = s_b;
      exp_c = 8'hFF;
      mantisa_c = 23'd0;
    end
    else begin
      // =========================================================
      // STEP 2: Prepare mantissas with implicit bit
      // =========================================================
      mant_a_exp = (exp_a != 8'b0) ? {1'b1, mantisa_a, 3'b000} : {1'b0, mantisa_a, 3'b000};
      mant_b_exp = (exp_b != 8'b0) ? {1'b1, mantisa_b, 3'b000} : {1'b0, mantisa_b, 3'b000};
      
      // =========================================================
      // STEP 3: Align exponents
      // =========================================================
      if (exp_a > exp_b) begin
        diff = exp_a - exp_b;
        exp_aligned = exp_a;
        mant_a_aligned = mant_a_exp;
        
        if (diff >= 27) begin
          sticky_bit = |mant_b_exp;
          mant_b_aligned = 27'd0;
        end else begin
          mant_b_aligned = mant_b_exp >> diff;
          sticky_bit = |(mant_b_exp & ((27'd1 << diff) - 27'd1));
        end
      end else begin
        diff = exp_b - exp_a;
        exp_aligned = exp_b;
        mant_b_aligned = mant_b_exp;
        
        if (diff >= 27) begin
          sticky_bit = |mant_a_exp;
          mant_a_aligned = 27'd0;
        end else begin
          mant_a_aligned = mant_a_exp >> diff;
          sticky_bit = |(mant_a_exp & ((27'd1 << diff) - 27'd1));
        end
      end
      
      // =========================================================
      // STEP 4: Add or subtract mantissas
      // =========================================================
      if (s_a == s_b) begin
        suma = {1'b0, mant_a_aligned} + {1'b0, mant_b_aligned};
        s_result = s_a;
      end else begin
        if (mant_a_aligned >= mant_b_aligned) begin
          suma = {1'b0, mant_a_aligned} - {1'b0, mant_b_aligned};
          s_result = s_a;
        end else begin
          suma = {1'b0, mant_b_aligned} - {1'b0, mant_a_aligned};
          s_result = s_b;
        end
      end
      
      exp_temp = exp_aligned;
      
      // =========================================================
      // STEP 5: Check for zero result
      // =========================================================
      if (suma == 28'd0) begin
        s_c = 1'b0;
        exp_c = 8'd0;
        mantisa_c = 23'd0;
      end
      else begin
        // =========================================================
        // STEP 6: Normalization
        // =========================================================
        if (suma[27]) begin
          // Carry out - shift right
          suma = suma >> 1;
          exp_temp = exp_temp + 8'd1;
        end else begin
          // Normalize left (find leading 1)
          for (i = 0; i < 27; i = i + 1) begin
            if (suma[26] == 1'b0 && suma != 28'd0 && exp_temp > 8'd0) begin
              suma = suma << 1;
              exp_temp = exp_temp - 8'd1;
            end
          end
        end
        
        // Extract guard, round, sticky bits
        guard = suma[2];
        round = suma[1];
        sticky = sticky_bit | suma[0];
        
        // =========================================================
        // STEP 7: Rounding
        // =========================================================
        s_c = s_result;
        mantisa_temp = suma[25:3];
        
        // Set inexact flag
        if (guard | round | sticky)
          flags[0] = 1'b1;
        
        // Apply rounding mode
        case (mode_r)
          2'b00: begin // Round to nearest even
            if (guard && (round | sticky | mantisa_temp[0]))
              mantisa_temp = mantisa_temp + 24'd1;
          end
          2'b01: begin // Round toward zero (truncate)
            // No rounding needed
          end
          2'b10: begin // Round toward +inf
            if (s_result == 1'b0 && (guard | round | sticky))
              mantisa_temp = mantisa_temp + 24'd1;
          end
          2'b11: begin // Round toward -inf
            if (s_result == 1'b1 && (guard | round | sticky))
              mantisa_temp = mantisa_temp + 24'd1;
          end
        endcase
        
        // =========================================================
        // STEP 8: Post-round normalization
        // =========================================================
        if (mantisa_temp[23]) begin
          mantisa_temp = mantisa_temp >> 1;
          exp_temp = exp_temp + 8'd1;
        end
        
        // =========================================================
        // STEP 9: Overflow/Underflow check
        // =========================================================
        if (exp_temp >= 8'd255) begin
          // Overflow
          exp_c = 8'hFF;
          mantisa_c = 23'd0;
          flags[4] = 1'b1; // overflow
        end else if (exp_temp == 8'd0) begin
          // Underflow (denormal result)
          exp_c = 8'd0;
          mantisa_c = mantisa_temp[22:0];
          if (guard | round | sticky)
            flags[3] = 1'b1; // underflow
        end else begin
          // Normal result
          exp_c = exp_temp;
          mantisa_c = mantisa_temp[22:0];
        end
      end
    end
  end

endmodule
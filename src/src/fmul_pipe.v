//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yifan Zhou
// 
// Create Date: 2023/06/08
// Design Name: 
// Module Name: fpu_multi
// Project Name: FPU_16
// Target Devices: KCU105
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 1.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module fpu_mul_pipe(
    input aclk,
    // input rst,
    input [15:0] s_axis_a_tdata,  // input 16-bit float A
    input [15:0] s_axis_b_tdata,  // input 16-bit float B
    input s_axis_a_tvalid,
    input s_axis_b_tvalid,
    output reg [15:0] m_axis_result_tdata, // output 16-bit float sum
    output m_axis_result_tvalid
    // output reg [1:0] error_num,         // flag to show result non-number, 1 for INF \2 for NAN
    // output reg subnormal_num            // flag to show result subnormal
    );
    

    reg is_ready_out;
    reg [1:0] error_num;
    // 1-stage pipeline for original op process, including pre-normalization for subnormal
    reg [6:0] opa_e_s_1, opb_e_s_1;
    reg [10:0] opa_m_s_1, opb_m_s_1;
    reg opa_s_1, opb_s_1;
    reg is_valid_ain_1, is_valid_bin_1;
    reg zero_mul_1;
    reg [1:0] nan_mul_1;
    reg [15:0] opa_1, opb_1;

    // 2-stage pipeline for main multiply process
    reg [6:0] mul_e_2;
    reg mul_s_2;
    reg [21:0] mul_m_raw_2;
    reg is_valid_ain_2, is_valid_bin_2;
    reg zero_mul_2;
    reg [1:0] nan_mul_2;    
    reg [15:0] opa_2, opb_2;

    // 3-stage pipeline for left normalization
    reg [6:0] mul_e_test_3;
    reg [21:0] mul_m_raw_3;
    reg [21:0] mul_normalize_test_3;
    reg [6:0] mul_e_3;
    reg mul_s_3;
    reg is_valid_ain_3, is_valid_bin_3;
    reg zero_mul_3;
    reg [1:0] nan_mul_3;    
    reg [15:0] opa_3, opb_3;

    // 4-stage

    // 4-stage pipeline for right normalization and final result
    reg [11:0] mul_normalize_4;
    reg sticky_4;
    reg ovf_4;
    reg mul_s_4;
    reg round_up_or_not_4;
    reg [6:0] mul_e_test_f_4;
    reg is_valid_ain_4, is_valid_bin_4;
    reg zero_mul_4;
    reg [1:0] nan_mul_4;    
    reg [15:0] opa_4, opb_4;

    // original signals for s_axis_a_tdata and s_axis_b_tdata;
    // including subnormal flag\ nan flag\ valid_in flag
    wire ovf;
    wire opa_s, opb_s;
    wire [4:0] opa_e, opb_e;
    wire [6:0] opa_e_n, opb_e_n;
    wire [6:0] opa_e_s, opb_e_s;
    wire [10:0] opa_m, opb_m;
    wire [10:0] opa_m_s, opb_m_s;
    wire subnormal_a, subnormal_b;
    wire nan_a, nan_b;
    wire is_valid_ain_0, is_valid_bin_0;
    wire [15:0] opa_0, opb_0;

    assign opa_s = s_axis_a_tdata[15];
    assign opb_s = s_axis_b_tdata[15];
    // check subnormal number
    assign subnormal_a = ~(|opa_e);
    assign subnormal_b = ~(|opb_e);
    assign opa_e = s_axis_a_tdata[14:10];
    assign opb_e = s_axis_b_tdata[14:10];
    // for multiply, necessary to minus bias
    assign opa_e_n = opa_e - 7'd15;
    assign opb_e_n = opb_e - 7'd15;
    // check nan\inf
    assign nan_a = &opa_e;
    assign nan_b = &opb_e;
    // Similarly, subnormal input's mantassi need to be add 0, while other's add 1
    assign opa_m = subnormal_a ? {1'b0, s_axis_a_tdata[9:0]} : {1'b1, s_axis_a_tdata[9:0]};
    assign opb_m = subnormal_b ? {1'b0, s_axis_b_tdata[9:0]} : {1'b1, s_axis_b_tdata[9:0]};

    assign is_valid_ain_0 = s_axis_a_tvalid;
    assign is_valid_bin_0 = s_axis_b_tvalid;
    assign opa_0 = s_axis_a_tdata;
    assign opb_0 = s_axis_b_tdata;

    // Pre-Normalise for subnormal s_axis_a_tdata s_axis_b_tdata;
    // if subnormal, need LEFT NORMALIZATION;
    // With shift number, exponent need to add 1 for 0->1, then minus shift number
    wire [3:0] shift_a;
    wire [3:0] shift_b;
    LZC_for_fmul_pipe U1_shift_module(opa_m, shift_a);
    LZC_for_fmul_pipe U2_shift_module(opb_m, shift_b);

    assign opa_m_s = subnormal_a ? opa_m << shift_a : opa_m;
    assign opb_m_s = subnormal_b ? opb_m << shift_b : opb_m;
    assign opa_e_s = subnormal_a ? opa_e_n + 1 - shift_a : opa_e_n;
    assign opb_e_s = subnormal_b ? opb_e_n + 1 - shift_b : opb_e_n;

    // check whether s_axis_a_tdata/s_axis_b_tdata zero
    // check s_axis_a_tdata/s_axis_b_tdata which nan
    wire zero_mul = (~(|opa_e) && ~(|s_axis_a_tdata[9:0])) | (~(|opb_e) && ~(|s_axis_b_tdata[9:0]));
    wire [1:0] nan_mul = {nan_a, nan_b};

    // initially multiply, for sign\exponent\mantassi
    // note that exponent initially add 1 for right normalization
    wire [6:0] mul_e = opb_e_s + opa_e_s + 1;
    wire mul_s = opa_s ^ opb_s;
    wire [21:0] mul_m_raw = opa_m_s * opb_m_s;

    // ==========================================================================
    // decide to left-normalization or right-normalization
    wire normalize_flag = mul_m_raw_2[21];
    

    // left normalization
    wire [3:0] shift_m_0;
    LZC_for_fmul_pipe U0_shift_module(mul_m_raw_2[21:11], shift_m_0);

    wire [4:0] shift_m_test = normalize_flag ? 0 : shift_m_0;
    wire [21:0] mul_normalize_test = mul_m_raw_2 << shift_m_test;
    wire [6:0] mul_e_test = mul_e_2 - shift_m_test;

    // =========================================================================
    // right normalization

    wire right_normalize_flag = $signed(mul_e_test_3) < -14;
    wire [6:0] right_shift = right_normalize_flag ? -14 - mul_e_test_3 : 0;


    reg [6:0] right_sft_ff;
    reg [6:0] mul_e_test_33;
    reg [21:0] mul_normalize_test_33;
    reg [21:0] mul_m_raw_33;
    reg [6:0] mul_e_33;
    reg [1:0] nan_mul_33;
    reg mul_s_33;
    reg is_valid_ain_33, is_valid_bin_33;
    reg zero_mul_33;
    reg [15:0] opa_33, opb_33;

    always@(posedge aclk) begin
        right_sft_ff <= right_shift;
        mul_e_test_33 <= mul_e_test_3;
        mul_normalize_test_33 <= mul_normalize_test_3;
        mul_m_raw_33 <= mul_m_raw_3;
        mul_e_33 <= mul_e_3;
        nan_mul_33 <= nan_mul_3;
        mul_s_33 <= mul_s_3;
        is_valid_ain_33 <= is_valid_ain_3;
        is_valid_bin_33 <= is_valid_bin_3;
        zero_mul_33 <= zero_mul_3;
        opa_33 <= opa_3;
        opb_33 <= opb_3; 
    end


    wire [6:0] mul_e_test_f = mul_e_test_33 + right_sft_ff;
    wire [21:0] mul_normalize_test_right = mul_normalize_test_33 >> right_sft_ff;

    wire or_result;
    assign or_result = |mul_normalize_test_33[9:0];
    reg sticky;
    always@(*)begin
        case(right_sft_ff)
        7'd00: sticky = or_result;
        01: sticky = mul_normalize_test_33[10] | or_result;
        02: sticky = |mul_normalize_test_33[11:10] | or_result;
        03: sticky = |mul_normalize_test_33[12:10] | or_result;
        04: sticky = |mul_normalize_test_33[13:10] | or_result;
        05: sticky = |mul_normalize_test_33[14:10] | or_result;
        06: sticky = |mul_normalize_test_33[15:10] | or_result;
        07: sticky = |mul_normalize_test_33[16:10] | or_result;
        08: sticky = |mul_normalize_test_33[17:10] | or_result;
        09: sticky = |mul_normalize_test_33[18:10] | or_result;
        10: sticky = |mul_normalize_test_33[19:10] | or_result;
        11: sticky = |mul_normalize_test_33[20:10] | or_result;
        endcase
    end

    // ============================================================================
    reg [6:0] right_sft_fff;
    reg [6:0] mul_e_test_ff;
    reg [21:0]  mul_normalize_test_right_f;
    reg [21:0] mul_m_raw_333;
    reg [6:0] mul_e_333;
    reg [1:0] nan_mul_333;
    reg sticky_333;
    reg mul_s_333;
    reg is_valid_ain_333, is_valid_bin_333;
    reg zero_mul_333;
    reg [15:0] opa_333, opb_333;
    always@(posedge aclk)begin
        right_sft_fff <= right_sft_ff;
        mul_e_test_ff <= mul_e_test_f;
        mul_normalize_test_right_f <= mul_normalize_test_right;
        mul_m_raw_333 <= mul_m_raw_33;
        sticky_333 <= sticky;
        mul_e_333 <= mul_e_33;
        nan_mul_333 <= nan_mul_33;
        mul_s_333 <= mul_s_33;
        is_valid_ain_333 <= is_valid_ain_33;
        is_valid_bin_333 <= is_valid_bin_33;
        zero_mul_333 <= zero_mul_33;
        opa_333 <= opa_33;
        opb_333 <= opb_33; 
    end
    
    wire ovf_1 = (mul_m_raw_333[21] && (& (mul_e_333 + 15))) || (|nan_mul_333) ? 1 : 0;


    wire [10:0] round_bits = mul_normalize_test_right_f[10:0];
    wire last_mantissa = mul_normalize_test_right_f[11];
    wire [9:0] round_bits_nos = round_bits[9:0];
    reg round_up_or_not;
    always@(*)begin
        if(round_bits[10] == 1 && ((|round_bits_nos) | sticky_333))begin
            round_up_or_not = 1;
        end
        else if(round_bits[10] == 1 && (~(|round_bits_nos))) begin
            round_up_or_not = last_mantissa ? 1:0;
        end
        else begin
            round_up_or_not = 0;
        end        
    end
  
    wire [11:0] mul_normalize = ovf_1 ? 11'b0 :
                mul_normalize_test_right_f[21:11] + round_up_or_not; 
    // =========================================================================
    always@(posedge aclk)begin
        // mul_normalize_test_right_4 <= mul_normalize_test_right;
        ovf_4 <= ovf_1;
        // mul_normalize_test_4 <= mul_normalize_test_3;
        mul_normalize_4 <= mul_normalize;
        mul_s_4 <= mul_s_333;
        // round_up_or_not_4 <= round_up_or_not;
        mul_e_test_f_4 <= mul_e_test_ff;
        is_valid_ain_4 <= is_valid_ain_333;
        is_valid_bin_4 <= is_valid_bin_333;
        zero_mul_4 <= zero_mul_333;
        nan_mul_4 <= nan_mul_333;  
        opa_4 <= opa_333;
        opb_4 <= opb_333;     
    end
    wire [6:0] mul_e_f = mul_normalize_4[11] ? mul_e_test_f_4 + 1: mul_e_test_f_4;
    wire [6:0] mul_e_ff = mul_e_f + 15;

    wire ovf_f = $signed(mul_e_ff) > 30;

    wire [6:0] mul_e_fff = $signed(mul_e_ff[4:0]) == 1 && ~mul_normalize_4[10] ? 6'd0 :
                            mul_e_ff;

    wire [15:0] mul_r = {mul_s_4, mul_e_fff[4:0], mul_normalize_4[9:0]};

    reg [6:0] mul_e_fff1;
    reg ovf_f1;
    reg [15:0] mul_r_f;
    reg mul_s_5;
    reg is_valid_ain_5, is_valid_bin_5;
    reg zero_mul_5;
    reg [1:0] nan_mul_5;    
    reg [15:0] opa_5, opb_5;
    always@(posedge aclk)begin
        mul_e_fff1 <= mul_e_fff;
        ovf_f1 <= ovf_f | ovf_4;
        mul_r_f <= mul_r;
        is_valid_ain_5 <= is_valid_ain_4;
        is_valid_bin_5 <= is_valid_bin_4;
        zero_mul_5 <= zero_mul_4;
        nan_mul_5 <= nan_mul_4;  
        mul_s_5 <= mul_s_4;
        opa_5 <= opa_4;
        opb_5 <= opb_4;  
    end
    

    wire [15:0] mul_f;


    assign mul_f = (~is_valid_ain_5 | ~is_valid_bin_5) ? 16'bx :
                nan_mul_5[1] ? {mul_s_5, opa_5[14:0]} :
                nan_mul_5[0] && ~nan_mul_5[1] ? {mul_s_5, opb_5[14:0]} : 
                zero_mul_5 ? {mul_s_5, 15'b0} : 
                ovf_f1 && ~(|nan_mul_5) ? {mul_s_5, 5'b11111, 10'b0} : 
                // {mul_s_4, mul_e_fff1[4:0], mul_normalize_4[9:0]};
                mul_r_f;

    always@(posedge aclk)begin
        m_axis_result_tdata <= mul_f;
        error_num <= (ovf_f1 && |(mul_f[9:0])) ? 1 : 
                    (ovf_f1 && ~(|mul_f[9:0])) ? 2 : 0;
        // subnormal_num <= ~(|mul_e_fff1[4:0]);  
        // is_ready_out <= 1;  
        if (&(mul_f === 16'bx))begin
            is_ready_out <= 0;
        end
        else begin
            is_ready_out <= 1;
        end    
    end



    // Check ready signal, only after result come out for new inputs can be high
    reg ready_out;
    always@(m_axis_result_tdata or opa_4 or opb_4)begin
        if(m_axis_result_tdata >= 16'd0)
            ready_out = 1;
        else    
            ready_out = 0;
    end

    // ready_out to show the last calculation finished;
    // valid_out to show the last calculating result meet the IEEE 754 principle, not error_num or subnormal_num and ready.
    // assign is_ready_out = ready_out;
    assign m_axis_result_tvalid = ~(|error_num) && is_ready_out;



    always@(posedge aclk)begin
        mul_e_2 <= mul_e;
        mul_s_2 <= mul_s;
        mul_m_raw_2 <= mul_m_raw;
        is_valid_ain_2 <= is_valid_ain_0;
        is_valid_bin_2 <= is_valid_bin_0;
        zero_mul_2 <= zero_mul;
        nan_mul_2 <= nan_mul;
        opa_2 <= opa_0;
        opb_2 <= opb_0;
    end

    always @(posedge aclk) begin
        mul_s_3 <= mul_s_2;
        mul_e_test_3 <= mul_e_test;
        mul_m_raw_3 <= mul_m_raw_2;
        mul_normalize_test_3 <= mul_normalize_test;
        mul_e_3 <= mul_e_2;
        is_valid_ain_3 <= is_valid_ain_2;
        is_valid_bin_3 <= is_valid_bin_2;
        zero_mul_3 <= zero_mul_2;
        nan_mul_3 <= nan_mul_2;  
        opa_3 <= opa_2;
        opb_3 <= opb_2;         
    end


endmodule

// left shift until the highest bit equal to 1
module LZC_for_fmul_pipe(
    input wire [10:0] op,
    output wire [3:0] shift_cnt
    );
    assign shift_cnt =
    op[10] ? 0 :
    op[9] ? 1 :
    op[8] ? 2 :
    op[7] ? 3 :
    op[6] ? 4 :
    op[5] ? 5 :
    op[4] ? 6 :
    op[3] ? 7 :
    op[2] ? 8 :
    op[1] ? 9 :
    op[0] ? 10:
    11;
endmodule


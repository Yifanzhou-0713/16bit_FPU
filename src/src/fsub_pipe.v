//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yifan Zhou
// 
// Create Date: 2023/06/08
// Design Name: 
// Module Name: fpu_add
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
module fpu_sub_pipe(
    input aclk,
    input [15:0] s_axis_a_tdata,               // input 16-bit float A
    input [15:0] s_axis_b_tdata,               // input 16-bit float B
    input s_axis_a_tvalid,
    input s_axis_b_tvalid,
    output reg [15:0] m_axis_result_tdata,              // output 16-bit float m_axis_result_tdata
    output  m_axis_result_tvalid
    // output reg [1:0] error_num,         // flag to show result non-number, 1 for INF \2 for NAN
    // output reg subnormal_num           // flag to show result subnormal
    );


    // for output check
    reg is_ready_out;
    reg [1:0] error_num;

    // 1-stage pipeline
    reg [14:0] sum_raw_1;
    reg sum_raw_zero_1;
    reg [4:0] l_e_1;
    reg [4:0] l_e_0_1;
    reg [10:0] l_m_1; 
    reg f_s_1;
    reg l_s_1;
    reg is_valid_ain_1, is_valid_bin_1;
    reg [15:0] opa_1, opb_1;
    reg s_zero_1;
    reg [1:0] ls_zero_1;
    reg pos_add_neg_inf_1;

    // 2-stage pipeline
    reg guard_2;
    reg round_bit_2;
    reg sticky_2;
    reg [14:0] sum_raw_2;
    reg sum_raw_zero_2;
    reg [4:0] sum_e_0_2;
    reg [3:0] shift_m_2;
    reg e_subnormal_2;
    reg normalize_flag_2;
    reg [4:0] l_e_0_2;
    reg f_s_2;
    reg l_s_2;
    reg [4:0] l_e_2;
    reg [10:0] l_m_2; 
    reg is_valid_ain_2, is_valid_bin_2;
    reg [15:0] opa_2, opb_2;
    reg s_zero_2;
    reg [1:0] ls_zero_2;
    reg pos_add_neg_inf_2;

    // 3-stage pipeline
    reg guard_3;
    reg round_bit_3;
    reg sticky_3;
    reg [10:0] sum_normalize_3;
    reg [4:0] sum_e_3;
    reg f_s_3;
    reg l_s_3;
    reg [4:0] l_e_0_3;
    reg [10:0] l_m_3; 
    // reg [14:0] sum_raw_3;
    reg sum_raw_zero_3;
    reg is_valid_ain_3, is_valid_bin_3;
    reg [15:0] opa_3, opb_3;
    reg s_zero_3;
    reg [1:0] ls_zero_3;
    reg pos_add_neg_inf_3;

    // ===================================
    // distribute sign/exponent/mantissa
    wire opa_s;
    wire opb_s;
    wire [4:0] opa_e;
    wire [4:0] opb_e;
    wire [4:0] opa_e_s;
    wire [4:0] opb_e_s;
    wire [10:0] opa_m;
    wire [10:0] opb_m;
    wire subnormal_a;
    wire subnormal_b;
    wire is_valid_ain_0;
    wire is_valid_bin_0;
    wire [15:0] opa_0;
    wire [15:0] opb_0;

    assign opa_s = s_axis_a_tdata[15];
    assign opb_s = s_axis_b_tdata[15];
    // check subnormal number
    assign subnormal_a = ~(|opa_e);
    assign subnormal_b = ~(|opb_e);
    assign opa_e = s_axis_a_tdata[14:10];
    assign opb_e = s_axis_b_tdata[14:10];
    assign opa_e_s = subnormal_a ? opa_e + 1 : opa_e;
    assign opb_e_s = subnormal_b ? opb_e + 1 : opb_e;
    assign opa_m = subnormal_a ? {1'b0, s_axis_a_tdata[9:0]} : {1'b1, s_axis_a_tdata[9:0]};
    assign opb_m = subnormal_b ? {1'b0, s_axis_b_tdata[9:0]} : {1'b1, s_axis_b_tdata[9:0]};
    assign is_valid_ain_0 = s_axis_a_tvalid;
    assign is_valid_bin_0 = s_axis_b_tvalid;
    assign opa_0 = s_axis_a_tdata;
    assign opb_0 = s_axis_b_tdata;

    // find s_axis_a_tdata large than s_axis_b_tdata
    wire opa_lt_opb = (opa_e > opb_e) ? 1 : ((opa_e == opb_e) && (s_axis_a_tdata[9:0] > s_axis_b_tdata[9:0])) ? 1 : 0;
    
    wire f_s = ((opa_lt_opb && ~opa_s) || (~opa_lt_opb && opb_s)) ? 0 : 1; 
    wire l_s = opa_lt_opb ? opa_s : opb_s;
    wire s_s = opa_lt_opb ? opb_s : opa_s;
    wire l_subnormal = opa_lt_opb ? subnormal_a : subnormal_b;
    wire s_subnormal = opa_lt_opb ? subnormal_b : subnormal_a;
    wire [4:0] l_e_0 = opa_lt_opb ? opa_e : opb_e;
    wire [4:0] s_e_0 = opa_lt_opb ? opb_e : opa_e;
    wire [4:0] l_e = opa_lt_opb ? opa_e_s : opb_e_s;
    wire [4:0] s_e = opa_lt_opb ? opb_e_s : opa_e_s;
    wire [10:0] l_m = opa_lt_opb ? opa_m : opb_m;
    wire [10:0] s_m = opa_lt_opb ? opb_m : opa_m;
    wire s_zero = s_subnormal && ~(|s_m[9:0]);
    wire [1:0] ls_zero = { l_s && s_s, (l_subnormal && ~(|l_m[9:0])) && s_zero };
    wire pos_add_neg_inf = (l_s ^ s_s) && (&s_e) && (~(|s_axis_a_tdata[9:0])&&~(|s_axis_b_tdata[9:0])); 

    wire [4:0] diff = l_e - s_e;
    wire [3:0] diff_e = diff > 4'd14 ? 4'd14 : diff;

    wire [13:0] s_m_shift_0 = {s_m, 3'b0};

    // sticky portion obtain
    reg sticky;
    always@(*)begin
        case(diff_e)
        00: sticky = 1'b0;
        01: sticky = s_m_shift_0[0];
        02: sticky = |s_m_shift_0[01:0];
        03: sticky = |s_m_shift_0[02:0];
        04: sticky = |s_m_shift_0[03:0];
        05: sticky = |s_m_shift_0[04:0];
        06: sticky = |s_m_shift_0[05:0];
        07: sticky = |s_m_shift_0[06:0];
        08: sticky = |s_m_shift_0[07:0];
        09: sticky = |s_m_shift_0[08:0];
        10: sticky = |s_m_shift_0[09:0];
        11: sticky = |s_m_shift_0[10:0];
        12: sticky = |s_m_shift_0[11:0];
        13: sticky = |s_m_shift_0[12:0];
        14: sticky = |s_m_shift_0[13:0];
        endcase
    end

    wire [13:0] s_m_shift_1 = s_m_shift_0 >> diff_e;
    wire [13:0] s_m_shift = {s_m_shift_1[13:1], s_m_shift_1[0] | sticky};

    // whether add or sub, for 0\1 in sign bit
    wire sub_add_flag = s_s ^ l_s;

    wire [13:0] l_m_longer = {l_m, 3'b0};

    wire [14:0] sum_raw = sub_add_flag ? l_m_longer + s_m_shift : l_m_longer - s_m_shift;
    wire sum_raw_zero = ~(|sum_raw);
    // 1-stage pipeline
    // =======================================================================================
    wire normalize_flag = sum_raw_1[14];

    wire [5:0] e_right_shift = l_e_1 + 1;   
    wire [4:0] sum_e_right = e_right_shift[5] ? 5'b11111 : e_right_shift[4:0];
    wire [4:0] sum_e_0 = normalize_flag ? sum_e_right : l_e_1; 
    wire [10:0] sum_for_normalize = normalize_flag ? sum_raw_1[13:4] : sum_raw_1[12:3];
    
    // left normalization
    wire [3:0] shift_m_0;
    LZC_for_fadd_new U0_shift_module(sum_raw_1[13:3], shift_m_0);
    
    // original rounding bits
    wire guard_0 = normalize_flag ? sum_raw_1[3] : sum_raw_1[2];
    wire round_bit_0 = normalize_flag ? sum_raw_1[2] : sum_raw_1[1];
    wire sticky_n_0 = normalize_flag ? (sum_raw_1[1] | sum_raw_1[0]) : sum_raw_1[0];
    
    // check first time subnormal result
    wire e_subnormal = (sum_e_0 <= shift_m_0 && ~normalize_flag) || (sum_e_0==1 && l_e_0_1==0);
    wire [3:0] shift_m = (sum_e_0 == 1 || normalize_flag) ? 0 : 
                        e_subnormal ? l_e_1 - 1 : shift_m_0;

    // obtain final rounding bits    
    wire guard;
    wire round_bit;
    Rounding_bit_gen U0_rounding_module(shift_m, guard_0, round_bit_0, guard, round_bit);

    // 2-stage pipeline
    // ====================================================================================== 
    wire [14:0] sum_normalize_00 = sum_raw_2 << shift_m_2;
    wire [10:0] sum_normalize_0 = normalize_flag_2 ? sum_raw_2[13:4] : sum_normalize_00[12:3];
    wire [4:0] sum_e = (e_subnormal_2 && ~sum_normalize_00[13])? sum_e_0_2 - shift_m_2 - 1 : sum_e_0_2 - shift_m_2;

    // =======================================================================================
    // 3-stage pipeline
    // final calculation
    wire [10:0] sum_m = (guard_3 && (round_bit_3 | sticky_3 | sum_normalize_3[0])) ? sum_normalize_3 + 1 :
                                                                                sum_normalize_3;
    wire [4:0] sum_e_f = sum_m[10] ? sum_e_3 + 1 : sum_e_3;

    reg [15:0] sum_f;
    reg [15:0] sum_ff;
    reg [4:0] sum_e_ff;
    reg pos_add_neg_inf_ff;
    always@(posedge aclk)begin
        sum_f <= (~is_valid_ain_3 | ~is_valid_bin_3) ? 16'bx:
            pos_add_neg_inf_3 ? 16'hfe00 :
            ls_zero_3[0] ? {ls_zero_3[1], 15'b0} : 16'hffff;
        sum_ff <= s_zero_3 | (&l_e_0_3) ? {f_s_3, l_e_0_3, l_m_3[9:0]} : 
            sum_raw_zero_3 ? 16'b0 :
            &sum_e_f ? {f_s_3, sum_e_f, 10'b0} : {f_s_3, sum_e_f, sum_m[9:0]};     
        sum_e_ff <= sum_e_f;   
        pos_add_neg_inf_ff <= pos_add_neg_inf_3;
    end
    
    // =======================================================================
    reg [15:0] sum_fff;
    reg [15:0] sum_e_fff;
    reg pos_add_neg_inf_fff;
    always@(posedge aclk)begin
        sum_fff <= &sum_f ? sum_ff : sum_f;
        sum_e_fff <= sum_e_ff;
        pos_add_neg_inf_fff <= pos_add_neg_inf_ff;
    end

    always@(posedge aclk)begin
        m_axis_result_tdata <= sum_fff;
        // subnormal_num <= ~(|sum_e_fff) && (|sum_fff[9:0]);
        if (&(sum_fff === 16'bx))begin
            is_ready_out <= 0;
        end
        else begin
            is_ready_out <= 1;
        end
        error_num <= (&(sum_fff[14:10]) && |(sum_fff[9:0])) | pos_add_neg_inf_fff ? 1:(&(sum_fff[14:10]) && ~(|sum_fff[9:0])) ? 2:0;
        // m_axis_result_tvalid <= ~(|error_num) && is_ready_out;
    end
    
    assign m_axis_result_tvalid = ~(|error_num) && is_ready_out;


    always@(posedge aclk)begin
        l_e_1 <= l_e;
        l_e_0_1 <= l_e_0;
        l_m_1 <= l_m;
        l_s_1 <= l_s;
        f_s_1 <= f_s;
        sum_raw_1 <= sum_raw;
        sum_raw_zero_1 <= sum_raw_zero;
        is_valid_ain_1 <= is_valid_ain_0;
        is_valid_bin_1 <= is_valid_bin_0;
        opa_1 <= opa_0;
        opb_1 <= opb_0;
        s_zero_1 <= s_zero;
        ls_zero_1 <= ls_zero;
        pos_add_neg_inf_1 <= pos_add_neg_inf;
    end

    always@(posedge aclk)begin
        sum_raw_2 <= sum_raw_1;
        sum_raw_zero_2 <= sum_raw_zero_1;
        sum_e_0_2 <= sum_e_0;
        guard_2 <= guard;
        round_bit_2 <= round_bit;
        sticky_2 <= sticky_n_0;
        shift_m_2 <= shift_m;
        e_subnormal_2 <= e_subnormal;
        normalize_flag_2 <= normalize_flag;
        l_e_0_2 <= l_e_0_1;
        l_s_2 <= l_s_1;
        f_s_2 <= f_s_1;
        l_e_2 <= l_e_1;
        l_m_2 <= l_m_1;
        is_valid_ain_2 <= is_valid_ain_1;
        is_valid_bin_2 <= is_valid_bin_1;
        opa_2 <= opa_1;
        opb_2 <= opb_1;
        s_zero_2 <= s_zero_1;
        ls_zero_2 <= ls_zero_1;
        pos_add_neg_inf_2 <= pos_add_neg_inf_1;             
    end

    always@(posedge aclk)begin
        guard_3 <= guard_2;
        round_bit_3 <= round_bit_2;
        sticky_3 <= sticky_2;
        sum_normalize_3 <= sum_normalize_0;
        sum_raw_zero_3 <= sum_raw_zero_2;
        sum_e_3 <= sum_e;
        l_s_3 <= l_s_2;
        f_s_3 <= f_s_2;
        l_e_0_3 <= l_e_0_2;
        l_m_3 <= l_m_2;
        is_valid_ain_3 <= is_valid_ain_2;
        is_valid_bin_3 <= is_valid_bin_2;
        opa_3 <= opa_2;
        opb_3 <= opb_2;
        s_zero_3 <= s_zero_2;
        ls_zero_3 <= ls_zero_2;
        pos_add_neg_inf_3 <= pos_add_neg_inf_2;        
    end
endmodule


// left shift until the highest bit equal to 1
module LZC_for_fadd_new(
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


module Rounding_bit_gen(
    input wire [3:0] shift_m,
    input wire guard_i,
    input wire round_bit_i,
    output wire guard_o,
    output wire round_bit_o
    );
    reg guard;
    reg round_bit;

    always@(*)begin
        case(shift_m)
        0: begin 
            guard = guard_i; 
            round_bit = round_bit_i;
        end
        1: begin
            guard = round_bit_i;
            round_bit = 0;
        end
        default: begin
            guard = 0;
            round_bit = 0;
        end
        endcase
    end

    assign guard_o = guard;
    assign round_bit_o = round_bit;

endmodule
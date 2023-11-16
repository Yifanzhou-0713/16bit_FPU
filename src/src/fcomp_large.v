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
module fpu_comp_large(
    input aclk,
    input [15:0] s_axis_a_tdata,               // input 16-bit float A
    input [15:0] s_axis_b_tdata,               // input 16-bit float B
    input s_axis_a_tvalid,
    input s_axis_b_tvalid,
    output [7:0] m_axis_result_tdata,              // output 16-bit float sum
    output reg m_axis_result_tvalid
    // output [1:0] error_num          // flag to show result non-number, 1 for INF \2 for NAN
    );

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
    wire [15:0] opa_0;
    wire [15:0] opb_0;
    reg [15:0] opa_1;
    reg [15:0] opb_1;
    wire is_valid_ain_0, is_valid_bin_0;
    reg is_valid_ain_1, is_valid_bin_1;
    reg is_ready_out;
    reg [1:0] error_num;
    assign opa_s = s_axis_a_tdata[15];
    assign opb_s = s_axis_b_tdata[15];

    assign opa_e = s_axis_a_tdata[14:10];
    assign opb_e = s_axis_b_tdata[14:10];

    assign opa_m = s_axis_a_tdata[9:0];
    assign opb_m = s_axis_b_tdata[9:0];
    assign opa_0 = s_axis_a_tdata;
    assign opb_0 = s_axis_b_tdata;
    assign is_valid_ain_0 = s_axis_a_tvalid;
    assign is_valid_bin_0 = s_axis_b_tvalid;

    // find s_axis_a_tdata large than s_axis_b_tdata
    wire a_e_b = ~(| (s_axis_a_tdata ^ s_axis_b_tdata));
    wire s_a_g_b = (~opa_s) & opb_s;
    wire s_a_e_b = ~(opa_s ^ opb_s);
    wire e_a_g_b = (opa_e > opb_e);
    wire e_a_l_b = (opa_e < opb_e);
    wire e_a_e_b = (opa_e == opb_e);
    wire m_a_g_b = (opa_m > opb_m);
    wire m_a_l_b = (opa_m < opb_m);
    reg con1;
    reg con2;
    reg con3;
    reg con4;
    reg con5;
    reg con6;

    always@(posedge aclk)begin
        con1 <= a_e_b;
        con2 <= ~a_e_b & s_a_g_b;
        con3 <= ~a_e_b & s_a_e_b & (~opa_s) & e_a_g_b;
        con4 <= ~a_e_b & s_a_e_b & (~opa_s) & e_a_e_b & m_a_g_b;
        con5 <= ~a_e_b & s_a_e_b & opa_s & e_a_l_b;
        con6 <= ~a_e_b & s_a_e_b & opa_s & e_a_e_b & m_a_l_b;     
        opa_1 <= opa_0;
        opb_1 <= opb_0;   
        is_valid_ain_1 <= is_valid_ain_0;
        is_valid_bin_1 <= is_valid_bin_0;
        // is_ready_out <= 0;
    end


    assign m_axis_result_tdata = (con1 | con2 | con3 | con4 | con5 | con6) ? 8'b00000001 : 8'b00000000;
    // assign m_axis_result_tdata = (con1 | con2 | con3 | con4 | con5 | con6) ? opa_1 : opb_1;

    always@(m_axis_result_tdata)begin
        // is_ready_out = 1;
        m_axis_result_tvalid = is_valid_ain_1 & is_valid_bin_1;
        is_ready_out = m_axis_result_tvalid;
    end

endmodule



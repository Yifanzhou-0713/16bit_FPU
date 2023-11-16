//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Yifan Zhou
// 
// Create Date: 2023/06/08
// Design Name: 
// Module Name: fpu_add_tb
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
`timescale 1ns / 100ps

module fpu_add_pipe_tb();
    reg [15:0] opa; 
    reg [15:0] opb;
    wire [15:0] sum;
    wire is_ready_out;
    wire is_valid_out;
    wire [1:0] error_num;  // flag to show result non-number, 1 for INF \2 for NAN
    wire subnormal_num; // flag to show result subnormal

    reg	[15:0]	data_list[0:199999];
    reg [15:0]  data_list_result[0:99999];
    reg [15:0]  tmp_res;

    reg is_valid_ain;
    reg is_valid_bin;

    reg [31:0]  cnt;
    reg         is_error;

    integer i;
    // logic sum_gt_last;

    reg clk = 0, rst = 1;
        
    always clk = #1.667 ~clk;
    // wire [15:0] sum_ff;
    fpu_add_pipe U0_fpu_add_pipe(
        .aclk(clk),
        .s_axis_a_tdata(opa),
        .s_axis_b_tdata(opb),
        .m_axis_result_tdata(sum),
        .s_axis_a_tvalid(is_valid_ain),
        .s_axis_b_tvalid(is_valid_bin),
        .m_axis_result_tvalid(is_valid_out)
    );

    // floating_point_0  U1_fpu_add(
    //     .aclk(clk),
    //     .s_axis_a_tdata(opa),
    //     // .s_axis_a_tready(1),
    //     .s_axis_a_tvalid(1),
    //     .s_axis_b_tdata(opb),
    //     // .s_axis_b_tready(1),
    //     .s_axis_b_tvalid(1),
    //     .m_axis_result_tvalid(sum_gt_valid),
    //     .m_axis_result_tready(sum_gt_ready),
    //     .m_axis_result_tdata(sum_gt)
    // );

    initial begin
        // @(posedge clk);
        // opa = 16'h0F00; //0_00011_1100000000
        // opb = 16'h0B80; //0_00010_1110000000

        // @(posedge clk);
        // opa = 16'hD98D; //1_10110_0110001101
        // opb = 16'h4F08; //0_10011_1100001000
        // $readmemb("D:/Code/Chip/Vivado_rtl/FPU-main/tb_data.txt", data_list);
        $readmemh("D:/Code/Chip/Vivado_rtl/FPU-main/new_test_vectors/tb_sum_ab_100k.txt", data_list);
        $readmemh("D:/Code/Chip/Vivado_rtl/FPU-main/new_test_vectors/tb_sum_res_100k.txt", data_list_result);

        is_error = 0;
        cnt = 0;
        #100 rst = 0;

        // repeat(10000) begin
        //     @(posedge clk);
        //     opa = data_list[2*cnt];
        //     opb = data_list[2*cnt + 1];
        //     is_valid_ain = 1;
        //     is_valid_bin = 1;
        //     tmp_res = data_list_result[cnt];
        //     if(data_list_result[cnt-3]!=sum && (cnt > 3)) begin
        //         is_error = 1;
        //     end
        //     else 
        //         is_error = 0;
        //     cnt = cnt + 1;
        // end
        // @(posedge clk);
        // opa = data_list[9999];
        // opb = 0;

        // @(posedge clk);
        // opa = 0;
        // opb = data_list[9999];

        repeat(100000) begin
            @(posedge clk);
            opa = data_list[2*cnt];
            opb = data_list[2*cnt+1];
            is_valid_ain = 1;
            is_valid_bin = 1;
            tmp_res = data_list_result[cnt];
            // if(data_list_result[cnt-7]!=sum && (cnt >7) && error_num!=2'b1) begin
            if(data_list_result[cnt-7]!=sum && (cnt >7) && is_valid_out!=1'b0) begin
                is_error = 1;
            end
            else 
                is_error = 0;
            cnt = cnt + 1;
        end

        // @(posedge clk);
        // opa = 16'b0111101111110010;
        // opb = 16'b0111100111110110;

        // @(posedge clk);
        // is_valid_ain = 0;
        // is_valid_bin = 0;
        // opa = 16'b0;
        // opb = 16'b0;

        // # 20;
        // @(posedge clk);
        // is_valid_ain = 1;
        // is_valid_bin = 1;
        // opa = 16'h8401;
        // opb = 16'h3400;
        // tmp_res = 16'h33ff;

        // =====================
        // @(posedge clk);
        // is_valid_ain = 1;
        // is_valid_bin = 1;
        // opa = 16'h13e4;
        // opb = 16'h940d;
        // tmp_res = 16'h33ff;   

        // @(posedge clk);
        // opa = 16'h0bd3;
        // opb = 16'h8b7b;
        // tmp_res = 16'h33ff; 
        // =====================

        // @(posedge clk);
        // is_valid_ain = 1;
        // is_valid_bin = 1;
        // opa = 16'h87ef;
        // opb = 16'h3400;
        // tmp_res = 16'h33ff;

        // @(posedge clk);
        // is_valid_ain = 1;
        // is_valid_bin = 1;
        // opa = 16'h2e0e;
        // opb = 16'h017e;
        // tmp_res = 16'h2e0e;

        // @(posedge clk);
        // opa = 16'h0848;
        // opb = 16'h003a;  
        // tmp_res = 16'h0865;
   
        // @(posedge clk);
        // opa = 16'h0aab;
        // opb = 16'h83ba;  
        // tmp_res = 16'h08ce; 

        // @(posedge clk);
        // opa = 16'h06ab;
        // opb = 16'h83ba;  
        // tmp_res = 16'h02f1; 

        // @(posedge clk);
        // opa = 16'hcca6;
        // opb = 16'hb17c;
        // tmp_res = 16'hccb1;

        // @(posedge clk);
        // opa = 16'hafed;
        // opb = 16'h8027;
        // tmp_res = 16'hafed;

        // @(posedge clk);
        // opa = 16'b0000100001001000;
        // opb = 16'b0000010000011101;
        // tmp_res = 16'h0865;
        @(posedge clk);
        is_valid_ain = 0;
        is_valid_bin = 0;
        // @(posedge clk);
        // is_valid_ain = 1;
        // is_valid_bin = 1;
        // opa = 16'b0000100001001000;
        // opb = 16'b0000010000011101;   
        // @(posedge clk);
        // is_valid_ain = 0;
        // is_valid_bin = 0;
        // @(posedge clk);
        // is_valid_ain = 1;
        // is_valid_bin = 1;
        // opa = 16'b0000100001001000;
        // opb = 16'b0000010000011101;        
        // @(posedge clk);
        // is_valid_ain = 0;
        // is_valid_bin = 0;
        // opa = 16'b0;
        // opb = 16'b0;

        # 50 $finish;
    end



endmodule
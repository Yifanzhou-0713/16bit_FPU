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

module fpu_mul_pipe_tb();
    reg [15:0] opa; 
    reg [15:0] opb;
    wire [15:0] sum;
    wire is_ready_out;
    wire [1:0] error_num;
    wire subnormal_num;
    wire is_valid_out;


    reg	[15:0]	data_list[0:199999];
    reg [15:0]  data_list_result[0:99999];
    reg [15:0]  tmp_res;

    reg is_valid_ain;
    reg is_valid_bin;

    reg         is_error;


    // logic sum_gt_last;
    integer i;
    reg [31:0] cnt;
    reg clk = 0, rst = 1;
    reg [10:0] testa;
    reg [10:0] testb;
    reg [21:0] test_num;
        
    always clk = #1.667 ~clk;
    
    fpu_mul_pipe U0_fpu_mul_pipe(
        .aclk(clk),
        .s_axis_a_tdata(opa),
        .s_axis_b_tdata(opb),
        .s_axis_a_tvalid(is_valid_ain),
        .s_axis_b_tvalid(is_valid_bin),
        .m_axis_result_tdata(sum),
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
        is_error = 0;
        cnt = 0;


        // @(posedge clk);
        // opa = 16'h0F00; //0_00011_1100000000
        // opb = 16'h0B80; //0_00010_1110000000

        // @(posedge clk);
        // opa = 16'hD98D; //1_10110_0110001101
        // opb = 16'h4F08; //0_10011_1100001000

        $readmemh("D:/Code/Chip/Vivado_rtl/FPU-main/new_test_vectors/tb_mul_ab_100k.txt", data_list);
        // $readmemh("D:/Code/Chip/Vivado_rtl/FPU-main/old_test_vectors/tb_data_gt_1.txt", data_list);
        $readmemh("D:/Code/Chip/Vivado_rtl/FPU-main/new_test_vectors/tb_mul_res_100k.txt", data_list_result);
        // $readmemh("D:/Code/Chip/Vivado_rtl/FPU-main/old_test_vectors/tb_data_mul_gt_1.txt", data_list_result);

        #100 rst = 0;
        #10;
        // opa = 16'h7978;
        // opb = 16'h0001; 
        // is_valid_ain = 1;
        // is_valid_bin = 1;
        // tmp_res = 16'h1978;
        testa = 11'b10101111000;
        testb = 11'b10000000000;
        test_num = testa * testb;

        repeat(100000) begin
            @(posedge clk);
            opa = data_list[2*cnt];
            opb = data_list[2*cnt + 1];
            is_valid_ain = 1;
            is_valid_bin = 1;
            tmp_res = data_list_result[cnt];
            if(data_list_result[cnt-8]!=sum && cnt > 8 && ( is_valid_out!=2'b0 )) begin
            // if(data_list_result[cnt-1]!=sum && cnt > 1) begin
                is_error = 1;
            end
            else begin
                is_error = 0;
            end
            cnt = cnt + 1;
        end

        // @(posedge clk);
        // opa = data_list[9999];
        // opb = 0;

        // @(posedge clk);
        // opa = 0;
        // opb = data_list[9999];

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
        // opa = 16'b0111101111110010;
        // opb = 16'b0111100111110110;

        // @(posedge clk);
        // opa = 16'b0011110000000000;
        // opb = 16'b0111100111110110;        

        @(posedge clk);
        is_valid_ain = 0;
        is_valid_bin = 0;
        opa = 16'b0;
        opb = 16'b0;
        #100 $finish;
    end

endmodule
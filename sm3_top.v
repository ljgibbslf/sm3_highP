`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:  SHU·ACTION
// Engineer: li fan
// 
// Create Date: 2019/05/23 20:25:32
// Design Name: 
// Module Name: sm3_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// SM3 运算核顶层 控制填充模块的输出，并将其输入运算模块
// top of SM3, contrl output of fill module input calculation module through  FSM
//////////////////////////////////////////////////////////////////////////////////
//`define USE_ILA 1
module sm3_top(
    input           clk,
    input           rst_n,

    input [63:0]    data_input_i,
    input [7:0]     data_input_keep_i,
    input           data_input_valid_i,
    input           data_input_last_i,

    output          sm3_output_valid_o,
    output [255:0]  sm3_dout
    );

    
    //FSM of sm3_top
    `define         STAT_WIDTH 4
    reg    [`STAT_WIDTH - 1 :0] status;

    parameter       IDLE                    = `STAT_WIDTH'h01,
                    READ_FIFO               = `STAT_WIDTH'h02,
                    OUTPUT                  = `STAT_WIDTH'h04,
                    CHECK_LAST_BLOCK        = `STAT_WIDTH'h08;
    reg [7:0]       read_fifo_cnt;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            status              <=  IDLE;
            read_fifo_cnt       <=  8'd0;
        end
        else begin
            case (status)
                IDLE:begin
                    if(fifo_data_count >= 9'd8 && loop_compact_input_ready) begin
                        status              <=  READ_FIFO;
                    end
                end 
                READ_FIFO:begin
                    if(read_fifo_cnt == 8'd8 - 8'd1) begin
                        read_fifo_cnt       <=  8'd0;
                        status              <=  CHECK_LAST_BLOCK;
                    end
                    else begin
                        read_fifo_cnt       <=  8'd1 + read_fifo_cnt;
                        status              <=  READ_FIFO;
                    end
                end
                OUTPUT:begin
                    if( loop_compact_valid_output)
                        status              <=  IDLE;
                    else
                        status              <=  OUTPUT;
                end
                CHECK_LAST_BLOCK:begin
                    if(flag_last_block_ena)
                        status              <=  OUTPUT;
                    else 
                        status              <=  IDLE;
                end
                default: begin
                    status              <=  IDLE;
                end
            endcase
        end
    end

    reg    [`STAT_WIDTH - 1 :0] status_r;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            status_r    <=  IDLE;
        end
        else begin
            status_r    <=  status;
        end
    end

    //读取迭代压缩模块输入中的最后一个 block 标志
    reg     flag_last_block;
    wire    flag_last_block_ena = loop_compact_input[127] == 1'b1 && (~(status == IDLE));
    wire    flag_last_block_clr = (status == IDLE && status_r == OUTPUT);
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n | flag_last_block_clr) begin
            flag_last_block     <=  1'b0;    
        end
        else if(flag_last_block_ena)begin
            flag_last_block     <=  1'b1; 
        end
    end

    //读取FIFO，将数据送入迭代压缩模块
    wire        fifo_rd_en = status == READ_FIFO;
    assign      sm3_output_valid_o = loop_compact_valid_output && status == OUTPUT;
    assign      sm3_dout    =   loop_compact_res_output;
    //迭代压缩模块输入使能，相当于 FIFO 读使能的打拍，以抵消延迟
    reg             loop_compact_ctl_input_valid;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            loop_compact_ctl_input_valid    <=  1'b0;
        end
        else begin
            loop_compact_ctl_input_valid    <=  fifo_rd_en;
        end
    end

    wire   [63 :0]  loop_compact_input_data;
    wire   [63 :0]  loop_compact_input_block_index;
    wire   [127:0]  loop_compact_input;
    assign  {loop_compact_input_block_index,loop_compact_input_data} = loop_compact_input;
    wire   [255:0]  loop_compact_res_output;
    wire            loop_compact_valid_output;
    wire            loop_compact_input_ready;
    loop_compact U_loop_compact(
        .clk                    (clk),
        .rst_n                  (rst_n),

        .din                    (loop_compact_input_data),
        .input_valid_i          (loop_compact_ctl_input_valid),
        .input_block_index_i    (loop_compact_input_block_index),
        .input_ready_o          (loop_compact_input_ready),
        .output_valid_o         (loop_compact_valid_output),
        .dout                   (loop_compact_res_output)
    );

    //硬件对齐模块
    wire [63:0]       unalign_dw_data     =   data_input_i      ;
    wire [7:0]        unalign_dw_keep     =   data_input_keep_i ;
    wire              unalign_dw_valid    =   data_input_valid_i;
    wire              unalign_dw_last     =   data_input_last_i ;

    wire [63:0]       align_dw_data_o ;
    wire [7:0]        align_dw_keep_o ;
    wire              align_dw_valid_o;
    wire              align_dw_last_o ;
    hw_dw_align_module U_hw_dw_align_module
    (
        .clk                                (clk),
        .rst_n                              (rst_n),

        .debug_tri_i                        (1'b0),

        .fifo_if_tdata_i                    (unalign_dw_data ),
        .fifo_if_tkeep_i                    (unalign_dw_keep ),
        .fifo_if_tvalid_i                   (unalign_dw_valid),
        .fifo_if_tlast_i                    (unalign_dw_last ),

        .flag_last_segment_i                (),
        
        .align_dw_data_o                    (align_dw_data_o),
        .align_dw_keep_o                    (align_dw_keep_o),
        .align_dw_valid_o                   (align_dw_valid_o),
        .align_dw_last_o                    (align_dw_last_o)
    );

    wire            fifo_full_i;
    wire            fifo_wena_o;
    wire [63:0]     filled_data_output;
    wire [63:0]     filled_data_index_output;
    wire [127 : 0]  fifo_din_o = {filled_data_index_output,filled_data_output};
    data_fill_module U_data_fill_module (
		.clk                    (clk), 
		.rst_n                  (rst_n), 

		.data_input_i           (align_dw_data_o),
		.data_input_keep_i      (align_dw_keep_o),
		.data_input_valid_i     (align_dw_valid_o),
		.data_input_last_i      (align_dw_last_o),

		.data_input_ready_o     (data_input_ready_o), 
		.block_index_o          (filled_data_index_output),
		.fifo_din_o             (filled_data_output), 
		.fifo_wena_o            (fifo_wena_o), 
		.fifo_full_i            (fifo_full_i)
	);



    wire [8 : 0]    fifo_data_count;
    wire            fifo_empty;

    //Instantiate Your own FIFO here
    //width:128b
    //depth:256 recommend
    filled_mess_fifo_128bx512 U_filled_mess_fifo_128bx512 (
        .clk(clk),                                  // input wire clk
        .din(fifo_din_o),                           // input wire [127 : 0] din
        .wr_en(fifo_wena_o),                        // input wire wr_en
        .rd_en(fifo_rd_en),                         // input wire rd_en
        .dout(loop_compact_input),                  // output wire [127 : 0] dout
        .full(fifo_full_i),                         // output wire full
        .empty(),                                   // output wire empty
        .data_count(fifo_data_count)                // output wire [8 : 0] data_count
    );

endmodule

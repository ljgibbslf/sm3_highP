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
// fill module of SM3, fill message to n*512b ,512b consist a block
//////////////////////////////////////////////////////////////////////////////////
module data_fill_module(
    input           clk,
    input           rst_n,
    
    input [63:0]    data_input_i,
    input [7:0]     data_input_keep_i,
    input           data_input_valid_i,
    input           data_input_last_i,
    
    output          data_input_ready_o,

    //输出当前的消息块 消息块最多可达 2^55 个
    output [63:0]   block_index_o, 

    //输出 fifo 接口
    output [63:0]   fifo_din_o,
    output          fifo_wena_o,
    input           fifo_full_i

    );


    //统计 keep 输入中1的个数
    reg [3:0]  valid_byte_cnt;
    reg [3:0]  valid_byte_cnt_r;
    always @(*) begin
        valid_byte_cnt = 4'b0;
        for(integer i = 0;i < 8;i=i+1) begin
            //if(data_input_keep_i[i])
                valid_byte_cnt = valid_byte_cnt + data_input_keep_i[i];
        end
    end
    always @(*) begin
        valid_byte_cnt_r = 4'b0;
        for(integer i = 0;i < 8;i=i+1) begin
            //if(data_input_keep_i[i])
                valid_byte_cnt_r = valid_byte_cnt_r + data_input_keep_r[i];
        end
    end


    //最后一个双字是否完整,即 keep 位是否为全1
    wire        is_input_last_2word_complete = data_input_last_i && (&data_input_keep_i);

    //输入 ready 控制
    assign  data_input_ready_o = (~fifo_full_i) && (~fill_processing); //在数据填充期间或者FIFO满时，阻止数据输入

    //对输入数据打拍
    reg [63:0]    data_input_r;
    reg [7:0]     data_input_keep_r;
    reg [7:0]     data_input_keep_r2;
    reg           data_input_valid_r;
    reg           data_input_last_r;
    reg           data_input_last_r2;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            data_input_r            <= 64'd0;
            data_input_keep_r       <= 8'd0;
            data_input_keep_r2      <= 8'd0;
            data_input_valid_r      <= 1'd0;
            data_input_last_r       <= 1'd0;
            data_input_last_r2      <= 1'd0;
        end else begin
            data_input_r            <= data_input_i;
            data_input_keep_r       <= data_input_keep_i;
            data_input_keep_r2      <= data_input_keep_r;
            data_input_valid_r      <= data_input_valid_i;
            data_input_last_r       <= data_input_last_i;
            data_input_last_r2      <= data_input_last_r;
        end
    end

    //todo 清除上一次状态
    wire    system_clr = ~fill_processing && fill_processing_r;
    reg     fill_processing_r;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            fill_processing_r       <=  1'b0;  
        end
        else begin
            fill_processing_r       <=  fill_processing;  
        end
    end

    //输入字节计数
    reg [63:0]  input_byte_cnt;
    wire        input_byte_cnt_ena = data_input_valid_r;
    wire        input_byte_cnt_clr = system_clr;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n | input_byte_cnt_clr) begin
            input_byte_cnt          <=  64'd0; 
        end else if(input_byte_cnt_ena)begin
            input_byte_cnt          <=  input_byte_cnt + valid_byte_cnt_r; 
        end
    end

    //填充控制，控制填0的字节个数
    reg [63:0]  fill_0_byte_need;
    wire        fill_o_byte_need_clr = system_clr;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n | fill_o_byte_need_clr) begin
            fill_0_byte_need          <=  64'd56;//56-8(填充10)
        end else if(input_byte_cnt_ena)begin

            //如果输入的是最后一个字，判断是否需要填充10，需要填充10，则减8
            if(data_input_last_r) begin
                if(&data_input_keep_r) begin //需要填充 10
                    if(fill_0_byte_need == 'd0)
                        fill_0_byte_need <= 64'd64 - 64'd8 - 64'd8;//64 - 8(最后一个数据字) -8(10)
                    else if (fill_0_byte_need == 'd8)
                        fill_0_byte_need <= 64'd64 - 64'd8; //64 - 8(10占用)
                    else
                        fill_0_byte_need    <=  fill_0_byte_need - 64'd8 - 64'd8; //减去一个双字用于最后一个数据 再额外减去一个10占用的双字
                end else begin //不需要额外填充 10
                    if(fill_0_byte_need == 'd0)
                        fill_0_byte_need <= 64'd64 - 64'd8;//64 - 8(最后一个数据字) 
                    else if (fill_0_byte_need == 'd8)
                        fill_0_byte_need <= 64'd0; 
                    else
                        fill_0_byte_need    <=  fill_0_byte_need - 64'd8 ; //减去一个双字用于最后一个数据
                end
            end else begin //普通输入
                //在有输入的情况下减8,减不了的情况下复位为64再减8（等于 56）
                if(fill_0_byte_need == 'd0)
                    fill_0_byte_need    <=  64'd64 - 64'd8;
                else 
                    fill_0_byte_need    <=  fill_0_byte_need - 64'd8;
            end
        end
    end

    //填充状态控制
    reg         fill_processing_10;        
    reg         fill_processing_0;        
    reg         fill_processing_bit_len;     
    reg [63:0]  fill_processing_10_pattern;
    wire        fill_processing = fill_processing_10 | fill_processing_0 | fill_processing_bit_len;
    wire        fill_ena = (data_input_last_i && ~(&data_input_keep_i)) || (data_input_last_r && (&data_input_keep_r));
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            fill_processing_10          <=  1'b0;     
            fill_processing_0           <=  1'b0;      
            fill_processing_bit_len     <=  1'b0;
            fill_processing_10_pattern  <=  64'd0;
        end else begin
            if(fill_ena) begin 
                fill_processing_10          <=  1'b1;  //填充1所在的双字
                if(data_input_last_r && (&data_input_keep_r))
                    fill_processing_10_pattern  <=  64'h8000_0000_0000_0000;
                else begin
                    case (valid_byte_cnt) //根据最后一个双字时 有效的字节数，决定填充 10 的pattern
                    4'd0:
                        fill_processing_10_pattern  <=  64'h8000_0000_0000_0000 | data_input_i; //no reach
                    4'd1:
                        fill_processing_10_pattern  <=  64'h0080_0000_0000_0000 | data_input_i;
                    4'd2:
                        fill_processing_10_pattern  <=  64'h0000_8000_0000_0000 | data_input_i;
                    4'd3:
                        fill_processing_10_pattern  <=  64'h0000_0080_0000_0000 | data_input_i;
                    4'd4:
                        fill_processing_10_pattern  <=  64'h0000_0000_8000_0000 | data_input_i;
                    4'd5:
                        fill_processing_10_pattern  <=  64'h0000_0000_0080_0000 | data_input_i;
                    4'd6:
                        fill_processing_10_pattern  <=  64'h0000_0000_0000_8000 | data_input_i;
                    4'd7:
                        fill_processing_10_pattern  <=  64'h0000_0000_0000_0080 | data_input_i;
                    endcase
                end
            end
            else if (fill_processing_10) begin
                if((fill_0_byte_need == 64'd8 &&  data_input_last_r && ~(&data_input_keep_r)) ||
                    (fill_0_byte_need == 64'd0 &&  data_input_last_r2 && (&data_input_keep_r2))
                    ) begin //无需填0的情况
                    fill_processing_bit_len     <=  1'b1;
                end else begin//需要填0
                    fill_processing_0           <=  1'b1;  //填充全 0
                end
                fill_processing_10          <=  1'b0;
            end else if(fill_processing_0) begin
                if(output_fill_0_byte_cnter == fill_0_byte_need - 64'd8)begin
                    fill_processing_0           <=  1'b0;      //全0填充完毕，开始填充消息长度
                    fill_processing_bit_len     <=  1'b1;
                end
            end else if (fill_processing_bit_len)
                fill_processing_bit_len     <=  1'b0;   //填充一个 clk 的消息长度

        end
    end

    //输出0填充计数
    reg [63:0]  output_fill_0_byte_cnter;
    wire        output_fill_0_byte_cnter_clr = system_clr;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n | output_fill_0_byte_cnter_clr) begin
            output_fill_0_byte_cnter   <=  64'd0;
        end else if(fifo_wena_o && fill_processing_0)begin
            output_fill_0_byte_cnter   <=  output_fill_0_byte_cnter + 64'd8;
        end
    end

    //FIFO输出控制
    assign  fifo_wena_o = data_input_valid_r | fill_processing;
    assign  fifo_din_o = (fill_processing_10)?fill_processing_10_pattern:
                            fill_processing_0?64'd0:      
                            fill_processing_bit_len?{45'd0,input_byte_cnt,3'b000}:
                            data_input_r;
    assign  block_index_o = fill_processing_bit_len?{1'b1,fifo_block_index[62:0]}:fifo_block_index;
    //输出计数，以提供数据块的 block 号
    reg [7:0]   fifo_output_cnt;
    reg [63:0]  fifo_block_index;
    wire        fifo_block_index_clr = system_clr;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n | fifo_block_index_clr) begin
            fifo_output_cnt         <=  8'd0;
            fifo_block_index        <=  64'd0; 
        end
        else if(fifo_wena_o)begin
            if(fifo_output_cnt == 8'd7) begin
                fifo_output_cnt         <=  8'd0;
                fifo_block_index        <=  fifo_block_index + 64'd1; 
            end
            else
                fifo_output_cnt         <=  fifo_output_cnt + 8'd1;
        end
    end


endmodule

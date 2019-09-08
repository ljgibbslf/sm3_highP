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
// loop_compact module of SM3: conduct loop compact & message expand through core FSM
//////////////////////////////////////////////////////////////////////////////////


module loop_compact(
    input           clk,
    input           rst_n,
    input           input_valid_i,
    input [63:0]    input_block_index_i,
    input [63:0]    din,

    output          input_ready_o,
    output          output_valid_o,
    output [255:0]  dout
    );


    localparam SM3_H0 = 32'h7380166f;
    localparam SM3_H1 = 32'h4914b2b9;
    localparam SM3_H2 = 32'h172442d7;
    localparam SM3_H3 = 32'hda8a0600;
    localparam SM3_H4 = 32'ha96f30bc;
    localparam SM3_H5 = 32'h163138aa;
    localparam SM3_H6 = 32'he38dee4d;
    localparam SM3_H7 = 32'hb0fb0e4e;
    localparam SM3_T0 = 32'h79cc4519;
    localparam SM3_T1 = 32'h9d8a7a87;

    reg	[31:0]	 H0,H1,H2,H3,H4,H5,H6,H7;
    reg	[31:0]	 W0,W1,W2,W3,W4,W5,W6,W7,W8,W9,W10,W11,W12,W13,W14,W15,W16,W17,W18,W19,W20,Wt,wtmp_h,wtmp_l;
    reg	[31:0]	 Tj_h,Tj_l;
    reg	[31:0]	 A,B,C,D,E,F,G,H;

    reg	[6:0]	 round;
    wire[6:0]	 round_plus_1;

    wire [31:0]  FF1_ABC,FF2_ABC,FFj_ABC,GG1_EFG,GG2_EFG,GGj_EFG;
    reg  [31:0]  Wj1_low,Wj2_low;
    reg  [31:0]  Wj1_high,Wj2_high;

    //----------------------------------------------------------------------------
    //
    wire	[31:0] wtmp_l_w =   W5 ^ W12 ^ {W18[16:0],W18[31:17]};
    wire	[31:0] wtmp_h_w =   W6 ^ W13 ^ {W19[16:0],W19[31:17]};
    
    wire    [31:0] next_C = {A[22:0],A[31:23]}; //C= A <<< 9
    wire    [31:0] next_D = {B[22:0],B[31:23]}; //D= B <<< 9
    wire    [31:0] next_G = {E[12:0],E[31:13]}; //G= E <<< 19
    wire    [31:0] next_H = {F[12:0],F[31:13]}; //H= F <<< 19
    wire    [31:0] next_E = tt2_h ^ {tt2_h[22:0],tt2_h[31:23]} ^ {tt2_h[14:0],tt2_h[31:15]}; //E = P0(TT2_1)
    wire    [31:0] next_F = tt2_l ^ {tt2_l[22:0],tt2_l[31:23]} ^ {tt2_l[14:0],tt2_l[31:15]}; //F = P0(TT2_0)
    wire    [31:0] A_middle = tt1_l;
    wire    [31:0] E_middle = next_F;
    
    //FF&GG func
    assign FF1_ABC = A ^ B ^ C;  
    assign FF2_ABC = (A & B) | (A & C) | (B & C);
    assign GG1_EFG = E ^ F ^ G;
    assign GG2_EFG = (E & F) | (~E & G);
    
    assign FFj_ABC = (round < 'd12) ? FF1_ABC : FF2_ABC;
    assign GGj_EFG = (round < 'd12) ? GG1_EFG : GG2_EFG;

    wire    [31:0] FF1_ABC_h = A_middle ^ A ^ {B[22:0],B[31:23]};  //FF(A_middle,A,(B<<<9))
    wire    [31:0] FF2_ABC_h = (A_middle & A) | (A_middle & {B[22:0],B[31:23]}) | (A & {B[22:0],B[31:23]});
    wire    [31:0] GG1_EFG_h = E_middle ^ E ^ {F[12:0],F[31:13]};   //GG(E_middle,E,(F<<<19))
    wire    [31:0] GG2_EFG_h = (E_middle & E) | (~E_middle & {F[12:0],F[31:13]});
    wire    [31:0] FFj_ABC_h = (round < 'd12) ? FF1_ABC_h : FF2_ABC_h;
    wire    [31:0] GGj_EFG_h = (round < 'd12) ? GG1_EFG_h : GG2_EFG_h;


    //Tj
    wire    [31:0] next_Tj_h = {Tj_h[29:0],Tj_h[31:30]};   //循环左移2位
    wire    [31:0] next_Tj_l = {Tj_l[29:0],Tj_l[31:30]};
    wire    [31:0] Tj_h_init_0 = {SM3_T0[30:0],SM3_T0[31]};
    wire    [31:0] Tj_h_init_1 = {SM3_T1[30:0],SM3_T1[31]};
    
    //SS1 SS2
    
    wire    [31:0]  ss1_l_tmp = {A[19:0],A[31:20]} + E + Tj_l;
    wire    [31:0]  ss1_l = {ss1_l_tmp[24:0],ss1_l_tmp[31:25]}; //SS1_0 = ((A<<<12) + E + Temp_0) <<< 7
    wire    [31:0]  ss2_l = ss1_l ^ {A[19:0],A[31:20]}; //SS2_0 = SS1_0 ^ (A <<< 12)

    wire    [31:0]  ss1_h_tmp = {A_middle[19:0],A_middle[31:20]} + E_middle + Tj_h;

    
    wire    [31:0]  ss1_h = {ss1_h_tmp[24:0],ss1_h_tmp[31:25]};//SS1_1 = ((A_m<<<12) + E_m + Temp_1) <<< 7 
    wire    [31:0]  ss2_h = ss1_h ^ {A_middle[19:0],A_middle[31:20]};//SS2_1 = SS1_1 ^ (A_m <<< 12)


    //TT1 TT2
    wire    [31:0]  tt1_l = FFj_ABC + D + ss2_l + Wj2_low; //TT1_0 = FFj(A,B,C) + D + SS2_0 + Wj'(2j)
    wire    [31:0]  tt2_l = GGj_EFG + H + ss1_l + Wj1_low; //TT2_0 = GGj(A,B,C) + H + SS1_0 + Wj(2j)
    wire    [31:0]  tt1_h = FFj_ABC_h + C + ss2_h + Wj2_high; //TT1_1 = FFj(A,B,C) + C + SS2_1 + Wj'(2j+1)
    wire    [31:0]  tt2_h = GGj_EFG_h + G + ss1_h + Wj1_high; //TT2_1 = GGj(A,B,C) + G + SS1_1 + Wj(2j+1)

    //loop 生成W16 W20 用于计算 wj16 wj'16
    wire    [31:0]  wj16_tmp = W0 ^ W7 ^ {W13[16:0],W13[31:17]};
    wire    [31:0]  wj16     = {wj16_tmp ^ {wj16_tmp[16:0],wj16_tmp[31:17]} ^ {wj16_tmp[8:0],wj16_tmp[31:9]}} ^ {W3[24:0],W3[31:25]} ^ W10;
    wire    [31:0]  wj20_tmp = W4 ^ W11 ^ {W17[16:0],W17[31:17]};
    wire    [31:0]  wj20     = {wj20_tmp ^ {wj20_tmp[16:0],wj20_tmp[31:17]} ^ {wj20_tmp[8:0],wj20_tmp[31:9]}} ^ {W7[24:0],W7[31:25]} ^ W14;
    wire    [31:0]  wjj16    = wj16 ^ wj20;
    //loop 生成W17 W21 用于计算 wj17 wj'17
    wire    [31:0]  wj17_tmp = W1 ^ W8 ^ {W14[16:0],W14[31:17]};
    wire    [31:0]  wj17     = {wj17_tmp ^ {wj17_tmp[16:0],wj17_tmp[31:17]} ^ {wj17_tmp[8:0],wj17_tmp[31:9]}} ^ {W4[24:0],W4[31:25]} ^ W11;
    wire    [31:0]  wj21_tmp = W5 ^ W12 ^ {W18[16:0],W18[31:17]};
    wire    [31:0]  wj21     = {wj21_tmp ^ {wj21_tmp[16:0],wj21_tmp[31:17]} ^ {wj21_tmp[8:0],wj21_tmp[31:9]}} ^ {W8[24:0],W8[31:25]} ^ W15;
    wire    [31:0]  wjj17    = wj17 ^ wj21;
    
    //临时变量区
    wire    [31:0]  w16_tmp = W0 ^ W7 ^ {W13[16:0],W13[31:17]}; 
    wire    [31:0]  w17_tmp = W1 ^ W8 ^ {W14[16:0],W14[31:17]};
    wire    [31:0]  w19_tmp = W3 ^ W10 ^ {W16[16:0],W16[31:17]};

    assign dout = {A,B,C,D,E,F,G,H};
    
    assign round_plus_1 = round + 1;


    //main loop
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            W0      <= 'b0;
            W1      <= 'b0;
            W2      <= 'b0;
            W3      <= 'b0;
            W4      <= 'b0;
            W5      <= 'b0;
            W6      <= 'b0;
            W7      <= 'b0;
            W8      <= 'b0;
            W9      <= 'b0;
            W10     <= 'b0;
            W11     <= 'b0;
            W12     <= 'b0;
            W13     <= 'b0;
            W14     <= 'b0;
            W15     <= 'b0;
            W16     <= 'b0;
            W17     <= 'b0;
            W18     <= 'b0;
            W19     <= 'b0;
            W20     <= 'b0;
            Wt      <= 'b0;
            wtmp_h  <= 'b0;
            wtmp_l  <= 'b0;
            A       <= 'b0;
            B       <= 'b0;
            C       <= 'b0;
            D       <= 'b0;
            E       <= 'b0;
            F       <= 'b0;
            G       <= 'b0;
            H       <= 'b0;
            H0      <= 'b0;
            H1      <= 'b0;
            H2      <= 'b0;
            H3      <= 'b0;
            H4      <= 'b0;
            H5      <= 'b0;
            H6      <= 'b0;
            H7      <= 'b0;
            Wj1_low <=  'b0;
            Wj2_low <=  'b0;
            Wj1_high<=  'b0;
            Wj2_high<=  'b0;
            Tj_h    <=  'b0;
            Tj_l    <=  'b0;
            round   <=  'b0;
        end
        else begin
            case (round)
                'd0:begin
                    if(input_valid_i) begin //在有输入的情况下开始运算，目前只在第一个输入时判断，默认输入是连续的
                        {W0,W1} <=  din;
                        if(input_block_index_i == 64'd0) begin //当输入的是第一个块时，加载初始值
                            A <=    SM3_H0;
                            B <=    SM3_H1;
                            C <=    SM3_H2;
                            D <=    SM3_H3;
                            E <=    SM3_H4;
                            F <=    SM3_H5;
                            G <=    SM3_H6;
                            H <=    SM3_H7;

                            H0 <=   SM3_H0;
                            H1 <=   SM3_H1;
                            H2 <=   SM3_H2;
                            H3 <=   SM3_H3;
                            H4 <=   SM3_H4;
                            H5 <=   SM3_H5;
                            H6 <=   SM3_H6;
                            H7 <=   SM3_H7;
                        end else begin
                            H0 <=   A;
							H1 <=   B;
							H2 <=   C;
							H3 <=   D;
							H4 <=   E;
							H5 <=   F;
							H6 <=   G;
							H7 <=   H;
                        end
                        round <= round_plus_1;
                    end
                end 
                'd1:
                    begin
                        {W2,W3} <=  din;
                        round <= round_plus_1;
                    end
                'd2:
                    begin
                        {W4,W5} <=  din;
                        round <= round_plus_1; //前3个节拍 纯输入 输入 6 个字
                    end
                //输入W6 - W7 输出 wj0-wj1 共 1 个周期  tj_h tj_l 取 round 小于 15 的初始值------------------------------------------------
                'd3:begin
                    {W6,W7} <=  din;
                    Wj1_low <=  W0;
                    Wj1_high<=  W1;
                    Wj2_low <=  W0 ^ W4;    //开始输出 wj'
                    Wj2_high<=  W1 ^ W5;
                    
                    Tj_l    <=  SM3_T0;          // 移位
                    Tj_h    <=  Tj_h_init_0;


                    round <= round_plus_1;
                    end
                //输入W8 - W15 输出 wj2-wj9 共 4 个周期  tj_h tj_l  移位------------------------------------------------
                'd4:begin
                    {W8,W9} <=  din;
                    Wj1_low <=  W2;
                    Wj1_high<=  W3;
                    Wj2_low <=  W2 ^ W6;    // wj'2
                    Wj2_high<=  W3 ^ W7;
                    
                    Tj_l    <=  next_Tj_l;     // 移位
                    Tj_h    <=  next_Tj_h;

                    A <= tt1_h;     //A = TT1_1
			        B <= tt1_l;     //B = TT1_0
			        C <= next_C;
			        D <= next_D;
			        E <= next_E;
			        F <= next_F;
			        G <= next_G;
			        H <= next_H;
                    round <= round_plus_1;
                end
                'd5:begin
                	{W10,W11}	<=	din;
                	Wj1_low 	<=	W4;
                	Wj1_high	<=	W5;
                	Wj2_low 	<=	W4 ^ W8; //wj'4
                	Wj2_high	<=	W5 ^ W9;
                	Tj_l	<=	next_Tj_l;  
                	Tj_h	<=	next_Tj_h;
                	A <= tt1_h; 
                	B <= tt1_l; 
                	C <= next_C;
                	D <= next_D;
                	E <= next_E;
                	F <= next_F;
                	G <= next_G;
                	H <= next_H;
                	round <= round_plus_1;
                end
                'd6:begin
                	{W12,W13}	<=	din;
                	Wj1_low 	<=	W6;
                	Wj1_high	<=	W7;
                	Wj2_low 	<=	W6 ^ W10; //wj'6
                	Wj2_high	<=	W7 ^ W11;
                	Tj_l	<=	next_Tj_l;
                	Tj_h	<=	next_Tj_h;
                	A <= tt1_h; 
                	B <= tt1_l; 
                	C <= next_C;
                	D <= next_D;
                	E <= next_E;
                	F <= next_F;
                	G <= next_G;
                	H <= next_H;
                	round <= round_plus_1;
                end
                'd7:begin
                	{W14,W15}	<=	din;
                	Wj1_low 	<=	W8;
                	Wj1_high	<=	W9;
                	Wj2_low 	<=	W8 ^ W12; //wj'8
                	Wj2_high	<=	W9 ^ W13;

                    //w16 生成中间变量
                    //wtmp_l      <=  W0 ^ W7 ^ {W13[16:0],W13[31:17]}; 

                	Tj_l	<=	next_Tj_l;
                	Tj_h	<=	next_Tj_h;
                	A <= tt1_h; 
                	B <= tt1_l; 
                	C <= next_C;
                	D <= next_D;
                	E <= next_E;
                	F <= next_F;
                	G <= next_G;
                	H <= next_H;
                	round <= round_plus_1;
                end
                // 'd8:begin
                //     //提前准备 wtmp_h wtmp_l 作为下一个周期生成 W16 W17 的中间变量
                //     //W16 <= {wtmp_l ^ {wtmp_l[16:0],wtmp_l[31:17]} ^ {wtmp_l[8:0],wtmp_l[31:9]}} ^ {W3[24:0],W3[31:25]} ^ W10;
                    
                //     //w17中间变量
                //     //wtmp_h      <=  W1 ^ W8 ^ {W14[16:0],W14[31:17]};
                //     round <= round_plus_1;
                // end


                //外部输入完毕  输出 wj10-wj15 共 3 个周期  wj 输出方式不变，但 wj' 的生成方式改变,使用公式生成 W16-W19 tj_h tj_l  移位------------------------------------------------
                'd8:begin
                	Wj1_low 	<=	W10;
                	Wj1_high	<=	W11;
                	Wj2_low 	<=	W10 ^ W14; //wj'10
                	Wj2_high	<=	W11 ^ W15;

                    W16 <= {w16_tmp ^ {w16_tmp[16:0],w16_tmp[31:17]} ^ {w16_tmp[8:0],w16_tmp[31:9]}} ^ {W3[24:0],W3[31:25]} ^ W10;
                    W17 <= {w17_tmp ^ {w17_tmp[16:0],w17_tmp[31:17]} ^ {w17_tmp[8:0],w17_tmp[31:9]}} ^ {W4[24:0],W4[31:25]} ^ W11;
                    
                    //继续准备计算 W18 W19 的中间变量
                    wtmp_l      <=  W2 ^ W9 ^ {W15[16:0],W15[31:17]};
                    //wtmp_h      <=  W3 ^ W10 ^ {W16[16:0],W16[31:17]};

                	Tj_l	<=	next_Tj_l;
                	Tj_h	<=	next_Tj_h;
                	A <= tt1_h; 
                	B <= tt1_l; 
                	C <= next_C;
                	D <= next_D;
                	E <= next_E;
                	F <= next_F;
                	G <= next_G;
                	H <= next_H;
                	round <= round_plus_1;
                end
                'd9:begin
                	Wj1_low 	<=	W12;
                	Wj1_high	<=	W13;
                	Wj2_low 	<=	W12 ^ W16; //wj'12
                	Wj2_high	<=	W13 ^ W17;
                    //准备W18 W19 
                    W18 <= {wtmp_l ^ {wtmp_l[16:0],wtmp_l[31:17]} ^ {wtmp_l[8:0],wtmp_l[31:9]}} ^ {W5[24:0],W5[31:25]} ^ W12;
                    W19 <= {w19_tmp ^ {w19_tmp[16:0],w19_tmp[31:17]} ^ {w19_tmp[8:0],w19_tmp[31:9]}} ^ {W6[24:0],W6[31:25]} ^ W13;
                    
                    // W20 的中间变量
                    wtmp_l      <=  W4 ^ W11 ^ {W17[16:0],W17[31:17]};
                    //wtmp_h      <=  W4 ^ W11 ^ {W17[16:0],W17[31:17]};

                	Tj_l	<=	next_Tj_l;
                	Tj_h	<=	next_Tj_h;
                	A <= tt1_h; 
                	B <= tt1_l; 
                	C <= next_C;
                	D <= next_D;
                	E <= next_E;
                	F <= next_F;
                	G <= next_G;
                	H <= next_H;
                	round <= round_plus_1;
                end
                'd10:begin
                	Wj1_low 	<=	W14;
                	Wj1_high	<=	W15;
                	Wj2_low 	<=	W14 ^ W18; //wj'14
                	Wj2_high	<=	W15 ^ W19; //wj'15

                    //准备W20 后一个状态的移位要用
                    W20  <= {wtmp_l ^ {wtmp_l[16:0],wtmp_l[31:17]} ^ {wtmp_l[8:0],wtmp_l[31:9]}} ^ {W7[24:0],W7[31:25]} ^ W14;
                    
                    //todo 准备两个 wt 用于在后一个状态找那个生成 w21 w22 用于补充 W19 W20 
                    wtmp_l      <=  W5 ^ W12 ^ {W18[16:0],W18[31:17]};
                    wtmp_h      <=  W6 ^ W13 ^ {W19[16:0],W19[31:17]};

                	Tj_l	<=	next_Tj_l;
                	Tj_h	<=	next_Tj_h;
                	A <= tt1_h; 
                	B <= tt1_l; 
                	C <= next_C;
                	D <= next_D;
                	E <= next_E;
                	F <= next_F;
                	G <= next_G;
                	H <= next_H;
                	round <= round_plus_1;
                end
                //前16个 wj wj' 输出完毕 此前的11状态中填满了20个寄存器 W0-W19 此后的48个 wj 和 wj'依靠20个寄存器移位组合逻辑实现
                //首先用一个状态装载新的 Tj------------------------------------------------
                'd11:begin
                    Wj1_low 	<=	wj16; //wj16 
                	Wj1_high	<=	wj17; //wj17
                	Wj2_low 	<=	wjj16; //wj'16
                	Wj2_high	<=	wjj17; //wj'17

                    Tj_l	    <=	SM3_T1;
                    Tj_h	    <=	Tj_h_init_1; //读取新的 Tj

                    //寄存器移位2位 向W0-W18 补充新的寄存器值 W18 之前的寄存器 始终用来计算 W16 W17
                    W0  <= W2;
				    W1  <= W3;
				    W2  <= W4;
			        W3  <= W5;
				    W4  <= W6;
				    W5  <= W7;
				    W6  <= W8;
				    W7  <= W9;
				    W8  <= W10;
				    W9  <= W11;
				    W10 <= W12;
				    W11 <= W13;
				    W12 <= W14;
				    W13 <= W15;
				    W14 <= W16;
				    W15 <= W17;
				    W16 <= W18;
				    W17 <= W19;
				    W18 <= W20;//更新前19个寄存器组 在 wj 的外部迭代中使用

                    //构造w21 w22 用于补充进寄存器组
                    W19 <= {wtmp_l ^ {wtmp_l[16:0],wtmp_l[31:17]} ^ {wtmp_l[8:0],wtmp_l[31:9]}} ^ {W8[24:0],W8[31:25]} ^ W15;
                    W20 <= {wtmp_h ^ {wtmp_h[16:0],wtmp_h[31:17]} ^ {wtmp_h[8:0],wtmp_h[31:9]}} ^ {W9[24:0],W9[31:25]} ^ W16;

                    //准备用于构建 w23 w24
                    // wtmp_l      <=  W5 ^ W12 ^ {W18[16:0],W18[31:17]};
                    // wtmp_h      <=  W6 ^ W13 ^ {W19[16:0],W19[31:17]};
                    
                    A <= tt1_h; 
                	B <= tt1_l; 
                	C <= next_C;
                	D <= next_D;
                	E <= next_E;
                	F <= next_F;
                	G <= next_G;
                	H <= next_H;
                	round <= round_plus_1;
                end
                //余下的23个状态都通过寄存器移位生成------------------------------------------------
                'd12,
                'd13,//w18 w19
                'd14,//w20 w21
                'd15,
                'd16,
                'd17,
                'd18,
                'd19,
                'd20,
                'd21,
                'd22,
                'd23,
                'd24,
                'd25,
                'd26,
                'd27,
                'd28,
                'd29,
                'd30,
                'd31,
                'd32,
                'd33,
                'd34:
                //'d35:
                    begin
                        //在外部迭代 生成 wj 和 wjj
                        Wj1_low 	<=	wj16; 
                	    Wj1_high	<=	wj17; 
                	    Wj2_low 	<=	wjj16; 
                	    Wj2_high	<=	wjj17; 
    
                        Tj_l	<=	next_Tj_l;  //移位Tj
                	    Tj_h	<=	next_Tj_h;
    
                        //寄存器移位2位 向W0-W18 补充新的寄存器值 W18 之前的寄存器 始终用来计算 W16 W17
                        W0  <= W2;
				        W1  <= W3;
				        W2  <= W4;
			            W3  <= W5;
				        W4  <= W6;
				        W5  <= W7;
				        W6  <= W8;
				        W7  <= W9;
				        W8  <= W10;
				        W9  <= W11;
				        W10 <= W12;
				        W11 <= W13;
				        W12 <= W14;
				        W13 <= W15;
				        W14 <= W16;
				        W15 <= W17;
				        W16 <= W18;
				        W17 <= W19;
				        W18 <= W20;
    
                        //构造新的临时变量 用于补充进寄存器组
                        //todo 准备两个 wt 用于补充 W19 W20 转而使用组合逻辑生成
                        // wtmp_l      <=  W5 ^ W12 ^ {W18[16:0],W18[31:17]};
                        // wtmp_h      <=  W6 ^ W13 ^ {W19[16:0],W19[31:17]};

                        //构造新的W19 W20 用于补充进寄存器组 这里使用组合逻辑产生临时值 因为需要提前一拍
                        W19 <= {wtmp_l_w ^ {wtmp_l_w[16:0],wtmp_l_w[31:17]} ^ {wtmp_l_w[8:0],wtmp_l_w[31:9]}} ^ {W8[24:0],W8[31:25]} ^ W15;
                        W20 <= {wtmp_h_w ^ {wtmp_h_w[16:0],wtmp_h_w[31:17]} ^ {wtmp_h_w[8:0],wtmp_h_w[31:9]}} ^ {W9[24:0],W9[31:25]} ^ W16;    
                        A <= tt1_h; 
                	    B <= tt1_l; 
                	    C <= next_C;
                	    D <= next_D;
                	    E <= next_E;
                	    F <= next_F;
                	    G <= next_G;
                	    H <= next_H;
                	    round <= round_plus_1;
                    end
                'd35:
                    begin
                        //A等算完最后一个周期
                        A <= tt1_h ^ H0;
                        B <= tt1_l ^ H1;
                        C <= next_C ^ H2;
                        D <= next_D ^ H3;
                        E <= next_E ^ H4;
                        F <= next_F ^ H5;
                        G <= next_G ^ H6;
                        H <= next_H ^ H7;
                        round <= round_plus_1;
                    end
                'd36:
                    begin
                        round <= 'b0;
                    end
                default: 
                    begin
                        round <= 'b0;
                    end
            endcase
        end
    end

    assign  input_ready_o     =   round == 'b0;
    assign  output_valid_o    =   round == 'd36;

endmodule

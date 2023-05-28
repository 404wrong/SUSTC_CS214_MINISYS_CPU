`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/28 19:14:03
// Design Name: 
// Module Name: uart_tx
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
// 
//////////////////////////////////////////////////////////////////////////////////


module uart_tx(
	input 			sys_clk,	//50M系统时钟
	input	[7:0] 	uart_data,	//发送的8位置数据
	output reg 		uart_txd	//串口发送数据线

);
reg sys_rst_n=1,uart_tx_en=0;
parameter 	SYS_CLK_FRE=100_000_000;    //50M系统时钟 
parameter 	BPS=12_800;                 //波特率9600bps，可更改
localparam	BPS_CNT=SYS_CLK_FRE/BPS;   //传输一位数据所需要的时钟个数

reg	uart_tx_en_d0;			//寄存1拍
reg uart_tx_en_d1;			//寄存2拍
reg tx_flag;				//发送标志位
reg [7:0]  uart_data_reg,d1;	//发送数据寄存器
reg [15:0] clk_cnt;			//时钟计数器
reg [3:0]  tx_cnt;			//发送个数计数器
reg [2:0] cnt=0;
 
wire pos_uart_en_txd;		//使能信号的上升沿
//捕捉使能端的上升沿信号，用来标志输出开始传输
assign pos_uart_en_txd= uart_tx_en_d0 && (~uart_tx_en_d1);
//======================检测到信号改变开始===============
always @(posedge sys_clk)begin
    if (uart_data!=d1)begin cnt<=0;uart_tx_en<=1;end
    else if(cnt!=0) begin cnt<=cnt+1;end
    else begin uart_tx_en<=0;end
    d1<=uart_data;
end
//========================================================
always @(posedge sys_clk)begin
    begin
		uart_tx_en_d0<=uart_tx_en;
		uart_tx_en_d1<=uart_tx_en_d0;
	end	
end
//捕获到使能端的上升沿信号，拉高传输开始标志位，并在第9个数据（终止位）的传输过程正中（数据比较稳定）再将传输开始标志位拉低，标志传输结束
always @(posedge sys_clk)begin
    if(pos_uart_en_txd)begin
		uart_data_reg<=uart_data;
		tx_flag<=1'b1;
	end
	else if((tx_cnt==4'd9) && (clk_cnt==BPS_CNT/2))begin//在第9个数据（终止位）的传输过程正中（数据比较稳定）再将传输开始标志位拉低，标志传输结束
		tx_flag<=1'b0;
		uart_data_reg<=8'd0;
	end
	else begin
		uart_data_reg<=uart_data_reg;
		tx_flag<=tx_flag;	
	end
end
//时钟每计数一个BPS_CNT（传输一位数据所需要的时钟个数），即将数据计数器加1，并清零时钟计数器
always @(posedge sys_clk)begin
	if(tx_flag) begin
		if(clk_cnt<BPS_CNT-1)begin
			clk_cnt<=clk_cnt+1'b1;
			tx_cnt <=tx_cnt;
		end
		else begin
			clk_cnt<=16'd0;
			tx_cnt <=tx_cnt+1'b1;
		end
	end
	else begin
		clk_cnt<=16'd0;
		tx_cnt<=4'd0;
	end
end
//在每个数据的传输过程正中（数据比较稳定）将数据寄存器的数据赋值给数据线
always @(posedge sys_clk)begin
	if(tx_flag)
		case(tx_cnt)
			4'd0:	uart_txd<=1'b0;
			4'd1:	uart_txd<=uart_data_reg[0];
			4'd2:	uart_txd<=uart_data_reg[1];
			4'd3:	uart_txd<=uart_data_reg[2];
			4'd4:	uart_txd<=uart_data_reg[3];
			4'd5:	uart_txd<=uart_data_reg[4];
			4'd6:	uart_txd<=uart_data_reg[5];
			4'd7:	uart_txd<=uart_data_reg[6];
			4'd8:	uart_txd<=uart_data_reg[7];
			4'd9:	uart_txd<=1'b1;
			default:;
		endcase
	else 	
		uart_txd<=1'b1;
end
endmodule
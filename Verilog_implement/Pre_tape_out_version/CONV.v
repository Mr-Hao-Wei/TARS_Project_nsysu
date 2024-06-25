
`timescale 1ns/10ps

module  CONV(
	input 				clk,
	input 				reset,
	output reg 			busy,	
//	input 				ready,	
			
	// output reg [11:0]   iaddr,
	// input signed [19:0] idata,	
	
	output reg 			cwr,
	output reg [3:0] 	caddr_wr,
	output reg [4:0] 	cdata_wr,
	
	output reg 			crd,
	output reg [3:0] 	caddr_rd,
	input signed [4:0]  cdata_rd,
	
	output reg [2:0] 	csel
	);

//////////parameter//////////

//Kernel0
parameter Kernel0_0=5'b11101, Kernel0_1=5'b11111, Kernel0_2=5'b00010, Kernel0_3=5'b00011, Kernel0_4=5'b00001, 
		  Kernel0_5=5'b11101, Kernel0_6=5'b11110, Kernel0_7=5'b11101, Kernel0_8=5'b00011;
//Kernel1
parameter Kernel1_0=5'b00010, Kernel1_1=5'b11110, Kernel1_2=5'b00011, Kernel1_3=5'b00011, Kernel1_4=5'b00010, 
		  Kernel1_5=5'b11110, Kernel1_6=5'b00011, Kernel1_7=5'b00001, Kernel1_8=5'b00010;
//Bias
parameter Bias0=5'b00010, Bias1=5'b11111;

//FSM_State
parameter 
		State_Initial=4'd0,
		State_Conv=4'd1,
		State_MP=4'd2,
		State_Flat=4'd3,
		State_L0MEM=4'd4,
		State_L1MEM=4'd5,
		State_L2MEM=4'd6,
		State_Complete=4'd7;

//////////////////////////////

//////////wire & reg//////////

reg [3:0] cs,ns;
reg [3:0] pixel_count;	
reg [1:0] x,y;
reg kernel_switch_L0,mem_switch_L1,L0_finish,L1_finish,mem_switch_L2;
reg signed [4:0] cdata_rd_conv,cdata_rd_conv1,cdata_rd_conv2,Kernel,cdata_mp,L1_result;
reg signed [9:0] conv_mul,conv_acc;
reg [2:0] mp_count;

wire mul_comp0,mul_comp1,mul_comp2;
wire signed [9:0] conv_bias,mul_u0,mul_u1,mul_u2,mul_comp_result;
wire signed [4:0] conv_result,L0_result;

//////////////////////////////

/////////////FSM//////////////

always @(posedge clk or posedge reset) begin
	if(reset)
		cs<=4'd0;
	else
		cs<=ns;
end

always @(*) begin
	case(cs)
		State_Initial: ns<=(busy)?State_Conv:State_Initial;
		State_Conv: ns<=(pixel_count==4'd12)?State_L0MEM:State_Conv;
		State_MP: ns<=(mp_count==3'd6)?State_L1MEM:State_MP;
		State_Flat: ns<=State_L2MEM;
		State_L0MEM: ns<=(pixel_count==4'd0)?((L0_finish)?State_MP:State_Conv):(State_L0MEM);
		State_L1MEM: ns<=(mp_count==3'd0)?((L1_finish)?State_Flat:State_MP):(State_L1MEM);
		State_L2MEM: ns<=(x==2'd2 && y==2'd2 && mem_switch_L2==1'b0)?State_Complete:State_Flat;
		State_Complete: ns<=State_Complete;
		default: ns<=State_Initial;
	endcase
	
end

//////////////////////////////

///////Control signal/////////

always @(posedge clk or posedge reset) begin
	if(reset)
		busy<=1'b0;
	else if(cs==State_Initial)
		busy<=1'b1;
	else if(cs==State_Complete)
		busy<=1'b0;	
	else
		busy<=busy;
end

always @(*) begin
	case(cs)
		State_Initial: begin
			crd<=1'b1;
			cwr<=1'b0;
		end
		State_Conv: begin
			crd<=1'b1;
			cwr<=1'b0;		
		end
		State_MP: begin
			crd<=1'b1;
			cwr<=1'b0;			
		end
		State_Flat: begin
			crd<=1'b1;
			cwr<=1'b0;	
		end
		State_L0MEM: begin
			crd<=1'b0;
			cwr<=1'b1;		
		end
		State_L1MEM: begin
			crd<=1'b0;
			cwr<=1'b1;		
		end
		State_L2MEM: begin
			crd<=1'b0;
			cwr<=1'b1;		
		end
		State_Complete:	begin
			crd<=1'b0;
			cwr<=1'b0;		
		end
		default: begin
			crd<=1'b0;
			cwr<=1'b0;			
		end
	endcase
end

always @(*) begin
	case(cs)
		State_Initial: csel<=3'b000;
		State_Conv: csel<=3'b000;
		State_MP: csel<=(mem_switch_L1)?3'b010:3'b001;
		State_Flat: csel<=(mem_switch_L2)?3'b100:3'b011;
		State_L0MEM: csel<=(kernel_switch_L0)?((x==2'd0 && y==2'd0)?3'b001:3'b010):((x==2'd0 && y==2'd0)?3'b010:3'b001);
		State_L1MEM: csel<=(mem_switch_L1)?((x==2'd0 && y==2'd0)?3'b011:3'b100):((x==2'd0 && y==2'd0)?3'b100:3'b011);
		State_L2MEM: csel<=3'b101;
		State_Complete: csel<=3'b000;
		default: csel<=3'b000;
	endcase
	
end

always @(posedge clk or posedge reset) begin
	if(reset) begin
		x<=2'd0;
		y<=2'd0;
	end
	else if(ns==State_L0MEM) begin
		x<=x+1;
		y<=y+(x==2'd3);
	end
	else if(ns==State_L1MEM) begin
		x<=x+2;
		y<=y+(x==2'd2)+(x==2'd2);
	end
	else if(ns==State_L2MEM && mem_switch_L2==1'b1) begin
		x<=x+1;
		y<=y+(x==2'd1);		
	end
	else begin
		x<=x;
		y<=y;
	end
end

always @(posedge clk or posedge reset) begin
	if(reset)
		kernel_switch_L0<=1'b0;
	else if(x==2'd3 && y==2'd3 && ns==State_L0MEM)
		kernel_switch_L0<=~kernel_switch_L0;
	else
		kernel_switch_L0<=kernel_switch_L0;	
end

always @(posedge clk or posedge reset) begin
	if(reset)
		L0_finish<=1'b0;
	else if(x==2'd3 && y==2'd3 && ns==State_L0MEM && kernel_switch_L0==1'b1)
		L0_finish<=1'b1;
	else
		L0_finish<=1'b0;
end

always @(posedge clk or posedge reset) begin
	if(reset)
		mem_switch_L1<=1'b0;
	else if(x==2'd2 && y==2'd2 && ns==State_L1MEM)
		mem_switch_L1<=~mem_switch_L1;
	else
		mem_switch_L1<=mem_switch_L1;
end

always @(posedge clk or posedge reset) begin
	if(reset)
		L1_finish<=1'b0;
	else if(x==2'd2 && y==2'd2 && ns==State_L1MEM && mem_switch_L1==1'b1)
		L1_finish<=1'b1;
	else
		L1_finish<=1'b0;
end

always @(posedge clk or posedge reset) begin
	if(reset)
		mem_switch_L2<=1'b0;
	else if(ns==State_L2MEM)
		mem_switch_L2<=~mem_switch_L2;
	else
		mem_switch_L2<=mem_switch_L2;
end

//////////////////////////////

////////caddr_rd & cdata_rd/////////

always @(posedge clk or posedge reset) begin
	if(reset)
		caddr_rd<=4'd0;
	else if(ns==State_Conv) begin
		case(pixel_count)
			4'd0: caddr_rd<={y-2'd1,x-2'd1};
			4'd1: caddr_rd<={y-2'd1,x};
			4'd2: caddr_rd<={y-2'd1,x+2'd1};
			4'd3: caddr_rd<={y,x-2'd1};
			4'd4: caddr_rd<={y,x};
			4'd5: caddr_rd<={y,x+2'd1};
			4'd6: caddr_rd<={y+2'd1,x-2'd1};
			4'd7: caddr_rd<={y+2'd1,x};
			4'd8: caddr_rd<={y+2'd1,x+2'd1};
			default: caddr_rd<=4'd0;
		endcase
	end
	else if(ns==State_MP) begin
		case(mp_count)
			3'd0: caddr_rd<={y,x};
			3'd1: caddr_rd<={y,x+2'd1};
			3'd2: caddr_rd<={y+2'd1,x};
			3'd3: caddr_rd<={y+2'd1,x+2'd1};
			default: caddr_rd<=4'd0;
		endcase
	end
	else if(ns==State_Flat)
		caddr_rd<={2'b0,y[0],x[0]};
	else 
		caddr_rd<=4'd0;
end

always @(posedge clk or posedge reset) begin
	if(reset)
		cdata_rd_conv<=5'd0;
	else begin
		case (pixel_count)
			4'd1: cdata_rd_conv<=(x==2'd0 || y==2'd0)?5'd0:cdata_rd;
			4'd2: cdata_rd_conv<=(y==2'd0)?5'd0:cdata_rd;
			4'd3: cdata_rd_conv<=(x==2'd3 || y==2'd0)?5'd0:cdata_rd;
			4'd4: cdata_rd_conv<=(x==2'd0)?5'd0:cdata_rd;
			4'd5: cdata_rd_conv<=cdata_rd;
			4'd6: cdata_rd_conv<=(x==2'd3)?5'd0:cdata_rd;
			4'd7: cdata_rd_conv<=(x==2'd0 || y==2'd3)?5'd0:cdata_rd;
			4'd8: cdata_rd_conv<=(y==2'd3)?5'd0:cdata_rd;
			4'd9: cdata_rd_conv<=(x==2'd3 || y==2'd3)?5'd0:cdata_rd;
			default: cdata_rd_conv<=5'd0;
		endcase
	end
	
end

always @(posedge clk or posedge reset) begin
	if(reset)
		cdata_rd_conv1<=5'd0;
	else begin
		case (pixel_count)
			4'd1: cdata_rd_conv1<=(x==2'd0 || y==2'd0)?5'd0:cdata_rd;
			4'd2: cdata_rd_conv1<=(y==2'd0)?5'd0:cdata_rd;
			4'd3: cdata_rd_conv1<=(x==2'd3 || y==2'd0)?5'd0:cdata_rd;
			4'd4: cdata_rd_conv1<=(x==2'd0)?5'd0:cdata_rd;
			4'd5: cdata_rd_conv1<=cdata_rd;
			4'd6: cdata_rd_conv1<=(x==2'd3)?5'd0:cdata_rd;
			4'd7: cdata_rd_conv1<=(x==2'd0 || y==2'd3)?5'd0:cdata_rd;
			4'd8: cdata_rd_conv1<=(y==2'd3)?5'd0:cdata_rd;
			4'd9: cdata_rd_conv1<=(x==2'd3 || y==2'd3)?5'd0:cdata_rd;
			default: cdata_rd_conv1<=5'd0;
		endcase
	end
	
end

always @(posedge clk or posedge reset) begin
	if(reset)
		cdata_rd_conv2<=5'd0;
	else begin
		case (pixel_count)
			4'd1: cdata_rd_conv2<=(x==2'd0 || y==2'd0)?5'd0:cdata_rd;
			4'd2: cdata_rd_conv2<=(y==2'd0)?5'd0:cdata_rd;
			4'd3: cdata_rd_conv2<=(x==2'd3 || y==2'd0)?5'd0:cdata_rd;
			4'd4: cdata_rd_conv2<=(x==2'd0)?5'd0:cdata_rd;
			4'd5: cdata_rd_conv2<=cdata_rd;
			4'd6: cdata_rd_conv2<=(x==2'd3)?5'd0:cdata_rd;
			4'd7: cdata_rd_conv2<=(x==2'd0 || y==2'd3)?5'd0:cdata_rd;
			4'd8: cdata_rd_conv2<=(y==2'd3)?5'd0:cdata_rd;
			4'd9: cdata_rd_conv2<=(x==2'd3 || y==2'd3)?5'd0:cdata_rd;
			default: cdata_rd_conv2<=5'd0;
		endcase
	end
	
end

//////////////////////////////

/////////Convolution//////////

always @(posedge clk or posedge reset) begin
	if(reset)
		pixel_count<=4'd0;
	else if(ns==State_Conv)
		pixel_count<=pixel_count+1;
	else
		pixel_count<=4'd0;
end

always @(*) begin
	case(pixel_count)
		4'd2: Kernel<=(kernel_switch_L0)?Kernel1_0:Kernel0_0;
		4'd3: Kernel<=(kernel_switch_L0)?Kernel1_1:Kernel0_1;
		4'd4: Kernel<=(kernel_switch_L0)?Kernel1_2:Kernel0_2;
		4'd5: Kernel<=(kernel_switch_L0)?Kernel1_3:Kernel0_3;
		4'd6: Kernel<=(kernel_switch_L0)?Kernel1_4:Kernel0_4;
		4'd7: Kernel<=(kernel_switch_L0)?Kernel1_5:Kernel0_5;
		4'd8: Kernel<=(kernel_switch_L0)?Kernel1_6:Kernel0_6;
		4'd9: Kernel<=(kernel_switch_L0)?Kernel1_7:Kernel0_7;
		4'd10: Kernel<=(kernel_switch_L0)?Kernel1_8:Kernel0_8;
		default: Kernel<= 5'd0;
	endcase
end

assign mul_u0=Kernel*cdata_rd_conv;
assign mul_u1=Kernel*cdata_rd_conv1;
assign mul_u2=Kernel*cdata_rd_conv2;

assign mul_comp0=(mul_u0==mul_u1)?1'b1:1'b0;
assign mul_comp1=(mul_u0==mul_u2)?1'b1:1'b0;
assign mul_comp2=(mul_u1==mul_u2)?1'b1:1'b0;

assign mul_comp_result=(mul_comp0 && mul_comp1)?mul_u0:((mul_comp2)?mul_u1:mul_u0);

always @(posedge clk or posedge reset) begin
	if(reset)
		conv_mul<=10'd0;
	else if(cs==State_Conv) begin
		if(pixel_count>=4'd2)
			conv_mul<=mul_comp_result;
		else
			conv_mul<=10'd0;
	end
	else 
		conv_mul<=10'd0;
end

always @(posedge clk or posedge reset) begin
	if(reset)
		conv_acc<=10'd0;
	else if(cs==State_Conv) begin
		if(pixel_count>=4'd3)
			conv_acc<=conv_acc+conv_mul;
		else
			conv_acc<=10'd0;
	end
	else
		conv_acc<=10'd0;
end

assign conv_bias=(kernel_switch_L0)?(conv_acc+{2'b0,Bias1,3'b0}):(conv_acc+{2'b0,Bias0,3'b0});

assign conv_result=(conv_bias[2])?conv_bias[7:3]+1:conv_bias[7:3];

//////////////////////////////

/////////////ReLU/////////////

assign L0_result=(conv_result[4])?5'd0:conv_result;

//////////////////////////////

/////////Max-pooling//////////

always @(posedge clk or posedge reset) begin
	if(reset)
		mp_count<=3'd0;
	else if(ns==State_MP)
		mp_count<=mp_count+1;
	else
		mp_count<=3'd0;
end

always @(posedge clk or posedge reset) begin
	if(reset)
		L1_result<=5'd0;
	else if(cs==State_MP) begin
		if(mp_count==3'd2)
			L1_result<=cdata_mp;
		else 
			L1_result<=(cdata_mp>L1_result)?cdata_mp:L1_result;
	end
end

//////////////////////////////

////////caddr & cdata/////////

always @(posedge clk or posedge reset) begin
	if(reset)
		caddr_wr<=4'd0;
	else begin
		case(ns)
			State_L0MEM: caddr_wr<={y,x};
			State_L1MEM: caddr_wr<={2'b0,y[1],x[1]};
			State_L2MEM: caddr_wr<=(mem_switch_L2)?{y,x[0],1'b0}+1'b1:{y,x[0],1'b0};
			default: caddr_wr<=4'd0;
		endcase
	end	
end

always @(posedge clk or posedge reset) begin
	if(reset)
		cdata_wr<=5'd0;
	else begin
		case(ns)
			State_L0MEM: cdata_wr<=L0_result;
			State_L1MEM: cdata_wr<=L1_result;
			State_L2MEM: cdata_wr<=cdata_rd;
			default: cdata_wr<=5'd0;
		endcase
	end	
end

always @(posedge clk or posedge reset) begin
	if(reset)
		cdata_mp<=5'd0;
	else if(ns==State_MP)
		cdata_mp<=cdata_rd;
	else 
		cdata_mp<=5'd0;
end

//////////////////////////////





endmodule





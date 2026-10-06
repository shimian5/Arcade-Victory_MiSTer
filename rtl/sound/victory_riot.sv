// SPDX-License-Identifier: GPL-3.0-or-later
// MOS6532 I/O/timer; its 128-byte RAM is in the sound-board RAM bank.
// Register mirrors and interrupt clearing follow MAME's mos6530.cpp.
module victory_riot (
	input  wire       clk, reset, ce,
	input  wire       rd, wr,
	input  wire [4:0] addr,
	input  wire [7:0] data, pa_in, pb_in,
	output wire [7:0] q, pa_out, pb_out,
	output wire      irq_n
);
reg [7:0] ora,orb,ddra,ddrb,timer;
reg [9:0] divider,remaining;
reg timer_running,underflow,timer_irq,timer_ie,edge_irq,edge_ie,edge_positive,pa7_d;
wire [7:0] pa=(ora&ddra)|(pa_in&~ddra);
wire [7:0] pb=(orb&ddrb)|(pb_in&~ddrb);
assign pa_out=ora | ~ddra;
assign pb_out=orb | ~ddrb;
assign irq_n= !((timer_irq && timer_ie) || (edge_irq && edge_ie));
assign q=!addr[2] ? (addr[1:0]==0 ? pa : addr[1:0]==1 ? ddra : addr[1:0]==2 ? pb : ddrb) :
	addr[0] ? {timer_irq,edge_irq,6'd0} : timer;
always @(posedge clk) begin
	if(reset) begin
		ora<=0; orb<=0; ddra<=0; ddrb<=0; timer<=0; divider<=0; remaining<=0;
		timer_running<=0; underflow<=0; timer_irq<=0; timer_ie<=0;
		edge_irq<=0; edge_ie<=0; edge_positive<=0; pa7_d<=0;
	end else if(ce) begin
		pa7_d<=pa[7];
		if(pa[7]!=pa7_d && pa[7]==edge_positive) edge_irq<=1;
		if(timer_running) begin
			if(remaining!=0) remaining<=remaining-10'd1;
			else begin
				timer<=timer-8'd1;
				remaining<=underflow ? 10'd0 : divider;
				if(timer==0) begin underflow<=1; timer_irq<=1; remaining<=0; end
			end
		end
		if(rd && addr[2]) begin
			if(addr[0]) edge_irq<=0;
			else begin
				timer_ie<=addr[3];
				// A read coincident with expiry must not discard the new IRQ.
				if(!(timer_running && timer==0 && remaining==0)) timer_irq<=0;
				if(underflow) begin underflow<=0; remaining<=divider; end
			end
		end
		if(wr) begin
			if(!addr[2]) case(addr[1:0])
				0: ora<=data;
				1: ddra<=data;
				2: orb<=data;
				3: ddrb<=data;
			endcase
			else if(addr[4]) begin
				case(addr[1:0])
					0: begin divider<=0; remaining<=0; end
					1: begin divider<=7; remaining<=7; end
					2: begin divider<=63; remaining<=63; end
					3: begin divider<=1023; remaining<=1023; end
				endcase
				timer<=data; timer_running<=1; underflow<=0; timer_irq<=0; timer_ie<=addr[3];
			end else begin edge_positive<=addr[0]; edge_ie<=addr[1]; end
		end
	end
end
endmodule

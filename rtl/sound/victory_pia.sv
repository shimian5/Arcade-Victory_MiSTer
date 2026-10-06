// SPDX-License-Identifier: GPL-3.0-or-later
// MC6821 command/response ports with CA2/CB2 handshakes.
module victory_pia (
	input  wire       clk, reset, paused,
	input  wire       rd, wr,
	input  wire [1:0] addr,
	input  wire [7:0] data, pa_in, pb_in,
	input  wire       ca1, cb1,
	output wire [7:0] q, pb_out,
	output wire      ca2, cb2, irq_a
);
reg [7:0] ora,orb,ddra,ddrb;
reg [5:0] cra,crb;
reg flag_a,flag_b,ca1_d,cb1_d,handshake_a,handshake_b;
reg pulse_a,pulse_b;
wire a_read=rd && addr==0 && cra[2];
wire b_read=rd && addr==2 && crb[2];
wire b_write=wr && addr==2 && crb[2];
assign q=addr==0 ? (cra[2] ? ((ora&ddra)|(pa_in&~ddra)) : ddra) :
	addr==1 ? {flag_a,1'b0,cra} : addr==2 ? (crb[2] ? ((orb&ddrb)|(pb_in&~ddrb)) : ddrb) : {flag_b,1'b0,crb};
assign pb_out=orb;
assign irq_a=flag_a && cra[0];
// 100: handshake; 101: one-cycle pulse; 110/111: forced low/high.
assign ca2=!cra[5] ? 1'b1 : cra[4] ? cra[3] : cra[3] ? !pulse_a : handshake_a;
assign cb2=!crb[5] ? 1'b1 : crb[4] ? crb[3] : crb[3] ? !pulse_b : handshake_b;
always @(posedge clk) begin
	if(reset) begin
		ora<=0; orb<=0; ddra<=0; ddrb<=0; cra<=0; crb<=0;
		flag_a<=0; flag_b<=0; ca1_d<=1; cb1_d<=1;
		handshake_a<=1; handshake_b<=1; pulse_a<=0; pulse_b<=0;
	end else if(!paused) begin
		ca1_d<=ca1; cb1_d<=cb1; pulse_a<=0; pulse_b<=0;
		if(ca1!=ca1_d && ca1==cra[1]) begin flag_a<=1; handshake_a<=1; end
		if(cb1!=cb1_d && cb1==crb[1]) begin flag_b<=1; handshake_b<=1; end
		if(a_read) begin flag_a<=0; handshake_a<=0; pulse_a<=1; end
		if(b_read) flag_b<=0;
		if(b_write) begin handshake_b<=0; pulse_b<=1; end
		if(wr) case(addr)
			0: if(cra[2]) ora<=data; else ddra<=data;
			1: cra<=data[5:0];
			2: if(crb[2]) orb<=data; else ddrb<=data;
			3: crb<=data[5:0];
		endcase
	end
end
endmodule

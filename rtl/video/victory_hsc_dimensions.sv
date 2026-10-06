// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 11: LS161 counters 3H/4H/5H, NAND 8H and inverters 9H.
// All three counters share raw SEQ CLK. LTC and HTC are the high
// counter bits, not the chips' terminal-carry outputs.
module victory_hsc_dimensions (
	input  wire       clk, reset, paused, seq_clk,
	input  wire       load_lh_n, increment_l_n, increment_h_n,
	input  wire [7:0] source_red,
	output reg  [7:0] length,
	output reg  [3:0] height,
	output wire       ltc, htc
);
reg seq_previous;
// 9H/8H: /LOAD L = INCH & SLOADLH, ENP L = !INCL.
// /LOAD H = SLOADLH, ENP H = !INCH. PUP holds ENT high
// except the low-to-high length-counter carry chain.
wire load_l_n = increment_h_n && load_lh_n;
assign ltc = length[7];
assign htc = height[3];
always @(posedge clk) begin
	if(reset) begin
		seq_previous <= seq_clk;
		length <= 0;
		height <= 0;
	end else if(!paused) begin
		seq_previous <= seq_clk;
		if(seq_clk && !seq_previous) begin
			// L's bit 0 and bit 7 load zero, bit 6 loads +5. H's
			// bit 3 loads zero. The remaining inputs are RSB0..7.
			if(!load_l_n) length <= {2'b01,source_red[4:0],1'b0};
			else if(!increment_l_n) length <= length+8'd1;
			if(!load_lh_n) height <= {1'b0,source_red[7:5]};
			else if(!increment_h_n) height <= height+4'd1;
		end
	end
end
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// HSC 77-0004-01 sheets 9/10: 18B/18C accumulator gates, 14C/14D
// LS283 adders, 12H LS32, 15C/15D LS174 registers and 12E LS112.
module victory_hsc_accumulator (
	input  wire       clk, reset, paused, ce_master, seq_clk, write_ea,
	input  wire [7:0] controls_c, instruction_high,
	input  wire       i_terminal,
	output reg  [7:0] accumulator,
	output reg        carry, vector_finished,
	output wire       clear_n, accumulator_clock
);
reg clock_previous;
assign clear_n = !(controls_c[4] && write_ea);
assign accumulator_clock = !(controls_c[3] && !seq_clk);
// 15D Q/pin 10 returns the registered carry to 14C C0/pin 7.
// 12H ORs ADD128 into the upper adder's A4; it does not replace
// the whole accumulator with 128. Both are significant at a seed edge.
wire [8:0] sum = {1'b0,(accumulator | (controls_c[4] ? 8'h80 : 8'h00))} +
	{1'b0,instruction_high} + {8'd0,carry};
always @(posedge clk) begin
	if(reset) begin
		accumulator <= 0;
		carry <= 0;
		vector_finished <= 0;
		clock_previous <= accumulator_clock;
	end else if(!paused) begin
		clock_previous <= accumulator_clock;
		// 15C/15D /CLR overrides their gated positive clock.
		if(!clear_n) begin
			accumulator <= 0;
			carry <= 0;
		end else if(accumulator_clock && !clock_previous)
			{carry,accumulator} <= sum;
		// 12E pin 12 is K, not /CLR. J=ILTC, K=!ACC CLEAR.
		// CLK11 falling coincides with inverted CLK11's master edge.
		if(ce_master) case({i_terminal,!clear_n})
			2'b01: vector_finished <= 0;
			2'b10: vector_finished <= 1;
			2'b11: vector_finished <= !vector_finished;
			default: begin end
		endcase
	end
end
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 8: primary X (11B/13B LS169), sampled /LOAD (14A),
// Y-prime latch (10C), working X (12D/13D LS161) and Y (10B/8B LS169).
// Inputs are pin-level strobes from the sheet-9 coordinate control gates.
// X and 14A share inverted CLK11. Y shares raw SEQ CLK with the PC counters.
module victory_hsc_coordinates (
	input  wire       clk, reset, paused, ce_master, seq_clk,
	input  wire       load_x_n, load_y_n, transfer_x_n, transfer_y_n,
	input  wire       add_x_n, increment_x, increment_y_n, right, down,
	input  wire [7:0] red_bus, blue_bus,
	output reg  [7:0] x_prime, y_prime, x, y
);
reg x_load_sample_n, y_load_previous, seq_previous;
always @(posedge clk) begin
	if(reset) begin
		x_prime <= 0;
		y_prime <= 0;
		x <= 0;
		y <= 0;
		x_load_sample_n <= 1;
		y_load_previous <= load_y_n;
		seq_previous <= seq_clk;
	end else if(!paused) begin
		y_load_previous <= load_y_n;
		seq_previous <= seq_clk;
		if(load_y_n && !y_load_previous) y_prime <= blue_bus;
		if(ce_master) begin
			// 14A and both X banks see the same edge: the primary
			// counters use the previous sampled /LOAD, not its new D.
			x_load_sample_n <= load_x_n;
			if(!x_load_sample_n) x_prime <= red_bus;
			else if(!add_x_n) x_prime <= right ? x_prime+8'd1 : x_prime-8'd1;
			// Parallel transfer complements only the three alignment bits.
			if(!transfer_x_n) x <= {x_prime[7:3],~x_prime[2:0]};
			else if(increment_x) x <= x+8'd1;
		end
		if(seq_clk && !seq_previous) begin
			if(!transfer_y_n) y <= y_prime;
			else if(!increment_y_n) y <= down ? y+8'd1 : y-8'd1;
		end
	end
end
endmodule

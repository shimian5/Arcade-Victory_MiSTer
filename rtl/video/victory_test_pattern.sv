// SPDX-License-Identifier: GPL-3.0-or-later
// Calibration pattern until the Victory graphics processor is implemented.
module victory_test_pattern (
	input clk, input reset, input paused, input ce_frame,
	input [8:0] hpos, input [8:0] vpos, input [7:0] dial,
	output [7:0] r, output [7:0] g, output [7:0] b
);
	reg [7:0] motion = 0;
	always @(posedge clk) begin
		if (reset) motion <= 0;
		else if (ce_frame && !paused) motion <= motion + 1'b1;
	end
	wire active_area = hpos < 9'd256 && vpos < 9'd256;
	wire border = (hpos == 0 || hpos == 255 || vpos == 0 || vpos == 255);
	wire grid_line = hpos[4:0] == 0 || vpos[4:0] == 0;
	wire moving_box = (hpos[7:0] - motion < 8'd12) && (vpos >= 9'd96 && vpos < 9'd112);
	wire dial_mark = hpos[7:0] == dial && vpos >= 9'd224;
	wire white_pixel = border || moving_box || dial_mark;
	assign r = !active_area ? 8'd0 : white_pixel ? 8'hff : grid_line ? 8'h40 : {8{hpos[7]}};
	assign g = !active_area ? 8'd0 : white_pixel ? 8'hff : grid_line ? 8'h40 : {8{hpos[6]}};
	assign b = !active_area ? 8'd0 : white_pixel ? 8'hff : grid_line ? 8'h40 : {8{hpos[5]}};
endmodule

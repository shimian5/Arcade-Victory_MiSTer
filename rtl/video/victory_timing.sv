// SPDX-License-Identifier: GPL-3.0-or-later
// Provisional raster from MAME victory.h; sync porches await PCB confirmation.
module victory_timing (
	input clk, input ce_pix,
	output reg [8:0] hpos = 0, output reg [8:0] vpos = 0,
	output hs, output vs, output hb, output vb,
	output ce_frame
);
	assign hb = hpos >= 9'd256;
	assign vb = vpos >= 9'd256;
	// Active-low native HSync: CRT Adjust uses the trailing/rising edge as
	// its line origin, leaving the back porch available for the line buffer.
	assign hs = !(hpos >= 9'd272 && hpos < 9'd304);
	assign vs = vpos >= 9'd260 && vpos < 9'd264;
	assign ce_frame = ce_pix && hpos == 9'd335 && vpos == 9'd279;
	// Raster continues during reset and pause, preserving monitor sync.
	always @(posedge clk) if (ce_pix) begin
		if (hpos == 9'd335) begin
			hpos <= 0;
			vpos <= (vpos == 9'd279) ? 9'd0 : vpos + 1'b1;
		end else hpos <= hpos + 1'b1;
	end
endmodule

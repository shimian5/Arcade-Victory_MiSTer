// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 3: sync decoder, scroll loads and 13F blanking latches.
// SHBLK/SVBLK are the actual sheet-4 ROM/gate outputs, not inferred DE.
// Factory 15J is unpopulated; actual receiver bias remains provisional.
// Keep explicit inputs for component tests; see docs/15J_UNPOPULATED.md.
module victory_hsc_raster_control (
	input  wire       clk, reset, ce_e4_fall,
	input  wire [8:3] raw_e,
	input  wire [8:0] raw_l,
	input  wire       sel5060, shblk, svblk,
	input  wire [2:0] hsync_jumper,
	output wire       hsync_n, vsync_n, se256,
	output wire       horizontal_load_n, vertical_load_n,
	output wire       blanking,
	output reg        blank_q, background_blank_n
);
// raw_e[8] represents 15F Q9. The named SE256 net is /Q7, which
// also clocks the vertical chain on the end of horizontal blank.
assign se256 = !raw_e[8];
// 18H LS138: G1=Q9, /G2A=/G2B=ground, A/B/C=17F QA/QB/QC.
// The drawn jumper selects Y7/pin7; expose all eight physical choices.
assign hsync_n = !(raw_e[8] && raw_e[6:4] == hsync_jumper);
// 13J LS20: Q5 of vertical 15F, XOR(16F QB,!SEL5060),
// inverted 16F QA and 15H QD. The selector wire is not a +5 tie.
assign vsync_n = !(raw_l[8] && (raw_l[5] ^ !sel5060) && !raw_l[4] && raw_l[3]);
// 4J ties two inputs to SHBLK; the third is horizontal Q9.
// 14J NANDs SE256 and vertical Q5. These are active-low LS193 loads.
assign horizontal_load_n = !(shblk && raw_e[8]);
assign vertical_load_n = !(se256 && raw_l[8]);
// 14F AND8 takes horizontal /Q7 (SE256) and vertical /Q6 (/L256).
// Follow pin10's long downward wire to vertical 15F: it crosses SVBLK
// without connecting. This native window also selects command/display
// clock-PROM banks; using SVBLK leaves commands at display rate in VBlank.
// Its other AND6 supplies SHBLK&SVBLK.
// Both 13F CLK3/11 pins see inverted E4CLK, not either blanking net.
assign blanking = se256 && !raw_l[8];
always @(posedge clk) begin
	if(reset) begin
		blank_q <= 0;
		background_blank_n <= 1;
	end else if(ce_e4_fall) begin
		blank_q <= blanking;
		// Sheet 3 exports the second section's /Q8, not Q9.
		background_blank_n <= !(shblk && svblk);
	end
end
endmodule

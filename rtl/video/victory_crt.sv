// SPDX-License-Identifier: GPL-3.0-or-later
// Core-side integration of rmonic79's CRT Adjust.
// Uses the standard VGA/CE_PIXEL outputs without framework hooks.
module victory_crt #(
	// The video mixer supplies combined DE blanking; the separate true VBlank is
	// needed only by the size engine and may precede the hook's pixels.
	parameter COMBINED_BLANK = 0
) (
	input clk, input ce_pix, input ce_frame,
	input enabled, input scandoubler, input crt_15k,
	input signed [4:0] hsize, input signed [5:0] hposition,
	input signed [4:0] vshift,
	input [8:0] hpos,
	input [7:0] r_in, g_in, b_in,
	input hs_in, vs_in, hb_in, vb_in,
	output ce_out, output [7:0] r_out, g_out, b_out,
	output hs_out, vs_out, hb_out, vb_out
);
	reg crt_on = 0;
	reg signed [4:0] hsize_q = 0;
	reg signed [8:0] hposition_q = 0;
	reg signed [5:0] vshift_q = 0;
	// Change geometry only between frames. Disable immediately for scandoubling.
	always @(posedge clk) if (ce_frame) begin
		crt_on <= enabled;
		hsize_q <= hsize;
		hposition_q <= {{3{hposition[5]}}, hposition};
		vshift_q <= {vshift[4], vshift};
	end
	// Native CE must remain untouched at neutral geometry. The integer native
	// divider gives eight transport cycles per pixel, including Direct Video.
	// Position-only adjustments preserve integer pixel widths. The rolling
	// CRT raster never uses the variable-rate native H-Size engine.
	wire active = crt_on && !scandoubler && !crt_15k && hsize_q != 0;
	wire hs_ref;
	reg hs_ref_d = 0;
	always @(posedge clk) hs_ref_d <= hs_ref;
	wire hs_ref_rise = hs_ref && !hs_ref_d;

	// H-Size changes the read period in quarter transport-clock increments.
	wire signed [6:0] period_signed = 7'sd32 + 7'(hsize_q);
	wire [5:0] period_quarters = period_signed[5:0];
	reg [5:0] read_phase = 0;
	wire [6:0] read_sum = {1'b0, read_phase} + 7'd4;
	wire read_tick = read_sum >= {1'b0, period_quarters};
	always @(posedge clk) begin
		if (hs_ref_rise) read_phase <= 0;
		else read_phase <= read_tick ? 6'(read_sum - {1'b0, period_quarters}) : read_sum[5:0];
	end
	wire read_ce = active ? read_tick : ce_pix;
	wire [7:0] adjusted_r, adjusted_g, adjusted_b;
	wire adjusted_hs, adjusted_vs, adjusted_hb, adjusted_vb;
	// Victory's active region starts at pixel 0, so use the sync-shift mode.
	crt_adjust_sys #(.HTOTAL(336), .VTOTAL(280), .HPOS_MODE(0)) adjust (
		.clk(clk), .pxl_cen(ce_pix), .pxl2_cen(read_ce), .active(active),
		.hsize(hsize_q), .hoffset(hposition_q), .voffset(vshift_q),
		.r_in(r_in), .g_in(g_in), .b_in(b_in),
		.hs_in(hs_in), .vs_in(vs_in), .hb_in(hb_in | vb_in), .vb_in(vb_in),
		.r_out(adjusted_r), .g_out(adjusted_g), .b_out(adjusted_b),
		.hs_out(adjusted_hs), .vs_out(adjusted_vs), .hb_out(adjusted_hb), .vb_out(adjusted_vb),
		.hs_ref_out(hs_ref)
	);
	// Keep the OSD's left edge anchored to native active video, as upstream
	// recommends. The stretched right edge determines the width of DE.
	reg vblank_1l = 1;
	always @(posedge clk) if (ce_pix && hpos == 9'd335) vblank_1l <= vb_in;
	wire native_active = !(hb_in | vblank_1l);
	reg native_active_d = 0;
	reg adjusted_active_d = 0;
	always @(posedge clk) begin
		if (ce_pix) native_active_d <= native_active;
		if (read_ce) adjusted_active_d <= !adjusted_hb;
	end
	reg de_osd = 0;
	always @(posedge clk) begin
		if (!active || vblank_1l) de_osd <= 0;
		else if (native_active && !native_active_d) de_osd <= 1;
		else if (adjusted_active_d && adjusted_hb) de_osd <= 0;
	end
	wire [23:0] position_rgb;
	wire position_ce, position_hs, position_vs, position_hb, position_vb;
	victory_crt_position position_adjust (
		.clk(clk), .ce_pix(ce_pix), .enabled(enabled),
		.scandoubler(scandoubler), .crt_15k(crt_15k),
		.hposition(hposition), .vshift(vshift), .rgb_in({r_in,g_in,b_in}),
		.hs_in(hs_in), .vs_in(vs_in), .hb_in(hb_in),
		.vb_in(COMBINED_BLANK ? 1'b0 : vb_in),
		.rgb_out(position_rgb), .ce_out(position_ce),
		.hs_out(position_hs), .vs_out(position_vs),
		.hb_out(position_hb), .vb_out(position_vb)
	);
	assign ce_out = active ? read_ce : position_ce;
	assign {r_out,g_out,b_out} = active ? {adjusted_r,adjusted_g,adjusted_b} : position_rgb;
	assign hs_out = active ? adjusted_hs : position_hs;
	assign vs_out = active ? adjusted_vs : position_vs;
	assign hb_out = active ? !de_osd : position_hb;
	assign vb_out = active ? vblank_1l : position_vb;
endmodule

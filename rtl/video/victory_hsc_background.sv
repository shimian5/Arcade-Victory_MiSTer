// SPDX-License-Identifier: GPL-3.0-or-later
// Development sheet-5/6/16 background path. The supplied BIT/SE256,
// active-low scroll loads must be physical raster phases;
// replacing the provisional whole-core raster/CPU ports is separate work.
module victory_hsc_background (
	input  wire       clk, reset, paused,
	input  wire       bit_clock, e256, screen_invert,
	input  wire       horizontal_load_n, vertical_load_n,
	input  wire [7:0] scroll_x, scroll_y,
	input  wire [15:0] cpu_addr,
	input  wire [7:0] cpu_data,
	input  wire       cpu_rd_n, write_clock, background_n, lookahead_n, advance_n,
	input  wire [2:0] foreground,
	output wire [7:0] cpu_background_q, scrolled_e, scrolled_l,
	output wire [2:0] background_pixel,
	output wire [5:0] collision_vp,
	output wire [8:0] color_pins_n, digital_rgb
);
	wire serial_load_n;
wire [7:0] tile_q;
wire [23:0] pattern_rgb_q;
reg bit_clock_q;
always @(posedge clk) bit_clock_q <= bit_clock;
wire ce_bit = bit_clock && !bit_clock_q;
victory_hsc_scroll scroll (
	.clk(clk), .reset(reset), .bit_clock(bit_clock), .e256(e256),
	.screen_invert(screen_invert), .horizontal_load_n(horizontal_load_n),
	.vertical_load_n(vertical_load_n), .scroll_x(scroll_x), .scroll_y(scroll_y),
	.scrolled_e(scrolled_e), .scrolled_l(scrolled_l), .serial_load_n(serial_load_n),
	.horizontal_up(), .horizontal_down(), .vertical_up(), .vertical_down()
);
victory_hsc_background_ram ram (
	.clk(clk), .reset(reset), .paused(paused), .cpu_addr(cpu_addr), .cpu_data(cpu_data),
	.cpu_rd_n(cpu_rd_n), .write_clock(write_clock), .background_n(background_n), .advance_n(advance_n),
	.scrolled_e(scrolled_e), .scrolled_l(scrolled_l), .tile_q(tile_q),
	.cpu_q(cpu_background_q), .pattern_rgb_q(pattern_rgb_q)
);
victory_hsc_background_display display (
	.clk(clk), .reset(reset), .ce_bit(ce_bit), .serial_load_n(serial_load_n),
	.screen_invert(screen_invert), .pattern_rgb(pattern_rgb_q),
	.serial_mode(), .pixel_rgb(background_pixel), .shift_rgb()
);
victory_hsc_lookahead lookahead (
	.clk(clk), .reset(reset), .paused(paused), .bit_clock(bit_clock), .cpu_addr(cpu_addr),
	.cpu_data(cpu_data), .cpu_rd_n(cpu_rd_n), .write_clock(write_clock),
	.lookahead_n(lookahead_n), .advance_n(advance_n),
	.foreground(foreground), .background(background_pixel), .address_q(), .collision_vp(collision_vp),
	.raster_selected(), .write_window_n(), .color_pins_n(color_pins_n), .digital_rgb(digital_rgb)
);
endmodule

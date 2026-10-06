// SPDX-License-Identifier: GPL-3.0-or-later
// Sheets 3/4: E4CLK and SSR LOAD come from the clock-PROM/latch network.
// The factory-empty 15J receiver levels remain explicit inputs.
module victory_hsc_raster (
	input  wire        clk, reset, paused, e4clk, sr_load,
	input  wire        crystal_11289, sel5060,
	input  wire [2:0]  hsync_jumper,
	input  wire [7:0]  video_control, blanking_rom_data,
	input  wire        clear_virq_n,
	output wire [10:0] blanking_rom_address,
	output wire [8:3]  raw_e,
	output wire [8:0]  raw_l,
	output wire [7:3]  raster_e,
	output wire [7:0]  raster_l,
	output wire        hsync_n, vsync_n, se256,
	output wire        horizontal_load_n, vertical_load_n,
	output wire        blanking, blank_q, background_blank_n,
	output wire        ebirq, virq_n
);
reg e4clk_q;
always @(posedge clk) e4clk_q <= e4clk;
wire ce_e4_fall = e4clk_q && !e4clk;
wire shblk, svblk;
victory_hsc_raster_counters counters (
	.clk(clk), .reset(reset), .ce_e4_fall(ce_e4_fall),
	.crystal_11289(crystal_11289), .sel5060(sel5060), .screen_invert(video_control[3]),
	.raw_e(raw_e), .raw_l(raw_l), .raster_e(raster_e), .raster_l(raster_l),
	.horizontal_carry(), .vertical_carry(), .horizontal_preload(), .vertical_preload()
);
victory_hsc_blanking_control rom_control (
	.clk(clk), .reset(reset), .paused(paused), .raster_e(raster_e), .raster_l(raster_l),
	.video_control(video_control), .rom_data(blanking_rom_data), .sr_load(sr_load),
	.l256(raw_l[8]), .clear_virq_n(clear_virq_n), .rom_address(blanking_rom_address),
	.shblk(shblk), .svblk(svblk), .ebirq(ebirq), .virq_n(virq_n)
);
victory_hsc_raster_control control (
	.clk(clk), .reset(reset), .ce_e4_fall(ce_e4_fall), .raw_e(raw_e), .raw_l(raw_l),
	.sel5060(sel5060), .shblk(shblk), .svblk(svblk), .hsync_jumper(hsync_jumper),
	.hsync_n(hsync_n), .vsync_n(vsync_n), .se256(se256),
	.horizontal_load_n(horizontal_load_n), .vertical_load_n(vertical_load_n),
	.blanking(blanking), .blank_q(blank_q), .background_blank_n(background_blank_n)
);
endmodule

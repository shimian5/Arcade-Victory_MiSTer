// SPDX-License-Identifier: GPL-3.0-or-later
// Foreground test integration. CPU bus levels and downloaded
// PROMs drive the shared command/display RAM. ce_master comes from the video
// PLL bridge, while the packet renderer keeps HDMI transport uniform.
// This foreground fixture is retained for tests; victory_hsc_native
// integrates the production background, palette, WAIT and raster paths.
module victory_hsc (
	input  wire        clk, reset, paused, ce_master,
	input  wire [15:0] cpu_addr,
	input  wire [7:0]  cpu_data,
	input  wire        cpu_mreq_n, cpu_rd_n, cpu_wr_n,
	input  wire        download, ioctl_wr,
	input  wire [15:0] ioctl_index,
	input  wire [26:0] ioctl_addr,
	input  wire [7:0]  ioctl_data,
	input  wire [7:0]  scroll_x, scroll_y, video_control,
	output wire        busy, fg_hit, pause_active,
	output wire [7:0]  command, fg_x, fg_y,
	output wire [9:0]  tile_addr,
	input  wire [7:0]  tile_q,
	output wire [12:0] char_addr,
	input  wire [23:0] char_rgb_q,
	output wire [5:0]  palette_addr,
	input  wire [8:0]  palette_q,
	output wire        ce_packet, hs, vs, hb, vb, bg_hit,
	output wire [8:0]  hpos, vpos,
	output wire [7:0]  r, g, b, bg_x, bg_y
);
wire [7:0] cpu_prom_addr,register_load_n,status_read_n;
wire [3:0] cpu_q;
wire [4:0] clock_addr,state_addr,vector_addr;
wire [7:0] clock_q,prom_b,prom_c,prom_d,prom_e,vector_q,raster_e,raster_l;
wire blanking_n,ce_bit;
wire [2:0] foreground;
victory_hsc_proms proms (
	.clk(clk), .download(download), .wr(ioctl_wr), .index(ioctl_index), .addr(ioctl_addr), .data(ioctl_data),
	.cpu_addr(cpu_prom_addr), .clock_addr(clock_addr), .state_addr(state_addr), .vector_addr(vector_addr),
	.cpu_q(cpu_q), .clock_q(clock_q), .prom_b(prom_b), .prom_c(prom_c), .prom_d(prom_d), .prom_e(prom_e), .vector_q(vector_q)
);
victory_hsc_cpu_decode cpu_decoder (
	.cpu_addr(cpu_addr), .mreq_n(cpu_mreq_n), .rd_n(cpu_rd_n), .wr_n(cpu_wr_n),
	.prom_addr(cpu_prom_addr), .prom_q(cpu_q), .bus_select_n(), .lookahead_n(), .background_n(),
	.register_load_n(register_load_n), .status_read_n(status_read_n), .auxiliary_load_n()
);
victory_hsc_datapath datapath (
	.clk(clk), .reset(reset), .ce_master(ce_master), .blanking_n(blanking_n), .screen_invert(video_control[3]),
	.pause_request(paused), .pause_active(pause_active), .cpu_load_n(register_load_n), .cpu_data(cpu_data),
	.raster_e(raster_e), .raster_l(raster_l), .collision_clear_n(status_read_n[1]),
	.clock_addr(clock_addr), .state_addr(state_addr), .vector_address(vector_addr),
	.clock_q(clock_q), .prom_b(prom_b), .prom_c(prom_c), .prom_d(prom_d), .prom_e(prom_e), .vector_q(vector_q),
	.command(command), .ready_n(), .busy(busy), .collision_pending_n(), .collision_hit(fg_hit),
	.collision_x(fg_x), .collision_y(fg_y), .ce_bit(ce_bit), .e4clk(), .bit_clk(), .sr_load(), .pixel_rgb(foreground)
);
victory_hsc_renderer renderer (
	.clk(clk), .reset(reset), .paused(paused || pause_active), .ce_bit(ce_bit), .foreground(foreground),
	.scroll_x(scroll_x), .scroll_y(scroll_y), .video_control(video_control), .blanking_n(blanking_n),
	.raster_e(raster_e), .raster_l(raster_l), .tile_addr(tile_addr), .tile_q(tile_q),
	.char_addr(char_addr), .char_rgb_q(char_rgb_q), .palette_addr(palette_addr), .palette_q(palette_q),
	.ce_packet(ce_packet), .hs(hs), .vs(vs), .hb(hb), .vb(vb), .bg_hit(bg_hit),
	.hpos(hpos), .vpos(vpos), .r(r), .g(g), .b(b), .bg_x(bg_x), .bg_y(bg_y)
);
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// Production whole-HSC integration, Exidy 77-0004-01 sheets 2-16.
// Foreground, background, palette, scroll and CPU WAIT share the physical
// clock network. Factory-empty 15J receiver levels are explicit inputs.
// Native jumper configuration: 11.289 MHz crystal, SEL5060=1, HS=Y7.
// Native packets preserve physical blank/sync phase; nominal analog RGB
// and CPU BUSY filtering are documented in docs/HSC_ANALOG.md. Full-ROM
// acceptance does not establish empty-socket receiver bias or calibrate a PCB.
module victory_hsc_native (
	input  wire        clk, reset, paused, ce_master, cpu_phi,
	input  wire [15:0] cpu_addr,
	input  wire [7:0]  cpu_data,
	input  wire        cpu_mreq_n, cpu_iorq_n, cpu_rd_n, cpu_wr_n,
	input  wire        download, ioctl_wr,
	input  wire [15:0] ioctl_index,
	input  wire [26:0] ioctl_addr,
	input  wire [7:0]  ioctl_data,
	input  wire [7:0]  scroll_x, scroll_y, video_control,
	input  wire [7:0]  blanking_rom_data,
	output wire [10:0] blanking_rom_address,
	output wire [7:0]  cpu_background_q,
	output wire        cpu_wait_n, cpu_hold, pause_active, busy, fg_hit,
	output wire [7:0]  command, fg_x, fg_y,
	output wire        bg_hit, bg_pending_n,
	output wire        fg_pending_n, vblank_pending_n,
	output wire [7:0]  bg_x, bg_y,
	output reg         ce_packet, hs, vs, hb, vb,
	output reg  [8:0]  hpos, vpos,
	output reg  [7:0]  r, g, b
);
wire [7:0] cpu_prom_addr, register_load_n, status_read_n, auxiliary_load_n;
wire [3:0] cpu_q;
wire [4:0] clock_addr, state_addr, vector_addr;
wire [7:0] clock_q, prom_b, prom_c, prom_d, prom_e, vector_q;
wire background_n, lookahead_n, advance_n, hsc_wait_n, drawing_request;
wire blanking, e4clk, bit_clk, sr_load, ce_bit;
wire [8:3] raw_e;
wire [8:0] raw_l;
wire [7:3] raster_e;
wire [7:0] raster_l, scrolled_e, scrolled_l;
wire hsync_n, vsync_n, se256, horizontal_load_n, vertical_load_n;
wire [2:0] foreground, background_pixel;
wire [8:0] digital_rgb;
wire [8:0] color_pins_n;
wire [23:0] analog_rgb;
wire display_active, busy_raw;
wire [5:0] collision_vp;
wire raster_blank, ebirq;
reg [2:0] foreground_before_bit;
victory_hsc_proms proms (
	.clk(clk), .download(download), .wr(ioctl_wr), .index(ioctl_index), .addr(ioctl_addr), .data(ioctl_data),
	.cpu_addr(cpu_prom_addr), .clock_addr(clock_addr), .state_addr(state_addr), .vector_addr(vector_addr),
	.cpu_q(cpu_q), .clock_q(clock_q), .prom_b(prom_b), .prom_c(prom_c), .prom_d(prom_d), .prom_e(prom_e), .vector_q(vector_q)
);
victory_hsc_cpu_decode cpu_decoder (
	.cpu_addr(cpu_addr), .mreq_n(cpu_mreq_n), .rd_n(cpu_rd_n), .wr_n(cpu_wr_n),
	.prom_addr(cpu_prom_addr), .prom_q(cpu_q), .bus_select_n(), .lookahead_n(lookahead_n), .background_n(background_n),
	.register_load_n(register_load_n), .status_read_n(status_read_n), .auxiliary_load_n(auxiliary_load_n)
);
victory_hsc_pause_bus pause_bus (
	.clk(clk), .reset(reset), .request(paused), .cpu_phi(cpu_phi),
	.mreq_n(cpu_mreq_n), .iorq_n(cpu_iorq_n), .rd_n(cpu_rd_n), .wr_n(cpu_wr_n),
	.advance_n(advance_n), .drawing_paused(pause_active), .cpu_hold(cpu_hold), .drawing_request(drawing_request)
);
victory_hsc_cpu_wait hsc_wait (
	.clk(clk), .reset(reset), .paused(cpu_hold), .cpu_phi(cpu_phi),
	.raster_phase4(scrolled_e[2] ^ !video_control[3]),
	.background_n(background_n), .lookahead_n(lookahead_n), .wait_n(hsc_wait_n), .advance_n(advance_n)
);
victory_cpu_wait cpu_wait (
	.clk(clk), .reset(reset), .paused(cpu_hold), .cpu_phi(cpu_phi),
	.mreq_n(cpu_mreq_n), .hsc_wait_n(hsc_wait_n), .wait_n(cpu_wait_n)
);
victory_hsc_datapath datapath (
	.clk(clk), .reset(reset), .ce_master(ce_master), .blanking_n(blanking), .screen_invert(video_control[3]),
	.pause_request(drawing_request), .pause_active(pause_active), .cpu_load_n(register_load_n), .cpu_data(cpu_data),
	.raster_e({raster_e,3'd0}), .raster_l(raster_l), .collision_clear_n(status_read_n[1]),
	.clock_addr(clock_addr), .state_addr(state_addr), .vector_address(vector_addr),
	.clock_q(clock_q), .prom_b(prom_b), .prom_c(prom_c), .prom_d(prom_d), .prom_e(prom_e), .vector_q(vector_q),
	.command(command), .ready_n(), .busy(busy_raw), .collision_pending_n(fg_pending_n), .collision_hit(fg_hit),
	.collision_x(fg_x), .collision_y(fg_y), .ce_bit(ce_bit),
	.e4clk(e4clk), .bit_clk(bit_clk), .sr_load(sr_load), .pixel_rgb(foreground)
);
// The RC/LS241 path affects CPU status only; the sequencer still uses raw
// PROM BUSY and its own ready/control pins without an added command delay.
victory_hsc_busy_filter busy_filter (
	.clk(clk), .reset(reset), .busy_in(busy_raw), .busy_out(busy), .voltage_uv()
);
victory_hsc_raster raster (
	.clk(clk), .reset(reset), .paused(cpu_hold), .e4clk(e4clk), .sr_load(sr_load),
	.crystal_11289(1'b1), .sel5060(1'b1), .hsync_jumper(3'd7),
	.video_control(video_control), .blanking_rom_data(blanking_rom_data), .clear_virq_n(auxiliary_load_n[3]),
	.blanking_rom_address(blanking_rom_address), .raw_e(raw_e), .raw_l(raw_l), .raster_e(raster_e), .raster_l(raster_l),
	.hsync_n(hsync_n), .vsync_n(vsync_n), .se256(se256), .horizontal_load_n(horizontal_load_n),
	.vertical_load_n(vertical_load_n), .blanking(blanking), .blank_q(raster_blank), .background_blank_n(), .ebirq(ebirq), .virq_n(vblank_pending_n)
);
victory_hsc_background background (
	.clk(clk), .reset(reset), .paused(cpu_hold), .bit_clock(bit_clk), .e256(se256),
	.screen_invert(video_control[3]), .horizontal_load_n(horizontal_load_n), .vertical_load_n(vertical_load_n),
	.scroll_x(scroll_x), .scroll_y(scroll_y), .cpu_addr(cpu_addr), .cpu_data(cpu_data), .cpu_rd_n(cpu_rd_n),
	.write_clock(scrolled_e[1] ^ !video_control[3]), .background_n(background_n), .lookahead_n(lookahead_n),
	.advance_n(advance_n), .foreground(foreground_before_bit), .cpu_background_q(cpu_background_q),
	.scrolled_e(scrolled_e), .scrolled_l(scrolled_l), .background_pixel(background_pixel),
	.color_pins_n(color_pins_n), .digital_rgb(digital_rgb), .collision_vp(collision_vp)
);
// 14L shares BIT with 15L and samples the same pre-shift endpoints. Its
// return-to-zero capture clock drives coordinates independently of EBIRQ;
// 13H takes EBIRQ from 15J/12J and asynchronous SBACKY from the live bus.
victory_hsc_background_collision background_collision (
	.clk(clk), .reset(reset), .paused(cpu_hold), .bit_clock(bit_clk),
	.e4clk(e4clk), .blank(raster_blank), .vp(collision_vp),
	.bir12(video_control[2]), .ebirq(ebirq), .clear_n(status_read_n[3]),
	.raster_e(raster_e), .raster_l(raster_l), .all_q(), .only_q(),
	.e4clk_q(), .blank_q(display_active), .capture_clock(), .pending_n(bg_pending_n),
	.hit(bg_hit), .captured_x(bg_x), .captured_y(bg_y)
);
victory_hsc_rgb rgb_driver (
	.color_pins_n(color_pins_n), .display_active(display_active), .rgb(analog_rgb)
);
// Foreground LS299 advances on predicted BIT; background/15L recognize the
// actual generated edge one SYS later. Retain the old foreground endpoint
// so 15L samples both serializers from the same physical instant.
// Physical blank counters preload E=432 and L=488. Translate those raw
// states to monotonically tagged 336x280 packets without changing counters.
wire [8:0] raw_pixel = {raw_e,clock_addr[3:1]};
wire [8:0] counter_h = raw_e[8] ? raw_pixel-9'd176 : raw_pixel;
wire [8:0] counter_v = raw_l[8] ? raw_l-9'd232 : raw_l;
// 13F samples the preceding E count at E4 fall; 14L then samples on BIT.
// Thus the physical drive window is E=8..263, not E=0..255. Normalize
// the complete output stream by eight pixels, including the line carry.
// This preserves every physical display pixel and the original sync phase.
wire [8:0] packet_h = counter_h>=9'd8 ? counter_h-9'd8 : counter_h+9'd328;
wire [8:0] packet_v = counter_h>=9'd8 ? counter_v : (counter_v==0 ? 9'd279 : counter_v-9'd1);
reg [1:0] packet_phase;
reg [8:0] pixel_h, pixel_v;
reg pixel_hs, pixel_vs, pixel_hb, pixel_vb;
always @(posedge clk) begin
	ce_packet <= 0;
	if(reset) begin
		foreground_before_bit <= 0; packet_phase <= 0;
		pixel_h <= 0; pixel_v <= 0;
		pixel_hs <= 1; pixel_vs <= 0; pixel_hb <= 1; pixel_vb <= 1;
		hpos <= 0; vpos <= 0; hs <= 1; vs <= 0; hb <= 1; vb <= 1;
		r <= 0; g <= 0; b <= 0;
	end else if(ce_bit) begin
		foreground_before_bit <= foreground;
		pixel_h <= packet_h; pixel_v <= packet_v;
		pixel_hs <= hsync_n; pixel_vs <= !vsync_n;
		pixel_hb <= packet_h>=9'd256; pixel_vb <= packet_v>=9'd256;
		packet_phase <= 1;
	end else if(packet_phase!=0) begin
		if(packet_phase==2) begin
			hpos <= pixel_h; vpos <= pixel_v;
			hs <= pixel_hs; vs <= pixel_vs; hb <= pixel_hb; vb <= pixel_vb;
			{r,g,b} <= analog_rgb;
			ce_packet <= 1; packet_phase <= 0;
		end else packet_phase <= packet_phase+2'd1;
	end
end
endmodule

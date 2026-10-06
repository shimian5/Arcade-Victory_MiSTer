//============================================================================
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

module emu (
	`include "sys/emu_ports.vh"
);

assign ADC_BUS = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;
assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;
assign AUDIO_S = 1;
assign AUDIO_L = sound_audio;
assign AUDIO_R = sound_audio;
assign AUDIO_MIX = 0;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

`include "build_id.v"
localparam CONF_STR = {
	"Victory;;",
	"P1,Video Settings;",
	"P1O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[3:1],Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"P1-;",
	"D1P1O[102],Video Timing,CRT 15kHz,Native;",
	"D1P1O[101],CRT Adjust,Off,On;",
	"H2P1O[100:96],CRT H-Size,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H0P1O[85:80],CRT H-Position,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,+16,+17,+18,+19,+20,+21,+22,+23,+24,+25,+26,+27,+28,+29,+30,+31,-32,-31,-30,-29,-28,-27,-26,-25,-24,-23,-22,-21,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"H0P1O[78:74],CRT V-Shift,0,+1,+2,+3,+4,+5,+6,+7,+8,+9,+10,+11,+12,+13,+14,+15,-16,-15,-14,-13,-12,-11,-10,-9,-8,-7,-6,-5,-4,-3,-2,-1;",
	"-;",
	"O[4],Pause on OSD,On,Off;",
	"O[5],Dim after 10s,On,Off;",
	"-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	// MiSTer stops parsing OSD entries at the first button mapping.
	"J1,Thrust,Fire,Shields,Doomsday,Start 1,Start 2,Coin,Service,Pause,Coin 2;",
	"jn,A,B,X,Y,Start,Select,L,R,Pause,R3;",
	"v,2;",
	"V,v",`BUILD_DATE
};

wire clk_sys, clk_reference, pll_locked;
// Keep the instance name: sys/sys_top.sdc matches *|pll|pll_inst|... clocks.
victory_system_pll pll (.refclk(CLK_50M), .rst(1'b0), .outclk_0(clk_sys), .outclk_1(clk_reference), .locked(pll_locked));
wire clk_video, video_locked;
// Cascade the fixed native PLL from the system PLL's 96 MHz output.
// Only the system/output PLLs consume the external CLK_50M reference.
victory_video_pll video_pll (.refclk(clk_reference), .clk_video(clk_video), .locked(video_locked));
wire [127:0] status;
wire [1:0] buttons;
wire [10:0] ps2_key;
wire [31:0] joystick;
wire [15:0] analog_stick;
wire [8:0] spinner;
wire [24:0] mouse;
wire forced_scandoubler, direct_video;
wire [21:0] gamma_bus;
wire scandoubler = forced_scandoubler || (status[3:1] != 0);
wire ioctl_download, ioctl_wr;
wire [15:0] ioctl_index;
wire [26:0] ioctl_addr;
wire [7:0] ioctl_data;
wire ioctl_upload, ioctl_rd, nv_transfer, nv_save_request;
wire [7:0] nv_data;
hps_io #(.CONF_STR(CONF_STR)) host_io (
	.clk_sys(clk_sys), .HPS_BUS(HPS_BUS), .EXT_BUS(), .gamma_bus(gamma_bus),
	.buttons(buttons), .status(status),
	.status_menumask({13'd0, (!status[101] || scandoubler || !status[102] || direct_video), scandoubler, (!status[101] || scandoubler)}),
	.forced_scandoubler(forced_scandoubler), .direct_video(direct_video),
	.ps2_key(ps2_key), .joystick_0(joystick), .joystick_l_analog_0(analog_stick),
	.spinner_0(spinner), .ps2_mouse(mouse), .ioctl_wait(1'b0),
	.ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index),
	.ioctl_addr(ioctl_addr), .ioctl_dout(ioctl_data),
	.ioctl_upload(ioctl_upload), .ioctl_rd(ioctl_rd), .ioctl_din(nv_data),
	.ioctl_upload_req(nv_save_request), .ioctl_upload_index(8'd4)
);

// System and video transport clocks continue through a user reset.
wire reset = RESET || !pll_locked || !video_locked || status[0] || buttons[1];
wire system_pause, menu_pause, pause_button;
// The HSC coordinator accepts pause after the CPU bus transaction completes.
assign system_pause = menu_pause || nv_transfer;
wire ce_pix, ce_cpu, ce_frame, cpu_phi, hsc_cpu_hold;
victory_clocks #(.HOLD_CPU_PHASE(1)) clocks (
	.clk(clk_sys), .reset(graphics_reset), .paused(hsc_cpu_hold),
	.ce_pix(), .ce_cpu(ce_cpu), .cpu_phi(cpu_phi)
);
wire [8:0] hpos, vpos;
wire core_hs, core_vs, core_hb, core_vb;
assign ce_frame = ce_pix && hpos==9'd335 && vpos==9'd279;
wire [7:0] dial, coin_port, button_port;
victory_inputs inputs (
	.clk(clk_sys), .reset(reset), .paused(system_pause), .ce_frame(ce_frame),
	.ps2_key(ps2_key), .joystick(joystick), .analog_x(analog_stick[7:0]),
	.spinner(spinner), .mouse(mouse), .pause_button(pause_button),
	.dial(dial), .coin_port(coin_port), .button_port(button_port)
);
wire [7:0] core_r, core_g, core_b, game_r, game_g, game_b;
// ROMs load through the MRA. The retired Display status bit is ignored even
// when an older saved configuration selected the development test pattern.
assign {core_r,core_g,core_b} = {game_r,game_g,game_b};
wire [7:0] pause_r, pause_g, pause_b;
pause #(.CLKSPD(48)) pause_control (
	.clk_sys(clk_sys), .reset(reset), .user_button(pause_button), .pause_request(1'b0),
	.options({!status[5], !status[4]}), .OSD_STATUS(OSD_STATUS),
	.r(core_r), .g(core_g), .b(core_b), .pause_cpu(menu_pause),
	.r_out(pause_r), .g_out(pause_g), .b_out(pause_b)
);
wire rom_ready, board_halt_n, sound_command_wr, sound_response_rd;
wire signed [15:0] sound_audio;
wire [7:0] sound_command, sound_response, sound_status, sound_rom_q;
wire [13:0] sound_rom_addr;
wire graphics_reset = reset || !rom_ready || (ioctl_download && (ioctl_index == 0 || ioctl_index == 4));
wire engine_busy, fg_hit, bg_hit, cpu_wait_n;
wire bg_pending_n, fg_pending_n, vblank_pending_n;
wire [7:0] engine_cmd, fg_x, fg_y, bg_x, bg_y, scroll_x, scroll_y, video_control, video_cpu_q;
wire [15:0] cpu_addr;
wire [7:0] cpu_data;
wire cpu_mreq_n, cpu_iorq_n, cpu_rd_n, cpu_wr_n, ce_master;
victory_hsc_native graphics (
	.clk(clk_sys), .reset(graphics_reset), .paused(system_pause), .ce_master(ce_master), .cpu_phi(cpu_phi),
	.cpu_addr(cpu_addr), .cpu_data(cpu_data), .cpu_mreq_n(cpu_mreq_n), .cpu_iorq_n(cpu_iorq_n),
	.cpu_rd_n(cpu_rd_n), .cpu_wr_n(cpu_wr_n),
	.download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index), .ioctl_addr(ioctl_addr), .ioctl_data(ioctl_data),
	.scroll_x(scroll_x), .scroll_y(scroll_y), .video_control(video_control),
	// Factory 15J is unpopulated (docs/15J_UNPOPULATED.md). This provisional
	// zero input disables EBIRQ; verify board tie-offs before changing levels.
	.blanking_rom_data(8'd0), .blanking_rom_address(),
	.cpu_background_q(video_cpu_q), .cpu_wait_n(cpu_wait_n), .cpu_hold(hsc_cpu_hold), .pause_active(),
	.busy(engine_busy), .fg_hit(fg_hit), .command(engine_cmd), .fg_x(fg_x), .fg_y(fg_y),
	.bg_hit(bg_hit), .bg_pending_n(bg_pending_n), .fg_pending_n(fg_pending_n), .vblank_pending_n(vblank_pending_n),
	.bg_x(bg_x), .bg_y(bg_y), .ce_packet(ce_pix),
	.hs(core_hs), .vs(core_vs), .hb(core_hb), .vb(core_vb), .hpos(hpos), .vpos(vpos),
	.r(game_r), .g(game_g), .b(game_b)
);
victory_sound sound_board (
	.clk(clk_sys), .reset(graphics_reset), .paused(hsc_cpu_hold),
	.command_wr(sound_command_wr), .response_rd(sound_response_rd), .command(sound_command),
	.response(sound_response), .status(sound_status), .rom_addr(sound_rom_addr), .rom_q(sound_rom_q),
	.audio(sound_audio), .cpu_addr(), .cpu_sync(), .cpu_rwn(), .unsupported_mode()
);
victory_board #(.EXTERNAL_VIDEO_MEMORY(1), .EXTERNAL_HSC_IRQ(1)) main_board (
	.video_cpu_q(video_cpu_q), .video_bg_pending_n(bg_pending_n), .video_fg_pending_n(fg_pending_n), .video_vblank_pending_n(vblank_pending_n),
	.cpu_wait_n(cpu_wait_n),
	.clk(clk_sys), .reset(reset), .paused(hsc_cpu_hold), .ce_cpu(ce_cpu),
	.vblank(core_vb), .vpos(vpos), .dial(dial), .coins(coin_port), .buttons(button_port),
	.ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr), .ioctl_index(ioctl_index),
	.ioctl_addr(ioctl_addr), .ioctl_data(ioctl_data), .rom_ready(rom_ready),
	.ioctl_upload(ioctl_upload), .ioctl_rd(ioctl_rd), .nv_data(nv_data),
	.nv_transfer(nv_transfer), .nv_save_request(nv_save_request),
	.engine_busy(engine_busy), .fg_hit(fg_hit), .bg_hit(bg_hit), .engine_attached(1'b1), .engine_cmd(engine_cmd),
	.video_reg_wr(), .video_reg_addr(), .video_reg_data(),
	.fg_collision_pending(), .fg_x(fg_x), .fg_y(fg_y), .bg_x(bg_x), .bg_y(bg_y),
	.command_start(), .reg_i(), .reg_cmd(), .reg_g(), .reg_x(), .reg_y(), .reg_r(), .reg_b(),
	.scroll_x(scroll_x), .scroll_y(scroll_y), .video_control(video_control), .lamps(),
	.sound_command_wr(sound_command_wr), .sound_response_rd(sound_response_rd), .sound_command(sound_command),
	.sound_response(sound_response), .sound_status(sound_status), .sound_rom_addr(sound_rom_addr), .sound_rom_q(sound_rom_q),
	.prom_addr(9'd0), .prom_q(),
	.tile_addr(10'd0), .tile_q(), .char_addr(13'd0), .char_q(), .char_rgb_q(),
	.palette_addr(6'd0), .palette_q(),
	.cpu_addr(cpu_addr), .cpu_dout(cpu_data), .cpu_m1_n(), .cpu_mreq_n(cpu_mreq_n), .cpu_iorq_n(cpu_iorq_n), .cpu_rd_n(cpu_rd_n),
	.cpu_wr_n(cpu_wr_n), .cpu_rfsh_n(), .cpu_halt_n(board_halt_n), .irq_n()
);
// Expose CPU HALT and transport faults alongside pause/download.
assign LED_USER = system_pause || video_fault || native_output_fault || (crt_selected && !crt_valid) || (ioctl_download && ioctl_index == 0) || (rom_ready && !board_halt_n);

wire video_ce, video_fault, video_hs, video_vs, video_hb, video_vb;
wire [8:0] video_x, video_y;
wire [23:0] video_rgb;
victory_video_bridge #(.EXTERNAL_PACKETS(1)) video_bridge (
	.ce_packet(ce_pix), .ce_master(ce_master),
	.clk_sys(clk_sys), .clk_video(clk_video), .reset_async(graphics_reset),
	.rgb_in({pause_r,pause_g,pause_b}), .hs_in(core_hs), .vs_in(core_vs),
	.hb_in(core_hb), .vb_in(core_vb), .hpos_in(hpos), .vpos_in(vpos),
	.ce_render(), .ce_video(video_ce), .rgb_out(video_rgb),
	.hs_out(video_hs), .vs_out(video_vs), .hb_out(video_hb), .vb_out(video_vb),
	.hpos_out(video_x), .vpos_out(video_y), .fault(video_fault)
);
// Native capture and game timing remain on their original free-running clocks.
// A direct reconfigurable PLL supplies CLK_VIDEO to the inherited selectors.
// Native transport has its own small packet FIFO, avoiding any assumed phase
// relationship between the fixed source PLL and equal-rate output PLL.
wire clk_output, output_locked, crt_selected, output_blank, transport_reset;
wire [63:0] output_reconfig_to_pll, output_reconfig_from_pll;
wire output_cfg_write, output_cfg_waitrequest;
wire [5:0] output_cfg_address;
wire [31:0] output_cfg_writedata;
victory_output_pll output_pll (
	.refclk(CLK_50M), .reset(!pll_locked), .clk_output(clk_output), .locked(output_locked),
	.reconfig_to_pll(output_reconfig_to_pll), .reconfig_from_pll(output_reconfig_from_pll)
);
pll_cfg output_config (
	.mgmt_clk(clk_sys), .mgmt_reset(!pll_locked), .mgmt_read(1'b0),
	.mgmt_write(output_cfg_write), .mgmt_address(output_cfg_address),
	.mgmt_writedata(output_cfg_writedata), .mgmt_readdata(), .mgmt_waitrequest(output_cfg_waitrequest),
	.reconfig_to_pll(output_reconfig_to_pll), .reconfig_from_pll(output_reconfig_from_pll)
);
wire native_output_ce, native_output_hs, native_output_vs, native_output_hb, native_output_vb, native_output_fault;
wire [23:0] native_output_rgb;
wire [8:0] native_output_x, native_output_y;
victory_video_bridge #(.EXTERNAL_PACKETS(1)) native_output_bridge (
	.clk_sys(clk_sys), .clk_video(clk_output),
	.reset_async(graphics_reset || transport_reset || crt_selected || !output_locked),
	.ce_packet(ce_pix), .ce_master(), .ce_render(),
	.rgb_in({pause_r,pause_g,pause_b}), .hs_in(core_hs), .vs_in(core_vs),
	.hb_in(core_hb), .vb_in(core_vb), .hpos_in(hpos), .vpos_in(vpos),
	.ce_video(native_output_ce), .rgb_out(native_output_rgb),
	.hs_out(native_output_hs), .vs_out(native_output_vs), .hb_out(native_output_hb), .vb_out(native_output_vb),
	.hpos_out(native_output_x), .vpos_out(native_output_y), .fault(native_output_fault)
);
wire crt_ce, crt_hs, crt_vs, crt_hb, crt_vb, crt_valid;
wire [23:0] crt_rgb;
wire [8:0] crt_x, crt_y;
victory_crt_stream crt_stream (
	.clk_native(clk_video), .clk_crt(clk_output),
	.reset_async(graphics_reset || transport_reset || !crt_selected || !output_locked),
	.ce_native(video_ce), .rgb_native(video_rgb), .x_native(video_x), .y_native(video_y),
	.hb_native(video_hb), .vb_native(video_vb),
	.ce_out(crt_ce), .rgb_out(crt_rgb), .x_out(crt_x), .y_out(crt_y),
	.hs_out(crt_hs), .vs_out(crt_vs), .hb_out(crt_hb), .vb_out(crt_vb),
	.frame_valid(crt_valid), .malformed_frames(), .source_skips(), .stream_faults()
);
wire output_ce = crt_selected ? crt_ce : native_output_ce;
wire [23:0] output_rgb = crt_selected ? crt_rgb : native_output_rgb;
wire [8:0] output_x = crt_selected ? crt_x : native_output_x;
wire [8:0] output_y = crt_selected ? crt_y : native_output_y;
wire output_hs = crt_selected ? crt_hs : native_output_hs;
wire output_vs = crt_selected ? crt_vs : native_output_vs;
wire output_hb = crt_selected ? crt_hb : native_output_hb;
wire output_vb = crt_selected ? crt_vb : native_output_vb;
wire output_frame = output_ce && output_x==9'd335 && output_y==(crt_selected ? 9'd261 : 9'd279);
victory_output_control output_control (
	.clk_sys(clk_sys), .clk_output(clk_output), .management_reset(!pll_locked), .user_reset(graphics_reset),
	.native_locked(video_locked), .output_locked(output_locked),
	.request_crt(!status[102] && !scandoubler), .native_frame(ce_frame),
	.output_frame(output_frame), .cfg_waitrequest(output_cfg_waitrequest),
	.cfg_write(output_cfg_write), .cfg_address(output_cfg_address), .cfg_writedata(output_cfg_writedata),
	.selected_crt(crt_selected), .transport_reset(transport_reset), .blank_output(output_blank)
);
// OSD settings are slow-changing controls; synchronize them before video use.
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [23:0] video_options_meta=0, video_options=0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg gamma_enable_meta=0, gamma_enable_video=0;
always @(posedge clk_output) begin
	video_options_meta<={direct_video,status[122:121],status[101],status[100:96],status[85:80],status[78:74],forced_scandoubler,status[3:1]};
	video_options<=video_options_meta;
	gamma_enable_meta<=gamma_bus[19];
	gamma_enable_video<=gamma_enable_meta;
end
// Gamma writes already use the framework's separate system-clock RAM port.
// Only the enable control needs synchronization into the new video domain.
wire [21:0] video_gamma_bus;
assign video_gamma_bus[20]=gamma_bus[20];
assign video_gamma_bus[19]=gamma_enable_video;
assign video_gamma_bus[18:0]=gamma_bus[18:0];
assign gamma_bus[21]=video_gamma_bus[21];
// A pending FX change cannot enable scandoubling while still on CRT transport.
wire video_scandoubler=!crt_selected && (video_options[3] || video_options[2:0]!=0);
// DV receivers decimate fixed pixel repeats. HQ2x needs /2, so use ordinary
// scandoubling (/4) for that preference in DV, and bypass fractional H-Size.
wire dv_hq2x=video_options[23] && video_options[2:0]==3'd1;

wire mixer_de, mixer_ce, mixer_hs, mixer_vs;
wire [7:0] mixer_r, mixer_g, mixer_b;
arcade_video #(.WIDTH(256), .DW(24)) video_output (
	.clk_video(clk_output), .ce_pix(output_ce), .RGB_in(output_rgb),
	.HSync(output_hs), .VSync(output_vs), .HBlank(output_hb), .VBlank(output_vb),
	.fx(crt_selected || dv_hq2x ? 3'd0 : video_options[2:0]), .forced_scandoubler(!crt_selected && (video_options[3] || dv_hq2x)), .gamma_bus(video_gamma_bus),
	.CLK_VIDEO(CLK_VIDEO), .CE_PIXEL(mixer_ce), .VGA_R(mixer_r), .VGA_G(mixer_g), .VGA_B(mixer_b),
	.VGA_HS(mixer_hs), .VGA_VS(mixer_vs), .VGA_DE(mixer_de), .VGA_SL(VGA_SL)
);
// Keep sync/CE flowing so the imported mixer relearns after a clock switch.
// Mask only picture/DE during the controller's two-frame output warmup.
wire [23:0] geometry_rgb;
wire geometry_hb, geometry_vb;
victory_crt #(.COMBINED_BLANK(1)) core_geometry (
	.clk(CLK_VIDEO), .ce_pix(mixer_ce), .ce_frame(output_frame),
	.enabled(video_options[20] && !video_scandoubler),
	.scandoubler(video_scandoubler), .crt_15k(crt_selected),
	.hsize(video_options[23] ? 5'd0 : video_options[19:15]),
	.hposition(video_options[14:9]), .vshift(video_options[8:4]), .hpos(output_x),
	.r_in(mixer_r), .g_in(mixer_g), .b_in(mixer_b),
	.hs_in(mixer_hs), .vs_in(mixer_vs), .hb_in(!mixer_de), .vb_in(output_vb),
	.ce_out(CE_PIXEL), .r_out(geometry_rgb[23:16]), .g_out(geometry_rgb[15:8]), .b_out(geometry_rgb[7:0]),
	.hs_out(VGA_HS), .vs_out(VGA_VS), .hb_out(geometry_hb), .vb_out(geometry_vb)
);
assign {VGA_R,VGA_G,VGA_B}=output_blank ? 24'd0 : geometry_rgb;
wire [1:0] aspect = video_options[22:21];
video_freak aspect_control (
	.CLK_VIDEO(CLK_VIDEO), .CE_PIXEL(CE_PIXEL), .VGA_VS(VGA_VS), .VGA_DE_IN(!(geometry_hb || geometry_vb) && !output_blank),
	.HDMI_WIDTH(HDMI_WIDTH), .HDMI_HEIGHT(HDMI_HEIGHT),
	.ARX(aspect == 0 ? 12'd4 : {10'd0, aspect} - 12'd1), .ARY(aspect == 0 ? 12'd3 : 12'd0),
	.CROP_SIZE(12'd0), .CROP_OFF(5'd0), .SCALE(3'd0),
	.VGA_DE(VGA_DE), .VIDEO_ARX(VIDEO_ARX), .VIDEO_ARY(VIDEO_ARY)
);

// Raster/CRT timing continues while game execution is paused or awaiting ROMs.
endmodule

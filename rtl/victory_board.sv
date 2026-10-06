// SPDX-License-Identifier: GPL-3.0-or-later
// Main board memory/PIO decode from the pinned MAME Victory driver.
// Graphics command execution and the sound board attach to the ports below.
module victory_board #(parameter EXTERNAL_VIDEO_MEMORY=0, EXTERNAL_BACKGROUND_IRQ=0, EXTERNAL_HSC_IRQ=0) (
	input  wire         clk, reset, paused, ce_cpu, cpu_wait_n, vblank,
	input  wire [7:0]    video_cpu_q,
	input  wire         video_bg_pending_n,
	input  wire         video_fg_pending_n, video_vblank_pending_n,
	input  wire [8:0]   vpos,
	input  wire [7:0]   dial, coins, buttons,
	input  wire         ioctl_download, ioctl_wr,
	input  wire [15:0]  ioctl_index,
	input  wire [26:0]  ioctl_addr,
	input  wire [7:0]   ioctl_data,
	input  wire         ioctl_upload, ioctl_rd,
	output wire [7:0]   nv_data,
	output wire         nv_transfer, nv_save_request,
	output wire         rom_ready,
	input  wire         engine_busy, fg_hit, bg_hit,
	input  wire         engine_attached,
	input  wire [7:0]   engine_cmd,
	output wire         video_reg_wr, fg_collision_pending,
	output wire [2:0]   video_reg_addr,
	output wire [7:0]   video_reg_data,
	input  wire [7:0]   fg_x, fg_y, bg_x, bg_y,
	output reg          command_start,
	output reg  [15:0]  reg_i,
	output reg  [7:0]   reg_cmd, reg_g, reg_x, reg_y, reg_r, reg_b,
	output reg  [7:0]   scroll_x, scroll_y, video_control,
	output reg  [7:0]   lamps,
	output reg          sound_command_wr, sound_response_rd,
	output reg  [7:0]   sound_command,
	input  wire [7:0]   sound_response, sound_status,
	input  wire [13:0]  sound_rom_addr,
	output wire [7:0]   sound_rom_q,
	input  wire [8:0]   prom_addr,
	output wire [7:0]   prom_q,
	input  wire [9:0]   tile_addr,
	output reg  [7:0]   tile_q,
	input  wire [12:0]  char_addr,
	output wire [7:0]   char_q,
	output wire [23:0]  char_rgb_q,
	input  wire [5:0]   palette_addr,
	output reg  [8:0]   palette_q,
	output wire [15:0]  cpu_addr,
	output wire [7:0]   cpu_dout,
	output wire         cpu_m1_n, cpu_mreq_n, cpu_iorq_n, cpu_rd_n, cpu_wr_n,
	output wire         cpu_rfsh_n, cpu_halt_n, irq_n
);
wire cpu_reset = reset || !rom_ready || (ioctl_download && (ioctl_index == 0 || ioctl_index == 4));
wire [7:0] rom_q;
victory_rom rom (
	.clk(clk), .download(ioctl_download), .wr(ioctl_wr), .index(ioctl_index),
	.addr(ioctl_addr), .data(ioctl_data), .main_addr(cpu_addr), .main_q(rom_q),
	.sound_addr(sound_rom_addr), .sound_q(sound_rom_q), .prom_addr(prom_addr), .prom_q(prom_q), .ready(rom_ready)
);
reg [7:0] tiles [0:1023], work [0:4095];
reg [7:0] chars_r [0:2047], chars_b [0:2047], chars_g [0:2047];
reg [8:0] palette [0:63];
initial begin
	for (integer i=0; i<1024; i=i+1) tiles[i]=0;
	// Three 2 KiB planes; keep each elaboration loop below Quartus's limit.
	for (integer i=0; i<2048; i=i+1) begin
		chars_r[i]=0;
		chars_b[i]=0;
		chars_g[i]=0;
	end
	for (integer i=0; i<4096; i=i+1) work[i]=0;
	for (integer i=0; i<64; i=i+1) palette[i]=0;
end
reg [7:0] tile_cpu_q, red_cpu_q, blue_cpu_q, green_cpu_q, work_cpu_q, device_q;
wire [7:0] nvram_cpu_q;
reg [7:0] red_video_q, blue_video_q, green_video_q;
reg [1:0] video_plane;
assign char_q = video_plane == 0 ? red_video_q : video_plane == 1 ? blue_video_q :
	video_plane == 2 ? green_video_q : 8'hff;
assign char_rgb_q = {red_video_q,blue_video_q,green_video_q};
// Video INT is not on a PIO daisy chain; interrupt acknowledge reads FF.
wire [7:0] cpu_di =
	(!cpu_iorq_n && !cpu_m1_n)                    ? 8'hff       :
	!cpu_iorq_n                                 ? device_q    :
	cpu_addr < 16'hc000                         ? rom_q       :
	(cpu_addr < 16'hc400 || cpu_addr >= 16'hf800) ? device_q    :
	(EXTERNAL_VIDEO_MEMORY && cpu_addr < 16'he000) ? video_cpu_q :
	cpu_addr < 16'hc800                         ? tile_cpu_q  :
	cpu_addr < 16'hd000                         ? red_cpu_q   :
	cpu_addr < 16'hd800                         ? blue_cpu_q  :
	cpu_addr < 16'he000                         ? green_cpu_q :
	cpu_addr < 16'hf000                         ? work_cpu_q  :
	                                             nvram_cpu_q;
cpu_z80 cpu (
	.clk(clk), .cen(ce_cpu && !paused), .reset_n(!cpu_reset), .wait_n(cpu_wait_n),
	.int_n(irq_n), .nmi_n(1'b1), .busrq_n(1'b1), .busak_n(),
	.a(cpu_addr), .di(cpu_di), .dout(cpu_dout), .m1_n(cpu_m1_n),
	.mreq_n(cpu_mreq_n), .iorq_n(cpu_iorq_n), .rd_n(cpu_rd_n), .wr_n(cpu_wr_n),
	.rfsh_n(cpu_rfsh_n), .halt_n(cpu_halt_n)
);
wire rd_active = !cpu_rd_n && (!cpu_mreq_n || !cpu_iorq_n);
wire wr_active = !cpu_wr_n && (!cpu_mreq_n || !cpu_iorq_n);
reg rd_seen, wr_seen;
reg [15:0] write_addr;
reg write_io;
wire read_once = rd_active && !rd_seen && !cpu_reset && !paused;
// TV80 updates dout late in T2. Commit once after WR rises, with its address
// and memory/I/O selection retained from the active strobe.
wire write_once = !wr_active && wr_seen && !cpu_reset && !paused;
wire [15:0] bus_addr = write_once ? write_addr : cpu_addr;
wire io_read = read_once && !cpu_iorq_n;
wire io_write = write_once && write_io;
wire mem_read = read_once && !cpu_mreq_n;
wire mem_write = write_once && !write_io;
victory_nvram battery_ram (
	.clk(clk), .cpu_addr(bus_addr[10:0]), .cpu_data(cpu_dout), .cpu_q(nvram_cpu_q),
	.cpu_wr(mem_write && write_addr >= 16'hf000 && write_addr < 16'hf800 && !nv_transfer),
	.download(ioctl_download), .upload(ioctl_upload), .wr(ioctl_wr), .rd(ioctl_rd),
	.index(ioctl_index), .addr(ioctl_addr), .data(ioctl_data), .q(nv_data),
	.active(nv_transfer), .save_request(nv_save_request)
);
wire [7:0] trigger_cmd = engine_attached ? engine_cmd : reg_cmd;
assign video_reg_wr   = mem_write && write_addr[15:3] == 13'h1820;
assign video_reg_addr = write_addr[2:0];
assign video_reg_data = cpu_dout;
wire [7:0] pio1_q, pio2_q;
victory_pio pio1 (.clk(clk), .reset(cpu_reset),
	.wr(io_write && bus_addr[7:2] == 6'd2), .addr(bus_addr[1:0]),
	.data(cpu_dout), .in_a(dial), .in_b(coins), .q(pio1_q));
victory_pio pio2 (.clk(clk), .reset(cpu_reset),
	.wr(io_write && bus_addr[7:2] == 6'd3), .addr(bus_addr[1:0]),
	.data(cpu_dout), .in_a(buttons), .in_b(8'hff), .q(pio2_q));
reg vb_d, vb_irq, fg_irq, bg_irq;
reg [7:0] fg_cx, fg_cy, bg_cx, bg_cy;
wire fg_ack = mem_read && cpu_addr == 16'hc001;
wire bg_ack = mem_read && cpu_addr == 16'hc003;
// Native HSC already owns 13H and its asynchronous clear. Do not recapture
// its pulse/coordinates or gate the pending latch a second time with BIRQEA.
localparam EXTERNAL_BG = EXTERNAL_BACKGROUND_IRQ || EXTERNAL_HSC_IRQ;
wire background_pending = EXTERNAL_BG ? !video_bg_pending_n : bg_irq;
wire foreground_pending = EXTERNAL_HSC_IRQ ? !video_fg_pending_n : fg_irq;
wire vertical_pending = EXTERNAL_HSC_IRQ ? !video_vblank_pending_n : vb_irq;
wire [7:0] background_x = EXTERNAL_BG ? bg_x : bg_cx;
wire [7:0] background_y = EXTERNAL_BG ? bg_y : bg_cy;
wire [7:0] foreground_x = EXTERNAL_HSC_IRQ ? fg_x : fg_cx;
wire [7:0] foreground_y = EXTERNAL_HSC_IRQ ? fg_y : fg_cy;
assign irq_n = !(vertical_pending || foreground_pending || (background_pending && (EXTERNAL_BG || video_control[5])));
assign fg_collision_pending = foreground_pending;
always @(posedge clk) begin
	// Synchronous BRAM reads remain active during pause; no game state changes.
	// Independent output registers allow Quartus to infer each BRAM bank.
	// The CPU port uses the same address for its read and write transaction.
	work_cpu_q <= work[bus_addr[11:0]];
	// The native HSC owns the physical shared video banks. Disable these
	// legacy independent ports entirely in that configuration, while work
	// RAM and release-edge register/PIO transactions remain on this board.
	if(!EXTERNAL_VIDEO_MEMORY) begin
		tile_cpu_q <= tiles[bus_addr[9:0]];
		red_cpu_q <= chars_r[bus_addr[10:0]];
		blue_cpu_q <= chars_b[bus_addr[10:0]];
		green_cpu_q <= chars_g[bus_addr[10:0]];
		tile_q <= tiles[tile_addr];
		red_video_q <= chars_r[char_addr[10:0]];
		blue_video_q <= chars_b[char_addr[10:0]];
		green_video_q <= chars_g[char_addr[10:0]];
		video_plane <= char_addr[12:11];
		palette_q <= palette[palette_addr];
		if(mem_write) begin
			if (write_addr >= 16'hc200 && write_addr < 16'hc400) palette[write_addr[5:0]] <= {write_addr[7],cpu_dout};
			else if (write_addr >= 16'hc400 && write_addr < 16'hc800) tiles[bus_addr[9:0]] <= cpu_dout;
			else if (write_addr >= 16'hc800 && write_addr < 16'hd000) chars_r[bus_addr[10:0]] <= cpu_dout;
			else if (write_addr >= 16'hd000 && write_addr < 16'hd800) chars_b[bus_addr[10:0]] <= cpu_dout;
			else if (write_addr >= 16'hd800 && write_addr < 16'he000) chars_g[bus_addr[10:0]] <= cpu_dout;
		end
	end else begin
		tile_q <= 0;
		red_video_q <= 0; blue_video_q <= 0; green_video_q <= 0;
		video_plane <= 0; palette_q <= 0;
		tile_cpu_q <= 0; red_cpu_q <= 0; blue_cpu_q <= 0; green_cpu_q <= 0;
	end
	if(mem_write && write_addr >= 16'he000 && write_addr < 16'hf000)
		work[bus_addr[11:0]] <= cpu_dout;
	vb_d <= vblank;
	if (cpu_reset) begin
		command_start     <= 0;
		sound_command_wr  <= 0;
		sound_response_rd <= 0;
		rd_seen       <= 0;
		wr_seen       <= 0;
		write_addr    <= 0;
		write_io      <= 0;
		device_q      <= 8'hff;
		vb_irq        <= 0;
		fg_irq        <= 0;
		bg_irq        <= 0;
		fg_cx         <= 0;
		fg_cy         <= 0;
		bg_cx         <= 0;
		bg_cy         <= 0;
		reg_i         <= 0;
		reg_cmd       <= 0;
		reg_g         <= 0;
		reg_x         <= 0;
		reg_y         <= 0;
		reg_r         <= 0;
		reg_b         <= 0;
		scroll_x      <= 0;
		scroll_y      <= 0;
		video_control <= 0;
		lamps         <= 0;
		sound_command <= 0;
	end else if (!paused) begin
		// Retain pending strobes across a pause until their consumers resume.
		command_start     <= 0;
		sound_command_wr  <= 0;
		sound_response_rd <= 0;
		rd_seen <= rd_active;
		wr_seen <= wr_active;
		if (wr_active) begin
			write_addr <= cpu_addr;
			write_io <= !cpu_iorq_n;
		end
		if (!EXTERNAL_HSC_IRQ && vblank && !vb_d) vb_irq <= 1;
		// SCLFIQ/SBACKY asynchronously clear the original 74LS74s. A Y
		// read wins over a simultaneous event; later events cannot replace
		// coordinates while pending (sheets 3, 7 and 15).
		if (!EXTERNAL_HSC_IRQ && fg_hit && !fg_irq && !fg_ack) begin
			fg_irq <= 1;
			fg_cx <= fg_x;
			fg_cy <= fg_y;
		end
		if (!EXTERNAL_BG && bg_hit && !bg_irq && !bg_ack && video_control[5]) begin
			bg_irq <= 1;
			bg_cx <= bg_x;
			bg_cy <= bg_y;
		end
		if (io_read) case (cpu_addr[7:2])
			0: device_q <= 8'h78;
			1: device_q <= 8'hff;
			2: device_q <= pio1_q;
			3: device_q <= pio2_q;
			default: device_q <= 8'hff;
		endcase
		if (io_write && write_addr[7:2] == 6'd4) lamps <= cpu_dout;
		if (mem_read) begin
			device_q <= 8'hff;
			if (cpu_addr[15:8] == 8'hc0) case (cpu_addr[7:0])
				0: device_q <= foreground_x;
				1: begin
					device_q <= foreground_y;
					fg_irq <= 0;
				end
				2: device_q <= background_x & 8'hfc;
				3: begin
					device_q <= background_y;
					bg_irq <= 0;
				end
				4: device_q <= {engine_busy,~foreground_pending,~vertical_pending,~background_pending,vpos[8],3'b000};
				default: device_q <= 0;
			endcase
			else if (cpu_addr >= 16'hf800) case (cpu_addr[1:0])
				0: begin
					device_q <= sound_response;
					sound_response_rd <= 1;
				end
				1: device_q <= sound_status;
				default: device_q <= 8'hff;
			endcase
		end
		// Sheet 4's 14K LS241 status driver is a live bus. Keep its
		// registered FPGA response current throughout RD, including a WAIT
		// extension; a first-read snapshot can miss BUSY rising before T3.
		if(!cpu_mreq_n && !cpu_rd_n && cpu_addr==16'hc004)
			device_q <= {engine_busy,~foreground_pending,~vertical_pending,~background_pending,vpos[8],3'b000};
		// Physical LS241 coordinate/status drivers remain live throughout RD.
		// 18L decodes A2..0 only, so the external HSC mirrors these reads.
		// Y's asynchronous clear may clock LS374 again during this same RD;
		// a first-edge snapshot would hide that change from CPU T3.
		if(EXTERNAL_BG && !cpu_mreq_n && !cpu_rd_n && cpu_addr[15:8]==8'hc0)
			case(cpu_addr[2:0])
				0: if(EXTERNAL_HSC_IRQ) device_q <= foreground_x;
				1: if(EXTERNAL_HSC_IRQ) device_q <= foreground_y;
				2: device_q <= background_x & 8'hfc;
				3: device_q <= background_y;
				4: device_q <= {engine_busy,~foreground_pending,~vertical_pending,~background_pending,vpos[8],3'b000};
				default: ;
			endcase
		if (mem_write) begin
			if (write_addr[15:8] == 8'hc1) case (write_addr[7:0])
				0: reg_i[7:0] <= cpu_dout;
				1: begin
					reg_i[15:8] <= cpu_dout;
					command_start <= trigger_cmd[2:0] == 5;
				end
				2: begin
					reg_cmd <= cpu_dout;
					command_start <= cpu_dout[2:0] == 6;
				end
				3: reg_g <= cpu_dout;
				4: begin
					reg_x <= cpu_dout;
					command_start <= trigger_cmd[2:0] == 3;
				end
				5: begin
					reg_y <= cpu_dout;
					command_start <= trigger_cmd[2:0] == 4;
				end
				6: reg_r <= cpu_dout;
				7: begin
					reg_b <= cpu_dout;
					command_start <= trigger_cmd[2:0] == 2 || trigger_cmd[2:0] == 7;
				end
				8: scroll_x <= cpu_dout;
				9: scroll_y <= cpu_dout;
				10: video_control <= cpu_dout;
				11: vb_irq <= 0;
				default: ;
			endcase
			else if (write_addr >= 16'hf800 && write_addr[1:0] == 0) begin
				sound_command <= cpu_dout;
				sound_command_wr <= 1;
			end
		end
	end
end
endmodule

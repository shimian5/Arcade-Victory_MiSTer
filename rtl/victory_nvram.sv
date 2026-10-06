// SPDX-License-Identifier: GPL-3.0-or-later
// Victory's 2 KiB battery RAM, exposed through MiSTer's index-4 NVRAM stream.
// Save/restore uses the upstream MiSTer hps_io upload request interface.
module victory_nvram #(
	parameter integer QUIET_CYCLES = 48000000,
	parameter integer MAX_CYCLES   = 1440000000
) (
	input  wire        clk,
	input  wire [10:0] cpu_addr,
	input  wire [7:0]  cpu_data,
	input  wire        cpu_wr,
	output reg  [7:0]  cpu_q,
	input  wire        download, upload, wr, rd,
	input  wire [15:0] index,
	input  wire [26:0] addr,
	input  wire [7:0]  data,
	output reg  [7:0]  q,
	output wire        active,
	output reg         save_request = 0
);
reg [7:0] mem [0:2047];
initial begin
	for (integer i = 0; i < 2048; i = i + 1) mem[i] = 0;
end

wire restoring = download && index == 4;
wire saving    = upload && index == 4;
assign active  = restoring || saving;
reg restore_d = 0, save_d = 0;
reg [11:0] restore_count = 0, save_count = 0;
reg restore_bad = 0, save_bad = 0;
wire restore_done = restore_d && !restoring && restore_count == 2048 && !restore_bad;
wire save_done    = save_d && !saving && save_count == 2048 && !save_bad;

// Do not clear pending changes on reset or at the start of an upload. An
// interrupted upload must leave them pending for a later complete transfer.
reg dirty = 0;
reg [31:0] quiet_time = 0, dirty_time = 0;
always @(posedge clk) begin
	cpu_q <= mem[cpu_addr];
	q     <= mem[addr[10:0]];
	if (restoring && wr && addr < 2048) mem[addr[10:0]] <= data;
	else if (cpu_wr && !active) mem[cpu_addr] <= cpu_data;

	restore_d <= restoring;
	save_d    <= saving;
	if (!restoring) begin
		restore_count <= 0;
		restore_bad   <= 0;
	end else if (wr) begin
		if (addr == {15'd0, restore_count} && restore_count < 2048)
			restore_count <= restore_count + 1'b1;
		else restore_bad <= 1;
	end
	if (!saving) begin
		save_count <= 0;
		save_bad   <= 0;
	end else if (rd) begin
		// Upload addresses advance when hps_io captures the preceding byte.
		// Its initial ioctl_rd primes byte zero; it is not a file data read.
		if (addr == {15'd0, save_count + 12'd1} && save_count < 2048)
			save_count <= save_count + 1'b1;
		else if (addr != {15'd0, save_count})
			save_bad <= 1;
	end

	if (!dirty || restore_done || save_done) begin
		dirty      <= 0;
		quiet_time <= 0;
		dirty_time <= 0;
	end else begin
		if (quiet_time < QUIET_CYCLES) quiet_time <= quiet_time + 1'b1;
		if (dirty_time < MAX_CYCLES) dirty_time <= dirty_time + 1'b1;
	end
	if (cpu_wr && !active) begin
		dirty      <= 1;
		quiet_time <= 0;
	end

	// Coalesce bookkeeping/default writes, but still save within 30 seconds
	// when a game keeps updating battery RAM continuously. Manual Save Settings
	// can request an upload at any time, including while the OSD is paused.
	if (active || restore_done || save_done) save_request <= 0;
	else if (dirty && (quiet_time >= QUIET_CYCLES || dirty_time >= MAX_CYCLES))
		save_request <= 1;
end
endmodule

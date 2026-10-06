// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 6 background RAM: one address/read/write port per 2114 bank.
// A delayed access tag retains the CPU's last response after SEAADV returns
// ownership to the raster. Physical scroll/LS299 stages and the board's
// external video-memory interface share these same production RAM ports.
module victory_hsc_background_ram (
	input  wire        clk, reset, paused,
	input  wire [15:0] cpu_addr,
	input  wire [7:0]  cpu_data,
	input  wire        cpu_rd_n, write_clock, background_n, advance_n,
	input  wire [7:0]  scrolled_e, scrolled_l,
	output reg  [7:0]  tile_q, cpu_q,
	output wire [23:0] pattern_rgb_q
);
reg [7:0] tiles[0:1023],red[0:2047],blue[0:2047],green[0:2047];
reg [7:0] red_q,blue_q,green_q;
reg [3:0] access_q;
wire [9:0] tile_address;
wire [10:0] pattern_address;
wire [3:0] access_n,write_n;
victory_hsc_background_control control (
	.cpu_addr(cpu_addr), .cpu_rd_n(cpu_rd_n), .write_clock(write_clock),
	.background_n(background_n), .lookahead_n(1'b1), .advance_n(advance_n),
	.scrolled_e(scrolled_e), .scrolled_l(scrolled_l), .tile_data(tile_q),
	.tile_address(tile_address), .pattern_address(pattern_address),
	.access_n(access_n), .write_n(write_n), .lookahead_access_n(), .lookahead_write_n()
);
assign pattern_rgb_q={red_q,blue_q,green_q};
initial begin
	for(integer address=0;address<1024;address++) tiles[address]=0;
	for(integer address=0;address<2048;address++) begin
		red[address]=0; blue[address]=0; green[address]=0;
	end
end
always @(posedge clk) begin
	tile_q<=tiles[tile_address];
	red_q<=red[pattern_address];
	blue_q<=blue[pattern_address];
	green_q<=green[pattern_address];
	if(reset) begin access_q<=4'b1111; cpu_q<=8'hff; end
	else begin
		access_q<=access_n;
		// These tags refer to the address sampled with the preceding RAM
		// read, including the final CPU slot before ownership changes.
		case(access_q)
			4'b1110: cpu_q<=tile_q;
			4'b1101: cpu_q<=red_q;
			4'b1011: cpu_q<=blue_q;
			4'b0111: cpu_q<=green_q;
			default: ;
		endcase
		// The original /WE is a level. Repeated writes while it is low
		// preserve its final data; no release-edge address substitution.
		if(!paused) begin
			if(!write_n[0]) tiles[tile_address]<=cpu_data;
			if(!write_n[1]) red[pattern_address]<=cpu_data;
			if(!write_n[2]) blue[pattern_address]<=cpu_data;
			if(!write_n[3]) green[pattern_address]<=cpu_data;
		end
	end
end
endmodule

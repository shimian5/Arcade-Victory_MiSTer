// SPDX-License-Identifier: GPL-3.0-or-later
// index 0: main 0000-bfff, sound c000-ffff, then 01e0 bytes of PROMs.
// A partial, oversized or out-of-order transfer keeps the CPU in reset.
module victory_rom (
	input  wire         clk, download, wr,
	input  wire [15:0]  index,
	input  wire [26:0]  addr,
	input  wire [7:0]   data,
	input  wire [15:0]  main_addr,
	output reg  [7:0]   main_q,
	input  wire [13:0]  sound_addr,
	output reg  [7:0]   sound_q,
	input  wire [8:0]   prom_addr,
	output reg  [7:0]   prom_q,
	output reg          ready = 0
);
localparam [26:0] IMAGE_SIZE = 27'h101e0;
reg [7:0] main_rom [0:49151], sound_rom [0:16383], proms [0:479];
reg active = 0, bad = 0;
reg [26:0] expected = 0;
wire selected = download && index == 0;
wire start = selected && !active;
wire [26:0] next_addr = start ? 27'd0 : expected;
always @(posedge clk) begin
	active <= selected;
	if (start) begin
		ready    <= 0;
		expected <= 0;
		bad      <= 0;
	end
	if (selected && wr) begin
		if (addr != next_addr || addr >= IMAGE_SIZE) bad <= 1;
		expected <= next_addr + 27'd1;
		if (addr < 27'hc000) main_rom[addr[15:0]] <= data;
		else if (addr < 27'h10000) sound_rom[addr[13:0]] <= data;
		else if (addr < IMAGE_SIZE) proms[addr[8:0]] <= data;
	end
	if (active && !selected) ready <= !bad && expected == IMAGE_SIZE;
	main_q <= main_addr < 16'hc000 ? main_rom[main_addr] : 8'hff;
	sound_q <= sound_rom[sound_addr];
	prom_q <= prom_addr < 9'd480 ? proms[prom_addr] : 8'hff;
end
endmodule

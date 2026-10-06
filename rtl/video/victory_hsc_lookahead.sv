// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 16: 15M/16L address and /WE muxes, 15L LS174 address
// latch and 15K Signetics 82S09 (64x9). CE15 is grounded; SEALOK
// selects raster addresses and forces /WE high, rather than disabling
// the RAM. The actual output pins complement the written bits.
module victory_hsc_lookahead (
	input  wire       clk, reset, paused, bit_clock,
	input  wire [15:0] cpu_addr,
	input  wire [7:0] cpu_data,
	input  wire       cpu_rd_n, write_clock, lookahead_n, advance_n,
	input  wire [2:0] foreground, background,
	output reg  [5:0] address_q,
	output wire [5:0] collision_vp,
	output wire      raster_selected, write_window_n,
	output wire [8:0] color_pins_n, digital_rgb
);
reg [8:0] palette[0:63];
reg bit_clock_q;
always @(posedge clk) bit_clock_q <= bit_clock;
// 15L CLK9 shares BIT with the background LS299s and 14L CLK9.
// E4CLK feeds 14L D2/pin6, not either latch's clock. Sample the
// preceding serial endpoints on this edge, before the LS299s shift.
wire ce_address = bit_clock && !bit_clock_q;
// Sheet 5 SEALOK = SLOKEA OR SEAADV. On 15M/16L high selects
// pixel B pins; low selects CPU A0..5. The third 16L mux selects
// +5 for video, or SWRLOK=!(RD & (scrolled E2 XOR INVERT)) for CPU.
assign raster_selected = lookahead_n || advance_n;
assign write_window_n  = raster_selected || !(cpu_rd_n && write_clock);
// 14L collision qualification sees VP before 15L, including CPU addresses.
assign collision_vp = raster_selected ? {foreground,background} : cpu_addr[5:0];
wire [8:0] write_data = {cpu_addr[7],cpu_data};
wire writing = !reset && !paused && !write_window_n;
// 82S09's open-collector outputs read the complemented stored word,
// and follow the complement of I0..8 during a write. digital_rgb
// preserves a stored-word view for diagnostics. Production video feeds
// color_pins_n to victory_hsc_rgb and its nominal sheet-16 driver model;
// measured transistor/source/tolerance calibration remains separate.
assign color_pins_n = writing ? ~write_data : ~palette[address_q];
assign digital_rgb  = ~color_pins_n;
initial begin
	for(integer address=0;address<64;address++) palette[address]=0;
end
always @(posedge clk) begin
	if(reset) address_q <= 0;
	else begin
		if(ce_address) address_q <= collision_vp;
		// One shared, latched address. Reset retains the palette.
		if(writing) palette[address_q] <= write_data;
	end
end
endmodule

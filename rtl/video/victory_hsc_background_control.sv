// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheets 5/6: SEAADV-controlled LS157 RAM address muxes, 6J/7H/4J
// bank access/write decode and lookahead strobes. write_clock is 2J XOR3:
// scrolled E2 XOR INVERT, not CPU phi. CPU and raster share the
// address muxes; scrolled coordinates come from the LS193 chain.
module victory_hsc_background_control (
	input  wire [15:0] cpu_addr,
	input  wire        cpu_rd_n, write_clock,
	input  wire        background_n, lookahead_n, advance_n,
	input  wire [7:0]  scrolled_e, scrolled_l, tile_data,
	output wire [9:0]  tile_address,
	output wire [10:0] pattern_address,
	output wire [3:0]  access_n, write_n,
	output wire        lookahead_access_n, lookahead_write_n
);
// LS157 pin 1 high selects B: raster pins 3/6/10/13. SEAADV low
// selects the CPU A pins 2/5/11/14. Both mux banks have /G grounded.
assign tile_address = advance_n ? {scrolled_l[7:3],scrolled_e[7:3]} : cpu_addr[9:0];
assign pattern_address = advance_n ? {tile_data,scrolled_l[2:0]} : cpu_addr[10:0];

wire background_access_n = background_n || advance_n;
// 7J A pins 2/14 receive A12, B pins 3/13 receive A11. Its physical
// Y1 is D000 and Y2 is C800; expose logical order C400,C800,D000,D800.
wire [3:0] selected_bank_n = ~(4'b0001 << cpu_addr[12:11]);
assign access_n = background_access_n ? 4'b1111 : selected_bank_n;
// 7H inverts the access gate. 4J NANDs it with RD and 2J XOR3; the
// original circuit uses RD high to distinguish writes, not a WR input.
assign write_n = (background_access_n || !cpu_rd_n || !write_clock) ? 4'b1111 : selected_bank_n;
assign lookahead_access_n = lookahead_n || advance_n;
// These are effective access/write tags, not 15K CE/WE pins. Sheet 16
// grounds CE15 and 16L selects +5 on WE13 when the access tag is high.
// Both tags must qualify a write; the RD/raster-phase level alone is insufficient.
assign lookahead_write_n = !(cpu_rd_n && write_clock);
endmodule

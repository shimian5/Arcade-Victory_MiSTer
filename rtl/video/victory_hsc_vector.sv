// SPDX-License-Identifier: GPL-3.0-or-later
// HSC 77-0004-01 sheet 10: PROM 13E's address and movement outputs.
// The accumulator and vector-finish latch supply the upper address bits.
module victory_hsc_vector (
	input  wire [2:0] octant,
	input  wire       carry, vector_finished,
	output wire [4:0] prom_addr,
	input  wire [7:0] prom_q,
	output wire       move_x, move_y, down, right
);
// 6331 pins 14,13,12,11,10 are A4..A0; output pins 9,7,6,5
// are D7..D4. The remaining four outputs are unconnected.
assign prom_addr = {vector_finished,carry,octant};
assign {move_x,move_y,down,right} = prom_q[7:4];
endmodule

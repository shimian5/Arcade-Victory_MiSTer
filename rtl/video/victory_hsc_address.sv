// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 8: seven LS151 address selectors, MPXRC row/column selection.
// Logical byte addresses are also exposed for FPGA block RAM. The physical
// 4116 address pins use the complemented W output (pin 6), not Y/pin 5.
module victory_hsc_address (
	input  wire [1:0]  address_select,
	input  wire       mpxrc,
	input  wire [15:0] instruction_address,
	input  wire [8:0]  program_counter,
	input  wire [7:0]  x, y, raster_e, raster_l,
	output reg  [13:0] byte_address,
	output wire [6:0]  dram_address
);
always @* begin
	case(address_select)
		0: byte_address = instruction_address[13:0];
		1: byte_address = {1'b0,y,x[7:3]};
		2: byte_address = {5'b10000,program_counter};
		3: byte_address = {1'b0,raster_l,raster_e[7:3]};
	endcase
end
// LS151 selects A/B/C at pins 11/10/9 = MPXRC/ASEL0/ASEL1.
// RAS falls while MPXRC is high: VRAMA7..1 carry I64..1 or their
// corresponding coordinate/PC bits. CAS falls with MPXRC low, selecting
// I8192..128. The PC high-column bit alone is +5; the other fixed inputs
// are grounded through the pin-7 stubs, crossing data wires without dots.
assign dram_address = ~(mpxrc ? byte_address[6:0] : byte_address[13:7]);
endmodule

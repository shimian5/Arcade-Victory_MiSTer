// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheets 11/12: SEA-selected source drivers. VDATA comes from the
// RGB CPU/program registers; BUFF is the DRAM read bus through LS241s;
// SR1/SR2 come from the Am25LS22 pairs. The encoded selector represents
// the four mutually exclusive active-low LS139 enables without tristates.
// read_rgb uses logical write-bit order, as the shared-RAM interface does.
module victory_hsc_source_bus (
	input  wire [1:0]  sea,
	input  wire [23:0] data_rgb, read_rgb, first_rgb, second_rgb,
	output reg  [23:0] source_rgb
);
always @* case(sea)
	0: source_rgb = data_rgb;
	1: source_rgb = read_rgb;
	2: source_rgb = first_rgb;
	3: source_rgb = second_rgb;
endcase
endmodule

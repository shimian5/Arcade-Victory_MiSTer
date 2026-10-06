// SPDX-License-Identifier: GPL-3.0-or-later
// Sheet 16 Q1..Q6 current-steering RGB drivers, normalized nominal transfer.
// Low 82S09 pins sink emitter current through 3.9k/2k/1k branches. Common
// transistor gain/output loading cancels in normalized full scale: 20:39:78.
// 14L Q5 drives Q7's blanking base; low removes drive from all three channels.
// Device tolerances, absolute voltage and bandwidth remain unmeasured.
module victory_hsc_rgb (
	input  wire [8:0] color_pins_n,
	input  wire       display_active,
	output wire [23:0] rgb
);
function automatic [7:0] normalized_channel(input [2:0] pins_n);
	case(~pins_n)
		3'd0: normalized_channel=8'd0;
		3'd1: normalized_channel=8'd37;
		3'd2: normalized_channel=8'd73;
		3'd3: normalized_channel=8'd110;
		3'd4: normalized_channel=8'd145;
		3'd5: normalized_channel=8'd182;
		3'd6: normalized_channel=8'd218;
		3'd7: normalized_channel=8'd255;
	endcase
endfunction
assign rgb=display_active ? {
	normalized_channel(color_pins_n[8:6]),normalized_channel(color_pins_n[2:0]),
	normalized_channel(color_pins_n[5:3])} : 24'd0;
endmodule

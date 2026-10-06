// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 16: 9K/9L/9M LS299s, 10L NAND mode gates and 10K
// endpoint mux. Read bytes use logical RGB bit order, as sheet 6's
// RAM outputs. Display clocks continue during game pause.
module victory_hsc_background_display (
	input  wire        clk, reset, ce_bit,
	input  wire        serial_load_n, screen_invert,
	input  wire [23:0] pattern_rgb,
	output wire [1:0]  serial_mode,
	output wire [2:0]  pixel_rgb,
	output wire [23:0] shift_rgb
);
// 10L pins 1/2 receive INVERT/SSELD and feed S1/pin19. Pins
// 5/4 receive S INVERT/SSELD and feed S0/pin1. SSELD low therefore
// selects parallel load in either orientation; otherwise one shift mode.
assign serial_mode[1] = !(!screen_invert && serial_load_n);
assign serial_mode[0] = !(screen_invert && serial_load_n);
// Both display banks wire logical bit7 to A/pin7, bit0 to H/pin16.
// 10K B3/6/10 select QA/pin8 when S INVERT=1; A2/5/11 select
// QH/pin17 otherwise. The previously verified sheet-14 bank has
// exactly this pin mapping, clear/OE ties and grounded serial inputs.
victory_hsc_display registers (
	.clk(clk), .reset(reset), .ce_bit(ce_bit), .serial_mode(serial_mode),
	.screen_invert(screen_invert), .read_data(pattern_rgb),
	.pixel_rgb(pixel_rgb), .shift_rgb(shift_rgb)
);
endmodule

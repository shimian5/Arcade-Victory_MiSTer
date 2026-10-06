// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 14: 1F/1E/1D LS299 and XH LS157. The DRAM read-data
// interface uses logical write-bit order. AX holds RVW7 and feeds pin 7/A;
// A5 holds RVW0 and feeds pin 16/H. Thus QA is write bit 7, QH write bit 0.
// screen_invert is the raw S INVERT wire: high selects QA/H-to-A shifting.
// Raster INVERT is its complement. Display shifting continues during pause.
// Production display registers consume the shared native RAM bus.
module victory_hsc_display (
	input  wire        clk, reset, ce_bit,
	input  wire [1:0]  serial_mode,
	input  wire        screen_invert,
	input  wire [23:0] read_data,
	output wire [2:0]  pixel_rgb,
	output wire [23:0] shift_rgb
);
genvar plane, pin_index;
generate for(plane=0;plane<3;plane=plane+1) begin: planes
	wire serial_a,serial_h;
	wire [7:0] parallel_pins;
	for(pin_index=0;pin_index<8;pin_index=pin_index+1) begin: ram_wires
		assign parallel_pins[pin_index] = read_data[plane*8+7-pin_index];
	end
	victory_74ls299 display_register (
		.clk(clk), .reset(reset), .ce_clock(ce_bit), .clear_n(1'b1),
		.mode(serial_mode), .serial_left(1'b0), .serial_right(1'b0),
		.output_enable_n(2'b11), .parallel_data(parallel_pins),
		.q(shift_rgb[plane*8+:8]), .serial_a(serial_a), .serial_h(serial_h),
		.parallel_driving()
	);
	assign pixel_rgb[plane] = screen_invert ? serial_a : serial_h;
end endgenerate
endmodule

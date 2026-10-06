// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheets 11/12: 4F/5F, 4E/5E and 4D/5D Am25LS22 pairs.
// SXFERX low loads the first stage and asynchronously clears the second.
// The second then receives the first's Q0 serial output; both shift right.
module victory_hsc_shift (
	input  wire        clk, reset, paused, ce_clock,
	input  wire        transfer_n, enable_n,
	input  wire [23:0] source_rgb,
	output wire [23:0] first_rgb, second_rgb
);
genvar plane;
generate for(plane=0;plane<3;plane=plane+1) begin: planes
	wire serial_link;
	victory_25ls22 first_stage (
		.clk(clk), .reset(reset), .paused(paused), .ce_clock(ce_clock),
		.clear_n(1'b1), .enable_n(enable_n), .parallel_n(transfer_n),
		.sign_extend_n(1'b1), .serial_select(1'b0), .serial_a(1'b0),
		.serial_b(1'b0), .output_enable_n(1'b1),
		.parallel_data(source_rgb[plane*8+:8]), .q(first_rgb[plane*8+:8]),
		.serial_out(serial_link), .output_driving()
	);
	victory_25ls22 second_stage (
		.clk(clk), .reset(reset), .paused(paused), .ce_clock(ce_clock),
		.clear_n(transfer_n), .enable_n(enable_n), .parallel_n(1'b1),
		.sign_extend_n(1'b1), .serial_select(1'b0), .serial_a(serial_link),
		.serial_b(1'b0), .output_enable_n(1'b1), .parallel_data(8'd0),
		.q(second_rgb[plane*8+:8]), .serial_out(), .output_driving()
	);
end endgenerate
endmodule

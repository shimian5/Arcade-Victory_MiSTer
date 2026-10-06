// SPDX-License-Identifier: GPL-3.0-or-later
// TI SDLS156: 8-bit universal shift/storage register. q[0] is QA (A),
// q[7] is QH (H); the manufacturer's "right" shifts A toward H.
// ce_clock represents a rising chip clock. Separate output ownership
// represents the bidirectional pins without internal FPGA tristates.
module victory_74ls299 (
	input  wire       clk, reset, ce_clock,
	input  wire       clear_n,
	input  wire [1:0] mode,
	input  wire       serial_left, serial_right,
	input  wire [1:0] output_enable_n,
	input  wire [7:0] parallel_data,
	output reg  [7:0] q,
	output wire       serial_a, serial_h, parallel_driving
);
assign serial_a = q[0];
assign serial_h = q[7];
assign parallel_driving = !(|output_enable_n) && mode!=2'b11;
always @(posedge clk) begin
	// CLR dominates all modes and does not require a chip clock edge.
	if(reset || !clear_n) q <= 0;
	else if(ce_clock) case(mode)
		2'b01: q <= {q[6:0],serial_right};
		2'b10: q <= {serial_left,q[7:1]};
		2'b11: q <= parallel_data;
		default: ;
	endcase
end
endmodule

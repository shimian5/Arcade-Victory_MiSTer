// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 9: 18C transfer NAND, 18B manual-increment NAND, 16D
// alignment NAND, and the first section of 15E with 17E's SRE NAND.
// 15E CLK/pin 3 joins WRITE EA, not the master-clock net crossing below it.
module victory_hsc_alignment_control (
	input  wire       clk, reset, paused,
	input  wire       write_ea, transfer_request, manual_increment,
	input  wire [2:0] x_low,
	output wire       transfer_n, increment_x, shift_enable_n
);
reg write_previous,transfer_latched;
assign transfer_n = !(write_ea && transfer_request);
assign increment_x = !(transfer_n && !(write_ea && manual_increment) && (&x_low));
assign shift_enable_n = !(transfer_latched && increment_x);
always @(posedge clk) begin
	if(reset) begin
		write_previous <= 0;
		transfer_latched <= 0;
	end else if(!paused) begin
		write_previous <= write_ea;
		if(write_ea && !write_previous) transfer_latched <= transfer_request;
	end
end
endmodule

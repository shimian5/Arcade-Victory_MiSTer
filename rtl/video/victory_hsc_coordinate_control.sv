// SPDX-License-Identifier: GPL-3.0-or-later
// HSC 77-0004-01 sheet 9: 18B manual-X NAND, 16C vector gates,
// 17C Y AND and the second section of 15E. Crossings without dots
// are separate nets: 18B pin 5 is REF EA; 16C pin 13 is WRITE EA.
module victory_hsc_coordinate_control (
	input  wire       clk, reset, paused, ce_master,
	input  wire       ref_ea, write_ea, move_x, move_y,
	input  wire [7:0] controls_b, controls_c,
	output reg        add_x_n,
	output wire       increment_y_n, vector_write
);
wire manual_x_n = !(controls_b[3] && ref_ea);
wire vector_x_n = !(controls_c[3] && write_ea && move_x);
// 16C ties two inputs together, combining the two active-low requests
// into 15E's D. Q-bar supplies both enable pins of the primary-X counters.
wire add_x_d = !(manual_x_n && vector_x_n);
assign vector_write = controls_c[3];
assign increment_y_n = controls_b[5] && !(controls_c[3] && move_y);
always @(posedge clk) begin
	if(reset) add_x_n <= 1;
	else if(!paused && ce_master) add_x_n <= !add_x_d;
end
endmodule

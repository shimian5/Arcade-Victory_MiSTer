// SPDX-License-Identifier: GPL-3.0-or-later
// AMD Am25LS22, datasheet 03622B, printed pages 9-57/9-59.
// ce_clock is a rising edge of the board's SCLK11; other inputs are pin levels.
// Output-enable is represented separately instead of FPGA internal tristates.
module victory_25ls22 (
	input  wire       clk, reset, paused, ce_clock,
	input  wire       clear_n, enable_n, parallel_n, sign_extend_n,
	input  wire       serial_select, serial_a, serial_b, output_enable_n,
	input  wire [7:0] parallel_data,
	output reg  [7:0] q,
	output wire       serial_out, output_driving
);
assign serial_out = q[0];
// The manufacturer's function table keeps the outputs enabled in HOLD
// even with S/P low. Parallel LOAD (RE low, S/P low) isolates the DY pins.
assign output_driving = !output_enable_n && (enable_n || parallel_n);
wire serial_input = !sign_extend_n ? q[7] : (serial_select ? serial_b : serial_a);
always @(posedge clk) begin
	// CLR is asynchronous to the chip's clock and overrides register enable.
	// Sample its level on SYS even when the emulated SCLK edge is absent.
	if(reset || !clear_n) q <= 0;
	else if(!paused && ce_clock && !enable_n)
		q <= !parallel_n ? parallel_data : {serial_input,q[7:1]};
end
endmodule

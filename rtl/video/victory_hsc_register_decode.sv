// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 7: LS08 gates 19H/19J combine CPU and program-register
// strobes. 18J LS151 selects the command's trigger register. All input
// and load strobes are active low; command_clock rises on load release.
module victory_hsc_register_decode (
	input  wire [7:0] cpu_load_n,
	input  wire       write_bus1_n, write_bus2_n,
	input  wire [2:0] command,
	output wire [7:0] register_load_n,
	output wire       command_clock
);
// Register order: IL, IH, CM, G, X-prime, Y-prime, R, B.
assign register_load_n = cpu_load_n & {
	1'b1, {3{write_bus2_n}}, 1'b1, {3{write_bus1_n}}
};
// 18J pin 5 is the non-inverted output. D0/D1/D6 are tied high;
// D2/D7 select B, D3 X-prime, D4 Y-prime and D5 IH. Sheet 7's
// +5 wire enters D6/pin 13; it crosses the CM-load return without
// a dot. Command 6 dispatches from a graphics program, not a CPU
// CM write. Using CM here falsely starts a command when leaving 6.
wire [7:0] trigger_pins = {
	register_load_n[7], 1'b1, register_load_n[1],
	register_load_n[5], register_load_n[4], register_load_n[7], 2'b11
};
assign command_clock = trigger_pins[command];
endmodule

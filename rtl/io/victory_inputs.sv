// SPDX-License-Identifier: GPL-3.0-or-later
module victory_inputs (
	input clk, input reset, input paused, input ce_frame,
	input [10:0] ps2_key, input [31:0] joystick,
	input signed [7:0] analog_x, input [8:0] spinner, input [24:0] mouse,
	output pause_button, output [7:0] dial,
	output [7:0] coin_port, output [7:0] button_port
);
	reg key_toggle = 0;
	reg [13:0] keys = 0;
	always @(posedge clk) begin
		key_toggle <= ps2_key[10];
		if (reset) keys <= 0;
		else if (key_toggle != ps2_key[10]) begin
			case (ps2_key[8:0])
				9'h174: keys[0] <= ps2_key[9]; // right
				9'h16b: keys[1] <= ps2_key[9]; // left
				9'h014: keys[4] <= ps2_key[9]; // Ctrl: thrust
				9'h011: keys[5] <= ps2_key[9]; // Alt: fire
				9'h029: keys[6] <= ps2_key[9]; // Space: shields
				9'h012: keys[7] <= ps2_key[9]; // Shift: doomsday
				9'h016: keys[8] <= ps2_key[9]; // 1: start 1
				9'h01e: keys[9] <= ps2_key[9]; // 2: start 2
				9'h02e: keys[10] <= ps2_key[9]; // 5: coin
				9'h005: keys[11] <= ps2_key[9]; // F1: service
				9'h04d: keys[12] <= ps2_key[9]; // P: pause
				9'h036: keys[13] <= ps2_key[9]; // 6: second coin mechanism
				default: ;
			endcase
		end
	end
	wire [13:0] controls = keys | joystick[13:0];
	assign pause_button = controls[12];
	assign coin_port = {5'b11111, ~controls[10], ~controls[13], 1'b1};
	assign button_port = ~{controls[4], controls[5], controls[7], controls[6], controls[8], controls[9], controls[11], 1'b0};
	// Victory's arcade knob is one relative axis. A USB trackball uses mouse X;
	// its Y axis is unused. Stick and D-pad movement are alternate host controls.
	wire [7:0] dial_position;
	trackball_input dial_axis (
		.clk_sys(clk), .reset(reset), .paused(paused), .ce_frame(ce_frame),
		.analog(analog_x), .dpad_neg(controls[1]), .dpad_pos(controls[0]),
		.spinner(spinner), .mouse({mouse[24], mouse[15:8]}),
		.mouse_invert(1'b0), .pos(dial_position)
	);
	// MAME declares PORT_REVERSE on Victory's dial.
	assign dial = 8'd0 - dial_position;
endmodule

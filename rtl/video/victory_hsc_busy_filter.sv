// SPDX-License-Identifier: GPL-3.0-or-later
// Sheet 4 R7=22 ohms, C27=0.01 uF feeds 14K LS241 pin 2 only.
// Nominal RC state at 48 MHz: alpha=1-exp(-20.833333 ns/220 ns).
// Ideal source rails and the hysteresis center are explicit assumptions;
// no PCB source impedance/threshold measurement is available. See HSC_ANALOG.md.
module victory_hsc_busy_filter #(
	parameter integer HIGH_UV=5000000, LOW_UV=0,
	parameter integer RISE_UV=1600000, FALL_UV=1200000,
	parameter [21:0] ALPHA_Q24=22'd1515846
) (
	input  wire        clk, reset, busy_in,
	output reg         busy_out,
	output reg  [23:0] voltage_uv
);
wire signed [24:0] target_uv=busy_in ? 25'(HIGH_UV) : 25'(LOW_UV);
wire signed [24:0] difference_uv=target_uv-$signed({1'b0,voltage_uv});
wire signed [46:0] correction_product=difference_uv*$signed(ALPHA_Q24);
wire signed [24:0] correction_uv=25'(correction_product >>> 24);
wire signed [24:0] next_voltage=$signed({1'b0,voltage_uv})+correction_uv;
always @(posedge clk) begin
	if(reset) begin voltage_uv<=24'(LOW_UV); busy_out<=0; end
	else begin
		voltage_uv<=24'(next_voltage);
		// LS241 has input hysteresis. Never treat the TTL guaranteed high/
		// low limits as two independent combinational threshold decisions.
		if(next_voltage>=25'(RISE_UV)) busy_out<=1;
		else if(next_voltage<=25'(FALL_UV)) busy_out<=0;
	end
end
endmodule

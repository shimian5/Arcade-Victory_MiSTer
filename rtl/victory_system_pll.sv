// SPDX-License-Identifier: GPL-3.0-or-later
// The 96 MHz reference uses a second counter of the same system PLL.
// It permits a fractional video PLL cascade without another board-clock port.
module victory_system_pll (
	input wire refclk, rst,
	output wire outclk_0, outclk_1, locked
);
	// Preserve the hierarchy matched by the framework timing constraints.
	victory_system_pll_clocks pll_inst (
		.refclk(refclk), .rst(rst), .clk_sys(outclk_0),
		.clk_reference(outclk_1), .locked(locked)
	);
endmodule

module victory_system_pll_clocks (
	input wire refclk, rst,
	output wire clk_sys, clk_reference, locked
);
	wire [1:0] clocks, cascade_clocks;
	assign clk_sys = clocks[0];
	assign clk_reference = cascade_clocks[1];
	altera_pll #(
		.fractional_vco_multiplier("false"),
		.reference_clock_frequency("50.0 MHz"), .operation_mode("direct"),
		.number_of_clocks(2),
		.output_clock_frequency0("48.000000 MHz"),
		.output_clock_frequency1("96.000000 MHz"),
		.phase_shift0("0 ps"), .phase_shift1("0 ps"),
		.duty_cycle0(50), .duty_cycle1(50),
		.pll_type("Cyclone V"), .pll_subtype("General"),
		.m_cnt_hi_div(48), .m_cnt_lo_div(48),
		.n_cnt_hi_div(3), .n_cnt_lo_div(2),
		.m_cnt_bypass_en("false"), .n_cnt_bypass_en("false"),
		.m_cnt_odd_div_duty_en("false"), .n_cnt_odd_div_duty_en("true"),
		.c_cnt_hi_div0(10), .c_cnt_lo_div0(10),
		.c_cnt_hi_div1(5), .c_cnt_lo_div1(5),
		.c_cnt_bypass_en0("false"), .c_cnt_bypass_en1("false"),
		.c_cnt_odd_div_duty_en0("false"), .c_cnt_odd_div_duty_en1("false"),
		.pll_vco_div(1), .pll_cp_current(5), .pll_bwctrl(18000),
		.pll_output_clk_frequency("960.000000 MHz"),
		.mimic_fbclk_type("gclk"),
		.pll_fbclk_mux_1("glb"), .pll_fbclk_mux_2("m_cnt"),
		.pll_m_cnt_in_src("ph_mux_clk"), .pll_slf_rst("true")
	) altera_pll_i (
		.refclk(refclk), .rst(rst), .outclk(clocks), .cascade_out(cascade_clocks),
		.locked(locked), .fboutclk(), .fbclk(1'b0)
	);
endmodule

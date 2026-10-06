// SPDX-License-Identifier: GPL-3.0-or-later
// Direct PLL output for the framework's clock selectors. Only transport is
// reconfigured; the dedicated native source PLL and 48 MHz board keep running.
module victory_output_pll (
	input wire refclk, reset,
	input wire [63:0] reconfig_to_pll,
	output wire [63:0] reconfig_from_pll,
	output wire clk_output, locked
);
	altera_pll #(
		.fractional_vco_multiplier("true"),
		.reference_clock_frequency("50.0 MHz"), .operation_mode("direct"),
		.number_of_clocks(1), .output_clock_frequency0("45.156000 MHz"),
		.phase_shift0("0 ps"), .duty_cycle0(50),
		.pll_type("Cyclone V"), .pll_subtype("Reconfigurable"),
		.m_cnt_hi_div(14), .m_cnt_lo_div(14),
		.m_cnt_bypass_en("false"), .m_cnt_odd_div_duty_en("false"),
		.n_cnt_hi_div(1), .n_cnt_lo_div(1),
		.n_cnt_bypass_en("true"), .n_cnt_odd_div_duty_en("false"),
		.c_cnt_hi_div0(16), .c_cnt_lo_div0(16),
		.c_cnt_bypass_en0("false"), .c_cnt_odd_div_duty_en0("false"),
		.pll_fractional_cout(32), .pll_fractional_division("3864784112"),
		.pll_dsm_out_sel("1st_order"), .pll_vco_div(1),
		.pll_cp_current(20), .pll_bwctrl(4000),
		.pll_output_clk_frequency("1444.992000 MHz"),
		.mimic_fbclk_type("gclk"), .pll_fbclk_mux_1("glb"),
		.pll_fbclk_mux_2("m_cnt"), .pll_m_cnt_in_src("ph_mux_clk"),
		.pll_slf_rst("true")
	) altera_pll_i (
		.refclk(refclk), .rst(reset), .outclk(clk_output), .locked(locked),
		.reconfig_to_pll(reconfig_to_pll), .reconfig_from_pll(reconfig_from_pll),
		.fboutclk(), .fbclk(1'b0)
	);
endmodule

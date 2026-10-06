// SPDX-License-Identifier: GPL-3.0-or-later
// Dedicated transport clock: eight cycles per native pixel at 45.156000 MHz.
// The 48 MHz board/audio PLL remains unchanged. No upstream IP is modified.
module victory_video_pll (
	input  wire refclk,
	output wire clk_video,
	output wire locked
);
	altera_pll #(
		.fractional_vco_multiplier("true"),
		.reference_clock_frequency("96.0 MHz"),
		.operation_mode("direct"),
		.number_of_clocks(1),
		.output_clock_frequency0("45.156000 MHz"),
		.phase_shift0("0 ps"),
		.duty_cycle0(50),
		// Native and output counters share the board reference through SYS.
		// 96 MHz * (15 + 223338685/2^32) / 32 matches the output
		// PLL's native rate and retains an exact 140:131 ratio to CRT.
		// PLL fractional synthesis does not change the fixed /8 pixel CE.
		.pll_type("Cyclone V"),
		.pll_clkin_0_src("adj_pll_clk"),
		.pll_subtype("General"),
		.m_cnt_hi_div(8), .m_cnt_lo_div(7),
		.n_cnt_hi_div(1), .n_cnt_lo_div(1),
		.m_cnt_bypass_en("false"), .n_cnt_bypass_en("true"),
		.m_cnt_odd_div_duty_en("true"), .n_cnt_odd_div_duty_en("false"),
		.c_cnt_hi_div0(16), .c_cnt_lo_div0(16),
		.c_cnt_bypass_en0("false"), .c_cnt_odd_div_duty_en0("false"),
		.pll_fractional_cout(32), .pll_fractional_division("223338685"),
		.pll_dsm_out_sel("1st_order"),
		.pll_vco_div(1),
		.pll_cp_current(20), .pll_bwctrl(4000),
		.pll_output_clk_frequency("1444.992000 MHz"),
		.mimic_fbclk_type("gclk"),
		.pll_fbclk_mux_1("glb"), .pll_fbclk_mux_2("m_cnt"),
		.pll_m_cnt_in_src("ph_mux_clk"), .pll_slf_rst("true")
	) altera_pll_i (
		.refclk(1'b0), .adjpllin(refclk), .rst(1'b0), .outclk(clk_video), .locked(locked),
		.fboutclk(), .fbclk(1'b0)
	);
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// CRT transport: fixed /8 pixels, 336x262, exact native frame cadence.
// Shared 50 MHz reference and Q32 counters give native:CRT exactly 140:131.
// Standalone counterpart of the production reconfigurable victory_output_pll.
// See sim/prove_crt_stream_schedule.py for the bounded line-store schedule.
module victory_crt_pll (
	input  wire refclk,
	output wire clk_crt, locked
);
	altera_pll #(
		.fractional_vco_multiplier("true"),
		.reference_clock_frequency("50.0 MHz"),
		.operation_mode("direct"), .number_of_clocks(1),
		.output_clock_frequency0("42.253114299 MHz"),
		.phase_shift0("0 ps"), .duty_cycle0(50),
		.pll_type("Cyclone V"), .pll_subtype("General"),
		// 50 MHz * (27 + 180359213/2^32) / 32.
		// Native fraction 3864783412 makes both 336-pixel raster frame periods equal.
		// Ownership checks still contain source/clock faults explicitly.
		.m_cnt_hi_div(14), .m_cnt_lo_div(13),
		.m_cnt_bypass_en("false"), .m_cnt_odd_div_duty_en("true"),
		.n_cnt_hi_div(1), .n_cnt_lo_div(1),
		.n_cnt_bypass_en("true"), .n_cnt_odd_div_duty_en("false"),
		.c_cnt_hi_div0(16), .c_cnt_lo_div0(16),
		.c_cnt_bypass_en0("false"), .c_cnt_odd_div_duty_en0("false"),
		.pll_fractional_cout(32), .pll_fractional_division("180359213"),
		.pll_dsm_out_sel("1st_order"),
		.pll_vco_div(1), .pll_cp_current(20), .pll_bwctrl(4000),
		.pll_output_clk_frequency("1352.099657 MHz"),
		.mimic_fbclk_type("gclk"),
		.pll_fbclk_mux_1("glb"), .pll_fbclk_mux_2("m_cnt"),
		.pll_m_cnt_in_src("ph_mux_clk"), .pll_slf_rst("true")
	) altera_pll_i (
		.refclk(refclk), .rst(1'b0), .outclk(clk_crt), .locked(locked),
		.fboutclk(), .fbclk(1'b0)
	);
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// Victory clock enables from a 48 MHz system clock.
module victory_clocks #(parameter HOLD_CPU_PHASE=0) (
	input clk, input reset, input paused,
	output ce_pix, output ce_cpu, output cpu_phi
);
	// Legacy simulation cadence: 5.6445 MHz = 11289 / 96000 of 48 MHz.
	// Production raster requests come from victory_video_bridge instead; this
	// fractional output is unconnected there and removed during synthesis.
	reg [16:0] pixel_phase = 0;
	wire [17:0] pixel_sum = {1'b0, pixel_phase} + 18'd11289;
	assign ce_pix = !reset && (pixel_sum >= 18'd96000);
	reg [3:0] cpu_div = 0;
	// The HSC WAIT circuit sees the CPU clock level between enable pulses.
	assign cpu_phi = cpu_div >= 4'd6;
	assign ce_cpu = !reset && !paused && (cpu_div == 4'd11);
	always @(posedge clk) begin
		if (reset) begin
			pixel_phase <= 0;
			cpu_div <= 0;
		end else begin
			pixel_phase <= (pixel_sum >= 18'd96000) ? 17'(pixel_sum - 18'd96000) : pixel_sum[16:0];
			// Native WAIT is clocked by phi as well as CPU enables. Hold both
			// together after the coordinator accepts an idle bus pause.
			if(!HOLD_CPU_PHASE || !paused)
				cpu_div <= (cpu_div == 4'd11) ? 4'd0 : cpu_div + 1'b1;
		end
	end
endmodule

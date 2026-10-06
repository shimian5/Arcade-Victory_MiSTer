// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheets 9/14: address/write NANDs, foreground write latch 16B and
// serial-register direction gates. Isolated until the RAM datapath is ready.
module victory_hsc_memory_control (
	input  wire       clk, reset, paused, ce_master,
	input  wire       ref_ea, write_ea, sr_load, screen_invert,
	input  wire [7:0] controls_d,
	input  wire [2:0] plane_enable,
	output wire [1:0] address_select,
	output wire       write_ea_n, write_vram_n,
	output wire       write_bus1_n, write_bus2_n,
	output reg        write_latched,
	output wire [2:0] plane_write_n,
	output wire [1:0] serial_mode
);
// 18D/18C qualify strobes with WRITE EA; address NANDs instead use REF EA.
// REF EA low forces selector 3, the raster refresh address.
assign address_select = ~(controls_d[1:0] & {2{ref_ea}});
assign write_ea_n     = !write_ea;
assign write_vram_n   = !(write_ea && controls_d[7]);
assign write_bus1_n   = !(write_ea && controls_d[6]);
assign write_bus2_n   = !(write_ea && controls_d[5]);
// Sheet 14 16B: D=S W VRAM, Q-bar pin 6 drives 6C and BIRWR.
// SCLK11 is the same inverted-crystal edge that advances clock latch 15A;
// sample the established phase before that latch updates its outputs.
always @(posedge clk) begin
	if(reset) write_latched <= 0;
	else if(!paused && ce_master) write_latched <= !write_vram_n;
end
assign plane_write_n = ~(plane_enable & {3{write_latched}});
// 8H pin 6 -> LS299 S0/pin 1; pin 8 -> S1/pin 19.
// SSR LOAD low selects parallel load in either screen orientation.
assign serial_mode = {!(sr_load && !screen_invert),!(sr_load && screen_invert)};
endmodule

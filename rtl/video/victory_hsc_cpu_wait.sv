// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 5: 5J request/feedback NANDs, 8J and both sections of 9J.
// This handshake arbitrates background/lookahead access, not HSC command
// triggers. Only 8J clocks on CPU phi. Both 9J sections use the sheet-5
// 2J XOR8 phase (scrolled E4 XOR INVERT), inverted for the first section.
// Pause must halt cpu_phi and hold the sampled edge/handshake state together.
// A pending SYS-delayed completion must not release SEAADV during that pause.
module victory_hsc_cpu_wait (
	input  wire clk, reset, paused, cpu_phi, raster_phase4,
	input  wire background_n, lookahead_n,
	output reg  wait_n,
	output wire advance_n
);
reg phi_previous, raster_previous, selected_previous, request_q, complete_q;
wire memory_selected = !(background_n && lookahead_n);
assign advance_n = !request_q;
always @(posedge clk) begin
	// Video keeps running during pause. Track its clock even when the
	// handshake state is held, so resuming cannot invent a raster edge.
	raster_previous <= raster_phase4;
	if(reset) begin
		phi_previous <= cpu_phi;
		selected_previous <= memory_selected;
		wait_n       <= 1;
		request_q    <= 0;
		complete_q   <= 0;
	end else if(!paused) begin
		phi_previous <= cpu_phi;
		selected_previous <= memory_selected;
		// 8J D12 = NAND(selected, 9J /Q8), CLK11 = CPU phi.
		// Sample the selection that existed at phi, before the CPU's bus
		// update. Phi detection is delayed one SYS edge in this model.
		if(cpu_phi && !phi_previous) wait_n <= !selected_previous || complete_q;
		// 9J first CLK3 sees inverted XOR8. /CLR1 is second /Q8.
		// A raster-edge completion can pulse before a post-edge MREQ release
		// clears 9J again. Its asynchronous clear of the first section must
		// survive even when the final sampled complete level is already low.
		if(complete_q || (raster_phase4 && !raster_previous && selected_previous && request_q)) request_q <= 0;
		else if(!raster_phase4 && raster_previous) request_q <= !wait_n;
		// 9J second /CLR13 is 5J's selected output, CLK11 = XOR8.
		if(!memory_selected) complete_q <= 0;
		else if(raster_phase4 && !raster_previous) complete_q <= request_q;
	end
end
endmodule

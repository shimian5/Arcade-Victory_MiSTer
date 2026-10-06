// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer pause extension, not an original-board circuit. Freeze commands
// after SEQ dispatch has settled and RAS has closed the previous byte.
// Keep the clock PROM/display running; resume at the identical phase/bank
// so held edge detectors cannot invent a sequencer or register clock.
module victory_hsc_pause (
	input  wire       clk, reset, request, ce_master,
	input  wire [4:0] clock_addr,
	input  wire       blanking_n, ras_n, write_latched,
	output reg        active
);
reg resume_bank;
always @(posedge clk) begin
	if(reset) begin
		active <= 0;
		resume_bank <= 0;
	end else if(ce_master && clock_addr[3:0]==4'd1 && ras_n && !write_latched) begin
		if(!active && request) begin
			active <= 1;
			// The clock bank latch samples blanking_n on this same edge.
			resume_bank <= blanking_n;
		end else if(active && !request && clock_addr[4]==resume_bank && blanking_n==resume_bank)
			active <= 0;
	end
end
endmodule

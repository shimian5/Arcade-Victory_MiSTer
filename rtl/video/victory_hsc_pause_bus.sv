// SPDX-License-Identifier: GPL-3.0-or-later
// MiSTer extension. Drain the current CPU cycle before freezing phi/WAIT.
// Raster ownership must be established before the foreground safe-phase
// pause is requested. This keeps display RAM available during the pause.
module victory_hsc_pause_bus (
	input  wire clk, reset, request, cpu_phi,
	input  wire mreq_n, iorq_n, rd_n, wr_n, advance_n,
	input  wire drawing_paused,
	output reg  cpu_hold,
	output wire drawing_request
);
reg phi_previous, idle_previous;
wire idle = mreq_n && iorq_n && rd_n && wr_n && advance_n;
assign drawing_request = cpu_hold && request;
always @(posedge clk) begin
	phi_previous <= cpu_phi;
	idle_previous <= idle;
	if(reset) cpu_hold <= 0;
	else if(!cpu_hold) begin
		// Phi's rising half-cycle precedes the next TV80 enable. Bus
		// strobes and any release-edge board write have already settled.
		if(request && cpu_phi && !phi_previous && idle && idle_previous)
			cpu_hold <= 1;
	end else if(!request && !drawing_paused) cpu_hold <= 0;
end
endmodule

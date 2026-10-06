// SPDX-License-Identifier: GPL-3.0-or-later
// CPU/audio drawing 77-0005-01 sheet 1: both H6 LS74 sections and N6 LS08.
// Both flip-flops use physical phi rising edges. First Q9 feeds N6 and the
// second D2; second Q5 returns to first /PRE10. A low second Q asynchronously
// presets first Q, releasing the local memory delay. SWAIT is HSC-originated.
// Pause must halt cpu_phi and retain this sampled model's pending edge as
// well; otherwise an edge detected after pause can consume a RAM write slot.
module victory_cpu_wait (
	input  wire clk, reset, paused, cpu_phi, mreq_n, hsc_wait_n,
	output wire wait_n
);
reg phi_previous, mreq_previous_n, first_q, second_q;
assign wait_n = hsc_wait_n && first_q;
always @(posedge clk) begin
	if(reset) begin
		phi_previous <= cpu_phi;
		mreq_previous_n <= mreq_n;
		first_q      <= 1;
		second_q     <= 1;
	end else if(!paused) begin
		phi_previous <= cpu_phi;
		mreq_previous_n <= mreq_n;
		if(cpu_phi && !phi_previous) begin
			second_q <= first_q;
			// The new second Q can assert /PRE after this same physical
			// edge. Fold that asynchronous settling into the SYS update.
			// Phi is generated on a SYS edge and detected one edge later.
			// H6 saw the pre-phi MREQ, not the CPU's post-edge bus update.
			first_q <= (!second_q || !first_q) ? 1'b1 : mreq_previous_n;
		end else if(!second_q) first_q <= 1;
	end
end
endmodule

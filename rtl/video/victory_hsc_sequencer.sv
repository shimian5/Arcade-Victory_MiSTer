// SPDX-License-Identifier: GPL-3.0-or-later
// HSC 77-0004-01 sheets 8/9: 19F's low-address counter, 16E's
// gated high-address flip-flop and command-ready latch.
module victory_hsc_sequencer (
	input  wire       clk, reset, paused,
	input  wire       seq_clk, command_clock,
	input  wire [7:0] prom_b, prom_c, prom_d, prom_e,
	input  wire [2:0] command,
	input  wire       command_continue, htc, ltc, vector_finished,
	output reg  [4:0] state_addr,
	output wire       ready_n, busy, zero_ram,
	output wire [1:0] sea,
	output wire [7:0] controls_b, controls_c, controls_d
);
reg ready;
reg seq_previous, command_previous, branch_previous;
wire load_state;
wire [4:0] next_addr;
// Sheet 8: 14E inverts the raw SEQ CLK to S SEQ CLK. Sheet 9:
// 17E NANDs that signal with the non-inverted 18E condition output.
// A condition falling during the low half-cycle is also a clock edge;
// it must not be collapsed into an unconditional five-bit assignment.
wire branch_clock = !(!seq_clk && load_state);
// 17E pins 2/1 receive 19C pin 2 (C1) and 19E pin 6 (BUSY).
// Its output pin 3 returns to 16E /CLR13. The long return crosses
// S SEQ CLK without a junction; clearing on SEQ loses valid CPU writes.
wire ready_clear_n = !(prom_c[1] && busy);
assign ready_n = !ready;
victory_hsc_decode decode (
	.state_addr(state_addr), .prom_b(prom_b), .prom_c(prom_c),
	.prom_d(prom_d), .prom_e(prom_e), .command(command),
	.command_continue(command_continue), .ready_n(ready_n),
	.htc(htc), .ltc(ltc), .vector_finished(vector_finished),
	.next_addr(next_addr), .load_state(load_state), .busy(busy),
	.zero_ram(zero_ram), .sea(sea), .controls_b(controls_b),
	.controls_c(controls_c), .controls_d(controls_d)
);
always @(posedge clk) begin
	if(reset) begin
		state_addr <= 0;
		ready <= 0;
		seq_previous <= seq_clk;
		command_previous <= command_clock;
		branch_previous <= 1;
	end else if(!paused) begin
		seq_previous <= seq_clk;
		command_previous <= command_clock;
		branch_previous <= branch_clock;
		// 16E's second section has D tied high, CLK=S SETRDY and
		// asynchronous /CLR=17E output 3. Clear dominates a coincident
		// command clock while the PROM requests command acknowledgement.
		if(!ready_clear_n) ready <= 0;
		else if(command_clock && !command_previous) ready <= 1;
		if(seq_clk && !seq_previous) state_addr[3:0] <= next_addr[3:0];
		if(branch_clock && !branch_previous) state_addr[4] <= prom_e[4];
	end
end
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 8: I counters 12C/11C/12B/14B, PC counters 9B/7B,
// PC bit zero at 12E. CPU strobes and shared RAM phases connect through
// the production PROM datapath rather than behavioral command handlers.
module victory_hsc_counters (
	input  wire        clk, reset, paused, ce_master, seq_clk,
	input  wire        write_ea, increment_i, increment_pc,
	input  wire        load_il_n, load_ih_n, load_pc_n,
	input  wire [7:0]  red_bus, blue_bus, y_prime,
	output reg  [15:0] instruction_address,
	output reg  [8:0]  program_counter
);
reg seq_previous;
wire i_enable = write_ea && increment_i;
// 9E NOR plus 14E inverter drives 12E /CLR. Only the PC load
// instruction's WRITE EA window clears the odd/even bit; the upper
// eight bits load synchronously from Y-prime on raw SEQ CLK rising.
wire pc_bit_clear_n = load_pc_n || increment_pc || !write_ea;
always @(posedge clk) begin
	if(reset) begin
		instruction_address <= 0;
		program_counter <= 0;
		seq_previous <= seq_clk;
	end else if(!paused) begin
		seq_previous <= seq_clk;
		if(ce_master) begin
			// Synchronous /LOAD wins over counting in each byte. The
			// terminal-carry chain uses pre-edge outputs, independently
			// of /LOAD, so a simultaneous low-byte load can carry upward.
			if(!load_il_n) instruction_address[7:0] <= red_bus;
			else if(i_enable) instruction_address[7:0] <= instruction_address[7:0] + 8'd1;
			if(!load_ih_n) instruction_address[15:8] <= blue_bus;
			else if(i_enable && instruction_address[7:0]==8'hff)
				instruction_address[15:8] <= instruction_address[15:8] + 8'd1;
		end
		if(!pc_bit_clear_n) program_counter[0] <= 0;
		else if(seq_clk && !seq_previous && increment_pc)
			program_counter[0] <= !program_counter[0];
		if(seq_clk && !seq_previous) begin
			if(!load_pc_n) program_counter[8:1] <= y_prime;
			else if(increment_pc && program_counter[0])
				program_counter[8:1] <= program_counter[8:1] + 8'd1;
		end
	end
end
endmodule

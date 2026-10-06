// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 2: 17A (74LS161), 16B (74LS74) and 15A (74S374).
// ce_master represents each inverted-crystal rising edge; PROM 16A is
// asynchronous and must settle before the next enabled edge.
module victory_hsc_clock (
	input  wire       clk, reset, ce_master,
	input  wire       blanking_n,
	output wire [4:0] prom_addr,
	input  wire [7:0] prom_q,
	output reg  [7:0] phase_outputs,
	output reg        seq_rise, seq_fall,
	output wire       e4clk, mpxrc, bit_clk, ref_ea, seq_clk,
	output wire       write_ea, sr_load, cas_n, ras_n
);
reg [3:0] master_count;
reg blanking_q;
assign prom_addr = {blanking_q,master_count};
// 17A pin 11 is QD. E4CLK is the /16 raster-counter clock; the
// serial pixel clock is the separate /2 S BIT CLK from PROM/latch bit 1.
assign e4clk = master_count[3];
// PROM output pins 1,2,3,4,5,6,7,9 connect to latch inputs
// 8,7,4,3,13,14,17,18. Pin order is different from latch bit order.
// Follow the bends below 15A: pin 12 feeds SSR LOAD, while pin 15
// feeds WRITE EA. Their horizontal labels appear in the opposite order.
assign {ras_n,cas_n,write_ea,sr_load,seq_clk,mpxrc,bit_clk,ref_ea} = phase_outputs;
always @(posedge clk) begin
	seq_rise <= 0;
	seq_fall <= 0;
	if(reset) begin
		master_count <= 0;
		blanking_q <= 0;
		phase_outputs <= 8'hff;
	end else if(ce_master) begin
		master_count <= master_count + 4'd1;
		blanking_q <= blanking_n;
		phase_outputs <= prom_q;
		seq_rise <= !phase_outputs[3] && prom_q[3];
		seq_fall <= phase_outputs[3] && !prom_q[3];
	end
end
endmodule

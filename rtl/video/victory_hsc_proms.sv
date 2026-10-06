// SPDX-License-Identifier: GPL-3.0-or-later
// HSC's seven physical PROMs need simultaneous asynchronous read ports.
// Preserve the MRA download layout; small chip banks avoid replicating the
// entire PROM image for every reader. Payloads arrive from ioctl, not RTL.
module victory_hsc_proms (
	input  wire        clk, download, wr,
	input  wire [15:0] index,
	input  wire [26:0] addr,
	input  wire [7:0]  data,
	input  wire [7:0]  cpu_addr,
	input  wire [4:0]  clock_addr, state_addr, vector_addr,
	output wire [3:0]  cpu_q,
	output wire [7:0]  clock_q, prom_b, prom_c, prom_d, prom_e, vector_q
);
reg [3:0] cpu_decode [0:255];
reg [7:0] vector_decode [0:31], clock_decode [0:31];
reg [7:0] state_b [0:31], state_c [0:31], state_d [0:31], state_e [0:31];
initial begin
	for(integer offset=0;offset<256;offset=offset+1) cpu_decode[offset]=4'hf;
	for(integer offset=0;offset<32;offset=offset+1) begin
		vector_decode[offset]=8'hff;
		clock_decode[offset]=8'hff;
		state_b[offset]=8'hff;
		state_c[offset]=8'hff;
		state_d[offset]=8'hff;
		state_e[offset]=8'hff;
	end
end
assign cpu_q    = cpu_decode[cpu_addr];
assign vector_q = vector_decode[vector_addr];
assign clock_q  = clock_decode[clock_addr];
assign prom_b   = state_b[state_addr];
assign prom_c   = state_c[state_addr];
assign prom_d   = state_d[state_addr];
assign prom_e   = state_e[state_addr];
always @(posedge clk) begin
	if(download && wr && index==0 && addr>=27'h10000 && addr<27'h101e0) begin
		if(addr<27'h10100) cpu_decode[addr[7:0]] <= data[3:0];
		else case(addr[7:5])
			3'd0: vector_decode[addr[4:0]] <= data;
			3'd1: clock_decode[addr[4:0]]  <= data;
			3'd2: state_b[addr[4:0]]       <= data;
			3'd3: state_c[addr[4:0]]       <= data;
			3'd4: state_d[addr[4:0]]       <= data;
			3'd5: state_e[addr[4:0]]       <= data;
			default: ;
		endcase
	end
end
endmodule

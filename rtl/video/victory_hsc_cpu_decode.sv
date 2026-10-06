// SPDX-License-Identifier: GPL-3.0-or-later
// HSC 77-0004-01 sheet 1: 17L PROM, 19L/18L/19K/18K LS138s,
// 12H bus-selection OR and 12L address inverter. Register strobes are
// levels from the live Z80 bus; their release edges clock HSC registers.
module victory_hsc_cpu_decode (
	input  wire [15:0] cpu_addr,
	input  wire        mreq_n, rd_n, wr_n,
	output wire [7:0]  prom_addr,
	input  wire [3:0]  prom_q,
	output wire        bus_select_n, lookahead_n, background_n,
	output wire [7:0]  register_load_n, status_read_n, auxiliary_load_n
);
wire [7:0] region_n = mreq_n ? 8'hff : ~(8'b1 << prom_q[2:0]);
assign prom_addr = cpu_addr[15:8];
// 17L output pin 9 is bit 3. 12H ORs it with MREQ; the returned
// active-low BSEL controls the CPU board's data-bus transceiver.
assign bus_select_n = prom_q[3] || mreq_n;
assign lookahead_n  = region_n[3];
assign background_n = region_n[2];
// 19K G1=!A3, /G2A=WR, /G2B=REGWR. 18K instead uses A3.
// Address bits 7:4 are not decoded: all sixteen register blocks alias.
assign register_load_n = (region_n[1] || wr_n || cpu_addr[3]) ?
	8'hff : ~(8'b1 << cpu_addr[2:0]);
assign auxiliary_load_n = (region_n[1] || wr_n || !cpu_addr[3]) ?
	8'hff : ~(8'b1 << cpu_addr[2:0]);
// 18L G1=+5, /G2A=RD, /G2B=REGRD. A3 is not decoded here.
assign status_read_n = (region_n[0] || rd_n) ?
	8'hff : ~(8'b1 << cpu_addr[2:0]);
endmodule

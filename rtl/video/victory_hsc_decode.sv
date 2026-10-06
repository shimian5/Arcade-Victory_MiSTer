// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 9's next-address selection and raw PROM control outputs.
// Inputs are the actual 19B/C/D/E bytes at state_addr. This development
// decoder does not replace the production command FSM or RAM arbitration.
module victory_hsc_decode (
	input  wire [4:0] state_addr,
	input  wire [7:0] prom_b, prom_c, prom_d, prom_e,
	input  wire [2:0] command,
	input  wire       command_continue, ready_n, htc, ltc, vector_finished,
	output wire [4:0] next_addr,
	output wire       load_state, busy, zero_ram,
	output wire [1:0] sea,
	output wire [7:0] controls_b, controls_c, controls_d
);
// 18E (74LS151): D0=GND, D1=HTC, D2=/LTC, D3=/SETRDY,
// D4=/CM7, D5=VFIN, D6/D7=+5. 19D bits 4:2 select the input.
wire [7:0] conditions = {2'b11,vector_finished,!command_continue,ready_n,!ltc,htc,1'b0};
assign load_state = conditions[prom_d[4:2]];
// 18F selects CM0..2 (D3 grounded) when 19E bit 6 is high.
// 19F's low nibble increments otherwise; 16E's high bit holds on
// that path. A low-nibble rollover does not carry into the high bit.
assign next_addr = load_state ?
	{prom_e[4],(prom_e[6] ? {1'b0,command} : prom_e[3:0])} :
	{state_addr[4],(state_addr[3:0] + 4'd1)};
assign busy = prom_e[5];
assign zero_ram = !prom_e[7];
assign sea = prom_c[6:5];
assign controls_b = prom_b;
assign controls_c = prom_c;
assign controls_d = prom_d;
endmodule

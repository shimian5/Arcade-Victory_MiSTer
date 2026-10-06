// SPDX-License-Identifier: GPL-3.0-or-later
// Exidy audio sheet 9: MC6840, CD4006/CD4070 and volume latches.
module victory_effects (
	input  wire        clk, reset, paused, ce, e_clock,
	input  wire        rd, wr, volume_wr,
	input  wire [2:0]  addr,
	input  wire [7:0]  data,
	output wire [7:0]  q,
	output wire [15:0] sample,
	output wire [2:0]  audio_gates,
	output wire [8:0]  volume_taps,
	output wire        unsupported_mode
);
reg [2:0] volume[0:2];
reg [7:0] sfx_control;
wire [2:0] timer_pins;
wire noise_level;
wire [15:0] amplitude[0:2];
victory_6840 ptm (
	.clk(clk), .reset(reset), .paused(paused), .ce(ce), .rd(rd), .wr(wr),
	.addr(addr), .data(data), .clock_in({3{noise_level}}), .gate_in(3'b000),
	.q(q), .timer_out(timer_pins), .irq_n()
);
// The 6840 IRQ pin is not part of this board's CPU interrupt network.
// A0 is the actual CPU address pin, including accesses outside this device.
// Q1 is the physical output after CR1's output-enable mask.
victory_noise noise (
	.clk(clk), .reset(reset), .paused(paused), .e_clock(e_clock),
	.q1(timer_pins[0]), .select_q1(sfx_control[0]), .address_a0(addr[0]),
	.noise_level(noise_level)
);
function automatic [15:0] gain(input [2:0] value);
	case(value)
		// Unloaded taps of the 5330-ohm shared ladder; the analog
		// network's loading/coupling is modeled separately.
		0: gain=40; 1: gain=80; 2: gain=164; 3: gain=328;
		4: gain=666; 5: gain=1363; 6: gain=2695; 7: gain=5461;
	endcase
endfunction
assign amplitude[0] = timer_pins[0] && !sfx_control[1] ? gain(volume[0]) : 16'd0;
assign amplitude[1] = timer_pins[1] ? gain(volume[1]) : 16'd0;
assign amplitude[2] = timer_pins[2] ? gain(volume[2]) : 16'd0;
assign sample = amplitude[0]+amplitude[1]+amplitude[2];
assign audio_gates = {timer_pins[2:1],timer_pins[0] && !sfx_control[1]};
assign volume_taps = {volume[2],volume[1],volume[0]};
// All eight manufacturer-defined modes are implemented by the timer.
assign unsupported_mode = 1'b0;
always @(posedge clk) begin
	if(reset) begin
		for(integer ch=0; ch<3; ch++) volume[ch] <= 0;
		sfx_control <= 0;
	end else if(!paused && ce && volume_wr) begin
		if(addr[1:0]==0) sfx_control <= data;
		else volume[addr[1:0]-1] <= data[2:0];
	end
end
endmodule

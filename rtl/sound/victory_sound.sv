// SPDX-License-Identifier: GPL-3.0-or-later
// Victory sound board: 6502, RIOT, PIA, 8253 music, 6840 effects and speech.
module victory_sound (
	input  wire         clk, reset, paused,
	input  wire         command_wr, response_rd,
	input  wire [7:0]   command,
	output wire [7:0]   response, status,
	output wire [13:0]  rom_addr,
	input  wire [7:0]   rom_q,
	output wire signed [15:0] audio,
	output wire [15:0]  cpu_addr,
	output wire         cpu_sync, cpu_rwn,
	output wire         unsupported_mode
);
reg [25:0] crystal_phase;
wire [26:0] crystal_sum={1'b0,crystal_phase}+27'd3579545;
wire crystal_ce=crystal_sum>=27'd48000000;
reg [1:0] crystal_div;
reg pit_clock;
wire ce_cpu=crystal_ce && crystal_div==3 && !paused;
reg [6:0] speech_div;
wire ce_speech=speech_div==74 && !paused;
always @(posedge clk) begin
	if(reset) begin crystal_phase<=0; crystal_div<=0; pit_clock<=0; speech_div<=0; end
	else if(!paused) begin
		crystal_phase<=crystal_ce ? 26'(crystal_sum-27'd48000000) : crystal_sum[25:0];
		if(crystal_ce) begin crystal_div<=crystal_div+2'd1; pit_clock<=!pit_clock; end
		speech_div<=speech_div==74 ? 7'd0 : speech_div+7'd1;
	end
end
wire [23:0] cpu_a;
wire [7:0] cpu_data,cpu_q,riot_q,pia_q,effects_q;
wire riot_irq_n,pia_irq;
T65 cpu (
	.Mode(2'b00), .BCD_en(1'b1), .Res_n(!reset), .Enable(ce_cpu), .Clk(clk), .Rdy(1'b1),
	.Abort_n(1'b1), .IRQ_n(riot_irq_n && !pia_irq), .NMI_n(1'b1), .SO_n(1'b1),
	.R_W_n(cpu_rwn), .Sync(cpu_sync), .EF(), .MF(), .XF(), .ML_n(), .VP_n(), .VDA(), .VPA(), .PH3(),
	.A(cpu_a), .DI(cpu_q), .DO(cpu_data), .Regs(), .NMI_ack()
);
assign cpu_addr=cpu_a[15:0];
assign rom_addr=cpu_addr[13:0];
reg [7:0] ram[0:255];
reg [7:0] ram_q;
initial for(integer i=0;i<256;i++) ram[i]=0;
wire bus_rd=ce_cpu && cpu_rwn;
wire bus_wr=ce_cpu && !cpu_rwn;
always @(posedge clk) begin
	ram_q<=ram[cpu_addr[7:0]];
	if(bus_wr && cpu_addr[15:12]==0 && !reset) ram[cpu_addr[7:0]]<=cpu_data;
end
assign cpu_q=!cpu_rwn ? cpu_data : cpu_addr[15:12]==0 ? ram_q :
	cpu_addr[15:12]==1 ? riot_q : cpu_addr[15:12]==2 ? pia_q :
	cpu_addr[15:12]==5 ? effects_q : cpu_addr>=16'hc000 ? rom_q : 8'd0;
wire [7:0] speech_status,speech_data,riot_pb;
wire speech_ready_n,speech_irq_n;
victory_riot riot (
	.clk(clk), .reset(reset), .ce(ce_cpu), .rd(bus_rd && cpu_addr[15:12]==1),
	.wr(bus_wr && cpu_addr[15:12]==1), .addr(cpu_addr[4:0]), .data(cpu_data),
	.pa_in(speech_status), .pb_in({4'd0,speech_irq_n,speech_ready_n,2'd0}),
	.q(riot_q), .pa_out(speech_data), .pb_out(riot_pb), .irq_n(riot_irq_n)
);
wire ca2,cb2;
reg ca1,cb1,cb2_d;
reg [7:0] command_latch;
always @(posedge clk) begin
	if(reset) begin ca1<=1; cb1<=1; cb2_d<=1; command_latch<=0; end
	else if(!paused) begin
		cb2_d<=cb2;
		if(!ca2) ca1<=1;
		if(cb2_d && !cb2) cb1<=1;
		if(command_wr) begin command_latch<=command; ca1<=0; end
		if(response_rd) cb1<=0;
	end
end
assign status={ca1,cb1,6'd0};
victory_pia pia (
	.clk(clk), .reset(reset), .paused(paused), .rd(bus_rd && cpu_addr[15:12]==2),
	.wr(bus_wr && cpu_addr[15:12]==2), .addr(cpu_addr[1:0]), .data(cpu_data),
	.pa_in(command_latch), .pb_in(8'd0), .ca1(ca1), .cb1(cb1), .q(pia_q),
	.pb_out(response), .ca2(ca2), .cb2(cb2), .irq_a(pia_irq)
);
// KF8253 consumes writes on WR's rising edge. Retain the CPU bus through
// both strobe phases, rather than releasing its address with the CPU CE.
reg [1:0] pit_pending,pit_addr;
reg [7:0] pit_data;
always @(posedge clk) begin
	if(reset) begin pit_pending<=0; pit_addr<=0; pit_data<=0; end
	else if(!paused) begin
		if(pit_pending!=0) pit_pending<=pit_pending-2'd1;
		if(bus_wr && cpu_addr[15:12]==3) begin pit_pending<=3; pit_addr<=cpu_addr[1:0]; pit_data<=cpu_data; end
	end
end
wire [2:0] pit_out;
// KF8253 updates its outputs on the falling system-clock edge. Capture
// those three bits before the mixer so the half-cycle path has no adders.
reg [2:0] pit_sample;
always @(posedge clk) begin
	if(reset) pit_sample<=0;
	else if(!paused) pit_sample<=pit_out;
end
KF8253 music (
	.clock(clk), .reset(reset), .chip_select_n(pit_pending==0), .read_enable_n(1'b1),
	.write_enable_n(pit_pending<2), .address(pit_addr), .data_bus_in(pit_data), .data_bus_out(),
	.counter_0_clock(pit_clock), .counter_0_gate(1'b1), .counter_0_out(pit_out[0]),
	.counter_1_clock(pit_clock), .counter_1_gate(1'b1), .counter_1_out(pit_out[1]),
	.counter_2_clock(pit_clock), .counter_2_gate(1'b1), .counter_2_out(pit_out[2])
);
wire [15:0] effects_sample;
wire [2:0] effects_gates;
wire [8:0] volume_taps;
victory_effects effects (
	.clk(clk), .reset(reset), .paused(paused), .ce(ce_cpu), .e_clock(crystal_div[1]), .rd(bus_rd && cpu_addr[15:12]==5),
	.wr(bus_wr && cpu_addr[15:12]==5), .volume_wr(bus_wr && cpu_addr[15:12]==6),
	.addr(cpu_addr[2:0]), .data(cpu_data), .q(effects_q), .sample(effects_sample),
	.audio_gates(effects_gates), .volume_taps(volume_taps), .unsupported_mode(unsupported_mode)
);
wire signed [13:0] speech_sample;
TMS5220 speech (
	.I_OSC(clk), .I_ENA(reset || ce_speech), .I_WSn(reset ? 1'b0 : riot_pb[1]),
	.I_RSn(reset ? 1'b0 : riot_pb[0]), .I_DATA(1'b0), .I_TEST(1'b0), .I_DBUS(speech_data),
	.O_DBUS(speech_status), .O_RDYn(speech_ready_n), .O_INTn(speech_irq_n),
	.O_M0(), .O_M1(), .O_ADD8(), .O_ADD4(), .O_ADD2(), .O_ADD1(), .O_ROMCLK(),
	.O_T11(), .O_IO(), .O_PRMOUT(), .O_SPKR(speech_sample)
);
// Integrate the switched sources over each 48 kHz interval. Sampling a
// timer pin just once aliases high-frequency counters into audible tones.
// Volume capacitors are before the CD4053 switches, not in series with audio.
reg [9:0] sample_div;
reg [11:0] music_high_count;
reg [25:0] effects_voltage_sum;
wire signed [31:0] volume_0,volume_1,volume_2;
wire [1:0] music_step={1'b0,pit_sample[0]}+{1'b0,pit_sample[1]}+{1'b0,pit_sample[2]};
wire [16:0] effects_step=(effects_gates[0] ? 17'(volume_0[24:8]) : 17'd0)+
	(effects_gates[1] ? 17'(volume_1[24:8]) : 17'd0)+(effects_gates[2] ? 17'(volume_2[24:8]) : 17'd0);
wire [11:0] music_next=music_high_count+{10'd0,music_step};
wire [25:0] effects_next=effects_voltage_sum+{9'd0,effects_step};
wire signed [31:0] speech_voltage=$signed({{18{speech_sample[13]}},speech_sample}) <<< 7;
wire signed [15:0] audio_sample;
victory_audio analog (
	.clk(clk), .reset(reset), .paused(paused), .sample_ce(sample_div==999),
	.speech_input(speech_voltage), .music_input($signed({4'd0,music_next,16'd0})),
	.effects_input($signed({2'd0,effects_next,4'd0})), .volume_taps(volume_taps),
	.sample(audio_sample), .volume_0(volume_0), .volume_1(volume_1), .volume_2(volume_2),
	.busy(), .overrun()
);
always @(posedge clk) begin
	if(reset) begin sample_div<=0; music_high_count<=0; effects_voltage_sum<=0; end
	else if(!paused) begin
		sample_div<=sample_div==999 ? 10'd0 : sample_div+10'd1;
		if(sample_div==999) begin
			music_high_count<=0; effects_voltage_sum<=0;
		end else begin music_high_count<=music_next; effects_voltage_sum<=effects_next; end
	end
end
assign audio=reset || paused ? 16'sd0 : audio_sample;
endmodule

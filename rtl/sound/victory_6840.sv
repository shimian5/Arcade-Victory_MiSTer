// SPDX-License-Identifier: GPL-3.0-or-later
// MC6840, Motorola DS9802R3 (1988), tables 1-8 and figure 10.
// ce is the falling E edge. Bus strobes are valid on that same edge.
// C/G inputs are levels, not event enables: recognition is on the fourth E.
module victory_6840 (
	input  wire        clk, reset, paused, ce,
	input  wire        rd, wr,
	input  wire [2:0]  addr,
	input  wire [7:0]  data,
	input  wire [2:0]  clock_in, gate_in,
	output wire [7:0]  q,
	output wire [2:0]  timer_out,
	output wire        irq_n
);
reg [7:0] control[0:2];
reg [15:0] latch[0:2], counter[0:2];
reg [7:0] msb_buffer, lsb_buffer;
reg [2:0] output_state, interrupt_flag, status_seen;
reg [2:0] enabled, timed_out, shot_done, shot_valid;
reg [2:0] clock_pipe[0:2], gate_pipe[0:2];
reg [2:0] clock_last, gate_last;
reg [2:0] prescale_e, prescale_c;
reg clock_c3_last;
wire [2:0] clock_sample = {control[2][0] && !control[2][1] ?
	prescale_c[2] : clock_in[2],clock_in[1:0]};
wire [2:0] clock_fall = clock_last & ~clock_pipe[2];
wire [2:0] gate_fall = gate_last & ~gate_pipe[2];
wire [2:0] gate_rise = ~gate_last & gate_pipe[2];
wire [2:0] irq_enable = {control[2][6],control[1][6],control[0][6]};
wire [2:0] output_enable = {control[2][7],control[1][7],control[0][7]};
assign irq_n = !(|(interrupt_flag & irq_enable));
assign timer_out = output_state & output_enable;
assign q = addr==0 ? 8'd0 : addr==1 ? {!irq_n,4'd0,interrupt_flag} :
	addr[0] ? lsb_buffer : counter[(addr>>1)-1][15:8];

always @(posedge clk) begin
	if(reset) begin
		for(integer ch=0; ch<3; ch++) begin
			control[ch] <= ch==0 ? 8'h01 : 8'h00;
			latch[ch] <= 16'hffff;
			counter[ch] <= 16'hffff;
			clock_pipe[ch] <= clock_sample;
			gate_pipe[ch] <= gate_in;
		end
		msb_buffer <= 0;
		lsb_buffer <= 0;
		output_state <= 0;
		interrupt_flag <= 0;
		status_seen <= 0;
		enabled <= 0;
		timed_out <= 0;
		shot_done <= 0;
		shot_valid <= 0;
		prescale_e <= 0;
		prescale_c <= 0;
		clock_c3_last <= clock_in[2];
		clock_last <= clock_sample;
		gate_last <= gate_in;
	end else if(!paused) begin
		// The C3 ripple prescaler precedes E synchronization and must
		// count even pulses shorter than E (DS9802R3, page 9).
		clock_c3_last <= clock_in[2];
		if(control[0][0]) prescale_c <= 0;
		else if(clock_c3_last && !clock_in[2]) prescale_c <= prescale_c + 3'd1;
		if(ce) begin
			clock_pipe[0] <= clock_sample;
			gate_pipe[0] <= gate_in;
			for(integer stage=1; stage<3; stage++) begin
				clock_pipe[stage] <= clock_pipe[stage-1];
				gate_pipe[stage] <= gate_pipe[stage-1];
			end
			clock_last <= clock_pipe[2];
			gate_last <= gate_pipe[2];
			if(control[0][0]) prescale_e <= 0;
			else prescale_e <= prescale_e + 3'd1;

			if(rd && addr==1) status_seen <= interrupt_flag;
			if(rd && addr>=2 && !addr[0]) begin
				lsb_buffer <= counter[(addr>>1)-1][7:0];
				if(status_seen[(addr>>1)-1]) interrupt_flag[(addr>>1)-1] <= 0;
				status_seen[(addr>>1)-1] <= 0;
			end

			for(integer ch=0; ch<3; ch++) begin : timers
				reg count_clock, timeout_now, initialize, latch_write, count_enabled;
				reg measurement, single_shot;
				reg [15:0] reload;
				measurement = control[ch][3];
				single_shot = !measurement && control[ch][5];
				latch_write = wr && addr==3'(3+2*ch);
				reload = latch_write ? {msb_buffer,data} : latch[ch];
				count_clock = control[ch][1] ? (ch!=2 || !control[2][0] || prescale_e==7) : clock_fall[ch];
				count_enabled = measurement ? enabled[ch] && !interrupt_flag[ch] && !latch_write &&
					(!control[ch][4] || !gate_pipe[2][ch]) &&
					!(!control[ch][5] && !timed_out[ch] && counter[ch]!=0 &&
						(control[ch][4] ? gate_rise[ch] : gate_fall[ch])) : single_shot || !gate_pipe[2][ch];
				timeout_now = count_clock && count_enabled && counter[ch]==0;
				initialize = control[0][0];
				if(!measurement) begin
					initialize = initialize || gate_fall[ch] || (latch_write && !control[ch][4]);
				end else if(gate_fall[ch] && !interrupt_flag[ch]) begin
					// Table 8: the <frequency mode holds the measured count
					// when the next gate precedes timeout. The other three
					// modes initialize on every eligible negative gate edge.
					initialize = initialize || control[ch][4] || control[ch][5] || !enabled[ch] || timed_out[ch] || timeout_now;
				end

				if(latch_write) begin
					latch[ch] <= reload;
					interrupt_flag[ch] <= 0;
					status_seen[ch] <= 0;
					if(measurement) enabled[ch] <= 0;
				end

				if(!control[0][0]) begin
					if(measurement) begin
						if(gate_fall[ch] && !interrupt_flag[ch] && !latch_write) enabled[ch] <= 1;
						if(control[ch][4] && gate_pipe[2][ch]) enabled[ch] <= 0;
						if(!control[ch][5] && enabled[ch] && !timed_out[ch] && !timeout_now &&
							(control[ch][4] ? gate_rise[ch] : gate_fall[ch])) begin
							interrupt_flag[ch] <= 1;
							status_seen[ch] <= 0;
							enabled[ch] <= 0;
						end
					end
					if(count_clock && count_enabled) begin
						if(timeout_now) begin
							counter[ch] <= latch[ch];
							timed_out[ch] <= 1;
							if(!measurement || control[ch][5]) begin
								interrupt_flag[ch] <= 1;
								// A new timeout wins over an older status/read ack.
								status_seen[ch] <= 0;
							end
							if(measurement) begin
								output_state[ch] <= !output_state[ch];
								if(control[ch][5]) enabled[ch] <= 0;
							end else if(single_shot) begin
								output_state[ch] <= 0;
								// A zero-length cycle has no pulse to complete.
								// Nonzero writes can therefore release its inhibit
								// in mode 6 without a new gate/reset initialization.
								if(shot_valid[ch]) shot_done[ch] <= 1;
								shot_valid[ch] <= latch[ch]!=0;
							end else if(control[ch][2] && latch[ch][7:0]!=0) output_state[ch] <= 0;
							else output_state[ch] <= !output_state[ch];
						end else begin
							if(!control[ch][2]) counter[ch] <= counter[ch] - 16'd1;
							else if(counter[ch][7:0]!=0) counter[ch][7:0] <= counter[ch][7:0] - 8'd1;
							else counter[ch] <= {counter[ch][15:8]-8'd1,latch[ch][7:0]};
							if(!measurement && (!single_shot || !shot_done[ch])) begin
								if(control[ch][2] && latch[ch][7:0]!=0) begin
									if(counter[ch][15:8]==0) output_state[ch] <= 1;
								end else if(single_shot) output_state[ch] <= 1;
							end
						end
					end
				end

				if(initialize) begin
					counter[ch] <= reload;
					output_state[ch] <= 0;
					interrupt_flag[ch] <= 0;
					status_seen[ch] <= 0;
					timed_out[ch] <= 0;
					shot_done[ch] <= 0;
					shot_valid[ch] <= reload!=0;
					if(control[0][0]) enabled[ch] <= 0;
				end
				// This is the explicit zero-period exception on page 11,
				// not an unconditional single-shot rearm on latch writes.
				if(single_shot && latch_write && latch[ch]==0 && reload!=0) shot_done[ch] <= 0;
			end

			if(wr) begin
				if(addr<2) begin
					if(control[addr==1 ? 1 : control[1][0] ? 0 : 2][5:3]!=data[5:3])
						shot_done[addr==1 ? 1 : control[1][0] ? 0 : 2] <= 0;
					if(addr==1) control[1] <= data;
					else if(control[1][0]) control[0] <= data;
					else control[2] <= data;
					if(addr==0 && control[1][0] && (data[0] || control[0][0])) begin
						// Reset transition initializes every timer; software
						// reset never changes latches or the other controls.
						for(integer ch=0; ch<3; ch++) begin
							counter[ch] <= latch[ch];
							output_state[ch] <= 0;
							interrupt_flag[ch] <= 0;
							status_seen[ch] <= 0;
							enabled[ch] <= 0;
							timed_out[ch] <= 0;
							shot_done[ch] <= 0;
							shot_valid[ch] <= latch[ch]!=0;
						end
						prescale_e <= 0;
						prescale_c <= 0;
					end
				end else if(!addr[0]) msb_buffer <= data;
			end
		end
	end
end
endmodule

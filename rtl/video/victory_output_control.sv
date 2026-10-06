// SPDX-License-Identifier: GPL-3.0-or-later
// Slow SYS-side Avalon PLL configuration, followed by local output warmup.
// See the unchanged sys/pll_cfg register map: M=4, fractional K=7, start=2.
// User/ROM reset restarts visibility, never forces a transport mode change.
module victory_output_control (
	input wire clk_sys, clk_output,
	input wire management_reset, user_reset,
	input wire native_locked, output_locked, request_crt, native_frame,
	input wire output_frame, cfg_waitrequest,
	output wire cfg_write,
	output wire [5:0] cfg_address,
	output wire [31:0] cfg_writedata,
	output reg selected_crt=0,
	output reg transport_reset=1,
	output wire blank_output
);
localparam [3:0] BOOT_LOCK=0, BLANK_WAIT=1, WRITE_M=2, GAP_M=3,
	WRITE_K=4, GAP_K=5, WRITE_START=6, WAIT_BUSY=7, WAIT_DONE=8,
	LOCK_GUARD=9, RELEASE=10, WARMUP=11, IDLE=12;
reg [3:0] state=BOOT_LOCK;
reg [9:0] settle_count=0;
reg target_crt=0;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg native_lock_meta=0,native_lock_sync=0,output_lock_meta=0,output_lock_sync=0;
always @(posedge clk_sys) begin
	native_lock_meta<=native_locked; native_lock_sync<=native_lock_meta;
	output_lock_meta<=output_locked; output_lock_sync<=output_lock_meta;
end
wire clocks_ready=native_lock_sync && output_lock_sync;
assign cfg_write=state==WRITE_M || state==WRITE_K || state==WRITE_START;
assign cfg_address=state==WRITE_M ? 6'd4 : state==WRITE_K ? 6'd7 : 6'd2;
// M high/low and odd flag: native 14+14, CRT 14+13. N=1,C=32 stay fixed.
assign cfg_writedata=state==WRITE_M ? (target_crt ? 32'h00020e0d : 32'h00000e0e) :
	state==WRITE_K ? (target_crt ? 32'd180359868 : 32'd3864784112) : 32'd1;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg warm_done_meta=0,warm_done_sync=0;
reg [1:0] warm_frames=0;
always @(posedge clk_sys) begin
	warm_done_meta<=warm_frames==2; warm_done_sync<=warm_done_meta;
	if(management_reset) begin
		state<=BOOT_LOCK; settle_count<=0; target_crt<=0;
		selected_crt<=0; transport_reset<=1;
	end else case(state)
		BOOT_LOCK: if(clocks_ready && !cfg_waitrequest) begin
			// Program the requested startup mode before any visible image;
			// the fitted native PLL startup clock remains blank during setup.
			target_crt<=request_crt; settle_count<=0; state<=BLANK_WAIT;
		end
		BLANK_WAIT: if(settle_count==63) begin settle_count<=0;state<=WRITE_M;end
			else settle_count<=settle_count+10'd1;
		WRITE_M: if(!cfg_waitrequest) begin settle_count<=0;state<=GAP_M;end
		GAP_M: if(settle_count==255) begin settle_count<=0;state<=WRITE_K;end
			else settle_count<=settle_count+10'd1;
		WRITE_K: if(!cfg_waitrequest) begin settle_count<=0;state<=GAP_K;end
		GAP_K: if(settle_count==255) begin settle_count<=0;state<=WRITE_START;end
			else settle_count<=settle_count+10'd1;
		WRITE_START: if(!cfg_waitrequest) state<=WAIT_BUSY;
		// Waitrequest must assert after the accepted start; a stale locked
		// level cannot release output before the configuration completes.
		WAIT_BUSY: if(cfg_waitrequest) state<=WAIT_DONE;
		WAIT_DONE: if(!cfg_waitrequest && clocks_ready) begin
			settle_count<=0;state<=LOCK_GUARD;
		end
		LOCK_GUARD: if(!clocks_ready || cfg_waitrequest) settle_count<=0;
			else if(settle_count==1023) begin
				selected_crt<=target_crt;settle_count<=0;state<=RELEASE;
			end else settle_count<=settle_count+10'd1;
		RELEASE: if(!clocks_ready || cfg_waitrequest) begin state<=LOCK_GUARD;settle_count<=0;end
			else if(settle_count==63) begin transport_reset<=0;state<=WARMUP;end
			else settle_count<=settle_count+10'd1;
		WARMUP: if(!clocks_ready) begin transport_reset<=1;settle_count<=0;state<=LOCK_GUARD;end
			else if(!user_reset && warm_done_sync) state<=IDLE;
		IDLE: if(!clocks_ready) begin transport_reset<=1;settle_count<=0;state<=LOCK_GUARD;end
			else if(!user_reset && native_frame && request_crt!=selected_crt) begin
				target_crt<=request_crt;transport_reset<=1;settle_count<=0;state<=BLANK_WAIT;
			end
		default: begin state<=BOOT_LOCK;transport_reset<=1;settle_count<=0;end
	endcase
end
wire pipeline_hold=transport_reset || user_reset || !output_locked;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [1:0] warm_reset_pipe=2'b11;
always @(posedge clk_output or posedge pipeline_hold)
	if(pipeline_hold) warm_reset_pipe<=2'b11;
	else warm_reset_pipe<={warm_reset_pipe[0],1'b0};
always @(posedge clk_output)
	if(warm_reset_pipe[1]) warm_frames<=0;
	else if(output_frame && warm_frames<2) warm_frames<=warm_frames+2'd1;
assign blank_output=warm_reset_pipe[1] || warm_frames!=2;
endmodule

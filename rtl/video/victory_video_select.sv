// SPDX-License-Identifier: GPL-3.0-or-later
// Only output video changes clock. Both source clocks must keep running.
// Blank before ALTCLKCTRL selection; release after settling and two complete
// output frame boundaries. Source/game reset is never generated here.
module victory_video_select (
	input  wire clk_sys, clk_native, clk_crt,
	input  wire reset, clocks_ready, request_crt, native_frame,
	input  wire output_frame,
	output wire clk_output, blank_output,
	output reg  selected_crt=0
);
localparam [2:0] IDLE=0, BEFORE_SWITCH=1, CLOCK_OFF=2, SELECT_SETTLE=3, AFTER_SWITCH=4;
reg [2:0] state=SELECT_SETTLE;
reg [5:0] settle_count=0;
reg target_crt=0, pipeline_hold=1, clock_enable=1;
always @(posedge clk_sys) begin
	if(reset) begin
		// User/ROM reset retains the selected clock; only validity restarts.
		state<=SELECT_SETTLE; settle_count<=0; pipeline_hold<=1;
	end else case(state)
		IDLE: if(clocks_ready && native_frame && request_crt!=selected_crt) begin
			target_crt<=request_crt; pipeline_hold<=1;
			settle_count<=0; state<=BEFORE_SWITCH;
		end
		BEFORE_SWITCH: if(!clocks_ready) settle_count<=0;
			else if(settle_count==31) begin
				clock_enable<=0; settle_count<=0; state<=CLOCK_OFF;
			end else settle_count<=settle_count+6'd1;
		CLOCK_OFF: if(!clocks_ready) settle_count<=0;
			else if(settle_count==31) begin
				selected_crt<=target_crt; settle_count<=0; state<=SELECT_SETTLE;
			end else settle_count<=settle_count+6'd1;
		SELECT_SETTLE: if(!clocks_ready) settle_count<=0;
			else if(settle_count==31) begin
				clock_enable<=1; settle_count<=0; state<=AFTER_SWITCH;
			end else settle_count<=settle_count+6'd1;
		AFTER_SWITCH: if(!clocks_ready) settle_count<=0;
			else if(settle_count==63) begin state<=IDLE; pipeline_hold<=0; end
			else settle_count<=settle_count+6'd1;
		default: begin state<=SELECT_SETTLE; pipeline_hold<=1; settle_count<=0; end
	endcase
end

// Dedicated global clock-control IP. The fitter must retain this block;
// a combinational RTL mux on clocks is not an implementation alternative.
altclkctrl #(
	.clock_type("Global Clock"), .intended_device_family("Cyclone V"),
	.number_of_clocks(4), .width_clkselect(2),
	.ena_register_mode("double register"), .implement_in_les("OFF"),
	.use_glitch_free_switch_over_implementation("OFF")
) output_clock_mux (
	// Cyclone V clock-control PLL sources use slots 2/3. The registered
	// output gate is closed for 32 SYS clocks before changing selection.
	.inclk({clk_crt,clk_native,2'b00}), .clkselect({1'b1,selected_crt}),
	.ena(clock_enable), .outclk(clk_output)
);

(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [1:0] warm_reset_pipe=2'b11;
always @(posedge clk_output or posedge pipeline_hold)
	if(pipeline_hold) warm_reset_pipe<=2'b11;
	else warm_reset_pipe<={warm_reset_pipe[0],1'b0};
reg [1:0] warm_frames=0;
always @(posedge clk_output) begin
	if(warm_reset_pipe[1]) warm_frames<=0;
	else if(output_frame && warm_frames<2) warm_frames<=warm_frames+2'd1;
end
assign blank_output=warm_reset_pipe[1] || warm_frames!=2;
endmodule

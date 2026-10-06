// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheets 16/3: VP qualification (14M/13L/12L), 14L LS174,
// 13L capture NOR, 13H LS74 and 17K/16K LS374 coordinate latches.
// VP is the pre-15L mux output, including CPU address when SEALOK is low.
// EBIRQ comes from the external 15J/12J circuit, not directly BIRQEA.
module victory_hsc_background_collision (
	input  wire       clk, reset, paused, bit_clock, e4clk, blank,
	input  wire [5:0] vp,
	input  wire       bir12, ebirq, clear_n,
	input  wire [7:3] raster_e,
	input  wire [7:0] raster_l,
	output reg        all_q, only_q, e4clk_q, blank_q,
	output wire       capture_clock, pending_n,
	output reg        hit,
	output reg  [7:0] captured_x, captured_y
);
reg bit_previous, capture_previous, clear_previous, pending;
wire foreground_zero = !(|vp[5:3]);
wire background_zero = !(|vp[2:0]);
// 14M pins 10/9/11 take BIR12, NOR(VP5..3), NOR(VP2..0).
// Its other section takes !VP2, foreground-zero and !BIR12.
wire all_d = !(bir12 || foreground_zero || background_zero);
wire only_d = !(!vp[2] || foreground_zero || !bir12);
assign capture_clock = !(pending || all_q || only_q);
assign pending_n = !pending;
always @(posedge clk) begin
	bit_previous <= bit_clock;
	capture_previous <= capture_clock;
	clear_previous <= clear_n;
	hit <= 0;
	if(reset) begin
		all_q <= 0; only_q <= 0; e4clk_q <= 0; blank_q <= 0;
		pending <= 0; captured_x <= 0; captured_y <= 0;
		capture_previous <= 1;
		clear_previous <= 1;
	end else begin
		// 14L continues with video during pause. Its CLR1 is tied +5;
		// FPGA startup initializes these otherwise unspecified power-up bits.
		if(bit_clock && !bit_previous) begin
			all_q <= all_d; only_q <= only_d;
			e4clk_q <= e4clk; blank_q <= blank;
		end
		if(!paused) begin
			// Read-clear dominates 13H; LS374 coordinate capture itself is
			// independent of EBIRQ and that asynchronous pending clear.
			if(!clear_n) pending <= 0;
			else if(capture_clock && !capture_previous) begin
				// The detected edge occurred on the preceding SYS transition.
				// Preserve /CLR at that edge as well as its current level: a
				// Y read ending now must not enable a capture which took place
				// while /CLR was low. LS374 capture remains independent below.
				pending <= ebirq && clear_previous;
				hit <= ebirq && clear_previous;
			end
			if(capture_clock && !capture_previous) begin
				// 17K stores E128..E8 and the BIT-latched E4CLK. Its two
				// unused inputs feed ignored CPU bits 1:0; define those as 0.
				captured_x <= {raster_e,e4clk_q,2'b00};
				captured_y <= raster_l;
			end
		end
	end
end
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// Position-only analog geometry: RGB, DE and pixel CE pass unchanged.
// Derive pixel phase from the actual normalized hook HSync, not coordinates
// forwarded ahead of mixer/scanline latency. Learn the actual VSync edge
// phase: arcade_video resamples it at HSync, unlike the raw source raster.
module victory_crt_position (
	input  wire       clk, ce_pix, enabled, scandoubler, crt_15k,
	input  wire signed [5:0] hposition,
	input  wire signed [4:0] vshift,
	input  wire [23:0] rgb_in,
	input  wire       hs_in, vs_in, hb_in, vb_in,
	output wire [23:0] rgb_out,
	output wire       ce_out, hs_out, vs_out, hb_out, vb_out
);
reg enabled_q=0, mode_q=0, hs_previous=0, vs_previous=0;
reg signed [5:0] hposition_q=0;
reg signed [4:0] vshift_q=0;
reg [8:0] next_column=0, history_lines=0;
reg [8:0] vertical_phase=328;
reg [335:0] hs_history=0;
reg [279:0] vs_history=0;
reg shifted_hs=0, shifted_vs=0;
wire hs_rise=hs_in && !hs_previous;
wire vs_rise=vs_in && !vs_previous;
wire [8:0] column=hs_rise ? (crt_15k ? 9'd272 : 9'd312) : next_column;
wire [8:0] vertical_sample=vertical_phase;
wire [8:0] total_lines=crt_15k ? 9'd262 : 9'd280;
wire [8:0] hdelay=hposition_q[5] ? 9'(336+int'(hposition_q)) : {3'd0,hposition_q};
wire [8:0] vdelay=vshift_q[4] ? 9'(int'(total_lines)+int'(vshift_q)) : {4'd0,vshift_q};
always @(posedge clk) begin
	if(mode_q!=crt_15k) begin
		mode_q<=crt_15k; history_lines<=0; next_column<=0;
		vertical_phase<=crt_15k ? 9'd0 : 9'd328;
		hs_history<=0; vs_history<=0; hs_previous<=0; vs_previous<=0;
		shifted_hs<=0; shifted_vs<=0;
	end else if(ce_pix) begin
		hs_previous<=hs_in; vs_previous<=vs_in;
		next_column<=column==335 ? 9'd0 : column+9'd1;
		hs_history<={hs_history[334:0],hs_in};
		shifted_hs<=hdelay==0 ? hs_in : hs_history[hdelay-9'd1];
		if(column==vertical_sample) begin
			vs_history<={vs_history[278:0],vs_in};
			shifted_vs<=vdelay==0 ? vs_in : vs_history[vdelay-9'd1];
			if(history_lines<280) history_lines<=history_lines+9'd1;
		end
		// The actual VSync edge lies in blank; settings cannot change an
		// active pixel. Settled sync cadence is invariant after one transition.
		if(vs_rise) begin
			enabled_q<=enabled;
			hposition_q<=hposition; vshift_q<=vshift;
			if(vertical_phase!=column) begin
				// Discard history taken at a different line phase. Sampling
				// hereafter at the observed edge gives exact whole-line shifts.
				vertical_phase<=column;history_lines<=0;
				vs_history<=0;shifted_vs<=0;
			end
		end
	end
end
wire active=enabled_q && !scandoubler && mode_q==crt_15k && history_lines==280;
assign rgb_out=rgb_in;
assign ce_out=ce_pix;
assign {hb_out,vb_out}={hb_in,vb_in};
assign hs_out=active && hposition_q!=0 ? shifted_hs : hs_in;
assign vs_out=active && vshift_q!=0 ? shifted_vs : vs_in;
endmodule

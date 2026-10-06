// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 3 counter chain: 13H LS74, 17F LS161 and both 15F LS112
// sections, with vertical 15H/16F LS161s. ce_e4_fall represents raw E4CLK
// falling (inverted E4CLK rising). Reset is FPGA startup, not CPU reset.
// Sheet-3 sync/load gates are modeled by victory_hsc_raster_control.
// Raster counters continue regardless of game pause.
module victory_hsc_raster_counters (
	input  wire       clk, reset, ce_e4_fall,
	input  wire       crystal_11289, sel5060, screen_invert,
	output wire [8:3] raw_e,
	output wire [8:0] raw_l,
	output wire [7:3] raster_e,
	output wire [7:0] raster_l,
	output wire       horizontal_carry, vertical_carry,
	output wire [3:0] horizontal_preload,
	output wire [7:0] vertical_preload
);
reg e8,e256,l256;
reg [3:0] horizontal;
reg [7:0] vertical;
assign raw_e={e256,horizontal,e8};
assign raw_l={l256,vertical};
// Sheet 3's INVERT is the complement of raw S INVERT. XORs invert
// the low raster bits only. raw_e[8] is horizontal Q9, while the named
// SE256 net is its complement /Q7; raw_l[8] is vertical Q5 (L256).
assign raster_e=raw_e[7:3] ^ {5{!screen_invert}};
assign raster_l=vertical ^ {8{!screen_invert}};
assign horizontal_carry=e8 && (&horizontal);
assign vertical_carry=&vertical;
// 17F A/D0 is the crystal jumper: ground for 11.827, /E256 for
// 11.289. B/D1 and D/D3 are /E256; C/D2 is grounded. LOAD9 comes
// from inverted RCO15. J11/K12 of 15F both receive that old RCO.
assign horizontal_preload={!e256,1'b0,!e256,crystal_11289 && !e256};
// Vertical parallel inputs: 15H A/B/C grounded, D=SEL5060 & /L256.
// 16F A=!SEL5060 & /L256, B=/L256, C=SEL5060 & /L256, D=/L256.
assign vertical_preload={!l256,sel5060 && !l256,!l256,!sel5060 && !l256,
	sel5060 && !l256,3'b000};
always @(posedge clk) begin
	if(reset) begin
		e8<=0; e256<=0; l256<=0; horizontal<=0; vertical<=0;
	end else if(ce_e4_fall) begin
		// 13H /Q loops into D. 17F samples the preceding Q on both
		// enable pins; its active-low parallel load dominates counting.
		e8<=!e8;
		if(horizontal_carry) begin
			horizontal<=horizontal_preload;
			e256<=!e256;
		end else if(e8) horizontal<=horizontal+4'd1;
		// Falling E256 clocks 15H/16F through /E256 and the vertical JK
		// directly. Preserve pre-edge carry and /L256 for both reloads.
		if(horizontal_carry && e256) begin
			if(vertical_carry) begin
				vertical<=vertical_preload;
				l256<=!l256;
			end else vertical<=vertical+8'd1;
		end
	end
end
endmodule

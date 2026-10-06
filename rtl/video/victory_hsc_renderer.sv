// SPDX-License-Identifier: GPL-3.0-or-later
// Foreground test renderer: physical LS299 pixels, background/palette ports
// and fixed-clock packets. Production raster generation uses victory_hsc_native.
module victory_hsc_renderer (
	input  wire        clk, reset, paused, ce_bit,
	input  wire [2:0]  foreground,
	input  wire [7:0]  scroll_x, scroll_y, video_control,
	output wire        blanking_n,
	output wire [7:0]  raster_e, raster_l,
	output reg  [9:0]  tile_addr,
	input  wire [7:0]  tile_q,
	output reg  [12:0] char_addr,
	input  wire [23:0] char_rgb_q,
	output reg  [5:0]  palette_addr,
	input  wire [8:0]  palette_q,
	output reg         ce_packet, hs, vs, hb, vb, bg_hit,
	output reg  [8:0]  hpos, vpos,
	output reg  [7:0]  r, g, b, bg_x, bg_y
);
reg [8:0] scan_h,scan_v,pixel_h,pixel_v;
reg [2:0] phase,bg_row,bg_bit,fg_pixel;
reg active;
// Sheet 3 inverter 14H derives raster INVERT from raw S INVERT (CONTROL
// bit 3). Sheet 14 uses the raw wire for LS299 direction and endpoint.
wire invert=!video_control[3];
wire [8:0] fetch_h=scan_h>=9'd328 ? scan_h-9'd328 : scan_h+9'd8;
wire [8:0] fetch_v=scan_h<9'd328 ? scan_v : (scan_v==9'd279 ? 9'd0 : scan_v+9'd1);
// The raster byte advances before RAS/CAS, halfway through the current
// byte's serialization. Supply the upcoming byte, including line wrap.
assign raster_e=invert ? ~fetch_h[7:0] : fetch_h[7:0];
assign raster_l=invert ? ~fetch_v[7:0] : fetch_v[7:0];
// Clock-bank selection follows the upcoming raster byte, providing the
// final blank-line CAS and SSR LOAD before the first visible pixel.
// This is provisional glue, not a claim to reproduce missing PROM 15J.
assign blanking_n=fetch_h<9'd256 && fetch_v<9'd256;
wire visible=scan_h<9'd256 && scan_v<9'd256;
wire [7:0] background_x=(invert ? ~scan_h[7:0] : scan_h[7:0])+scroll_x;
wire [7:0] background_y=(invert ? ~scan_v[7:0] : scan_v[7:0])+scroll_y;
wire [2:0] bg_pixel={char_rgb_q[5'd16+{2'b0,bg_bit}],char_rgb_q[5'd8+{2'b0,bg_bit}],char_rgb_q[{2'b0,bg_bit}]};
wire [2:0] collision_mask=video_control[2] ? 3'b100 : 3'b111;
function automatic [7:0] expand_color(input [2:0] value);
	expand_color={value,value,value[2:1]};
endfunction
always @(posedge clk) begin
	ce_packet<=0;
	bg_hit<=0;
	if(reset) begin
		// Clock reset starts BIT high. Seven shifts precede the first
		// phase-0 parallel load; hide them in the preceding blank line.
		scan_h<=9'd329; scan_v<=9'd279;
		pixel_h<=0; pixel_v<=0; phase<=0;
		bg_row<=0; bg_bit<=0; fg_pixel<=0; active<=0;
		tile_addr<=0; char_addr<=0; palette_addr<=0;
		hpos<=0; vpos<=0; hs<=1; vs<=0; hb<=1; vb<=1;
		r<=0; g<=0; b<=0; bg_x<=0; bg_y<=0;
	end else if(ce_bit) begin
		pixel_h<=scan_h; pixel_v<=scan_v;
		active<=visible;
		tile_addr<={background_y[7:3],background_x[7:3]};
		bg_row<=background_y[2:0]; bg_bit<=3'd7-background_x[2:0];
		phase<=1;
		if(scan_h==9'd335) begin
			scan_h<=0; scan_v<=scan_v==9'd279 ? 9'd0 : scan_v+9'd1;
		end else scan_h<=scan_h+9'd1;
	end else case(phase)
		1: begin fg_pixel<=foreground; phase<=2; end
		2: begin char_addr<={2'd0,tile_q,bg_row}; phase<=3; end
		3: phase<=4;
		4: begin
			palette_addr<={fg_pixel,bg_pixel};
			if(!paused && active && fg_pixel!=0 && (bg_pixel&collision_mask)!=0 && video_control[5]) begin
				bg_hit<=1;
				bg_x<=invert ? ~pixel_h[7:0] : pixel_h[7:0];
				bg_y<=invert ? ~pixel_v[7:0] : pixel_v[7:0];
			end
			phase<=5;
		end
		5: phase<=6;
		6: begin
			r<=active ? expand_color(palette_q[8:6]) : 8'd0;
			g<=active ? expand_color(palette_q[2:0]) : 8'd0;
			b<=active ? expand_color(palette_q[5:3]) : 8'd0;
			hpos<=pixel_h; vpos<=pixel_v;
			hs<=!(pixel_h>=9'd272 && pixel_h<9'd304);
			vs<=pixel_v>=9'd260 && pixel_v<9'd264;
			hb<=pixel_h>=9'd256; vb<=pixel_v>=9'd256;
			ce_packet<=1; phase<=0;
		end
		default: ;
	endcase
end
endmodule

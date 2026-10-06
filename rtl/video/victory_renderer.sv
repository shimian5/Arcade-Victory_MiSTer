// SPDX-License-Identifier: GPL-3.0-or-later
// Prefetch the next native pixel: six 48 MHz clocks fit inside an 8/9-clock
// pixel interval. The output is ready before the existing native CE pixel.
module victory_renderer (
	input  wire        clk, reset, paused, ce_pix,
	input  wire [8:0]  hpos, vpos,
	input  wire [7:0]  scroll_x, scroll_y, video_control,
	output reg  [9:0]  tile_addr,
	input  wire [7:0]  tile_q,
	output reg  [12:0] char_addr,
	input  wire [23:0] char_rgb_q,
	output reg  [12:0] fg_addr,
	input  wire [23:0] fg_rgb_q,
	output reg  [5:0]  palette_addr,
	input  wire [8:0]  palette_q,
	output reg  [7:0]  r, g, b,
	output reg         bg_hit,
	output reg  [7:0]  bg_x, bg_y
);
wire [8:0] next_h = hpos == 9'd335 ? 9'd0 : hpos + 9'd1;
wire [8:0] next_v = hpos != 9'd335 ? vpos : vpos == 9'd279 ? 9'd0 : vpos + 9'd1;
wire [7:0] background_x = next_h[7:0] + scroll_x;
wire [7:0] background_y = next_v[7:0] + scroll_y;
reg [2:0] phase;
reg active, collision;
reg [7:0] pixel_x, pixel_y;
reg [2:0] bg_row, bg_bit, fg_bit, fg_pixel;
wire [2:0] bg_pixel = {char_rgb_q[16+bg_bit],char_rgb_q[8+bg_bit],char_rgb_q[bg_bit]};
wire [2:0] collision_mask = video_control[2] ? 3'b100 : 3'b111;
function automatic [7:0] expand_color(input [2:0] value);
	expand_color = {value,value,value[2:1]};
endfunction
always @(posedge clk) begin
	bg_hit <= 0;
	if (reset) begin
		phase           <= 0;
		tile_addr       <= 0;
		char_addr       <= 0;
		fg_addr         <= 0;
		palette_addr    <= 0;
		r               <= 0;
		g               <= 0;
		b               <= 0;
		active          <= 0;
		collision       <= 0;
		pixel_x         <= 0;
		pixel_y         <= 0;
		bg_row          <= 0;
		bg_bit          <= 0;
		fg_bit          <= 0;
		fg_pixel        <= 0;
		bg_x            <= 0;
		bg_y            <= 0;
	end else if (ce_pix) begin
		if (!paused) begin
			// HSC sheets 3/4/16: EBIRQ enables capture, and the board's
			// pending latch holds coordinates until SBACKY acknowledges it.
			// There is no per-frame event budget in this circuit.
			if (collision && video_control[5]) begin
				bg_hit          <= 1;
				bg_x            <= pixel_x;
				bg_y            <= pixel_y;
			end
		end
		tile_addr <= {background_y[7:3],background_x[7:3]};
		fg_addr   <= {next_v[7:0],next_h[7:3]};
		bg_row    <= background_y[2:0];
		bg_bit    <= 3'd7 - background_x[2:0];
		fg_bit    <= 3'd7 - next_h[2:0];
		pixel_x   <= next_h[7:0];
		pixel_y   <= next_v[7:0];
		active    <= next_h < 9'd256 && next_v < 9'd256;
		phase     <= 1;
	end else case (phase)
		1: phase <= 2;
		2: begin
			char_addr <= {2'd0,tile_q,bg_row};
			fg_pixel  <= {fg_rgb_q[16+fg_bit],fg_rgb_q[8+fg_bit],fg_rgb_q[fg_bit]};
			phase     <= 3;
		end
		3: phase <= 4;
		4: begin
			palette_addr <= {fg_pixel,bg_pixel};
			collision    <= active && fg_pixel != 0 && (bg_pixel & collision_mask) != 0;
			phase        <= 5;
		end
		5: phase <= 6;
		6: begin
			r     <= active ? expand_color(palette_q[8:6]) : 8'd0;
			g     <= active ? expand_color(palette_q[2:0]) : 8'd0;
			b     <= active ? expand_color(palette_q[5:3]) : 8'd0;
			phase <= 0;
		end
		default: ;
	endcase
end
endmodule

// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 5: 3J LS157 clocks cascaded 1J/XJ and XL/XK LS193s.
// Inputs are settled chip-pin levels sampled in the SYS domain. /LOAD
// dominates counting; the counters keep scanning during game pause.
// Scroll bytes are the outputs of the separate CPU-loaded LS374s.
module victory_hsc_scroll (
	input  wire       clk, reset,
	// e256 is the sheet's SE256=/horizontal Q9, not Q9 itself.
	input  wire       bit_clock, e256, screen_invert,
	input  wire       horizontal_load_n, vertical_load_n,
	input  wire [7:0] scroll_x, scroll_y,
	output reg  [7:0] scrolled_e, scrolled_l,
	output wire      serial_load_n,
	output wire      horizontal_up, horizontal_down,
	output wire      vertical_up, vertical_down
);
wire invert = !screen_invert;
// LS157 /G15 is grounded; select1 is INVERT. Horizontal DOWN4
// selects A2=+5/B3=BIT; UP5 selects A5=BIT/B6=+5. Vertical DOWN4
// selects A11=+5/B10=E256; UP5 selects A14=E256/B13=+5.
// Follow the continuous wires at 3J pins 10/11: normal scan
// increments both X and Y, not just X.
assign horizontal_down = invert ? bit_clock : 1'b1;
assign horizontal_up   = invert ? 1'b1 : bit_clock;
assign vertical_down   = invert ? e256 : 1'b1;
assign vertical_up     = invert ? 1'b1 : e256;
// 2J's three XORs compare the low count bits against INVERT. 4J
// NANDs them: the load is low at 7 in forward scan, 0 in reverse.
assign serial_load_n = !(&(scrolled_e[2:0] ^ {3{invert}}));
reg horizontal_up_q, horizontal_down_q, vertical_up_q, vertical_down_q;
always @(posedge clk) begin
	horizontal_up_q   <= horizontal_up;
	horizontal_down_q <= horizontal_down;
	vertical_up_q     <= vertical_up;
	vertical_down_q   <= vertical_down;
	if(reset) begin
		scrolled_e <= 0;
		scrolled_l <= 0;
	end else begin
		// Each low nibble's active-low carry/borrow clocks its high
		// nibble. With mutually exclusive UP/DOWN pins, that cascade
		// is an eight-bit increment/decrement including 00/FF wrap.
		if(!horizontal_load_n) scrolled_e <= scroll_x;
		else if(horizontal_up && !horizontal_up_q && horizontal_down)
			scrolled_e <= scrolled_e + 8'd1;
		else if(horizontal_down && !horizontal_down_q && horizontal_up)
			scrolled_e <= scrolled_e - 8'd1;
		if(!vertical_load_n) scrolled_l <= scroll_y;
		else if(vertical_up && !vertical_up_q && vertical_down)
			scrolled_l <= scrolled_l + 8'd1;
		else if(vertical_down && !vertical_down_q && vertical_up)
			scrolled_l <= scrolled_l - 8'd1;
	end
end
endmodule

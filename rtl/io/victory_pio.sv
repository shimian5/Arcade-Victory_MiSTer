// SPDX-License-Identifier: GPL-3.0-or-later
// Victory's Z80 PIO subset: alternate register order, live cabinet inputs.
// No strobes are connected and PIO interrupt outputs are disconnected.
module victory_pio (
	input  wire         clk, reset, wr,
	input  wire [1:0]   addr,
	input  wire [7:0]   data, in_a, in_b,
	output reg  [7:0]   q
);
reg [1:0] mode [0:1];
reg [7:0] latch [0:1], direction [0:1], icw [0:1];
reg direction_follows [0:1], mask_follows [0:1];
wire channel = addr[1];
wire [7:0] pins = channel ? in_b : in_a;
always @* begin
	if (addr[0]) q = (icw[0] & 8'hc0) | (icw[1] >> 4);
	else case (mode[channel])
		0: q = latch[channel];
		3: q = (pins & direction[channel]) | (latch[channel] & ~direction[channel]);
		1: q = pins;
		default: q = 0; // No bidirectional input strobe/latch is implemented.
	endcase
end
always @(posedge clk) begin
	if (reset) begin
		for (integer i = 0; i < 2; i = i + 1) begin
			mode[i]              <= 1;
			latch[i]             <= 0;
			direction[i]         <= 8'hff;
			icw[i]               <= 0;
			direction_follows[i] <= 0;
			mask_follows[i]      <= 0;
		end
	end else if (wr) begin
		if (!addr[0]) latch[channel] <= data;
		else if (direction_follows[channel]) begin
			direction[channel]         <= data;
			direction_follows[channel] <= 0;
		end else if (mask_follows[channel]) mask_follows[channel] <= 0;
		else if (data[0]) case (data[3:0])
			4'hf: begin
				mode[channel] <= data[7:6];
				direction_follows[channel] <= data[7:6] == 3;
			end
			4'h7: begin
				icw[channel]          <= data;
				mask_follows[channel] <= data[4];
			end
			4'h3: icw[channel][7] <= data[7];
			default: ;
		endcase
		// Even control words are vectors; no interrupt daisy chain is wired.
	end
end
endmodule

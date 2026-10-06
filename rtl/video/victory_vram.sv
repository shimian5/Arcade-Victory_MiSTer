// SPDX-License-Identifier: GPL-3.0-or-later
// Coprocessor RGB planes: 8 KiB visible bitmap plus private data/program space.
module victory_vram (
	input  wire        clk,
	input  wire [13:0] engine_addr,
	input  wire [2:0]  engine_we,
	input  wire [23:0] engine_data,
	output reg  [23:0] engine_q,
	input  wire [12:0] video_addr,
	output reg  [23:0] video_q
);
reg [7:0] red [0:16383], blue [0:16383], green [0:16383];
initial begin
	// Bound each loop separately for Quartus's elaboration limit.
	for (integer bank=0; bank<8; bank=bank+1)
		for (integer i=0; i<2048; i=i+1) begin
			red[bank*2048+i]   = 0;
			blue[bank*2048+i]  = 0;
			green[bank*2048+i] = 0;
		end
end
always @(posedge clk) begin
	engine_q <= {red[engine_addr], blue[engine_addr], green[engine_addr]};
	video_q  <= {red[{1'b0,video_addr}], blue[{1'b0,video_addr}], green[{1'b0,video_addr}]};
	if (engine_we[2]) red[engine_addr]   <= engine_data[23:16];
	if (engine_we[1]) blue[engine_addr]  <= engine_data[15:8];
	if (engine_we[0]) green[engine_addr] <= engine_data[7:0];
end
endmodule

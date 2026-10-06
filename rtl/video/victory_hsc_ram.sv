// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 14's three banks of 4116 DRAM, addressed through sheet 8.
// Logical FPGA storage reverses the complemented physical row/column pins.
// One shared read/write port represents the command/display bus. This
// storage is integrated with safe-phase pause and the display LS299s in
// the production datapath; read/write bus behavior is retained during pause.
module victory_hsc_ram (
	input  wire        clk, reset,
	input  wire        ras_n, cas_n,
	input  wire [6:0]  dram_address,
	input  wire [2:0]  plane_write_n,
	input  wire [23:0] write_data,
	output wire [23:0] read_data,
	output wire [2:0]  read_driving,
	output reg         read_valid,
	output reg  [13:0] latched_address
);
reg [7:0] red [0:16383], blue [0:16383], green [0:16383];
reg [6:0] row_address;
reg row_open, ras_previous, cas_previous;
reg [2:0] write_previous;
reg [1:0] read_pending;
reg [23:0] memory_q;
reg [23:0] read_latch;
reg [2:0] read_plane_mask;
wire row_start = !ras_n && ras_previous;
wire column_start = !cas_n && cas_previous && row_open && !ras_n;
wire [13:0] access_address = column_start ? {~dram_address,row_address} : latched_address;
// Late write starts on /WE falling while CAS is already active. Early
// write starts at CAS falling with /WE already low. Each event commits once;
// held /WE is not a repeated XOR operation at the faster FPGA clock.
wire [2:0] write_event = (!reset && row_open && !ras_n && !cas_n) ?
	(~plane_write_n & (write_previous | {3{column_start}})) : 3'b000;
// TI 4116: early write floats Q for that entire CAS cycle. Late write
// retains the read output. Sheet 14's RP3/RP2 pull-ups make floating bits
// high; represent that bus value without inferring FPGA internal tristates.
assign read_driving = !cas_n ? read_plane_mask : 3'b000;
wire [23:0] read_mask = {{8{read_driving[2]}},{8{read_driving[1]}},{8{read_driving[0]}}};
assign read_data = (read_latch & read_mask) | ~read_mask;
initial begin
	for(integer bank=0;bank<8;bank=bank+1)
		for(integer index=0;index<2048;index=index+1) begin
			red[bank*2048+index] = 0;
			blue[bank*2048+index] = 0;
			green[bank*2048+index] = 0;
		end
end
// Keep the inferred RAM read registers free of reset. Resetting the bus
// state does not clear the physical DRAM contents or expand RAM into logic.
always @(posedge clk) begin
	memory_q <= {red[access_address],blue[access_address],green[access_address]};
	if(write_event[2]) red[access_address] <= write_data[23:16];
	if(write_event[1]) blue[access_address] <= write_data[15:8];
	if(write_event[0]) green[access_address] <= write_data[7:0];
end
always @(posedge clk) begin
	if(reset) begin
		row_address <= 0;
		row_open <= 0;
		latched_address <= 0;
		ras_previous <= 1;
		cas_previous <= 1;
		write_previous <= 3'b111;
		read_pending <= 0;
		read_latch <= 0;
		read_plane_mask <= 0;
		read_valid <= 0;
	end else begin
		ras_previous <= ras_n;
		cas_previous <= cas_n;
		write_previous <= plane_write_n;
		read_pending <= {read_pending[0],column_start};
		read_valid <= read_pending[1];
		if(read_pending[1]) read_latch <= memory_q;
		if(ras_n) row_open <= 0;
		else if(row_start) begin
			row_open <= 1;
			row_address <= ~dram_address;
		end
		if(column_start) begin
			latched_address <= access_address;
			read_plane_mask <= plane_write_n;
		end
	end
end
endmodule

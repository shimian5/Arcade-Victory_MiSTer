// SPDX-License-Identifier: GPL-3.0-or-later
// Common development HSC datapath, Exidy 77-0004-01 sheets 7-15.
// PROMs are asynchronous external inputs; no command timing surrogate is
// used. CPU strobes must obey sampled-X data hold; trigger releases do
// not require alignment with SEQ. The PROM acknowledges the ready latch.
// Display and commands share one RAM port. A phase-boundary pause freezes
// commands while clock PROM/display reads continue. Raster and background
// CPU waits are coordinated by the production victory_hsc_native wrapper.
module victory_hsc_datapath (
	input  wire        clk, reset, ce_master, blanking_n, screen_invert,
	input  wire        pause_request,
	output wire        pause_active,
	input  wire [7:0]  cpu_load_n, cpu_data, raster_e, raster_l,
	input  wire        collision_clear_n,
	output wire [4:0]  clock_addr, state_addr, vector_address,
	input  wire [7:0]  clock_q, prom_b, prom_c, prom_d, prom_e, vector_q,
	output reg  [7:0]  command,
	output wire        ready_n, busy, collision_pending_n, collision_hit,
	output wire [7:0]  collision_x, collision_y,
	output wire        ce_bit,
	output wire        e4clk, bit_clk, sr_load,
	output wire [2:0]  pixel_rgb
);
reg [7:0] red_source,blue_source,green_source,load_previous;
wire [7:0] register_load_n,x_prime,y_prime,working_x,working_y;
wire [23:0] first_rgb,second_rgb,source_mux,read_data,display_shift_rgb;
wire [7:0] dimension_length,accumulator;
wire [3:0] dimension_height;
wire ltc,htc,transfer_x_n,increment_x,shift_enable_n,add_x_n,increment_y_n;
wire vector_write,vector_carry,vector_finished,move_x,move_y,right,down;
wire command_clock,zero_ram;
wire [7:0] controls_b,controls_c,controls_d;
wire [1:0] sea,address_select,serial_mode;
wire mpxrc,ref_ea,seq_clk,write_ea,cas_n,ras_n;
wire write_bus1_n,write_bus2_n,write_latched;
wire [2:0] plane_write_n;
wire [15:0] instruction_address;
wire [8:0] program_counter;
wire [13:0] byte_address,latched_address;
wire [6:0] dram_address;
wire [23:0] source_rgb={red_source,blue_source,green_source};
wire [23:0] mux_rgb=zero_ram ? 24'd0 : (controls_b[1] ? read_data : {3{cpu_data}});
// Paused command slots become read-only raster slots. Masking WRITE EA
// also inhibits BUSS1/2 register clocks and transfer/accumulator strobes.
wire command_ref_ea = ref_ea && !pause_active;
wire command_write_ea = write_ea && !pause_active;
victory_hsc_pause pause_control (
	.clk(clk), .reset(reset), .request(pause_request), .ce_master(ce_master),
	.clock_addr(clock_addr), .blanking_n(blanking_n), .ras_n(ras_n),
	.write_latched(write_latched), .active(pause_active)
);
// Sample established data/mode on BIT's predicted positive edge. SSR LOAD
// releases on that same clock-latch transition, so post-edge mode loses LOAD.
assign ce_bit = ce_master && !bit_clk && clock_q[1];
always @(posedge clk) begin
	if(reset) begin
		command       <= 0;
		red_source    <= 0;
		blue_source   <= 0;
		green_source  <= 0;
		load_previous <= 8'hff;
	end else if(!pause_active) begin
		load_previous <= register_load_n;
		if(register_load_n[2] && !load_previous[2]) command <= mux_rgb[7:0];
		if(register_load_n[6] && !load_previous[6])
			red_source <= controls_b[1] ? read_data[7:0] : cpu_data;
		if(register_load_n[7] && !load_previous[7]) blue_source  <= cpu_data;
		if(register_load_n[3] && !load_previous[3]) green_source <= cpu_data;
	end
end
victory_hsc_clock clocks (
	.clk(clk), .reset(reset), .ce_master(ce_master), .blanking_n(blanking_n),
	.prom_addr(clock_addr), .prom_q(clock_q), .phase_outputs(),
	.seq_rise(), .seq_fall(), .e4clk(e4clk), .mpxrc(mpxrc), .bit_clk(bit_clk),
	.ref_ea(ref_ea), .seq_clk(seq_clk), .write_ea(write_ea), .sr_load(sr_load),
	.cas_n(cas_n), .ras_n(ras_n)
);
victory_hsc_sequencer sequencer (
	.clk(clk), .reset(reset), .paused(pause_active), .seq_clk(seq_clk), .command_clock(command_clock),
	.prom_b(prom_b), .prom_c(prom_c),
	.prom_d(prom_d), .prom_e(prom_e),
	.command(command[2:0]), .command_continue(command[7]), .htc(htc), .ltc(ltc),
	.vector_finished(vector_finished), .state_addr(state_addr), .ready_n(ready_n), .busy(busy),
	.zero_ram(zero_ram), .sea(sea), .controls_b(controls_b), .controls_c(controls_c), .controls_d(controls_d)
);
victory_hsc_memory_control control (
	.clk(clk), .reset(reset), .paused(pause_active), .ce_master(ce_master),
	.ref_ea(command_ref_ea), .write_ea(command_write_ea), .sr_load(sr_load), .screen_invert(screen_invert),
	.controls_d(controls_d), .plane_enable(command[6:4]|{3{vector_write}}), .address_select(address_select),
	.write_ea_n(), .write_vram_n(), .write_bus1_n(write_bus1_n), .write_bus2_n(write_bus2_n),
	.write_latched(write_latched), .plane_write_n(plane_write_n), .serial_mode(serial_mode)
);
victory_hsc_register_decode register_decode (
	.cpu_load_n(cpu_load_n), .write_bus1_n(write_bus1_n), .write_bus2_n(write_bus2_n),
	.command(command[2:0]), .register_load_n(register_load_n), .command_clock(command_clock)
);

victory_hsc_alignment_control alignment_control (
	.clk(clk), .reset(reset), .paused(pause_active), .write_ea(command_write_ea),
	.transfer_request(controls_c[7]), .manual_increment(controls_b[0]), .x_low(working_x[2:0]),
	.transfer_n(transfer_x_n), .increment_x(increment_x), .shift_enable_n(shift_enable_n)
);
victory_hsc_source_bus source_bus (
	.sea(sea), .data_rgb(source_rgb), .read_rgb(read_data),
	.first_rgb(first_rgb), .second_rgb(second_rgb), .source_rgb(source_mux)
);
victory_hsc_dimensions dimensions (
	.clk(clk), .reset(reset), .paused(pause_active), .seq_clk(seq_clk),
	.load_lh_n(controls_b[7]), .increment_l_n(controls_c[1]), .increment_h_n(controls_c[0]),
	.source_red(source_mux[23:16]), .length(dimension_length), .height(dimension_height),
	.ltc(ltc), .htc(htc)
);
victory_hsc_coordinates coordinates (
	.clk(clk), .reset(reset), .paused(pause_active), .ce_master(ce_master), .seq_clk(seq_clk),
	.load_x_n(register_load_n[4]), .load_y_n(register_load_n[5]),
	.transfer_x_n(transfer_x_n), .transfer_y_n(controls_b[4]), .add_x_n(add_x_n),
	.increment_x(increment_x), .increment_y_n(increment_y_n), .right(right), .down(down),
	.red_bus(mux_rgb[23:16]), .blue_bus(mux_rgb[15:8]),
	.x_prime(x_prime), .y_prime(y_prime), .x(working_x), .y(working_y)
);
victory_hsc_coordinate_control coordinate_control (
	.clk(clk), .reset(reset), .paused(pause_active), .ce_master(ce_master),
	.ref_ea(command_ref_ea), .write_ea(command_write_ea), .move_x(move_x), .move_y(move_y),
	.controls_b(controls_b), .controls_c(controls_c),
	.add_x_n(add_x_n), .increment_y_n(increment_y_n), .vector_write(vector_write)
);
victory_hsc_accumulator vector_accumulator (
	.clk(clk), .reset(reset), .paused(pause_active), .ce_master(ce_master), .seq_clk(seq_clk), .write_ea(command_write_ea),
	.controls_c(controls_c), .instruction_high(instruction_address[15:8]),
	.i_terminal(command_write_ea && controls_b[6] && instruction_address[7:0]==8'hff),
	.accumulator(accumulator), .carry(vector_carry), .vector_finished(vector_finished),
	.clear_n(), .accumulator_clock()
);
victory_hsc_vector vector_control (
	.octant(command[6:4]), .carry(vector_carry), .vector_finished(vector_finished),
	.prom_addr(vector_address), .prom_q(vector_q),
	.move_x(move_x), .move_y(move_y), .down(down), .right(right)
);
victory_hsc_shift shifts (
	.clk(clk), .reset(reset), .paused(pause_active), .ce_clock(ce_master),
	.transfer_n(transfer_x_n), .enable_n(shift_enable_n), .source_rgb(source_mux),
	.first_rgb(first_rgb), .second_rgb(second_rgb)
);
victory_hsc_collision collision (
	.clk(clk), .reset(reset), .paused(pause_active), .clear_n(collision_clear_n),
	.write_latched(write_latched), .collision_enable(command[3]),
	.ram_rgb(mux_rgb), .source_rgb(source_mux),
	.x({working_x[7:3],x_prime[2:0]}), .y(working_y),
	.pending_n(collision_pending_n), .capture_clock(), .hit(collision_hit),
	.captured_x(collision_x), .captured_y(collision_y)
);
victory_hsc_counters counters (
	.clk(clk), .reset(reset), .paused(pause_active), .ce_master(ce_master), .seq_clk(seq_clk),
	.write_ea(command_write_ea), .increment_i(controls_b[6]), .increment_pc(controls_c[2]),
	.load_il_n(register_load_n[0]), .load_ih_n(register_load_n[1]), .load_pc_n(controls_b[2]),
	.red_bus(mux_rgb[23:16]), .blue_bus(mux_rgb[15:8]), .y_prime(y_prime),
	.instruction_address(instruction_address), .program_counter(program_counter)
);
victory_hsc_address addresses (
	.address_select(address_select), .mpxrc(mpxrc), .instruction_address(instruction_address),
	.program_counter(program_counter), .x(working_x), .y(working_y),
	.raster_e(raster_e), .raster_l(raster_l), .byte_address(byte_address), .dram_address(dram_address)
);
victory_hsc_ram ram (
	.clk(clk), .reset(reset), .ras_n(ras_n), .cas_n(cas_n), .dram_address(dram_address),
	.plane_write_n(plane_write_n), .write_data(mux_rgb^source_mux),
	.read_data(read_data), .read_driving(), .read_valid(), .latched_address(latched_address)
);
victory_hsc_display display_registers (
	.clk(clk), .reset(reset), .ce_bit(ce_bit), .serial_mode(serial_mode),
	.screen_invert(screen_invert), .read_data(read_data),
	.pixel_rgb(pixel_rgb), .shift_rgb(display_shift_rgb)
);
endmodule

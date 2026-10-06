// SPDX-License-Identifier: GPL-3.0-or-later
// Synthesizable command implementation based on Aaron Giles's BSD-licensed
// victory_v.cpp. Register effects and state-count timing follow that reference;
// this is a behavioral command FSM, not the original PROM state sequencer.
module victory_graphics (
	input  wire        clk, reset, paused,
	input  wire        reg_wr,
	input  wire [2:0]  reg_addr,
	input  wire [7:0]  reg_data,
	input  wire        command_start, fg_pending,
	output wire [8:0]  prom_addr,
	input  wire [7:0]  prom_q,
	output wire        busy,
	output reg         fg_hit, command_overrun,
	output reg  [7:0]  fg_x, fg_y,
	output reg  [7:0]  current_cmd,
	input  wire [12:0] video_addr,
	output wire [23:0] video_q
);
reg [15:0] reg_i;
reg [7:0] reg_r, reg_g, reg_b, reg_x, reg_y;
reg [8:0] pc;
reg [13:0] mem_addr;
reg [2:0] mem_we;
reg [23:0] mem_data;
wire [23:0] mem_q;
victory_vram ram (
	.clk(clk), .engine_addr(mem_addr), .engine_we((paused || reset) ? 3'b000 : mem_we),
	.engine_data(mem_data), .engine_q(mem_q), .video_addr(video_addr), .video_q(video_q)
);

typedef enum logic [4:0] {
	IDLE, DISPATCH, SOURCE_WAIT, SOURCE_READ, FIRST_WAIT, FIRST_XOR,
	SECOND_ADDR, SECOND_WAIT, SECOND_XOR, ADVANCE, COPY_WRITE,
	COPY_ADVANCE, FETCH_ADDR, FETCH_WAIT, FETCH_FIRST, FETCH_SECOND_WAIT,
	FETCH_SECOND, VECTOR_ADDR, FINISH, ALIGN_LOAD, ALIGN_SHIFT
} state_t;
state_t state;
reg in_program, program_continue;
reg [7:0] x, y;
reg [2:0] plane_enable;
reg [23:0] source_rgb;
reg collision_first, detect_collision;
reg [8:0] vector_left;
reg [6:0] height, rows_left, copy_left;
reg [3:0] columns_left;
reg [7:0] vector_acc, vector_slope;

wire [23:0] first_bits, second_bits;
reg [2:0] shifts_left;
reg [15:0] shift_phase;
wire [16:0] shift_sum = {1'b0,shift_phase} + 17'd11289;
wire shift_tick = shift_sum >= 17'd48000;
// Use the actual serial/parallel storage behavior. The current command FSM
// requests loading/alignment; the PROM sequencer will supply these strobes
// when the shared RAM schedule is connected. /8 busy accounting remains below.
victory_hsc_shift pixel_shift (
	.clk(clk), .reset(reset), .paused(paused), .ce_clock(shift_tick),
	.transfer_n(state!=ALIGN_LOAD),
	.enable_n(state!=ALIGN_LOAD && state!=ALIGN_SHIFT), .source_rgb(source_rgb),
	.first_rgb(first_bits), .second_rgb(second_bits)
);
wire first_overlap, second_overlap;
// Sheet 15 detects occupied pixels across RGB colors. Plane write enables
// are absent from this circuit; they qualify RAM writes, not collisions.
victory_hsc_collision_pixels collision_byte1 (
	.ram_rgb(mem_q), .source_rgb(first_bits), .overlap(first_overlap)
);
victory_hsc_collision_pixels collision_byte2 (
	.ram_rgb(mem_q), .source_rgb(second_bits), .overlap(second_overlap)
);
wire [8:0] acc_sum = {1'b0,vector_acc} + {1'b0,vector_slope};
wire [4:0] vector_prom_addr;
wire move_x, move_y, move_down, move_right;
assign prom_addr = {4'b1000,vector_prom_addr};
victory_hsc_vector vector_decode (
	.octant(current_cmd[6:4]), .carry(acc_sum[8]),
	.vector_finished(vector_left==0), .prom_addr(vector_prom_addr), .prom_q(prom_q),
	.move_x(move_x), .move_y(move_y), .down(move_down), .right(move_right)
);
wire [6:0] sprite_height = 7'd64 - {1'b0,reg_r[4:0],1'b0};
wire [3:0] sprite_width = 4'd8 - {1'b0,reg_r[7:5]};

// MAME's busy model uses 11.289 MHz / 8. Keep the timer independent of the
// RAM micro-operations, which complete at the 48 MHz system clock.
reg [18:0] micro_phase;
wire [19:0] micro_sum = {1'b0,micro_phase} + 20'd11289;
wire micro_tick = micro_sum >= 20'd384000;
reg [23:0] busy_ticks;
wire [23:0] ticks_next = busy_ticks - ((micro_tick && busy_ticks != 0) ? 24'd1 : 24'd0);
assign busy = state != IDLE || busy_ticks != 0;

always @(posedge clk) begin
	if (reset) begin
		fg_hit            <= 0;
		state             <= IDLE;
		reg_i             <= 0;
		reg_r             <= 0;
		reg_g             <= 0;
		reg_b             <= 0;
		reg_x             <= 0;
		reg_y             <= 0;
		current_cmd       <= 0;
		pc                <= 0;
		mem_addr          <= 0;
		mem_we            <= 0;
		mem_data          <= 0;
		micro_phase       <= 0;
		shift_phase       <= 0;
		shifts_left       <= 0;
		busy_ticks        <= 0;
		in_program        <= 0;
		program_continue  <= 0;
		command_overrun   <= 0;
		fg_x              <= 0;
		fg_y              <= 0;
		collision_first   <= 0;
		detect_collision  <= 0;
		x                 <= 0;
		y                 <= 0;
		plane_enable      <= 0;
		source_rgb        <= 0;
		vector_left       <= 0;
		height            <= 0;
		rows_left         <= 0;
		copy_left         <= 0;
		columns_left      <= 0;
		vector_acc        <= 0;
		vector_slope      <= 0;
	end else if (!paused) begin
		fg_hit      <= 0;
		micro_phase <= micro_tick ? 19'(micro_sum - 20'd384000) : micro_sum[18:0];
		shift_phase <= shift_tick ? 16'(shift_sum - 17'd48000) : shift_sum[15:0];
		busy_ticks  <= ticks_next;
		mem_we      <= 0;
		if (command_start && state != IDLE) command_overrun <= 1;
		case (state)
			IDLE: if (command_start) begin
				in_program <= 0;
				program_continue <= 0;
				state      <= DISPATCH;
			end
			DISPATCH: begin
				plane_enable     <= current_cmd[6:4];
				detect_collision <= current_cmd[3];
				x                <= reg_x;
				y                <= reg_y;
				case (current_cmd[2:0])
					2: begin
						mem_addr   <= reg_i[13:0];
						mem_data   <= {reg_r,reg_b,reg_g};
						mem_we     <= current_cmd[6:4];
						reg_i      <= reg_i + 16'd1;
						busy_ticks <= ticks_next + 24'd3;
						state      <= FINISH;
					end
					3: begin
						height       <= sprite_height;
						rows_left    <= sprite_height;
						columns_left <= sprite_width;
						mem_addr     <= reg_i[13:0];
						busy_ticks   <= ticks_next + 24'd3 + (24'd2 + 24'(sprite_height)*24'd2)*24'(sprite_width);
						state        <= SOURCE_WAIT;
					end
					4: begin
						pc         <= {reg_y,1'b0};
						in_program <= 1;
						if (in_program) program_continue <= 1;
						if (!in_program) busy_ticks <= ticks_next + 24'd4;
						state      <= FETCH_ADDR;
					end
					5: begin
						vector_left  <= 9'd256 - {1'b0,reg_i[7:0]};
						vector_acc   <= 8'h80;
						vector_slope <= reg_i[15:8];
						source_rgb   <= {reg_r,reg_b,reg_g};
						plane_enable <= 3'b111;
						mem_addr     <= {1'b0,reg_y,reg_x[7:3]};
						busy_ticks   <= ticks_next + 24'd3 + (24'd256 - 24'(reg_i[7:0]))*24'd2;
						state        <= ALIGN_LOAD;
					end
					6: begin
						pc         <= {reg_y,1'b0};
						copy_left  <= sprite_height;
						mem_addr   <= reg_i[13:0];
						busy_ticks <= ticks_next + 24'd3 + 24'(sprite_height)*24'd2;
						state      <= SOURCE_WAIT;
					end
					7: begin
						source_rgb <= {reg_r,reg_b,reg_g};
						mem_addr   <= {1'b0,reg_y,reg_x[7:3]};
						busy_ticks <= ticks_next + 24'd4;
						state      <= ALIGN_LOAD;
					end
					// Program NOPs retain the preceding command's continuation.
					default: state <= in_program && program_continue ? FETCH_ADDR : IDLE;
				endcase
			end
			SOURCE_WAIT: state <= SOURCE_READ;
			SOURCE_READ: begin
				source_rgb <= mem_q;
				if (current_cmd[2:0] == 6) begin
					mem_addr <= 14'h2000 | {5'd0,pc};
					state    <= COPY_WRITE;
				end else begin
					mem_addr <= {1'b0,y,x[7:3]};
					state    <= ALIGN_LOAD;
				end
			end
			ALIGN_LOAD: if(shift_tick) begin
				shifts_left <= x[2:0];
				state <= x[2:0]==0 ? FIRST_WAIT : ALIGN_SHIFT;
			end
			ALIGN_SHIFT: if(shift_tick) begin
				shifts_left <= shifts_left - 3'd1;
				if(shifts_left==1) state <= FIRST_WAIT;
			end
			FIRST_WAIT: state <= FIRST_XOR;
			FIRST_XOR: begin
				collision_first <= first_overlap;
				mem_data        <= mem_q ^ first_bits;
				mem_we          <= plane_enable;
				state           <= SECOND_ADDR;
			end
			SECOND_ADDR: begin
				mem_addr <= mem_addr + 14'd1;
				state    <= SECOND_WAIT;
			end
			SECOND_WAIT: state <= SECOND_XOR;
			SECOND_XOR: begin
				mem_data <= mem_q ^ second_bits;
				mem_we   <= plane_enable;
				// HSC sheet 15: 11H feeds SFCIRQ back into 10H. All drawing
				// commands hold the first capture until the CPU reads its Y.
				if (detect_collision && !fg_pending &&
					(collision_first || second_overlap)) begin
					fg_hit <= 1;
					fg_x   <= current_cmd[2:0] == 7 ? x + 8'd8 : x;
					fg_y   <= y;
				end
				state <= ADVANCE;
			end
			ADVANCE: case (current_cmd[2:0])
				3: begin
					reg_i <= reg_i + 16'd1;
					if (rows_left > 1) begin
						rows_left <= rows_left - 7'd1;
						y         <= y + 8'd1;
						mem_addr  <= reg_i[13:0] + 14'd1;
						state     <= SOURCE_WAIT;
					end else begin
						reg_x <= reg_x + 8'd8;
						x     <= x + 8'd8;
						y     <= reg_y;
						if (columns_left > 1) begin
							columns_left <= columns_left - 4'd1;
							rows_left    <= height;
							mem_addr     <= reg_i[13:0] + 14'd1;
							state        <= SOURCE_WAIT;
						end else state <= FINISH;
					end
				end
				5: begin
					vector_acc <= acc_sum[7:0];
					// Sheet 10's downloaded 13E PROM supplies both movement
					// enables and directions. Its synchronous read settles
					// during the preceding RAM phases; pause holds inputs.
					if(move_x) x <= move_right ? x + 8'd1 : x - 8'd1;
					if(move_y) y <= move_down ? y + 8'd1 : y - 8'd1;
					vector_left <= vector_left - 9'd1;
					state       <= vector_left == 1 ? FINISH : VECTOR_ADDR;
				end
				default: state <= FINISH;
			endcase
			COPY_WRITE: begin
				mem_data <= source_rgb;
				mem_we   <= plane_enable;
				state    <= COPY_ADVANCE;
			end
			VECTOR_ADDR: begin
				mem_addr <= {1'b0,y,x[7:3]};
				state    <= ALIGN_LOAD;
			end
			COPY_ADVANCE: begin
				reg_i <= reg_i + 16'd1;
				pc    <= pc + 9'd1;
				if (copy_left > 1) begin
					copy_left <= copy_left - 7'd1;
					mem_addr  <= reg_i[13:0] + 14'd1;
					state     <= SOURCE_WAIT;
				end else state <= FINISH;
			end
			FETCH_ADDR: begin
				mem_addr <= 14'h2000 | {5'd0,pc};
				state    <= FETCH_WAIT;
			end
			FETCH_WAIT: state <= FETCH_FIRST;
			FETCH_FIRST: begin
				current_cmd <= mem_q[7:0];
				reg_i       <= {mem_q[15:8],mem_q[23:16]};
				mem_addr    <= 14'h2000 | {5'd0,(pc + 9'd1)};
				state       <= FETCH_SECOND_WAIT;
			end
			FETCH_SECOND_WAIT: state <= FETCH_SECOND;
			FETCH_SECOND: begin
				reg_r <= mem_q[7:0];
				reg_x <= mem_q[23:16];
				reg_y <= mem_q[15:8];
				pc    <= pc + 9'd2;
				state <= DISPATCH;
			end
			FINISH: begin
				program_continue <= current_cmd[7] && current_cmd[2:0] != 2;
				if (current_cmd[2:0] == 5) reg_x <= x;
				if (in_program && current_cmd[7] && current_cmd[2:0] != 2) state <= FETCH_ADDR;
				else state <= IDLE;
			end
			default: state <= IDLE;
		endcase
		// CPU register writes have priority, as in the shared hardware registers.
		if (reg_wr) case (reg_addr)
			0: reg_i[7:0] <= reg_data;
			1: reg_i[15:8] <= reg_data;
			2: current_cmd <= reg_data;
			3: reg_g <= reg_data;
			4: reg_x <= reg_data;
			5: reg_y <= reg_data;
			6: reg_r <= reg_data;
			7: reg_b <= reg_data;
		endcase
	end
end
endmodule

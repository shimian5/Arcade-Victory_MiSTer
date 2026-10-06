// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 15: 8E/8F/9E and 8D/9D/9F NOR each RGB triplet;
// 8C/9C OR the empty-pixel flags; 7C NANDs all eight results.
module victory_hsc_collision_pixels (
	input  wire [23:0] ram_rgb, source_rgb,
	output wire        overlap
);
wire [7:0] ram_occupied    = ram_rgb[23:16] | ram_rgb[15:8] | ram_rgb[7:0];
wire [7:0] source_occupied = source_rgb[23:16] | source_rgb[15:8] | source_rgb[7:0];
assign overlap = |(ram_occupied & source_occupied);
endmodule

// HSC sheets 7/15: 10H's qualified NAND clocks 11H and coordinate
// latches 10D/11D. Capture is on the RETURN edge of the collision pulse.
module victory_hsc_collision (
	input  wire        clk, reset, paused, clear_n,
	input  wire        write_latched, collision_enable,
	input  wire [23:0] ram_rgb, source_rgb,
	input  wire [7:0]  x, y,
	output wire        pending_n, capture_clock,
	output reg         hit,
	output reg  [7:0]  captured_x, captured_y
);
wire overlap;
reg pending, clock_previous, clear_previous;
victory_hsc_collision_pixels pixels (
	.ram_rgb(ram_rgb), .source_rgb(source_rgb), .overlap(overlap)
);
assign pending_n = !pending;
assign capture_clock = !(overlap && collision_enable && write_latched && pending_n);
always @(posedge clk) begin
	clear_previous <= clear_n;
	hit <= 0;
	if(reset) begin
		pending <= 0;
		clock_previous <= 1;
		clear_previous <= 1;
		hit <= 0;
		captured_x <= 0;
		captured_y <= 0;
	end else begin
		// 11H alone has /CLR. Sheet-7 10D/11D LS374s see the same
		// clock independently; SCLFIQ/SXFIQ only enable their bus outputs.
		if(!clear_n) pending <= 0;
		else if(!paused && capture_clock && !clock_previous) begin
			// Match /CLR at the preceding detected edge as well as now.
			pending <= clear_previous;
			hit <= clear_previous;
		end
		if(!paused || !clear_n) clock_previous <= capture_clock;
		if(!paused && capture_clock && !clock_previous) begin
			captured_x <= x;
			captured_y <= y;
		end
	end
end
endmodule

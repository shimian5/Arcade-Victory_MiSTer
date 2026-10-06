// SPDX-License-Identifier: GPL-3.0-or-later
// Complete RGB24 frames cross from native video to a 336x262 CRT raster.
// Request/acknowledgement transfers bank ownership, never game timing. See
// docs/CRT_RETIMER_DESIGN.md for the startup phase and held-bank CDC contract.
module victory_crt_retimer #(
	parameter integer VSYNC_LINES=1
) (
	input  wire        clk_native, clk_crt, reset_async,
	input  wire        ce_native,
	input  wire [23:0] rgb_native,
	input  wire [8:0]  x_native, y_native,
	input  wire        hb_native, vb_native,
	output reg         ce_out,
	output reg  [23:0] rgb_out,
	output reg  [8:0]  x_out, y_out,
	output reg         hs_out, vs_out, hb_out, vb_out,
	output wire        frame_valid,
	output reg  [31:0] skipped_frames, repeated_frames, malformed_frames
);
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg [1:0] reset_native_pipe=2'b11, reset_crt_pipe=2'b11;
always @(posedge clk_native or posedge reset_async) begin
	if(reset_async) reset_native_pipe<=2'b11;
	else reset_native_pipe<={reset_native_pipe[0],1'b0};
end
always @(posedge clk_crt or posedge reset_async) begin
	if(reset_async) reset_crt_pipe<=2'b11;
	else reset_crt_pipe<={reset_crt_pipe[0],1'b0};
end
wire reset_native=reset_native_pipe[1];
wire reset_crt=reset_crt_pipe[1];

reg write_bank, published_bank, request_toggle, ack_toggle;
reg read_bank, reader_valid, display_started;
(* altera_attribute = "-name SYNCHRONIZER_IDENTIFICATION FORCED" *)
reg ack_meta, ack_sync, request_meta, request_sync;
always @(posedge clk_native) begin
	if(reset_native) begin ack_meta<=0; ack_sync<=0; end
	else begin ack_meta<=ack_toggle; ack_sync<=ack_meta; end
end
always @(posedge clk_crt) begin
	if(reset_crt) begin request_meta<=0; request_sync<=0; end
	else begin request_meta<=request_toggle; request_sync<=request_meta; end
end

wire mailbox_free=request_toggle==ack_sync;
wire pending_frame=request_sync!=ack_toggle;
wire source_active=ce_native && !hb_native && !vb_native && x_native<256 && y_native<256;
wire source_start=source_active && x_native==0 && y_native==0;
wire [15:0] source_address={y_native[7:0],x_native[7:0]};
reg capturing;
reg [16:0] expected_address;
wire write_pixel=!reset_async && !reset_native && source_active &&
	(source_start ? mailbox_free : capturing && {1'b0,source_address}==expected_address);

// No reset/initial clear on the data array or read register: ownership and
// full-frame validity hide unwritten data while allowing mixed-clock M10K RAM.
reg [23:0] pixels[0:131071];
reg [23:0] read_rgb;
reg [8:0] raster_x, raster_y;
always @(posedge clk_native) if(write_pixel)
	pixels[{write_bank,source_address}]<=rgb_native;
always @(posedge clk_crt)
	read_rgb<=pixels[{read_bank,raster_y[7:0],raster_x[7:0]}];

always @(posedge clk_native) begin
	if(reset_native) begin
		write_bank<=0; published_bank<=0; request_toggle<=0;
		capturing<=0; expected_address<=0;
		skipped_frames<=0; malformed_frames<=0;
	end else if(source_start) begin
		if(capturing) malformed_frames<=malformed_frames+32'd1;
		capturing<=mailbox_free;
		expected_address<=17'd1;
		if(!mailbox_free) skipped_frames<=skipped_frames+32'd1;
	end else if(source_active && capturing) begin
		if({1'b0,source_address}!=expected_address) begin
			capturing<=0;
			malformed_frames<=malformed_frames+32'd1;
		end else if(source_address==16'hffff) begin
			capturing<=0;
			published_bank<=write_bank;
			request_toggle<=!request_toggle;
			write_bank<=!write_bank;
		end else expected_address<=expected_address+17'd1;
	end
end

reg [2:0] pixel_div;
wire pixel_tick=pixel_div==3'd7;
wire raster_end=raster_x==9'd335 && raster_y==9'd261;
assign frame_valid=reader_valid;
always @(posedge clk_crt) begin
	ce_out<=0;
	if(reset_crt) begin
		read_bank<=1; reader_valid<=0; display_started<=0; ack_toggle<=0;
		raster_x<=0; raster_y<=0; pixel_div<=0;
		rgb_out<=0; x_out<=0; y_out<=0;
		hs_out<=0; vs_out<=0; hb_out<=1; vb_out<=1;
		repeated_frames<=0;
	end else if(!reader_valid && pending_frame) begin
		// Start with six CRT blank lines after the first completed native
		// capture. Later consumer boundaries then fall inside native blank,
		// leaving time for acknowledgement before the next source (0,0).
		read_bank<=published_bank; ack_toggle<=request_sync; reader_valid<=1;
		raster_x<=0; raster_y<=9'd256; pixel_div<=0;
	end else begin
		pixel_div<=pixel_div+3'd1;
		if(pixel_tick) begin
			if(reader_valid && raster_x==0 && raster_y==0) display_started<=1;
			ce_out<=1;
			x_out<=raster_x; y_out<=raster_y;
			hb_out<=raster_x>=9'd256 || !reader_valid;
			vb_out<=raster_y>=9'd256 || !reader_valid;
			hs_out<=raster_x>=9'd272 && raster_x<9'd304;
			vs_out<=raster_y>=9'd258 && raster_y<9'(258+VSYNC_LINES);
			rgb_out<=reader_valid && raster_x<256 && raster_y<256 ? read_rgb : 24'd0;
			if(raster_x==9'd335) begin
				raster_x<=0;
				raster_y<=raster_y==9'd261 ? 9'd0 : raster_y+9'd1;
			end else raster_x<=raster_x+9'd1;
			// Swap at the final blank pixel, before prefetching next frame's
			// pixel (0,0). Switching on (0,0) would retain one old-bank pixel.
			if(reader_valid && raster_end) begin
				if(pending_frame) begin read_bank<=published_bank; ack_toggle<=request_sync; end
				else if(display_started) repeated_frames<=repeated_frames+32'd1;
			end
		end
	end
end
endmodule

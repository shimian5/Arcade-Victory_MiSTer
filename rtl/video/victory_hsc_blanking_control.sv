// SPDX-License-Identifier: GPL-3.0-or-later
// HSC sheet 4 pin network around 15J. ROM contents are external and must
// not be fabricated from the other PROMs in the supplied Victory set.
// Pin levels must settle in SYS before the sampled clock edge.
module victory_hsc_blanking_control (
	input  wire        clk, reset, paused,
	input  wire [7:3]  raster_e,
	input  wire [7:0]  raster_l,
	input  wire [7:0]  video_control, rom_data,
	input  wire        sr_load, l256, clear_virq_n,
	output wire [10:0] rom_address,
	output wire        shblk, svblk,
	output reg         ebirq, virq_n
);
// 2716 A10/pin19=SELOVER, A9..A5=L128..L8, A4..A0=E128..E8.
// /CE18 and /OE20 are grounded, VPP21 is tied +5.
assign rom_address = {video_control[1],raster_l[7:3],raster_e};
// Output pins 17/16/15 are Q7/Q6/Q5 respectively. Only the first
// two pass through 14J NANDs; Q5 is 12J D2, sampled by SSR LOAD.
assign shblk = !(rom_data[7] && video_control[7]);
assign svblk = !(rom_data[6] && video_control[6]);
reg sr_load_q, l256_q;
always @(posedge clk) begin
	sr_load_q <= sr_load;
	l256_q <= l256;
	if(reset || !video_control[5]) ebirq <= 0;
	else if(sr_load && !sr_load_q) ebirq <= rom_data[5];
	// Other half of 12J: D12=+5, CLK11=L256, /CLR13=CLRVIRQ.
	// Export /Q8; clear takes priority even when CLK rises concurrently.
	if(reset || !clear_virq_n) virq_n <= 1;
	// MiSTer pause holds game IRQ state while video keeps running. Track
	// L256 throughout that hold so resume cannot invent a delayed edge.
	else if(!paused && l256 && !l256_q) virq_n <= 0;
end
endmodule

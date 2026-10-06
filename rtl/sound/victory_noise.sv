// SPDX-License-Identifier: GPL-3.0-or-later
// Audio sheet 9's K4 (CD4006) and K5 (CD4070).
// The physical chip has no reset; all-one startup is a deterministic seed,
// not a claim about its electrical power-up contents.
module victory_noise (
	input  wire clk, reset, paused,
	input  wire e_clock, q1, select_q1, address_a0,
	output wire noise_level
);
reg [3:0] section_1, section_3;
reg [4:0] section_2, section_4;
reg clock_q;
wire noise_clock = select_q1 ? q1 : e_clock;
assign noise_level = section_3[3]; // K4 pin 10 goes to 6840 C1/C2/C3.
always @(posedge clk) begin
	if(reset) begin
		section_1 <= 4'hf;
		section_2 <= 5'h1f;
		section_3 <= 4'hf;
		section_4 <= 5'h1f;
		clock_q <= noise_clock;
	end else if(!paused) begin
		clock_q <= noise_clock;
		// CD4006 shifts on a falling clock edge. Connections are actual
		// chip pins: D1(1)<-Q12, D2(4)<-Q8^Q12, D3(5)<-Q13^A0,
		// D4(6)<-Q10. The two five-stage sections also expose stage 4.
		if(clock_q && !noise_clock) begin
			section_1 <= {section_1[2:0],section_2[4]};
			section_2 <= {section_2[3:0],section_4[3]^section_2[4]};
			section_3 <= {section_3[2:0],section_1[3]^address_a0};
			section_4 <= {section_4[3:0],section_3[3]};
		end
	end
end
endmodule

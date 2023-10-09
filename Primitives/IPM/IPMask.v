/****************************************************************************
 * IPMask.v
 ****************************************************************************/

/**
 * Module: IPMask
 * 
 * TODO: Add module documentation
 */
module IPMask #(parameter v = 8) (
	input [(v-1)*8 - 1 : 0] rand,
	input [v*8 - 1 : 0] L,
	input [7:0] S,
	output [v*8 - 1: 0] R
);
	
	wire [v*8 - 1: 0] g4out;
	wire [v*8 - 1: 0] sums;
	
	assign sums[7:0] = S[7:0];
	
	genvar i;
	generate
	for(i = 1; i < v; i = i + 1) begin
		assign R[((i+1)*8)-1 : i*8] = rand[i*8-1 : (i-1)*8];
		gmul8 gmul8 (
				.x(L[((i+1)*8)-1 : i*8]),
				.y(rand[i*8-1 : (i-1)*8]),
				.xy(g4out[((i+1)*8)-1 : i*8])
			);
		assign sums[((i+1)*8)-1 : i*8] = g4out[((i+1)*8)-1 : i*8] ^ sums[(i*8)-1 : (i-1)*8];
	end
	endgenerate
	assign R[7:0] = sums[(v*8) - 1 : ((v-1)*8)];


endmodule



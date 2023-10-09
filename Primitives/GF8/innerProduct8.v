/****************************************************************************
 * innerProduct4.v
 ****************************************************************************/

/**
 * Module: innerProduct
 * 
 * TODO: Add module documentation
 */
module innerProduct8 #(parameter v = 8) (
		input [v*8 - 1 : 0] x,
		input [v*8 - 1: 0] y,
		output [7 : 0] xy
		);
	wire [v*8 - 1 : 0] sums;
	wire [v*8 - 1 : 0] g4out;
	
	gmul8 gmul8 (
			.x(x[7:0]),
			.y(y[7:0]),
			.xy(sums[7:0])
		);
	
	genvar i;
	generate
		for(i = 1; i < v; i = i + 1) begin
			gmul8 gmul8 (
					.x(x[((i+1)*8)-1 : i*8]),
					.y(y[((i+1)*8)-1 : i*8]),
					.xy(g4out[((i+1)*8)-1 : i*8])
				);
			assign sums[((i+1)*8)-1 : i*8] = g4out[((i+1)*8)-1 : i*8] ^ sums[(i*8)-1 : (i-1)*8];
		end
	endgenerate
	assign xy = sums[(v*8) - 1 : ((v-1)*8)];


endmodule


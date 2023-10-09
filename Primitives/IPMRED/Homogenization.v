/****************************************************************************
 * Homogenization.v
 ****************************************************************************/

/**
 * Module: Homogenization
 * 
 * TODO: Add module documentation
 */
module Homogenization #(parameter v = 3) (
	input [v*8-1:0] L2,
	input [(v-1)*8 - 1: 0] a,
	input [(v-1)*8 - 1: 0] b,
	output [v*8 - 1: 0] c
);

	wire [(v-1)*8-1 : 0] delta;
	wire [(v-1)*8-1 : 0] sum;
	wire [(v-1)*8-1 : 0] prod;
	assign delta[7:0] = b[7:0];

	genvar j;
	generate
		for(j = 1; j < v-1; j = j + 1) begin
			assign c[(j+2)*8-1 : (j+1)*8] = a[(j+1)*8-1 : j*8];
			assign sum[j*8 - 1 : (j-1)*8] = b[(j+1)*8-1 : j*8] ^ a[(j+1)*8-1 : j*8];
			gmul8 gmul8(.x(L2[(j+2)*8-1 : (j+1)*8]), .y(sum[j*8 - 1 : (j-1)*8]), .xy(prod[j*8-1 : (j-1)*8]));
			assign delta[(j+1)*8-1 : j*8] = delta[j*8 - 1 : (j-1)*8] ^ prod[j*8-1 : (j-1)*8];
		end
	endgenerate

	assign c[15:8] = delta[(v-1)*8-1 : (v-2)*8];
	assign c[7:0] = a[7:0];


endmodule



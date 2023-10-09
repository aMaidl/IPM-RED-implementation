/****************************************************************************
 * IPMMask.v
 ****************************************************************************/

/**
 * Module: IPMMask
 * 
 * TODO: Add module documentation
 */
module IPMREDMask #(parameter v = 3) (
	input [(v-2)*8 - 1 : 0] rand,
	input [v*8-1:0] L1,
	input [v*8-1:0] L2,
	input [7:0] S,
	output [7:0] S3,
	output [v*8 - 1: 0] R
);

	cube8 cube8(
        .x(S),
        .x3(S3)
	);
	
	wire [(v-2)*8 - 1 : 0] products1;
	wire [(v-2)*8 - 1 : 0] products2;
	
	wire [(v-1)*8 - 1 : 0] sums1;
	wire [(v-1)*8 - 1 : 0] sums2;
	assign sums1[7:0] = 8'b0;
	assign sums2[7:0] = 8'b0;
	
	genvar i;
	genvar j;
	for (i = 0; i < v - 2; i = i + 1) begin
		gmul8 product1 (.x(L1[(i+3)*8 - 1 : (i+2)*8]), .y(rand[(i+1)*8-1 : i*8]), .xy(products1[(i+1)*8-1 : i*8]));
		gmul8 product2 (.x(L2[(i+3)*8 - 1 : (i+2)*8]), .y(rand[(i+1)*8-1 : i*8]), .xy(products2[(i+1)*8-1 : i*8]));
		assign sums1[(i+2)*8 - 1 : (i+1)*8] = sums1[(i+1)*8 - 1 : i*8] ^ products1[(i+1)*8-1 : i*8];
		assign sums2[(i+2)*8 - 1 : (i+1)*8] = sums2[(i+1)*8 - 1 : i*8] ^ products2[(i+1)*8-1 : i*8];
		assign R[(i+3)*8 - 1 : (i+2)*8] = rand[(i+1)*8-1 : i*8];
	end
	
	assign R[7:0] = S ^ sums1[(v-1)*8 - 1 : (v-2)*8];
	assign R[15:8] = S3 ^ sums2[(v-1)*8 - 1 : (v-2)*8];
	


endmodule



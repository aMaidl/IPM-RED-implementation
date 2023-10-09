/****************************************************************************
 * IPSetup.v
 ****************************************************************************/

/**
 * Module: IPSetup
 * 
 * TODO: Add module documentation
 */
module IPSetup #(parameter v = 8) (
	input [(v-1)*8 - 1 : 0] rand,
	output [v*8-1:0] L,
	output [(v*v*8)-1:0] L_hat
);
	
	wire [7:0] g4out;
	
	assign L[7:0] = 8'b1;
	genvar i;
	for(i = 1; i < v; i = i + 1) begin
		assign L[((i+1)*8)-1 : i*8] = rand[i*8 - 1 : (i - 1)*8];
	end
	
	genvar j;
	generate
	for(i = 0; i < v; i = i + 1) begin
		for(j = 0; j < v; j = j + 1) begin
			// 2d access:
			// A[i, j] = A[(i*v*4 + (j+1)*4)-1 : i*v*4 + j*4]
			gmul8 gmul8 (
					.x(L[((i+1)*8)-1 : i*8]),
					.y(L[((j+1)*8)-1 : j*8]),
					.xy(L_hat[i*8*v+j*8+7:i*8*v+j*8])
					);
		end
	end
	endgenerate


endmodule



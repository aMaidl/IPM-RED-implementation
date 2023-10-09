/****************************************************************************
 * IPMSetup.v
 ****************************************************************************/

/**
 * Module: IPMSetup
 * 
 * TODO: Add module documentation
 */
module IPMREDSetup #(parameter v = 8) (
	input [2*(v-2)*8 - 1 : 0] rand,
	output [v*8-1:0] L1,
	output [v*8-1:0] L2,
	// this is only the small version of L_hat because we never need the full version
	// we always only multiply the smaller sharings z(1) and z(2), so multiplication with (v-1) shares is done
	output [((v-1)*(v-1)*8)-1:0] L1_hat,
	output [((v-1)*(v-1)*8)-1:0] L2_hat
);
	
	assign L1[7:0] = 8'b1;
	assign L1[15:8] = 8'b0;
	assign L2[7:0] = 8'b0;
	assign L2[15:8] = 8'b1;
	
	genvar i;
	genvar j;
	for(i = 2; i < v; i = i + 1) begin
		assign L1[((i+1)*8)-1 : i*8] = rand[2*(i-2)*8 + 7 : 2*(i-2)*8];
		assign L2[((i+1)*8)-1 : i*8] = rand[2*(i-2)*8 + 15 : 2*(i-2)*8 + 8];
	end
	
	wire [(v-1)*8 - 1 : 0] L1_ = {L1[v*8 - 1:16],L1[7:0]};
	wire [(v-1)*8 - 1 : 0] L2_ = {L2[v*8 - 1:8]};
	
	generate
		for(i = 0; i < (v-1); i = i + 1) begin
			for(j = 0; j < (v-1); j = j + 1) begin
				// 2d access:
				// A[i, j] = A[(i*v*4 + (j+1)*4)-1 : i*v*4 + j*4]
				gmul8 gmul1 (
						.x(L1_[((i+1)*8)-1 : i*8]),
						.y(L1_[((j+1)*8)-1 : j*8]),
						.xy(L1_hat[i*8*(v-1)+j*8+7:i*8*(v-1)+j*8])
					);
				gmul8 gmul2 (
						.x(L2_[((i+1)*8)-1 : i*8]),
						.y(L2_[((j+1)*8)-1 : j*8]),
						.xy(L2_hat[i*8*(v-1)+j*8+7:i*8*(v-1)+j*8])
					);
			end
		end
	endgenerate
	
	
	
endmodule
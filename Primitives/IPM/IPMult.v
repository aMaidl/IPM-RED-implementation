/****************************************************************************
 * IPMult.v
 ****************************************************************************/

/**
 * Module: IPMult
 * 
 * TODO: Add module documentation
 */
module IPMult #(parameter v = 8) (
	input [(v*v*8) - 2 : 0] rand,
	input [v*8 - 1 : 0] R,
	input [v*8 - 1 : 0] Q,
	input [(v*v*8)-1 : 0] L_hat,
	output [v*8 - 1 : 0] T
);
	
	wire [(v*v*8)-1 : 0] A_hat_build;
	wire [(v*v*8)-1 : 0] A_hat;
	wire [(v*v*8)-1 : 0] R_hat;
	wire [(v*v*8)-1 : 0] B_hat;
	genvar i;
	genvar j;
	genvar k;
	
	// Line 1, init \hat{A}
	// Random Sampling
	for(i = 0; i < v; i = i + 1) begin
		for(j = 0; j < v; j = j + 1) begin
			if (i != (v-1) || j != (v-1)) begin
				assign A_hat_build[i*8*v+j*8+7:i*8*v+j*8] = rand[i*8*v+j*8+7:i*8*v+j*8];
			end else begin
				assign A_hat_build[i*8*v+j*8+7:i*8*v+j*8] = 8'b0;
			end
		end
	end
	
	// refer to "Mult_Line1_impl.pdf"
	// Stage 1:
	// calculate all the deltas
	wire [(v+1)*8-1:0] delta;
	assign delta[7:0] = 8'b0;
	wire [v*v*8-1:0] inner_terms;
	wire [v*v*8-1:0] inner_sums;
	generate
		for(j = 0; j < v; j = j + 1) begin
			for(i = 0; i < v; i = i + 1) begin
			    if(j==0 && i == 0) begin
                    assign inner_terms[i*8*v+j*8+7:i*8*v+j*8] = A_hat_build[i*8*v+j*8+7:i*8*v+j*8];
			    end else begin
                    gmul8 gmul8 (
                            .x(A_hat_build[i*8*v+j*8+7:i*8*v+j*8]),
                            .y(L_hat[i*8*v+j*8+7:i*8*v+j*8]),
                            .xy(inner_terms[i*8*v+j*8+7:i*8*v+j*8])
                        );
                end
				if (i == 0) begin
					assign inner_sums[i*8*v+j*8+7:i*8*v+j*8] = inner_terms[i*8*v+j*8+7:i*8*v+j*8];
				end else begin
					assign inner_sums[i*8*v+j*8+7:i*8*v+j*8] = inner_terms[i*8*v+j*8+7:i*8*v+j*8] ^ inner_sums[(i-1)*8*v+j*8+7:(i-1)*8*v+j*8];
				end
			end
			assign delta[8*((j+1)+1)-1:8*(j+1)] = delta[8*(j+1)-1:8*j] ^ inner_sums[(v-1)*8*v+j*8+7:(v-1)*8*v+j*8];
		end
	endgenerate
	// Stage 2
	// invert last element of L_hat and multiply it with delta
	wire [7:0] inverted;
	invert8 i8 (
			.a(L_hat[(v*v*8)-1 : (v*v*8)-1-7]),
			.b(inverted)
		);
	gmul8 g8 (
			.x(inverted),
			.y(delta[(v+1)*8-1:8*v]),
			.xy(A_hat[(v*v*8)-1 : (v*v*8)-1-7])
		);
	// assemble final A_hat matrix
	assign A_hat[(v*v*8)-1-8 : 0] = A_hat_build[(v*v*8)-1-8 : 0];
	
	
	// Inner product of Vectors R and Q, reuse IPSetup
	for(i = 0; i < v; i = i + 1) begin
		for(j = 0; j < v; j = j + 1) begin
			// 2d access:
			// A[i, j] = A[(i*v*4 + (j+1)*4)-1 : i*v*4 + j*4]
			gmul8 gmul8 (
					.x(R[((i+1)*8)-1 : i*8]),
					.y(Q[((j+1)*8)-1 : j*8]),
					.xy(R_hat[i*8*v+j*8+7:i*8*v+j*8])
				);
		end
	end
	
	// elementwise addition of R_hat and A_hat yields B_hat
	for(i = 0; i < v; i = i + 1) begin
		for(j = 0; j < v; j = j + 1) begin
			assign B_hat[i*8*v+j*8+7:i*8*v+j*8] = R_hat[i*8*v+j*8+7:i*8*v+j*8] ^ A_hat[i*8*v+j*8+7:i*8*v+j*8];
		end
	end
	
	// Line 4, row-wise processing
	wire [v*8-1:0] beta;
	assign beta[7:0] = B_hat[7:0];
	wire [v*(v-1)*8-1:0] inner_terms_beta;
	wire [v*(v-1)*8-1:0] inner_sums_beta;
	generate
		for(i = 1; i < v; i = i + 1) begin
			for(j = 0; j < v; j = j + 1) begin
			    if(j==0 && i == 0) begin
                    assign inner_terms_beta[i*8*v+j*8+7:i*8*v+j*8] = L_hat[i*8*v+j*8+7:i*8*v+j*8];
			    end else begin
                    gmul8 gmul8 (
                            .x(L_hat[i*8*v+j*8+7:i*8*v+j*8]),
                            .y(B_hat[i*8*v+j*8+7:i*8*v+j*8]),
                            .xy(inner_terms_beta[(i-1)*8*v+j*8+7:(i-1)*8*v+j*8])
                        );
                end
				if (j == 0) begin
					assign inner_sums_beta[(i-1)*8*v+j*8+7:(i-1)*8*v+j*8] = inner_terms_beta[(i-1)*8*v+j*8+7:(i-1)*8*v+j*8];
				end else begin
					assign inner_sums_beta[(i-1)*8*v+j*8+7:(i-1)*8*v+j*8] =
						inner_terms_beta[(i-1)*8*v+j*8+7:(i-1)*8*v+j*8] ^ inner_sums_beta[(i-1)*8*v+(j-1)*8+7:(i-1)*8*v+(j-1)*8];
				end
			end
			assign beta[8*(i+1)-1:8*i] = beta[8*((i-1)+1)-1:8*(i-1)] ^ inner_sums_beta[(i-1)*8*v+(v-1)*8+7:(i-1)*8*v+(v-1)*8];
		end
	endgenerate
	
	for(j = 1; j < v; j = j + 1) begin
		assign T[8*(j+1)-1:8*j] = B_hat[0*8*v+j*8+7:0*8*v+j*8];
	end
	assign T[7:0] = beta[8*v-1:8*(v-1)];


endmodule



/****************************************************************************
 * IPMREDMult.v
 ****************************************************************************/

/**
 * Module: IPMREDMult
 * 
 * TODO: Add module documentation
 */
module IPMREDMult #(parameter v = 8) (
	input [2*((v-1)*(v-1)*8) - 2 : 0] rand,
	input [v*8 - 1 : 0] Z,
	input [v*8 - 1 : 0] Z_,
	input [v*8-1:0] L2,
	input [((v-1)*(v-1)*8)-1:0] L1_hat,
	input [((v-1)*(v-1)*8)-1:0] L2_hat,
	output [v*8 - 1 : 0] P
);
	wire [(v-1)*8 - 1 : 0] z1 = {Z[v*8 - 1:16],Z[7:0]};
	wire [(v-1)*8 - 1 : 0] z2 = {Z[v*8 - 1:8]};
	wire [(v-1)*8 - 1 : 0] z1_ = {Z_[v*8 - 1:16], Z_[7:0]};
	wire [(v-1)*8 - 1 : 0] z2_ = {Z_[v*8 - 1:8]};
	wire [(v-1)*8 - 1 : 0] t;
	wire [(v-1)*8 - 1 : 0] u;

	IPMult #(.v(v-1)) IPMult_t (
		.rand(rand[((v-1)*(v-1)*8) - 2 : 0]), // input [(v*v*4) - 2 : 0] rand,
		.R(z1), // input [v*4 - 1 : 0] R,
		.Q(z1_), // input [v*4 - 1 : 0] Q,
		.L_hat(L1_hat), // input [(v*v*4)-1 : 0] L_hat,
		.T(t) // output [v*4 - 1 : 0] T
	);

	IPMult #(.v(v-1)) IPMult_u (
			.rand(rand[2*((v-1)*(v-1)*8) - 2 : ((v-1)*(v-1)*8)]), // input [(v*v*4) - 2 : 0] rand,
			.R(z2), // input [v*4 - 1 : 0] R,
			.Q(z2_), // input [v*4 - 1 : 0] Q,
			.L_hat(L2_hat), // input [(v*v*4)-1 : 0] L_hat,
			.T(u) // output [v*4 - 1 : 0] T
		);
	
	Homogenization #(.v(v)) homgen (
		.L2(L2), // input [v*4-1:0] L2,
		.a(t), // input [v*4 - 1: 0] a, // a = t
		.b(u), // input [v*4 - 1: 0] b, // b = u
		.c(P) // output [v*4 - 1: 0] c
	);

endmodule



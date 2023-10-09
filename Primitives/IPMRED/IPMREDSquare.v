/****************************************************************************
 * IPMREDMult.v
 ****************************************************************************/

/**
 * Module: IPMREDMult
 * 
 * TODO: Add module documentation
 */
module IPMREDSquare #(parameter v = 8) (
	input [v*8 - 1 : 0] Z,
	input [v*8-1:0] L1,
	input [v*8-1:0] L2,
	output [v*8 - 1 : 0] P
);

	wire [(v-1)*8 - 1 : 0] z1 = {Z[v*8 - 1:16],Z[7:0]};
	wire [(v-1)*8 - 1 : 0] z2 = {Z[v*8 - 1:8]};
	wire [(v-1)*8 - 1 : 0] t;
	wire [(v-1)*8 - 1 : 0] u;

	IPSquare #(.v(v-1)) IPSquare1 (
		.R(z1), // input [v*4 - 1 : 0] R,
		.L({L1[v*8-1:16], L1[7:0]}), // input [(v*v*4)-1 : 0] L_hat,
		.T(t) // output [v*4 - 1 : 0] T
	);

	IPSquare #(.v(v-1)) IPSquare2 (
        .R(z2), // input [v*4 - 1 : 0] R,
        .L(L2[v*8-1:8]), // input [(v*v*4)-1 : 0] L_hat,
        .T(u) // output [v*4 - 1 : 0] T
    );
	
	Homogenization #(.v(v)) homgen (
		.L2(L2), // input [v*4-1:0] L2,
		.a(t), // input [v*4 - 1: 0] a, // a = t
		.b(u), // input [v*4 - 1: 0] b, // b = u
		.c(P) // output [v*4 - 1: 0] c
	);

endmodule



module IPMREDMultConst #(parameter v = 8) (
	input [v*8 - 1 : 0] Z,
	input [7 : 0] const,
	input [v*8-1:0] L2,
	output [v*8 - 1 : 0] P
);

	wire [(v-1)*8 - 1 : 0] z1 = {Z[v*8 - 1:16],Z[7:0]};
	wire [(v-1)*8 - 1 : 0] z2 = {Z[v*8 - 1:8]};
	wire [(v-1)*8 - 1 : 0] t;
	wire [(v-1)*8 - 1 : 0] u;

	IPMultConst #(.v(v-1)) IPMultConst1 (
		.R(z1), // input [v*4 - 1 : 0] R,
		.const(const), // input [v*4 - 1 : 0] Q,
		.T(t) // output [v*4 - 1 : 0] T
	);

    wire [7:0] const3;
    cube8 cube8(
        .x(const),
        .x3(const3)
    );

	IPMultConst #(.v(v-1)) IPMultConst2 (
        .R(z2), // input [v*4 - 1 : 0] R,
        .const(const3), // input [v*4 - 1 : 0] Q,
        .T(u) // output [v*4 - 1 : 0] T
    );

	Homogenization #(.v(v)) homgen (
		.L2(L2), // input [v*4-1:0] L2,
		.a(t), // input [v*4 - 1: 0] a, // a = t
		.b(u), // input [v*4 - 1: 0] b, // b = u
		.c(P) // output [v*4 - 1: 0] c
	);

endmodule

module IPMREDAdd #(parameter v = 8) (
	input [2*((v-1)*(v-1)*8) - 2 : 0] rand,
	input [v*8 - 1 : 0] Z,
	input [v*8 - 1 : 0] Z_,
	input [v*8-1:0] L1,
	input [v*8-1:0] L2,
	input [((v-1)*(v-1)*8)-1:0] L1_hat,
	input [((v-1)*(v-1)*8)-1:0] L2_hat,
	output [v*8 - 1 : 0] P
);

	wire [(v-1)*8 - 1 : 0] z1 = {Z[v*8 - 1:16],Z[7:0]};
	wire [(v-1)*8 - 1 : 0] z2 = {Z[v*8 - 1:8]};
	wire [(v-1)*8 - 1 : 0] z1_ = {Z_[v*8 - 1:16], Z_[7:0]};
	wire [(v-1)*8 - 1 : 0] z2_ = {Z_[v*8 - 1:8]};
	wire [(v-1)*8 - 1 : 0] L1_star = {L1[v*8-1:16], L1[7:0]};
	wire [(v-1)*8 - 1 : 0] L2_star = L2[v*8-1:8];


	wire [(v-1)*8 - 1 : 0] line1;
	wire [(v-1)*8 - 1 : 0] line2;
	wire [(v-1)*8 - 1 : 0] line3;
	wire [(v-1)*8 - 1 : 0] line4;
	wire [(v-1)*8 - 1 : 0] line5;
	wire [(v-1)*8 - 1 : 0] line6;
	wire [(v-1)*8 - 1 : 0] line7;
	wire [(v-1)*8 - 1 : 0] line8;
	wire [(v-1)*8 - 1 : 0] line9;

	IPAdd #(.v(v-1)) l1 ( // x + x'
			.R(z1),
			.Q(z1_),
			.T(line1)
		);

	IPAdd #(.v(v-1)) l2 ( // x^3 + (x')^3
			.R(z2),
			.Q(z2_),
			.T(line2)
		);

	IPSquare #(.v(v-1)) l3 ( // x^2
			.R(z1), 
			.L(L1_star), 
			.T(line3) 
		);

	IPMult #(.v(v-1)) l4 ( // x^2 * x'
			.rand(rand[1*((v-1)*(v-1)*8) - 2 : 0*((v-1)*(v-1)*8)]), 
			.R(line3), 
			.Q(z1_), 
			.L_hat(L1_hat), 
			.T(line4) 
		);


	IPSquare #(.v(v-1)) l5 ( // (x')^2
			.R(z1_), 
			.L(L1_star), 
			.T(line5) 
		);

	IPMult #(.v(v-1)) l6 ( // (x')^2 * x
			.rand(rand[2*((v-1)*(v-1)*8) - 2 : 1*((v-1)*(v-1)*8)]), 
			.R(line5), 
			.Q(z1), 
			.L_hat(L1_hat), 
			.T(line6) 
		);

	IPAdd #(.v(v-1)) l7 ( // (x')^2 * x + x^2 * x'
			.R(line4),
			.Q(line6),
			.T(line7)
		);

	ShiftPublic #(.v(v-1)) l8 (.in(line7), .L_old(L1_star), .L_new(L2_star), .out(line8));

	IPAdd #(.v(v-1)) l9 (
			.R(line8),
			.Q(line2),
			.T(line9)
		);

	Homogenization #(.v(v)) l10 (
			.L2(L2), 
			.a(line1),
			.b(line9),
			.c(P) 
		);

endmodule




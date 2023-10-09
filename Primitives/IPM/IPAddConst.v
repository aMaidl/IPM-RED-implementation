module IPAddConst #(parameter v = 8) (
	input [v*8 - 1 : 0] R,
	input [7 : 0] const,
	output [v*8 - 1: 0] T
);
	
	assign T = {R[v*8 - 1 : 8], R[7:0] ^ const};


endmodule



/****************************************************************************
 * IPAdd.v
 ****************************************************************************/

/**
 * Module: IPAdd
 * 
 * TODO: Add module documentation
 */
module IPAdd #(parameter v = 8) (
	input [v*8 - 1 : 0] R,
	input [v*8 - 1: 0] Q,
	output [v*8 - 1: 0] T
);
	
	assign T[v*8 - 1: 0] = R[v*8 - 1: 0] ^ Q[v*8 - 1: 0];


endmodule



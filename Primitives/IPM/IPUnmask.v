/****************************************************************************
 * IPUnmask.v
 ****************************************************************************/

/**
 * Module: IPUnmask
 * 
 * TODO: Add module documentation
 */
module IPUnmask #(parameter v = 8) (
	input [v*8 - 1 : 0] L,
	input [v*8 - 1: 0] R,
	output [7 : 0] S
);

	innerProduct8 #(.v(v)) innerProduct8(
        .x(L),
        .y(R),
        .xy(S)
	);


endmodule



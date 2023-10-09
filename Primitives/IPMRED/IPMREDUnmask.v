/****************************************************************************
 * IPUnmask.v
 ****************************************************************************/

/**
 * Module: IPUnmask
 * 
 * TODO: Add module documentation
 */
module IPMREDUnmask #(parameter v = 4) (
	input [v*8 - 1 : 0] L1,
	input [v*8 - 1 : 0] L2,
	input [v*8 - 1: 0] R,
	output [7 : 0] S,
	output [7 : 0] S3
);

	innerProduct8 #(.v(v)) innerProduct1 (
        .x(L1),
        .y(R),
        .xy(S)
	);
	innerProduct8 #(.v(v)) innerProduct2 (
        .x(L2),
        .y(R),
        .xy(S3)
	);


endmodule



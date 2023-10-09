/****************************************************************************
 * IPSquare.v
 ****************************************************************************/

/**
 * Module: IPAdd
 *
 * TODO: Add module documentation
 */
module IPSquare #(parameter v = 8) (
	input [v*8 - 1 : 0] R,
	input [v*8 - 1 : 0] L,
	output [v*8 - 1 : 0] T
);

	square8 sq1 (
        .a(R[7:0]),
        .b(T[7:0])
	);

	wire [v*8 - 1 : 0] temp;

	genvar i;
	generate
		for(i = 1; i < v; i = i + 1) begin
			square8 sq (
			        .a(R[((i+1)*8)-1 : i*8]),
			        .b(temp[((i+1)*8)-1 : i*8])
				);
			gmul8 gm8 (
			        .x(L[((i+1)*8)-1 : i*8]),
			        .y(temp[((i+1)*8)-1 : i*8]),
			        .xy(T[((i+1)*8)-1 : i*8])
			    );
		end
	endgenerate

endmodule
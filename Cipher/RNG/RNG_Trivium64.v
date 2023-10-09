/****************************************************************************
 * AddKey.v
 ****************************************************************************/

/**
 * Module: AddKey
 *
 * TODO: Add module documentation
 */
module RNG_Trivium64 #(parameter instances = 5, parameter npad = 3) (
    input clk,
    input enable,
    input reseed,
    //input [instances*80-1:0] IV,
    input [instances*80-1:0] seed,
    output isReady,
	output [instances*64-1:0] random
);

    Trivium64 T64(
        .clk(clk),
        .enable(enable),
        .reseed(reseed),
        .IV(80'd0),
        .seed(seed[1*80-1 -: 80]),
        .isReady(isReady),
        .random(random[1*64-1 -: 64])
    );

    genvar j;
	generate
		for(j = 1; j < instances; j = j + 1) begin
		    Trivium64 T64(
                .clk(clk),
                .enable(enable),
                .reseed(reseed),
                .IV({48'd0, j}),
                .seed(seed[(j+1)*80-1 -: 80]),
                .random(random[(j+1)*64-1 -: 64])
		    );
		end
	endgenerate


endmodule
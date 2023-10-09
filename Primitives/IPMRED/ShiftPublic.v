/****************************************************************************
 * ShiftPublic.v
 ****************************************************************************/

/**
 * Module: ShiftBase
 * 
 * TODO: Add module documentation
 */
module ShiftPublic #(parameter v = 3) (
		// this expects an IPM share as input (NOT IPM-RED)
		// therefore both Ls have their 0 entry removed
	input [v*8-1:0] in,
	input [v*8-1:0] L_old,
	input [v*8-1:0] L_new,
	output [v*8 - 1: 0] out
);
	wire [v*8-1:0] delta;

    genvar j;
    generate
        for (j = 1; j < v; j = j + 1) begin : loop
            assign delta[(j+1)*8-1 : j*8] = L_old[(j+1)*8-1 : j*8] ^ L_new[(j+1)*8-1 : j*8];
        end
    endgenerate

    wire [7:0] inner;

    innerProduct8 #(.v(v-1)) innerProduct8 (
            .x(delta[v*8-1:8]),
            .y(in[v*8-1:8]),
            .xy(inner)
        );
    assign out = {in[v*8-1:8], in[7:0] ^ inner};


endmodule



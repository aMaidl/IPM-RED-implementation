module IPMultConst #(parameter v = 8) (
	input [v*8 - 1 : 0] R,
	input [7 : 0] const,
	output [v*8 - 1 : 0] T
);

    genvar i;
    for(i = 0; i < v; i = i + 1) begin
        gmul8 gmul8(
            .x(R[((i+1)*8)-1 : i*8]),
            .y(const),
            .xy(T[((i+1)*8)-1 : i*8])
        );
    end



endmodule

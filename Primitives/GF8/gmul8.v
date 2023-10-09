module gmul8 (
	input	[7:0]	x,
	input	[7:0]	y,
	output	[7:0]	xy
);


    wire [9*32-1:0] res;
    wire [9*32-1:0] roundx;

    // init roundx and roundy
    assign roundx[31:0] = x[7:0];
    assign res[31:0] = 0;

    // compare with
    // https://github.com/Qomo-CHENG/IPM-FD/blob/master/src/IPM.c
    // (GF256_Mult)
    genvar i;
    genvar j;
    generate
        for(i = 0; i < 8; i = i + 1) begin
            assign res[((i+2)*32)-1 : (i+1)*32] = (y[i]) ? res[((i+1)*32)-1 : i*32] ^ roundx[((i+1)*32)-1 : i*32] : res[((i+1)*32)-1 : i*32];
            assign roundx[((i+2)*32)-1 : (i+1)*32] = (roundx[i*32+7]) ? (roundx[((i+1)*32)-1 : i*32] << 1) ^ 32'h1B : (roundx[((i+1)*32)-1 : i*32] << 1);
        end
    endgenerate

    assign xy = res[264:256];



endmodule
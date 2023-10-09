module square8 (
	input  [7:0] a,
	output [7:0] b
);


	wire [7:0] square_lut [255:0];
	assign {
		square_lut[  0],square_lut[  1],square_lut[  2],square_lut[  3],square_lut[  4],square_lut[  5],square_lut[  6],square_lut[  7],
        square_lut[  8],square_lut[  9],square_lut[ 10],square_lut[ 11],square_lut[ 12],square_lut[ 13],square_lut[ 14],square_lut[ 15],
        square_lut[ 16],square_lut[ 17],square_lut[ 18],square_lut[ 19],square_lut[ 20],square_lut[ 21],square_lut[ 22],square_lut[ 23],
        square_lut[ 24],square_lut[ 25],square_lut[ 26],square_lut[ 27],square_lut[ 28],square_lut[ 29],square_lut[ 30],square_lut[ 31],
        square_lut[ 32],square_lut[ 33],square_lut[ 34],square_lut[ 35],square_lut[ 36],square_lut[ 37],square_lut[ 38],square_lut[ 39],
        square_lut[ 40],square_lut[ 41],square_lut[ 42],square_lut[ 43],square_lut[ 44],square_lut[ 45],square_lut[ 46],square_lut[ 47],
        square_lut[ 48],square_lut[ 49],square_lut[ 50],square_lut[ 51],square_lut[ 52],square_lut[ 53],square_lut[ 54],square_lut[ 55],
        square_lut[ 56],square_lut[ 57],square_lut[ 58],square_lut[ 59],square_lut[ 60],square_lut[ 61],square_lut[ 62],square_lut[ 63],
        square_lut[ 64],square_lut[ 65],square_lut[ 66],square_lut[ 67],square_lut[ 68],square_lut[ 69],square_lut[ 70],square_lut[ 71],
        square_lut[ 72],square_lut[ 73],square_lut[ 74],square_lut[ 75],square_lut[ 76],square_lut[ 77],square_lut[ 78],square_lut[ 79],
        square_lut[ 80],square_lut[ 81],square_lut[ 82],square_lut[ 83],square_lut[ 84],square_lut[ 85],square_lut[ 86],square_lut[ 87],
        square_lut[ 88],square_lut[ 89],square_lut[ 90],square_lut[ 91],square_lut[ 92],square_lut[ 93],square_lut[ 94],square_lut[ 95],
        square_lut[ 96],square_lut[ 97],square_lut[ 98],square_lut[ 99],square_lut[100],square_lut[101],square_lut[102],square_lut[103],
        square_lut[104],square_lut[105],square_lut[106],square_lut[107],square_lut[108],square_lut[109],square_lut[110],square_lut[111],
        square_lut[112],square_lut[113],square_lut[114],square_lut[115],square_lut[116],square_lut[117],square_lut[118],square_lut[119],
        square_lut[120],square_lut[121],square_lut[122],square_lut[123],square_lut[124],square_lut[125],square_lut[126],square_lut[127],
        square_lut[128],square_lut[129],square_lut[130],square_lut[131],square_lut[132],square_lut[133],square_lut[134],square_lut[135],
        square_lut[136],square_lut[137],square_lut[138],square_lut[139],square_lut[140],square_lut[141],square_lut[142],square_lut[143],
        square_lut[144],square_lut[145],square_lut[146],square_lut[147],square_lut[148],square_lut[149],square_lut[150],square_lut[151],
        square_lut[152],square_lut[153],square_lut[154],square_lut[155],square_lut[156],square_lut[157],square_lut[158],square_lut[159],
        square_lut[160],square_lut[161],square_lut[162],square_lut[163],square_lut[164],square_lut[165],square_lut[166],square_lut[167],
        square_lut[168],square_lut[169],square_lut[170],square_lut[171],square_lut[172],square_lut[173],square_lut[174],square_lut[175],
        square_lut[176],square_lut[177],square_lut[178],square_lut[179],square_lut[180],square_lut[181],square_lut[182],square_lut[183],
        square_lut[184],square_lut[185],square_lut[186],square_lut[187],square_lut[188],square_lut[189],square_lut[190],square_lut[191],
        square_lut[192],square_lut[193],square_lut[194],square_lut[195],square_lut[196],square_lut[197],square_lut[198],square_lut[199],
        square_lut[200],square_lut[201],square_lut[202],square_lut[203],square_lut[204],square_lut[205],square_lut[206],square_lut[207],
        square_lut[208],square_lut[209],square_lut[210],square_lut[211],square_lut[212],square_lut[213],square_lut[214],square_lut[215],
        square_lut[216],square_lut[217],square_lut[218],square_lut[219],square_lut[220],square_lut[221],square_lut[222],square_lut[223],
        square_lut[224],square_lut[225],square_lut[226],square_lut[227],square_lut[228],square_lut[229],square_lut[230],square_lut[231],
        square_lut[232],square_lut[233],square_lut[234],square_lut[235],square_lut[236],square_lut[237],square_lut[238],square_lut[239],
        square_lut[240],square_lut[241],square_lut[242],square_lut[243],square_lut[244],square_lut[245],square_lut[246],square_lut[247],
        square_lut[248],square_lut[249],square_lut[250],square_lut[251],square_lut[252],square_lut[253],square_lut[254],square_lut[255]
		} =

		{
		8'h00,8'h01,8'h04,8'h05,8'h10,8'h11,8'h14,8'h15,
        8'h40,8'h41,8'h44,8'h45,8'h50,8'h51,8'h54,8'h55,
        8'h1B,8'h1A,8'h1F,8'h1E,8'h0B,8'h0A,8'h0F,8'h0E,
        8'h5B,8'h5A,8'h5F,8'h5E,8'h4B,8'h4A,8'h4F,8'h4E,
        8'h6C,8'h6D,8'h68,8'h69,8'h7C,8'h7D,8'h78,8'h79,
        8'h2C,8'h2D,8'h28,8'h29,8'h3C,8'h3D,8'h38,8'h39,
        8'h77,8'h76,8'h73,8'h72,8'h67,8'h66,8'h63,8'h62,
        8'h37,8'h36,8'h33,8'h32,8'h27,8'h26,8'h23,8'h22,
        8'hAB,8'hAA,8'hAF,8'hAE,8'hBB,8'hBA,8'hBF,8'hBE,
        8'hEB,8'hEA,8'hEF,8'hEE,8'hFB,8'hFA,8'hFF,8'hFE,
        8'hB0,8'hB1,8'hB4,8'hB5,8'hA0,8'hA1,8'hA4,8'hA5,
        8'hF0,8'hF1,8'hF4,8'hF5,8'hE0,8'hE1,8'hE4,8'hE5,
        8'hC7,8'hC6,8'hC3,8'hC2,8'hD7,8'hD6,8'hD3,8'hD2,
        8'h87,8'h86,8'h83,8'h82,8'h97,8'h96,8'h93,8'h92,
        8'hDC,8'hDD,8'hD8,8'hD9,8'hCC,8'hCD,8'hC8,8'hC9,
        8'h9C,8'h9D,8'h98,8'h99,8'h8C,8'h8D,8'h88,8'h89,
        8'h9A,8'h9B,8'h9E,8'h9F,8'h8A,8'h8B,8'h8E,8'h8F,
        8'hDA,8'hDB,8'hDE,8'hDF,8'hCA,8'hCB,8'hCE,8'hCF,
        8'h81,8'h80,8'h85,8'h84,8'h91,8'h90,8'h95,8'h94,
        8'hC1,8'hC0,8'hC5,8'hC4,8'hD1,8'hD0,8'hD5,8'hD4,
        8'hF6,8'hF7,8'hF2,8'hF3,8'hE6,8'hE7,8'hE2,8'hE3,
        8'hB6,8'hB7,8'hB2,8'hB3,8'hA6,8'hA7,8'hA2,8'hA3,
        8'hED,8'hEC,8'hE9,8'hE8,8'hFD,8'hFC,8'hF9,8'hF8,
        8'hAD,8'hAC,8'hA9,8'hA8,8'hBD,8'hBC,8'hB9,8'hB8,
        8'h31,8'h30,8'h35,8'h34,8'h21,8'h20,8'h25,8'h24,
        8'h71,8'h70,8'h75,8'h74,8'h61,8'h60,8'h65,8'h64,
        8'h2A,8'h2B,8'h2E,8'h2F,8'h3A,8'h3B,8'h3E,8'h3F,
        8'h6A,8'h6B,8'h6E,8'h6F,8'h7A,8'h7B,8'h7E,8'h7F,
        8'h5D,8'h5C,8'h59,8'h58,8'h4D,8'h4C,8'h49,8'h48,
        8'h1D,8'h1C,8'h19,8'h18,8'h0D,8'h0C,8'h09,8'h08,
        8'h46,8'h47,8'h42,8'h43,8'h56,8'h57,8'h52,8'h53,
        8'h06,8'h07,8'h02,8'h03,8'h16,8'h17,8'h12,8'h13
		};

    assign b = square_lut[a];
endmodule
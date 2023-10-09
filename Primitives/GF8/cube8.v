module cube8 (
	input	[7:0]	x,
	output	[7:0]	x3
);




	wire [7:0] e3_lut [255:0];
	assign {
		e3_lut[  0],e3_lut[  1],e3_lut[  2],e3_lut[  3],e3_lut[  4],e3_lut[  5],e3_lut[  6],e3_lut[  7],
        e3_lut[  8],e3_lut[  9],e3_lut[ 10],e3_lut[ 11],e3_lut[ 12],e3_lut[ 13],e3_lut[ 14],e3_lut[ 15],
        e3_lut[ 16],e3_lut[ 17],e3_lut[ 18],e3_lut[ 19],e3_lut[ 20],e3_lut[ 21],e3_lut[ 22],e3_lut[ 23],
        e3_lut[ 24],e3_lut[ 25],e3_lut[ 26],e3_lut[ 27],e3_lut[ 28],e3_lut[ 29],e3_lut[ 30],e3_lut[ 31],
        e3_lut[ 32],e3_lut[ 33],e3_lut[ 34],e3_lut[ 35],e3_lut[ 36],e3_lut[ 37],e3_lut[ 38],e3_lut[ 39],
        e3_lut[ 40],e3_lut[ 41],e3_lut[ 42],e3_lut[ 43],e3_lut[ 44],e3_lut[ 45],e3_lut[ 46],e3_lut[ 47],
        e3_lut[ 48],e3_lut[ 49],e3_lut[ 50],e3_lut[ 51],e3_lut[ 52],e3_lut[ 53],e3_lut[ 54],e3_lut[ 55],
        e3_lut[ 56],e3_lut[ 57],e3_lut[ 58],e3_lut[ 59],e3_lut[ 60],e3_lut[ 61],e3_lut[ 62],e3_lut[ 63],
        e3_lut[ 64],e3_lut[ 65],e3_lut[ 66],e3_lut[ 67],e3_lut[ 68],e3_lut[ 69],e3_lut[ 70],e3_lut[ 71],
        e3_lut[ 72],e3_lut[ 73],e3_lut[ 74],e3_lut[ 75],e3_lut[ 76],e3_lut[ 77],e3_lut[ 78],e3_lut[ 79],
        e3_lut[ 80],e3_lut[ 81],e3_lut[ 82],e3_lut[ 83],e3_lut[ 84],e3_lut[ 85],e3_lut[ 86],e3_lut[ 87],
        e3_lut[ 88],e3_lut[ 89],e3_lut[ 90],e3_lut[ 91],e3_lut[ 92],e3_lut[ 93],e3_lut[ 94],e3_lut[ 95],
        e3_lut[ 96],e3_lut[ 97],e3_lut[ 98],e3_lut[ 99],e3_lut[100],e3_lut[101],e3_lut[102],e3_lut[103],
        e3_lut[104],e3_lut[105],e3_lut[106],e3_lut[107],e3_lut[108],e3_lut[109],e3_lut[110],e3_lut[111],
        e3_lut[112],e3_lut[113],e3_lut[114],e3_lut[115],e3_lut[116],e3_lut[117],e3_lut[118],e3_lut[119],
        e3_lut[120],e3_lut[121],e3_lut[122],e3_lut[123],e3_lut[124],e3_lut[125],e3_lut[126],e3_lut[127],
        e3_lut[128],e3_lut[129],e3_lut[130],e3_lut[131],e3_lut[132],e3_lut[133],e3_lut[134],e3_lut[135],
        e3_lut[136],e3_lut[137],e3_lut[138],e3_lut[139],e3_lut[140],e3_lut[141],e3_lut[142],e3_lut[143],
        e3_lut[144],e3_lut[145],e3_lut[146],e3_lut[147],e3_lut[148],e3_lut[149],e3_lut[150],e3_lut[151],
        e3_lut[152],e3_lut[153],e3_lut[154],e3_lut[155],e3_lut[156],e3_lut[157],e3_lut[158],e3_lut[159],
        e3_lut[160],e3_lut[161],e3_lut[162],e3_lut[163],e3_lut[164],e3_lut[165],e3_lut[166],e3_lut[167],
        e3_lut[168],e3_lut[169],e3_lut[170],e3_lut[171],e3_lut[172],e3_lut[173],e3_lut[174],e3_lut[175],
        e3_lut[176],e3_lut[177],e3_lut[178],e3_lut[179],e3_lut[180],e3_lut[181],e3_lut[182],e3_lut[183],
        e3_lut[184],e3_lut[185],e3_lut[186],e3_lut[187],e3_lut[188],e3_lut[189],e3_lut[190],e3_lut[191],
        e3_lut[192],e3_lut[193],e3_lut[194],e3_lut[195],e3_lut[196],e3_lut[197],e3_lut[198],e3_lut[199],
        e3_lut[200],e3_lut[201],e3_lut[202],e3_lut[203],e3_lut[204],e3_lut[205],e3_lut[206],e3_lut[207],
        e3_lut[208],e3_lut[209],e3_lut[210],e3_lut[211],e3_lut[212],e3_lut[213],e3_lut[214],e3_lut[215],
        e3_lut[216],e3_lut[217],e3_lut[218],e3_lut[219],e3_lut[220],e3_lut[221],e3_lut[222],e3_lut[223],
        e3_lut[224],e3_lut[225],e3_lut[226],e3_lut[227],e3_lut[228],e3_lut[229],e3_lut[230],e3_lut[231],
        e3_lut[232],e3_lut[233],e3_lut[234],e3_lut[235],e3_lut[236],e3_lut[237],e3_lut[238],e3_lut[239],
        e3_lut[240],e3_lut[241],e3_lut[242],e3_lut[243],e3_lut[244],e3_lut[245],e3_lut[246],e3_lut[247],
        e3_lut[248],e3_lut[249],e3_lut[250],e3_lut[251],e3_lut[252],e3_lut[253],e3_lut[254],e3_lut[255]
		} =

		{
		 8'h0,8'h1,8'h8,8'hF,8'h40,8'h55,8'h78,8'h6B,8'h36,8'h7F,8'h9E,8'hD1,8'hED,8'hB0,8'h75,8'h2E,
         8'hAB,8'hA1,8'hD5,8'hD9,8'h9C,8'h82,8'hD2,8'hCA,8'h29,8'h6B,8'hF7,8'hB3,8'h85,8'hD3,8'h6B,8'h3B,
         8'h2F,8'h62,8'h7F,8'h34,8'hF2,8'hAB,8'h92,8'hCD,8'h8C,8'h89,8'h7C,8'h7F,8'hCA,8'hDB,8'hA,8'h1D,
         8'h53,8'h15,8'h75,8'h35,8'hF9,8'hAB,8'hEF,8'hBB,8'h44,8'h4A,8'hC2,8'hCA,8'h75,8'h6F,8'hC3,8'hDF,
         8'h63,8'h89,8'h3D,8'hD1,8'hD5,8'h2B,8'hBB,8'h43,8'hD1,8'h73,8'h2F,8'h8B,8'hFC,8'h4A,8'h32,8'h82,
         8'hC,8'hED,8'h24,8'hC3,8'hCD,8'h38,8'hD5,8'h26,8'hA,8'hA3,8'h82,8'h2D,8'h50,8'hED,8'hE8,8'h53,
         8'hAE,8'h8,8'hA8,8'h8,8'h85,8'h37,8'hB3,8'h7,8'h89,8'h67,8'h2F,8'hC7,8'h39,8'hC3,8'hAF,8'h53,
         8'h16,8'hBB,8'h66,8'hCD,8'h4A,8'hF3,8'hA,8'hB5,8'h85,8'h60,8'h55,8'hB6,8'h42,8'hB3,8'hA2,8'h55,
         8'h35,8'h2E,8'h24,8'h39,8'hF3,8'hFC,8'hD2,8'hDB,8'hF2,8'hA1,8'h43,8'h16,8'hAF,8'hE8,8'h2E,8'h6F,
         8'hD2,8'hC2,8'hB5,8'hA3,8'h63,8'h67,8'h34,8'h36,8'hA1,8'hF9,8'h66,8'h38,8'h8B,8'hC7,8'h7C,8'h36,
         8'h60,8'h37,8'h29,8'h78,8'h3B,8'h78,8'h42,8'h7,8'h32,8'h2D,8'hDB,8'hC2,8'hF2,8'hF9,8'h2B,8'h26,
         8'h50,8'hC,8'h6F,8'h35,8'h7C,8'h34,8'h73,8'h3D,8'hB6,8'hA2,8'h29,8'h3B,8'h1,8'h1,8'hAE,8'hA8,
         8'h7,8'hF7,8'h40,8'hB6,8'h37,8'hD3,8'h40,8'hA2,8'h44,8'hFC,8'hA3,8'h1D,8'hEF,8'h43,8'h38,8'h92,
         8'h24,8'hDF,8'h15,8'hE8,8'h63,8'h8C,8'h62,8'h8B,8'hD3,8'h60,8'h42,8'hF7,8'hF,8'hA8,8'hAE,8'hF,
         8'hB0,8'hC,8'hAF,8'h15,8'h1D,8'hB5,8'h32,8'h9C,8'h66,8'h92,8'hD9,8'h2B,8'h50,8'hB0,8'hDF,8'h39,
         8'h44,8'hF3,8'h2D,8'h9C,8'h9E,8'h3D,8'hC7,8'h62,8'h26,8'hD9,8'hEF,8'h16,8'h67,8'h8C,8'h9E,8'h73
		};

	assign x3 = e3_lut[x];


endmodule
module invert8 (
	input  [7:0] a,
	output [7:0] b
);


	wire [7:0] inv_lut [255:0];
	assign {
		inv_lut[  0],inv_lut[  1],inv_lut[  2],inv_lut[  3],inv_lut[  4],inv_lut[  5],inv_lut[  6],inv_lut[  7],
        inv_lut[  8],inv_lut[  9],inv_lut[ 10],inv_lut[ 11],inv_lut[ 12],inv_lut[ 13],inv_lut[ 14],inv_lut[ 15],
        inv_lut[ 16],inv_lut[ 17],inv_lut[ 18],inv_lut[ 19],inv_lut[ 20],inv_lut[ 21],inv_lut[ 22],inv_lut[ 23],
        inv_lut[ 24],inv_lut[ 25],inv_lut[ 26],inv_lut[ 27],inv_lut[ 28],inv_lut[ 29],inv_lut[ 30],inv_lut[ 31],
        inv_lut[ 32],inv_lut[ 33],inv_lut[ 34],inv_lut[ 35],inv_lut[ 36],inv_lut[ 37],inv_lut[ 38],inv_lut[ 39],
        inv_lut[ 40],inv_lut[ 41],inv_lut[ 42],inv_lut[ 43],inv_lut[ 44],inv_lut[ 45],inv_lut[ 46],inv_lut[ 47],
        inv_lut[ 48],inv_lut[ 49],inv_lut[ 50],inv_lut[ 51],inv_lut[ 52],inv_lut[ 53],inv_lut[ 54],inv_lut[ 55],
        inv_lut[ 56],inv_lut[ 57],inv_lut[ 58],inv_lut[ 59],inv_lut[ 60],inv_lut[ 61],inv_lut[ 62],inv_lut[ 63],
        inv_lut[ 64],inv_lut[ 65],inv_lut[ 66],inv_lut[ 67],inv_lut[ 68],inv_lut[ 69],inv_lut[ 70],inv_lut[ 71],
        inv_lut[ 72],inv_lut[ 73],inv_lut[ 74],inv_lut[ 75],inv_lut[ 76],inv_lut[ 77],inv_lut[ 78],inv_lut[ 79],
        inv_lut[ 80],inv_lut[ 81],inv_lut[ 82],inv_lut[ 83],inv_lut[ 84],inv_lut[ 85],inv_lut[ 86],inv_lut[ 87],
        inv_lut[ 88],inv_lut[ 89],inv_lut[ 90],inv_lut[ 91],inv_lut[ 92],inv_lut[ 93],inv_lut[ 94],inv_lut[ 95],
        inv_lut[ 96],inv_lut[ 97],inv_lut[ 98],inv_lut[ 99],inv_lut[100],inv_lut[101],inv_lut[102],inv_lut[103],
        inv_lut[104],inv_lut[105],inv_lut[106],inv_lut[107],inv_lut[108],inv_lut[109],inv_lut[110],inv_lut[111],
        inv_lut[112],inv_lut[113],inv_lut[114],inv_lut[115],inv_lut[116],inv_lut[117],inv_lut[118],inv_lut[119],
        inv_lut[120],inv_lut[121],inv_lut[122],inv_lut[123],inv_lut[124],inv_lut[125],inv_lut[126],inv_lut[127],
        inv_lut[128],inv_lut[129],inv_lut[130],inv_lut[131],inv_lut[132],inv_lut[133],inv_lut[134],inv_lut[135],
        inv_lut[136],inv_lut[137],inv_lut[138],inv_lut[139],inv_lut[140],inv_lut[141],inv_lut[142],inv_lut[143],
        inv_lut[144],inv_lut[145],inv_lut[146],inv_lut[147],inv_lut[148],inv_lut[149],inv_lut[150],inv_lut[151],
        inv_lut[152],inv_lut[153],inv_lut[154],inv_lut[155],inv_lut[156],inv_lut[157],inv_lut[158],inv_lut[159],
        inv_lut[160],inv_lut[161],inv_lut[162],inv_lut[163],inv_lut[164],inv_lut[165],inv_lut[166],inv_lut[167],
        inv_lut[168],inv_lut[169],inv_lut[170],inv_lut[171],inv_lut[172],inv_lut[173],inv_lut[174],inv_lut[175],
        inv_lut[176],inv_lut[177],inv_lut[178],inv_lut[179],inv_lut[180],inv_lut[181],inv_lut[182],inv_lut[183],
        inv_lut[184],inv_lut[185],inv_lut[186],inv_lut[187],inv_lut[188],inv_lut[189],inv_lut[190],inv_lut[191],
        inv_lut[192],inv_lut[193],inv_lut[194],inv_lut[195],inv_lut[196],inv_lut[197],inv_lut[198],inv_lut[199],
        inv_lut[200],inv_lut[201],inv_lut[202],inv_lut[203],inv_lut[204],inv_lut[205],inv_lut[206],inv_lut[207],
        inv_lut[208],inv_lut[209],inv_lut[210],inv_lut[211],inv_lut[212],inv_lut[213],inv_lut[214],inv_lut[215],
        inv_lut[216],inv_lut[217],inv_lut[218],inv_lut[219],inv_lut[220],inv_lut[221],inv_lut[222],inv_lut[223],
        inv_lut[224],inv_lut[225],inv_lut[226],inv_lut[227],inv_lut[228],inv_lut[229],inv_lut[230],inv_lut[231],
        inv_lut[232],inv_lut[233],inv_lut[234],inv_lut[235],inv_lut[236],inv_lut[237],inv_lut[238],inv_lut[239],
        inv_lut[240],inv_lut[241],inv_lut[242],inv_lut[243],inv_lut[244],inv_lut[245],inv_lut[246],inv_lut[247],
        inv_lut[248],inv_lut[249],inv_lut[250],inv_lut[251],inv_lut[252],inv_lut[253],inv_lut[254],inv_lut[255]
		} =

		{
		 8'h00, 8'h01, 8'h8d, 8'hf6, 8'hcb, 8'h52, 8'h7b, 8'hd1,
         8'he8, 8'h4f, 8'h29, 8'hc0, 8'hb0, 8'he1, 8'he5, 8'hc7,
         8'h74, 8'hb4, 8'haa, 8'h4b, 8'h99, 8'h2b, 8'h60, 8'h5f,
         8'h58, 8'h3f, 8'hfd, 8'hcc, 8'hff, 8'h40, 8'hee, 8'hb2,
         8'h3a, 8'h6e, 8'h5a, 8'hf1, 8'h55, 8'h4d, 8'ha8, 8'hc9,
         8'hc1, 8'h0a, 8'h98, 8'h15, 8'h30, 8'h44, 8'ha2, 8'hc2,
         8'h2c, 8'h45, 8'h92, 8'h6c, 8'hf3, 8'h39, 8'h66, 8'h42,
         8'hf2, 8'h35, 8'h20, 8'h6f, 8'h77, 8'hbb, 8'h59, 8'h19,
         8'h1d, 8'hfe, 8'h37, 8'h67, 8'h2d, 8'h31, 8'hf5, 8'h69,
         8'ha7, 8'h64, 8'hab, 8'h13, 8'h54, 8'h25, 8'he9, 8'h09,
         8'hed, 8'h5c, 8'h05, 8'hca, 8'h4c, 8'h24, 8'h87, 8'hbf,
         8'h18, 8'h3e, 8'h22, 8'hf0, 8'h51, 8'hec, 8'h61, 8'h17,
         8'h16, 8'h5e, 8'haf, 8'hd3, 8'h49, 8'ha6, 8'h36, 8'h43,
         8'hf4, 8'h47, 8'h91, 8'hdf, 8'h33, 8'h93, 8'h21, 8'h3b,
         8'h79, 8'hb7, 8'h97, 8'h85, 8'h10, 8'hb5, 8'hba, 8'h3c,
         8'hb6, 8'h70, 8'hd0, 8'h06, 8'ha1, 8'hfa, 8'h81, 8'h82,
         8'h83, 8'h7e, 8'h7f, 8'h80, 8'h96, 8'h73, 8'hbe, 8'h56,
         8'h9b, 8'h9e, 8'h95, 8'hd9, 8'hf7, 8'h02, 8'hb9, 8'ha4,
         8'hde, 8'h6a, 8'h32, 8'h6d, 8'hd8, 8'h8a, 8'h84, 8'h72,
         8'h2a, 8'h14, 8'h9f, 8'h88, 8'hf9, 8'hdc, 8'h89, 8'h9a,
         8'hfb, 8'h7c, 8'h2e, 8'hc3, 8'h8f, 8'hb8, 8'h65, 8'h48,
         8'h26, 8'hc8, 8'h12, 8'h4a, 8'hce, 8'he7, 8'hd2, 8'h62,
         8'h0c, 8'he0, 8'h1f, 8'hef, 8'h11, 8'h75, 8'h78, 8'h71,
         8'ha5, 8'h8e, 8'h76, 8'h3d, 8'hbd, 8'hbc, 8'h86, 8'h57,
         8'h0b, 8'h28, 8'h2f, 8'ha3, 8'hda, 8'hd4, 8'he4, 8'h0f,
         8'ha9, 8'h27, 8'h53, 8'h04, 8'h1b, 8'hfc, 8'hac, 8'he6,
         8'h7a, 8'h07, 8'hae, 8'h63, 8'hc5, 8'hdb, 8'he2, 8'hea,
         8'h94, 8'h8b, 8'hc4, 8'hd5, 8'h9d, 8'hf8, 8'h90, 8'h6b,
         8'hb1, 8'h0d, 8'hd6, 8'heb, 8'hc6, 8'h0e, 8'hcf, 8'had,
         8'h08, 8'h4e, 8'hd7, 8'he3, 8'h5d, 8'h50, 8'h1e, 8'hb3,
         8'h5b, 8'h23, 8'h38, 8'h34, 8'h68, 8'h46, 8'h03, 8'h8c,
         8'hdd, 8'h9c, 8'h7d, 8'ha0, 8'hcd, 8'h1a, 8'h41, 8'h1c
		};

	assign b = inv_lut[a];

endmodule
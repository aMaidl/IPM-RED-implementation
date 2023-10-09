/****************************************************************************
 * 
 Unnecessary module, but this makes it easier to later replace sBox with ops in codespace
 
 ****************************************************************************/

/**
 * Module: gadd4
 * 
 * TODO: Add module documentation
 */
module gadd8 (
	input	[7:0]	x,
	input	[7:0]	y,
	output	[7:0]	xy
);
	
	assign xy = x ^ y;


endmodule



/****************************************************************************

 * roundAES.v

 ****************************************************************************/



/**

 * Module: roundAES

 * 

 * TODO: Add module documentation

 */
module roundAES #(parameter v = 4) (
	input  clk,
	input  rst,
	input  en,
	input [16*(v*8)-1:0] plaintext,
	input [16*(v*8)-1:0] round_ks,
	input [(v*8)-1:0] L1,
	input [(v*8)-1:0] L2,
	input [(v-1)*(v-1)*8-1:0] L1_hat,
	input [(v-1)*(v-1)*8-1:0] L2_hat,
	input [5*80-1:0] RNG_seed,
	output reg can_supply_last,
	output [3:0] current_round,
	output [16*(v*8)-1:0] ciphertext,
	output reg is_busy
);


    parameter BRAM_mul = 3'b000;
    parameter BRAM_add = 3'b001;
    parameter BRAM_sq = 3'b010;
    parameter BRAM_mc = 3'b011;
    parameter BRAM_PT = 3'b100;
    parameter BRAM_KS = 3'b101;
    parameter BRAM_mask = 3'b110;
    parameter BRAM_DEFAULT = 3'b111;


	wire [2*((v-1)*(v-1)*8)-2:0] IPMREDMult_rand;
	wire [2*((v-1)*(v-1)*8)-2:0] IPMREDAdd_rand;
	wire [(v-2)*8-1:0] IPMREDMask_rand;
	wire RNGisReady;

	reg RNGenable;
	reg RNGreseed;
	reg RNGisInit = 0;

    RNG_Trivium64 #(.instances(5)) RNG_Trivium64 (
        .clk(clk),
        .enable(en),
        .reseed(RNGreseed),
        .seed(RNG_seed),
        .isReady(RNGisReady),
        .random({IPMREDMult_rand,IPMREDAdd_rand,IPMREDMask_rand})
    );


    reg [16*(v*8)-1:0] round_pt;

	//==============================
	// wires :
	//==============================


	wire  [v*8-1:0] IPMREDSquare_Z;
	wire [v*8-1:0] IPMREDSquare_P;
	wire  [v*8-1:0] IPMREDMult_Z;
	wire  [v*8-1:0] IPMREDMult_Z_;
	wire [v*8-1:0] IPMREDMult_P;
	wire  [v*8-1:0] IPMREDAdd_Z;
	wire  [v*8-1:0] IPMREDAdd_Z_;
	wire [v*8-1:0] IPMREDAdd_P;
	wire [v*8-1:0] IPMREDMask_R;
	wire  [v*8-1:0] IPMREDMultConst_Z;
	reg  [8-1:0] IPMREDMultConst_const;
	wire [v*8-1:0] IPMREDMultConst_P;


	reg  [10-1:0] state;
	reg  [3:0] round_count;
	assign current_round = round_count;

	//==============================
	// IO :
	//==============================
	assign ciphertext = round_pt;

	//==============================
	// modules :
	//==============================
	IPMREDSquare #(.v(v)) IPMREDSquare(
		.Z(IPMREDSquare_Z),
		.L1(L1),
		.L2(L2),
		.P(IPMREDSquare_P)
	);

	IPMREDMult #(.v(v)) IPMREDMult(
		.rand(IPMREDMult_rand),
		.Z(IPMREDMult_Z),
		.Z_(IPMREDMult_Z_),
		.L1_hat(L1_hat),
		.L2_hat(L2_hat),
		.L2(L2),
		.P(IPMREDMult_P)
	);

	IPMREDAdd #(.v(v)) IPMREDAdd(
		.rand(IPMREDAdd_rand),
		.Z(IPMREDAdd_Z),
		.Z_(IPMREDAdd_Z_),
		.L1_hat(L1_hat),
		.L2_hat(L2_hat),
		.L2(L2),
		.L1(L1),
		.P(IPMREDAdd_P)
	);

	IPMREDMask #(.v(v)) IPMREDMask(
		.rand(IPMREDMask_rand),
		.S(8'h63),
		.L2(L2),
		.L1(L1),
		.R(IPMREDMask_R)
	);

	IPMREDMultConst #(.v(v)) IPMREDMultConst(
		.Z(IPMREDMultConst_Z),
		.const(IPMREDMultConst_const),
		.L2(L2),
		.P(IPMREDMultConst_P)
	);



	reg IPMREDAdd_BRAM_en;
	reg IPMREDMult_BRAM_en;
	reg IPMREDMultConst_BRAM_en;
	reg IPMREDSquare_BRAM_en;
	reg [4:0] IPMREDAdd_addr_w;
	reg [4:0] IPMREDMult_addr_w;
	reg [4:0] IPMREDMultConst_addr_w;
	reg [4:0] IPMREDSquare_addr_w;

    reg [4:0] IPMREDAdd_Z_addr_r;
    reg [4:0] IPMREDAdd_Z__addr_r;
    reg [4:0] IPMREDMult_Z_addr_r;
    reg [4:0] IPMREDMult_Z__addr_r;
    reg [4:0] IPMREDMultConst_Z_addr_r;
    reg [4:0] IPMREDSquare_Z_addr_r;

    reg [2:0] IPMREDAdd_Z_addr_r_BRAM;
    reg [2:0] IPMREDAdd_Z__addr_r_BRAM;
    reg [2:0] IPMREDMult_Z_addr_r_BRAM;
    reg [2:0] IPMREDMult_Z__addr_r_BRAM;
    reg [2:0] IPMREDMultConst_Z_addr_r_BRAM;
    reg [2:0] IPMREDSquare_Z_addr_r_BRAM;

    Bank #(.addr_bits(5), .debug(1)) Bank (
         .DEBUG_STATE(state),
         .clk(clk),
         .en(en),
         .plaintext(round_pt),
         .round_ks(round_ks),
         .add_en(IPMREDAdd_BRAM_en),
         .mul_en(IPMREDMult_BRAM_en),
         .mc_en(IPMREDMultConst_BRAM_en),
         .sq_en(IPMREDSquare_BRAM_en),
         .add_addr_w(IPMREDAdd_addr_w),
         .mul_addr_w(IPMREDMult_addr_w),
         .mc_addr_w(IPMREDMultConst_addr_w),
         .sq_addr_w(IPMREDSquare_addr_w),
         .add_val_w(IPMREDAdd_P),
         .mul_val_w(IPMREDMult_P),
         .mc_val_w(IPMREDMultConst_P),
         .sq_val_w(IPMREDSquare_P),
         .mask_val_w(IPMREDMask_R),
         .add0_addr_r(IPMREDAdd_Z_addr_r),
         .add1_addr_r(IPMREDAdd_Z__addr_r),
         .mul0_addr_r(IPMREDMult_Z_addr_r),
         .mul1_addr_r(IPMREDMult_Z__addr_r),
         .mc_addr_r(IPMREDMultConst_Z_addr_r),
         .sq_addr_r(IPMREDSquare_Z_addr_r),
         .add0_r_BRAM(IPMREDAdd_Z_addr_r_BRAM),
         .add1_r_BRAM(IPMREDAdd_Z__addr_r_BRAM),
         .mul0_r_BRAM(IPMREDMult_Z_addr_r_BRAM),
         .mul1_r_BRAM(IPMREDMult_Z__addr_r_BRAM),
         .mc_r_BRAM(IPMREDMultConst_Z_addr_r_BRAM),
         .sq_r_BRAM(IPMREDSquare_Z_addr_r_BRAM),
         .add0_out(IPMREDAdd_Z),
         .add1_out(IPMREDAdd_Z_),
         .mul0_out(IPMREDMult_Z),
         .mul1_out(IPMREDMult_Z_),
         .mc_out(IPMREDMultConst_Z),
         .sq_out(IPMREDSquare_Z)
    );




	//==============================
	// control :
	//==============================


	wire is_last = (round_count == 10);
	always @(posedge clk) begin
		if (!rst) begin
			state <= 10'b1111111111;
			is_busy <= 1;
		end
		else begin
            if(!en) begin
                state <= 10'b1111111111;
				is_busy <= 1;
            end else begin
                


                // these are important!!!
                IPMREDAdd_BRAM_en <= 0;
                IPMREDMult_BRAM_en <= 0;
                IPMREDMultConst_BRAM_en <= 0;
                IPMREDSquare_BRAM_en <= 0;
                IPMREDAdd_Z_addr_r_BRAM <= BRAM_DEFAULT;
                IPMREDAdd_Z__addr_r_BRAM <= BRAM_DEFAULT;
                IPMREDMult_Z_addr_r_BRAM <= BRAM_DEFAULT;
                IPMREDMult_Z__addr_r_BRAM <= BRAM_DEFAULT;
                IPMREDSquare_Z_addr_r_BRAM <= BRAM_DEFAULT;
                IPMREDMultConst_Z_addr_r_BRAM <= BRAM_DEFAULT;
                IPMREDMultConst_const <= 8'h0;
                // 0 address is not in use
                IPMREDSquare_addr_w <= 8'h0;
                IPMREDMult_addr_w <= 8'h0;
                IPMREDAdd_addr_w <= 8'h0;
                IPMREDMultConst_addr_w <= 8'h0;

                // FSM
                case(state)                    // reset RNG
                    10'b1111111111 : begin
                        can_supply_last <= 0;
                        RNGreseed <= 1;
                        RNGenable <= 1;
                        state <= 10'b1111111110;
                        round_count <= 1;
                        round_pt <= plaintext[1*16*v*8-1:0*16*v*8];
								is_busy <= 1;
                    end
                    // wait until RNG is ready
                    10'b1111111110 : begin
                        RNGreseed <= 0;
                        if (RNGisReady) begin
                            state <= 10'b0000000000;
                        end else begin
                            state <= 10'b1111111110;
                        end
                    end
                    // rounds 1-9 start here
                   10'b0000000000 : begin
                   	state <= 10'b0000000001;
                   	IPMREDAdd_Z_addr_r <= 5'h10; // addr of byte F
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h10; // addr of byte F
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   end
                   10'b0000000001 : begin
                   	state <= 10'b0000000010;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hF; // addr of byte E
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hF; // addr of byte E
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDSquare_Z_addr_r <= 5'h11;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000000010 : begin
						 
                   	state <= 10'b0000000011;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hE; // addr of byte D
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hE; // addr of byte D
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h11;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000000011 : begin
						 
                   	
                   	state <= 10'b0000000100;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hD; // addr of byte C
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hD; // addr of byte C
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000000100 : begin
						 
                   	
                   	state <= 10'b0000000101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hC; // addr of byte B
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hC; // addr of byte B
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMult_addr_w <= 5'h19;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h11;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000000101 : begin
						 
                   	
                   	state <= 10'b0000000110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hB; // addr of byte A
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hB; // addr of byte A
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMult_addr_w <= 5'h16;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000000110 : begin
						 
                   	
                   	
                   	state <= 10'b0000000111;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hA; // addr of byte 9
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hA; // addr of byte 9
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h15;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h19;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000000111 : begin
						 
                   	
                   	
                   	state <= 10'b0000001000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h9; // addr of byte 8
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h9; // addr of byte 8
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000001000 : begin
						 
                   	
                   	
                   	state <= 10'b0000001001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h8; // addr of byte 7
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h8; // addr of byte 7
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMult_addr_w <= 5'h13;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h3;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h11;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000001001 : begin
						 
                   	
                   	
                   	state <= 10'b0000001010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h7; // addr of byte 6
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h7; // addr of byte 6
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMult_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h11;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000001010 : begin
						 
                   	
                   	
                   	state <= 10'b0000001011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h6; // addr of byte 5
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h6; // addr of byte 5
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDMult_addr_w <= 5'h1C;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000001011 : begin
						 
                   	
                   	
                   	state <= 10'b0000001100;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h5; // addr of byte 4
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h5; // addr of byte 4
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMult_addr_w <= 5'hE;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000001100 : begin
						 
                   	
                   	
                   	state <= 10'b0000001101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h4; // addr of byte 3
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h4; // addr of byte 3
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000001101 : begin
						 
                   	
                   	
                   	state <= 10'b0000001110;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h3; // addr of byte 2
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h3; // addr of byte 2
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h19;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h16;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000001110 : begin
						 
                   	
                   	
                   	state <= 10'b0000001111;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h2; // addr of byte 1
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h2; // addr of byte 1
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMult_addr_w <= 5'h19;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h16;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000001111 : begin
						 
                   	
                   	
                   	state <= 10'b0000010000;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h1; // addr of byte 0
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h1; // addr of byte 0
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMult_addr_w <= 5'h12;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000010000 : begin
						 
                   	
                   	
                   	state <= 10'b0000010001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDMult_addr_w <= 5'h18;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h3;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000010001 : begin
						 
                   	
                   	
                   	state <= 10'b0000010010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hF;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000010010 : begin
                   	state <= 10'b0000010011;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h17;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h1C;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000010011 : begin
                   	state <= 10'b0000010100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h11;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h13;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000010100 : begin
                   	state <= 10'b0000010101;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hC;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h13;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000010101 : begin
                   	state <= 10'b0000010110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1B;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000010110 : begin
                   	state <= 10'b0000010111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1A;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000010111 : begin
                   	state <= 10'b0000011000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000011000 : begin
                   	state <= 10'b0000011001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h2;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000011001 : begin
                   	state <= 10'b0000011010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h14;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h19;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000011010 : begin
                   	state <= 10'b0000011011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h19;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000011011 : begin
                   	state <= 10'b0000011100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h7;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h12;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000011100 : begin
                   	state <= 10'b0000011101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h11;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h16;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h1B;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000011101 : begin
                   	state <= 10'b0000011110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1B;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000011110 : begin
                   	state <= 10'b0000011111;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h9;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h18;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000011111 : begin
                   	state <= 10'b0000100000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h14;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0000100000 : begin
                   	state <= 10'b0000100001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h14;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h17;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000100001 : begin
                   	state <= 10'b0000100010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hF;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hF;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000100010 : begin
                   	state <= 10'b0000100011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000100011 : begin
                   	state <= 10'b0000100100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1C;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h1B;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000100100 : begin
                   	state <= 10'b0000100101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1C;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h13;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000100101 : begin
                   	state <= 10'b0000100110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h16;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h1A;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000100110 : begin
                   	state <= 10'b0000100111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h16;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h16;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000100111 : begin
                   	state <= 10'b0000101000;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMult_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h15;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h14;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000101000 : begin
                   	state <= 10'b0000101001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h2;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000101001 : begin
                   	state <= 10'b0000101010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h5;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDSquare_Z_addr_r <= 5'h19;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000101010 : begin
                   	state <= 10'b0000101011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDMult_Z_addr_r <= 5'hD;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000101011 : begin
                   	state <= 10'b0000101100;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h12;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h11;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000101100 : begin
                   	state <= 10'b0000101101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h12;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h7;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000101101 : begin
                   	state <= 10'b0000101110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDMult_Z_addr_r <= 5'h4;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1B;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000101110 : begin
                   	state <= 10'b0000101111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000101111 : begin
                   	state <= 10'b0000110000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h18;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000110000 : begin
                   	state <= 10'b0000110001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h18;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h17;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000110001 : begin
                   	state <= 10'b0000110010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h17;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h14;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000110010 : begin
                   	state <= 10'b0000110011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDSquare_Z_addr_r <= 5'h1C;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000110011 : begin
                   	state <= 10'b0000110100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000110100 : begin
                   	state <= 10'b0000110101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1B;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h16;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000110101 : begin
                   	state <= 10'b0000110110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h16;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000110110 : begin
                   	state <= 10'b0000110111;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1A;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000110111 : begin
                   	state <= 10'b0000111000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000111000 : begin
                   	state <= 10'b0000111001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h14;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000111001 : begin
                   	state <= 10'b0000111010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h14;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h13;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000111010 : begin
                   	state <= 10'b0000111011;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h13;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDMult_Z_addr_r <= 5'hD;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h19;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h13;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h12;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000111011 : begin
                   	state <= 10'b0000111100;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMult_addr_w <= 5'h12;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000111100 : begin
                   	state <= 10'b0000111101;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h11;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000111101 : begin
                   	state <= 10'b0000111110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h11;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDMult_Z_addr_r <= 5'h4;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hD;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0000111110 : begin
                   	state <= 10'b0000111111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDSquare_Z_addr_r <= 5'h18;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0000111111 : begin
                   	state <= 10'b0001000000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDSquare_Z_addr_r <= 5'h17;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001000000 : begin
                   	state <= 10'b0001000001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001000001 : begin
                   	state <= 10'b0001000010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hF;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001000010 : begin
                   	state <= 10'b0001000011;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hF;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDMult_Z_addr_r <= 5'hB;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001000011 : begin
                   	state <= 10'b0001000100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hE;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001000100 : begin
                   	state <= 10'b0001000101;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h16;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001000101 : begin
                   	state <= 10'b0001000110;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001000110 : begin
                   	state <= 10'b0001000111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001000111 : begin
                   	state <= 10'b0001001000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDSquare_Z_addr_r <= 5'h14;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001001000 : begin
                   	state <= 10'b0001001001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDSquare_Z_addr_r <= 5'h13;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001001001 : begin
                   	state <= 10'b0001001010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001001010 : begin
                   	state <= 10'b0001001011;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h12;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001001011 : begin
                   	state <= 10'b0001001100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDSquare_Z_addr_r <= 5'h11;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001001100 : begin
                   	state <= 10'b0001001101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001001101 : begin
                   	state <= 10'b0001001110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDMult_Z_addr_r <= 5'h9;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h10;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001001110 : begin
                   	state <= 10'b0001001111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001001111 : begin
                   	state <= 10'b0001010000;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001010000 : begin
                   	state <= 10'b0001010001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001010001 : begin
                   	state <= 10'b0001010010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001010010 : begin
                   	state <= 10'b0001010011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001010011 : begin
                   	state <= 10'b0001010100;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hC;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001010100 : begin
                   	state <= 10'b0001010101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMult_addr_w <= 5'hC;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001010101 : begin
                   	state <= 10'b0001010110;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001010110 : begin
                   	state <= 10'b0001010111;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h7;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001010111 : begin
                   	state <= 10'b0001011000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMult_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001011000 : begin
                   	state <= 10'b0001011001;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001011001 : begin
                   	state <= 10'b0001011010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001011010 : begin
                   	state <= 10'b0001011011;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'hD;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001011011 : begin
                   	state <= 10'b0001011100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDMult_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001011100 : begin
                   	state <= 10'b0001011101;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001011101 : begin
                   	state <= 10'b0001011110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001011110 : begin
                   	state <= 10'b0001011111;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001011111 : begin
                   	state <= 10'b0001100000;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDMult_Z_addr_r <= 5'h4;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h2;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001100000 : begin
                   	state <= 10'b0001100001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001100001 : begin
                   	state <= 10'b0001100010;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001100010 : begin
                   	state <= 10'b0001100011;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001100011 : begin
                   	state <= 10'b0001100100;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001100100 : begin
                   	state <= 10'b0001100101;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001100101 : begin
                   	state <= 10'b0001100110;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'hB;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hB;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001100110 : begin
                   	state <= 10'b0001100111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMult_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001100111 : begin
                   	state <= 10'b0001101000;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h6;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001101000 : begin
                   	state <= 10'b0001101001;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMult_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h5;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001101001 : begin
                   	state <= 10'b0001101010;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMult_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001101010 : begin
                   	state <= 10'b0001101011;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001101011 : begin
                   	state <= 10'b0001101100;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'h6;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h4;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001101100 : begin
                   	state <= 10'b0001101101;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMult_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h8;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h3;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001101101 : begin
                   	state <= 10'b0001101110;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDMult_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001101110 : begin
                   	state <= 10'b0001101111;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h9;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h9;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001101111 : begin
                   	state <= 10'b0001110000;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMult_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001110000 : begin
                   	state <= 10'b0001110001;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001110001 : begin
                   	state <= 10'b0001110010;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'h7;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001110010 : begin
                   	state <= 10'b0001110011;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMult_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001110011 : begin
                   	state <= 10'b0001110100;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001110100 : begin
                   	state <= 10'b0001110101;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001110101 : begin
                   	state <= 10'b0001110110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001110110 : begin
                   	state <= 10'b0001110111;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001110111 : begin
                   	state <= 10'b0001111000;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001111000 : begin
                   	state <= 10'b0001111001;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001111001 : begin
                   	state <= 10'b0001111010;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001111010 : begin
                   	state <= 10'b0001111011;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001111011 : begin
                   	state <= 10'b0001111100;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001111100 : begin
                   	state <= 10'b0001111101;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001111101 : begin
                   	state <= 10'b0001111110;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0001111110 : begin
                   	state <= 10'b0001111111;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0001111111 : begin
                   	state <= 10'b0010000000;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010000000 : begin
                   	state <= 10'b0010000001;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010000001 : begin
                   	state <= 10'b0010000010;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b0010000010 : begin
                   	state <= 10'b0010000011;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010000011 : begin
                   	state <= 10'b0010000100;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010000100 : begin
                   	state <= 10'b0010000101;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010000101 : begin
                   	state <= 10'b0010000110;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010000110 : begin
                   	state <= 10'b0010000111;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010000111 : begin
                   	state <= 10'b0010001000;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001000 : begin
                   	state <= 10'b0010001001;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001001 : begin
                   	state <= 10'b0010001010;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001010 : begin
                   	state <= 10'b0010001011;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001011 : begin
                   	state <= 10'b0010001100;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001100 : begin
                   	state <= 10'b0010001101;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001101 : begin
                   	state <= 10'b0010001110;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001110 : begin
                   	state <= 10'b0010001111;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010001111 : begin
                   	state <= 10'b0010010000;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010000 : begin
                   	state <= 10'b0010010001;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010001 : begin
                   	state <= 10'b0010010010;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010010 : begin
                   	state <= 10'b0010010011;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010011 : begin
                   	state <= 10'b0010010100;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010100 : begin
                   	state <= 10'b0010010101;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010101 : begin
                   	state <= 10'b0010010110;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010110 : begin
                   	state <= 10'b0010010111;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010010111 : begin
                   	state <= 10'b0010011000;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011000 : begin
                   	state <= 10'b0010011001;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011001 : begin
                   	state <= 10'b0010011010;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'hF;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011010 : begin
                   	state <= 10'b0010011011;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011011 : begin
                   	state <= 10'b0010011100;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011100 : begin
                   	state <= 10'b0010011101;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011101 : begin
                   	state <= 10'b0010011110;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011110 : begin
                   	state <= 10'b0010011111;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010011111 : begin
                   	state <= 10'b0010100000;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100000 : begin
                   	state <= 10'b0010100001;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100001 : begin
                   	state <= 10'b0010100010;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'hE;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100010 : begin
                   	state <= 10'b0010100011;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100011 : begin
                   	state <= 10'b0010100100;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'hB;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100100 : begin
                   	state <= 10'b0010100101;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100101 : begin
                   	state <= 10'b0010100110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'hB;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100110 : begin
                   	state <= 10'b0010100111;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010100111 : begin
                   	state <= 10'b0010101000;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'hB;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101000 : begin
                   	state <= 10'b0010101001;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101001 : begin
                   	state <= 10'b0010101010;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'hB;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101010 : begin
                   	state <= 10'b0010101011;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDMultConst_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101011 : begin
                   	state <= 10'b0010101100;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'hB;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h14;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101100 : begin
                   	state <= 10'b0010101101;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDMultConst_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'hD;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h14;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101101 : begin
                   	state <= 10'b0010101110;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101110 : begin
                   	state <= 10'b0010101111;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010101111 : begin
                   	state <= 10'b0010110000;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110000 : begin
                   	state <= 10'b0010110001;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110001 : begin
                   	state <= 10'b0010110010;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110010 : begin
                   	state <= 10'b0010110011;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110011 : begin
                   	state <= 10'b0010110100;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'hC;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1B;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110100 : begin
                   	state <= 10'b0010110101;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'hE;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'hB;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1B;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110101 : begin
                   	state <= 10'b0010110110;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110110 : begin
                   	state <= 10'b0010110111;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010110111 : begin
                   	state <= 10'b0010111000;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111000 : begin
                   	state <= 10'b0010111001;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111001 : begin
                   	state <= 10'b0010111010;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111010 : begin
                   	state <= 10'b0010111011;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111011 : begin
                   	state <= 10'b0010111100;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111100 : begin
                   	state <= 10'b0010111101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h9;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111101 : begin
                   	state <= 10'b0010111110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111110 : begin
                   	state <= 10'b0010111111;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h8;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0010111111 : begin
                   	state <= 10'b0011000000;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'hF;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000000 : begin
                   	state <= 10'b0011000001;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000001 : begin
                   	state <= 10'b0011000010;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000010 : begin
                   	state <= 10'b0011000011;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000011 : begin
                   	state <= 10'b0011000100;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000100 : begin
                   	state <= 10'b0011000101;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000101 : begin
                   	state <= 10'b0011000110;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h5;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000110 : begin
                   	state <= 10'b0011000111;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'h11;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'hE;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011000111 : begin
                   	state <= 10'b0011001000;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001000 : begin
                   	state <= 10'b0011001001;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h9;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001001 : begin
                   	state <= 10'b0011001010;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001010 : begin
                   	state <= 10'b0011001011;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h13;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001011 : begin
                   	state <= 10'b0011001100;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h13;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001100 : begin
                   	state <= 10'b0011001101;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMultConst_addr_w <= 5'h11;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'hE;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001101 : begin
                   	state <= 10'b0011001110;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001110 : begin
                   	state <= 10'b0011001111;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h2;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011001111 : begin
                   	state <= 10'b0011010000;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h9;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011010000 : begin
                   	state <= 10'b0011010001;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011010001 : begin
                   	state <= 10'b0011010010;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h5;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011010010 : begin
                   	state <= 10'b0011010011;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011010011 : begin
                   	state <= 10'b0011010100;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'hE;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011010100 : begin
                   	state <= 10'b0011010101;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h1B;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011010101 : begin
                   	state <= 10'b0011010110;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h12;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011010110 : begin
                   	state <= 10'b0011010111;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h9;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b0011010111 : begin
                   	state <= 10'b0011011000;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h2;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h16;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011000 : begin
                   	state <= 10'b0011011001;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1D;
                   	IPMREDMultConst_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h8;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h16;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011001 : begin
                   	state <= 10'b0011011010;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h8;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h16;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011010 : begin
                   	state <= 10'b0011011011;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h16;
                   	IPMREDMultConst_addr_w <= 5'h8;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'h1B;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011011 : begin
                   	state <= 10'b0011011100;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1B;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h11;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011100 : begin
                   	state <= 10'b0011011101;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDMultConst_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'hE;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h11;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011101 : begin
                   	state <= 10'b0011011110;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDMultConst_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'hD;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011110 : begin
                   	state <= 10'b0011011111;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h13;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011011111 : begin
                   	state <= 10'b0011100000;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h11;
                   	IPMREDMultConst_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h9;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1C;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011100000 : begin
                   	state <= 10'b0011100001;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1C;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011100001 : begin
                   	state <= 10'b0011100010;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1A;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h15;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011100010 : begin
                   	state <= 10'b0011100011;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h15;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011100011 : begin
                   	state <= 10'b0011100100;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h18;
                   	IPMREDMultConst_addr_w <= 5'h5;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'h8;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011100100 : begin
                   	state <= 10'b0011100101;
                   	IPMREDMultConst_const <= 8'h2;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011100101 : begin
                   	state <= 10'b0011100110;
                   	IPMREDMultConst_const <= 8'h3;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1E;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h12;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1C;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011100110 : begin
                   	state <= 10'b0011100111;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1C;
                   	IPMREDAdd_Z__addr_r <= 5'h11;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   end
                   10'b0011100111 : begin
                   	state <= 10'b0011101000;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h19;
                   	IPMREDAdd_Z__addr_r <= 5'h15;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011101000 : begin
                   	state <= 10'b0011101001;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h17;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'h15;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011101001 : begin
                   	state <= 10'b0011101010;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h15;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'h13;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011101010 : begin
                   	state <= 10'b0011101011;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h13;
                   	IPMREDAdd_Z__addr_r <= 5'hD;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h14;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011101011 : begin
                   	state <= 10'b0011101100;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h14;
                   	IPMREDAdd_Z__addr_r <= 5'hC;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   end
                   10'b0011101100 : begin
                   	state <= 10'b0011101101;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h12;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   end
                   10'b0011101101 : begin
                   	state <= 10'b0011101110;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'h8;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011101110 : begin
                   	state <= 10'b0011101111;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011101111 : begin
                   	state <= 10'b0011110000;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011110000 : begin
                   	state <= 10'b0011110001;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011110001 : begin
                   	state <= 10'b0011110010;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011110010 : begin
                   	state <= 10'b0011110011;
                   	IPMREDAdd_Z__addr_r <= 5'h5;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   end
                   10'b0011110011 : begin
                   	state <= 10'b0011110100;
                   	round_pt[6*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   end
                   10'b0011110100 : begin
                   	state <= 10'b0011110101;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h1E;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h1D;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011110101 : begin
                   	state <= 10'b0011110110;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011110110 : begin
                   	state <= 10'b0011110111;
                   	round_pt[9*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h1C;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h1B;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011110111 : begin
                   	state <= 10'b0011111000;
                   	IPMREDAdd_Z__addr_r <= 5'h1A;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h19;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111000 : begin
                   	state <= 10'b0011111001;
                   	round_pt[12*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h18;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h17;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111001 : begin
                   	state <= 10'b0011111010;
                   	round_pt[5*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h16;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h15;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111010 : begin
                   	state <= 10'b0011111011;
                   	round_pt[15*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h14;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h13;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111011 : begin
                   	state <= 10'b0011111100;
                   	round_pt[16*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h12;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h11;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111100 : begin
                   	state <= 10'b0011111101;
                   	round_pt[8*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111101 : begin
                   	state <= 10'b0011111110;
                   	round_pt[7*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'hE;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111110 : begin
                   	state <= 10'b0011111111;
                   	round_pt[11*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'hC;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0011111111 : begin
                   	state <= 10'b0100000000;
                   	round_pt[2*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0100000000 : begin
                   	state <= 10'b0100000001;
                   	round_pt[3*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h8;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0100000001 : begin
                   	state <= 10'b0100000010;
                   	round_pt[10*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0100000010 : begin
                   	state <= 10'b0100000011;
                   	round_pt[14*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0100000011 : begin
                   	state <= 10'b0100000100;
                   	round_pt[13*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	round_count <= round_count + 1; // sen_ding this two cycles early to receive values from ks earlier
                   	IPMREDAdd_Z__addr_r <= 5'h2;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b0100000100 : begin
                   	state <= 10'b0100000101;
                   	round_pt[1*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   end
                   10'b0100000101 : begin
                   	state <= {is_last, 9'b000000000};
                   	round_pt[4*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   end
                   // LAST ROUND STARTS HERE
                   10'b1000000000 : begin
                   	state <= 10'b1000000001;
                   	IPMREDAdd_Z_addr_r <= 5'h10; // addr of byte F
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h10; // addr of byte F
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   end
                   10'b1000000001 : begin
                   	state <= 10'b1000000010;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hF; // addr of byte E
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hF; // addr of byte E
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000000010 : begin
                   	state <= 10'b1000000011;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hE; // addr of byte D
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hE; // addr of byte D
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h5;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000000011 : begin
                   	state <= 10'b1000000100;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hD; // addr of byte C
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hD; // addr of byte C
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000000100 : begin
                   	state <= 10'b1000000101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hC; // addr of byte B
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hC; // addr of byte B
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMult_addr_w <= 5'h19;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h5;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000000101 : begin
                   	state <= 10'b1000000110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hB; // addr of byte A
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hB; // addr of byte A
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMult_addr_w <= 5'h16;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h10;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000000110 : begin
                   	state <= 10'b1000000111;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'hA; // addr of byte 9
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'hA; // addr of byte 9
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h15;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h19;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000000111 : begin
                   	state <= 10'b1000001000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h9; // addr of byte 8
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h9; // addr of byte 8
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000001000 : begin
                   	state <= 10'b1000001001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h8; // addr of byte 7
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h8; // addr of byte 7
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMult_addr_w <= 5'h13;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h4;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000001001 : begin
                   	state <= 10'b1000001010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h7; // addr of byte 6
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h7; // addr of byte 6
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMult_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h5;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000001010 : begin
                   	state <= 10'b1000001011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h6; // addr of byte 5
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h6; // addr of byte 5
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMult_addr_w <= 5'h1C;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h10;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000001011 : begin
                   	state <= 10'b1000001100;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h5; // addr of byte 4
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h5; // addr of byte 4
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMult_addr_w <= 5'hE;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h6;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000001100 : begin
                   	state <= 10'b1000001101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h4; // addr of byte 3
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h4; // addr of byte 3
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000001101 : begin
                   	state <= 10'b1000001110;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h3; // addr of byte 2
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h3; // addr of byte 2
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h19;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000001110 : begin
                   	state <= 10'b1000001111;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h2; // addr of byte 1
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h2; // addr of byte 1
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDMult_addr_w <= 5'h19;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h7;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000001111 : begin
                   	state <= 10'b1000010000;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z_addr_r <= 5'h1; // addr of byte 0
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_PT; // take from plaintext
                   	IPMREDAdd_Z__addr_r <= 5'h1; // addr of byte 0
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMult_addr_w <= 5'h12;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000010000 : begin
                   	state <= 10'b1000010001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMult_addr_w <= 5'h18;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h4;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000010001 : begin
                   	state <= 10'b1000010010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h9;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000010010 : begin
                   	state <= 10'b1000010011;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h17;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h1C;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000010011 : begin
                   	state <= 10'b1000010100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h5;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000010100 : begin
                   	state <= 10'b1000010101;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hC;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000010101 : begin
                   	state <= 10'b1000010110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1B;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h10;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000010110 : begin
                   	state <= 10'b1000010111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1A;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000010111 : begin
                   	state <= 10'b1000011000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h6;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000011000 : begin
                   	state <= 10'b1000011001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hB;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000011001 : begin
                   	state <= 10'b1000011010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h14;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hC;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h19;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000011010 : begin
                   	state <= 10'b1000011011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h19;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000011011 : begin
                   	state <= 10'b1000011100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hD;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h12;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000011100 : begin
                   	state <= 10'b1000011101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h11;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h7;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000011101 : begin
                   	state <= 10'b1000011110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000011110 : begin
                   	state <= 10'b1000011111;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h9;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h18;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000011111 : begin
                   	state <= 10'b1000100000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1000100000 : begin
                   	state <= 10'b1000100001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hF;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h17;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000100001 : begin
                   	state <= 10'b1000100010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hF;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h9;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000100010 : begin
                   	state <= 10'b1000100011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000100011 : begin
                   	state <= 10'b1000100100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1C;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h1B;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000100100 : begin
                   	state <= 10'b1000100101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1C;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000100101 : begin
                   	state <= 10'b1000100110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h16;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h1A;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000100110 : begin
                   	state <= 10'b1000100111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h16;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h10;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h16;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000100111 : begin
                   	state <= 10'b1000101000;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	can_supply_last <= 1'b1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMult_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h15;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h14;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000101000 : begin
                   	state <= 10'b1000101001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hB;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000101001 : begin
                   	state <= 10'b1000101010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h5;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDSquare_Z_addr_r <= 5'h19;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000101010 : begin
                   	state <= 10'b1000101011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDMult_Z_addr_r <= 5'hD;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hC;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000101011 : begin
                   	state <= 10'b1000101100;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h12;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h11;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000101100 : begin
                   	state <= 10'b1000101101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h12;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hD;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000101101 : begin
                   	state <= 10'b1000101110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDMult_Z_addr_r <= 5'h4;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000101110 : begin
                   	state <= 10'b1000101111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000101111 : begin
                   	state <= 10'b1000110000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h18;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000110000 : begin
                   	state <= 10'b1000110001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h18;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h17;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000110001 : begin
                   	state <= 10'b1000110010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h17;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hF;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000110010 : begin
                   	state <= 10'b1000110011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDSquare_Z_addr_r <= 5'h1C;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000110011 : begin
                   	state <= 10'b1000110100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000110100 : begin
                   	state <= 10'b1000110101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMult_Z_addr_r <= 5'h10;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1B;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h16;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000110101 : begin
                   	state <= 10'b1000110110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h16;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000110110 : begin
                   	state <= 10'b1000110111;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1A;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000110111 : begin
                   	state <= 10'b1000111000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMult_addr_w <= 5'h15;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000111000 : begin
                   	state <= 10'b1000111001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMult_Z_addr_r <= 5'hF;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h14;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000111001 : begin
                   	state <= 10'b1000111010;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h14;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h13;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000111010 : begin
                   	state <= 10'b1000111011;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h13;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDMult_Z_addr_r <= 5'hD;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h19;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h13;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h12;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000111011 : begin
                   	state <= 10'b1000111100;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMult_addr_w <= 5'h12;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000111100 : begin
                   	state <= 10'b1000111101;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h11;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000111101 : begin
                   	state <= 10'b1000111110;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h11;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDMult_Z_addr_r <= 5'h4;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hD;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1000111110 : begin
                   	state <= 10'b1000111111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDSquare_Z_addr_r <= 5'h18;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1000111111 : begin
                   	state <= 10'b1001000000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDSquare_Z_addr_r <= 5'h17;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001000000 : begin
                   	state <= 10'b1001000001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001000001 : begin
                   	state <= 10'b1001000010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hF;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001000010 : begin
                   	state <= 10'b1001000011;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hF;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDMult_Z_addr_r <= 5'hB;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hE;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001000011 : begin
                   	state <= 10'b1001000100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hE;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001000100 : begin
                   	state <= 10'b1001000101;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h16;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001000101 : begin
                   	state <= 10'b1001000110;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001000110 : begin
                   	state <= 10'b1001000111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDSquare_Z_addr_r <= 5'h15;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001000111 : begin
                   	state <= 10'b1001001000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDSquare_Z_addr_r <= 5'h14;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001001000 : begin
                   	state <= 10'b1001001001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDSquare_Z_addr_r <= 5'h13;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001001001 : begin
                   	state <= 10'b1001001010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001001010 : begin
                   	state <= 10'b1001001011;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h12;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001001011 : begin
                   	state <= 10'b1001001100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDSquare_Z_addr_r <= 5'h11;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001001100 : begin
                   	state <= 10'b1001001101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001001101 : begin
                   	state <= 10'b1001001110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDMult_Z_addr_r <= 5'h9;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h10;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001001110 : begin
                   	state <= 10'b1001001111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001001111 : begin
                   	state <= 10'b1001010000;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001010000 : begin
                   	state <= 10'b1001010001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001010001 : begin
                   	state <= 10'b1001010010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001010010 : begin
                   	state <= 10'b1001010011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001010011 : begin
                   	state <= 10'b1001010100;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h2;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hC;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001010100 : begin
                   	state <= 10'b1001010101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMult_addr_w <= 5'hC;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001010101 : begin
                   	state <= 10'b1001010110;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001010110 : begin
                   	state <= 10'b1001010111;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'h3;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h7;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001010111 : begin
                   	state <= 10'b1001011000;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMult_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001011000 : begin
                   	state <= 10'b1001011001;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001011001 : begin
                   	state <= 10'b1001011010;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001011010 : begin
                   	state <= 10'b1001011011;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'hD;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hA;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001011011 : begin
                   	state <= 10'b1001011100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMult_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001011100 : begin
                   	state <= 10'b1001011101;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001011101 : begin
                   	state <= 10'b1001011110;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001011110 : begin
                   	state <= 10'b1001011111;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001011111 : begin
                   	state <= 10'b1001100000;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDMult_Z_addr_r <= 5'h4;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h2;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001100000 : begin
                   	state <= 10'b1001100001;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDMult_Z_addr_r <= 5'hC;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h8;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001100001 : begin
                   	state <= 10'b1001100010;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDMult_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001100010 : begin
                   	state <= 10'b1001100011;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001100011 : begin
                   	state <= 10'b1001100100;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001100100 : begin
                   	state <= 10'b1001100101;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001100101 : begin
                   	state <= 10'b1001100110;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'hB;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'hB;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001100110 : begin
                   	state <= 10'b1001100111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMult_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001100111 : begin
                   	state <= 10'b1001101000;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h5;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h6;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001101000 : begin
                   	state <= 10'b1001101001;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMult_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'hA;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h5;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001101001 : begin
                   	state <= 10'b1001101010;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMult_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001101010 : begin
                   	state <= 10'b1001101011;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001101011 : begin
                   	state <= 10'b1001101100;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'h6;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h4;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001101100 : begin
                   	state <= 10'b1001101101;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMult_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h8;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h3;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001101101 : begin
                   	state <= 10'b1001101110;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMult_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001101110 : begin
                   	state <= 10'b1001101111;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMult_Z_addr_r <= 5'h9;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h9;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001101111 : begin
                   	state <= 10'b1001110000;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDMult_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001110000 : begin
                   	state <= 10'b1001110001;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001110001 : begin
                   	state <= 10'b1001110010;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMult_Z_addr_r <= 5'h7;
                   	IPMREDMult_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDMult_Z__addr_r <= 5'h1;
                   	IPMREDMult_Z__addr_r_BRAM <= BRAM_mul;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001110010 : begin
                   	state <= 10'b1001110011;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMult_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMult_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001110011 : begin
                   	state <= 10'b1001110100;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_mul;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001110100 : begin
                   	state <= 10'b1001110101;
                   	IPMREDMultConst_const <= 8'h8f;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mask; // take from IPMREDMask
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_mc;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001110101 : begin
                   	state <= 10'b1001110110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001110110 : begin
                   	state <= 10'b1001110111;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001110111 : begin
                   	state <= 10'b1001111000;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001111000 : begin
                   	state <= 10'b1001111001;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001111001 : begin
                   	state <= 10'b1001111010;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001111010 : begin
                   	state <= 10'b1001111011;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001111011 : begin
                   	state <= 10'b1001111100;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001111100 : begin
                   	state <= 10'b1001111101;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001111101 : begin
                   	state <= 10'b1001111110;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1001111110 : begin
                   	state <= 10'b1001111111;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1001111111 : begin
                   	state <= 10'b1010000000;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010000000 : begin
                   	state <= 10'b1010000001;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010000001 : begin
                   	state <= 10'b1010000010;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_mul;
                   end
                   10'b1010000010 : begin
                   	state <= 10'b1010000011;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010000011 : begin
                   	state <= 10'b1010000100;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'h10;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010000100 : begin
                   	state <= 10'b1010000101;
                   	IPMREDMultConst_const <= 8'h5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010000101 : begin
                   	state <= 10'b1010000110;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010000110 : begin
                   	state <= 10'b1010000111;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010000111 : begin
                   	state <= 10'b1010001000;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001000 : begin
                   	state <= 10'b1010001001;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001001 : begin
                   	state <= 10'b1010001010;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001010 : begin
                   	state <= 10'b1010001011;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001011 : begin
                   	state <= 10'b1010001100;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001100 : begin
                   	state <= 10'b1010001101;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001101 : begin
                   	state <= 10'b1010001110;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001110 : begin
                   	state <= 10'b1010001111;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010001111 : begin
                   	state <= 10'b1010010000;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010000 : begin
                   	state <= 10'b1010010001;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010001 : begin
                   	state <= 10'b1010010010;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010010 : begin
                   	state <= 10'b1010010011;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h10;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010011 : begin
                   	state <= 10'b1010010100;
                   	IPMREDMultConst_const <= 8'h9;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h10;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h10;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010100 : begin
                   	state <= 10'b1010010101;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010101 : begin
                   	state <= 10'b1010010110;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010110 : begin
                   	state <= 10'b1010010111;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h10;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010010111 : begin
                   	state <= 10'b1010011000;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'h4; // addr of byte 3
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z_addr_r <= 5'h10;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011000 : begin
                   	state <= 10'b1010011001;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011001 : begin
                   	state <= 10'b1010011010;
                   	round_pt[4*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011010 : begin
                   	state <= 10'b1010011011;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'hF;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011011 : begin
                   	state <= 10'b1010011100;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011100 : begin
                   	state <= 10'b1010011101;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011101 : begin
                   	state <= 10'b1010011110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011110 : begin
                   	state <= 10'b1010011111;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010011111 : begin
                   	state <= 10'b1010100000;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100000 : begin
                   	state <= 10'b1010100001;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100001 : begin
                   	state <= 10'b1010100010;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100010 : begin
                   	state <= 10'b1010100011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100011 : begin
                   	state <= 10'b1010100100;
                   	IPMREDMultConst_const <= 8'hf9;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'hE;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100100 : begin
                   	state <= 10'b1010100101;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100101 : begin
                   	state <= 10'b1010100110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100110 : begin
                   	state <= 10'b1010100111;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hF;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010100111 : begin
                   	state <= 10'b1010101000;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hF;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hF;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101000 : begin
                   	state <= 10'b1010101001;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101001 : begin
                   	state <= 10'b1010101010;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101010 : begin
                   	state <= 10'b1010101011;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101011 : begin
                   	state <= 10'b1010101100;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hF;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101100 : begin
                   	state <= 10'b1010101101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101101 : begin
                   	state <= 10'b1010101110;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'h7; // addr of byte 6
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z_addr_r <= 5'hF;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101110 : begin
                   	state <= 10'b1010101111;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'hD;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010101111 : begin
                   	state <= 10'b1010110000;
                   	round_pt[7*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hE;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110000 : begin
                   	state <= 10'b1010110001;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'hE;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hE;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110001 : begin
                   	state <= 10'b1010110010;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110010 : begin
                   	state <= 10'b1010110011;
                   	IPMREDMultConst_const <= 8'h25;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110011 : begin
                   	state <= 10'b1010110100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110100 : begin
                   	state <= 10'b1010110101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110101 : begin
                   	state <= 10'b1010110110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hE;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'hC;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110110 : begin
                   	state <= 10'b1010110111;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010110111 : begin
                   	state <= 10'b1010111000;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'hB;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111000 : begin
                   	state <= 10'b1010111001;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'hA; // addr of byte 9
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z_addr_r <= 5'hE;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hD;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111001 : begin
                   	state <= 10'b1010111010;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'hD;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hD;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111010 : begin
                   	state <= 10'b1010111011;
                   	round_pt[10*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111011 : begin
                   	state <= 10'b1010111100;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'hA;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111100 : begin
                   	state <= 10'b1010111101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111101 : begin
                   	state <= 10'b1010111110;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111110 : begin
                   	state <= 10'b1010111111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h1;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hC;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1010111111 : begin
                   	state <= 10'b1011000000;
                   	IPMREDMultConst_const <= 8'hf4;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hD;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'hC;
                   	IPMREDAdd_Z__addr_r <= 5'h9;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hC;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'hB;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000000 : begin
                   	state <= 10'b1011000001;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'hB;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hB;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000001 : begin
                   	state <= 10'b1011000010;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h8;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000010 : begin
                   	state <= 10'b1011000011;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000011 : begin
                   	state <= 10'b1011000100;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'hD; // addr of byte C
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z_addr_r <= 5'hD;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'hA;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000100 : begin
                   	state <= 10'b1011000101;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDSquare_addr_w <= 5'hA;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'hA;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000101 : begin
                   	state <= 10'b1011000110;
                   	round_pt[13*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000110 : begin
                   	state <= 10'b1011000111;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hC;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h9;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011000111 : begin
                   	state <= 10'b1011001000;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hB;
                   	IPMREDSquare_addr_w <= 5'h9;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h9;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001000 : begin
                   	state <= 10'b1011001001;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h8;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001001 : begin
                   	state <= 10'b1011001010;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h8;
                   	IPMREDAdd_Z__addr_r <= 5'h5;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h8;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001010 : begin
                   	state <= 10'b1011001011;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDSquare_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDSquare_Z_addr_r <= 5'h7;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001011 : begin
                   	state <= 10'b1011001100;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'hA;
                   	IPMREDSquare_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h7;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h6;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001100 : begin
                   	state <= 10'b1011001101;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'h10; // addr of byte F
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDMultConst_addr_w <= 5'h7;
                   	IPMREDSquare_addr_w <= 5'h6;
                   	IPMREDAdd_Z_addr_r <= 5'hC;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h6;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h5;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001101 : begin
                   	state <= 10'b1011001110;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h6;
                   	IPMREDSquare_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h5;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h4;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001110 : begin
                   	state <= 10'b1011001111;
                   	round_pt[16*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'h3; // addr of byte 2
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDMultConst_addr_w <= 5'h5;
                   	IPMREDSquare_addr_w <= 5'h4;
                   	IPMREDAdd_Z_addr_r <= 5'hB;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h4;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h3;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011001111 : begin
                   	state <= 10'b1011010000;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDMultConst_addr_w <= 5'h4;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h2;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011010000 : begin
                   	state <= 10'b1011010001;
                   	round_pt[3*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h9;
                   	IPMREDMultConst_addr_w <= 5'h3;
                   	IPMREDSquare_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h2;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h3;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   	IPMREDSquare_Z_addr_r <= 5'h1;
                   	IPMREDSquare_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011010001 : begin
                   	state <= 10'b1011010010;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDSquare_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDMultConst_addr_w <= 5'h2;
                   	IPMREDSquare_addr_w <= 5'h2;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   	IPMREDMultConst_Z_addr_r <= 5'h2;
                   	IPMREDMultConst_Z_addr_r_BRAM <= BRAM_sq;
                   end
                   10'b1011010010 : begin
                   	state <= 10'b1011010011;
                   	IPMREDMultConst_const <= 8'hb5;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDMultConst_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h8;
                   	IPMREDMultConst_addr_w <= 5'h1;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_sq;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011010011 : begin
                   	state <= 10'b1011010100;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'h6; // addr of byte 5
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDAdd_Z_addr_r <= 5'hA;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011010100 : begin
                   	state <= 10'b1011010101;
                   	IPMREDAdd_Z__addr_r <= 5'h7;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011010101 : begin
                   	state <= 10'b1011010110;
                   	round_pt[6*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h7;
                   	IPMREDAdd_Z__addr_r <= 5'h6;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011010110 : begin
                   	state <= 10'b1011010111;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h6;
                   	IPMREDAdd_Z__addr_r <= 5'h5;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011010111 : begin
                   	state <= 10'b1011011000;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h5;
                   	IPMREDAdd_Z__addr_r <= 5'h4;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011000 : begin
                   	state <= 10'b1011011001;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'h9; // addr of byte 8
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h4;
                   	IPMREDAdd_Z_addr_r <= 5'h9;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011001 : begin
                   	state <= 10'b1011011010;
                   	IPMREDAdd_Z__addr_r <= 5'h3;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011010 : begin
                   	state <= 10'b1011011011;
                   	round_pt[9*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_addr_w <= 5'h3;
                   	IPMREDAdd_Z__addr_r <= 5'h2;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011011 : begin
                   	state <= 10'b1011011100;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'hC; // addr of byte B
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h2;
                   	IPMREDAdd_Z_addr_r <= 5'h8;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011100 : begin
                   	state <= 10'b1011011101;
                   	IPMREDAdd_Z__addr_r <= 5'h1;
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_mc;
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011101 : begin
                   	state <= 10'b1011011110;
                   	round_pt[12*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_BRAM_en <= 1;
                   	IPMREDAdd_Z__addr_r <= 5'hF; // addr of byte E
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_addr_w <= 5'h1;
                   	IPMREDAdd_Z_addr_r <= 5'h7;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011110 : begin
                   	state <= 10'b1011011111;
                   	IPMREDAdd_Z__addr_r <= 5'h2; // addr of byte 1
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_Z_addr_r <= 5'h6;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011011111 : begin
                   	state <= 10'b1011100000;
                   	round_pt[15*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h5; // addr of byte 4
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_Z_addr_r <= 5'h5;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011100000 : begin
                   	state <= 10'b1011100001;
                   	round_pt[2*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h8; // addr of byte 7
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_Z_addr_r <= 5'h4;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011100001 : begin
                   	state <= 10'b1011100010;
                   	round_pt[5*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'hB; // addr of byte A
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_Z_addr_r <= 5'h3;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011100010 : begin
                   	state <= 10'b1011100011;
                   	round_pt[8*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'hE; // addr of byte D
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_Z_addr_r <= 5'h2;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011100011 : begin
                   	state <= 10'b1011100100;
                   	round_pt[11*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	IPMREDAdd_Z__addr_r <= 5'h1; // addr of byte 0
                   	IPMREDAdd_Z__addr_r_BRAM <= BRAM_KS; // take from key
                   	IPMREDAdd_Z_addr_r <= 5'h1;
                   	IPMREDAdd_Z_addr_r_BRAM <= BRAM_add;
                   end
                   10'b1011100100 : begin
                   	state <= 10'b1011100101;
                   	round_pt[14*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   end
                   10'b1011100101 : begin
                   	state <= 10'b1111111100;
                   	round_pt[1*8*v-1 -: 8*v] <= IPMREDAdd_P;
                   	is_busy <= 1'b0;
                   end
                   default : begin
                   	state <= 10'b1111111100;
                   end
                endcase
            end
        end
    end


endmodule
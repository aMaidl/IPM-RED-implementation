module Cipher #(parameter v = 4) (
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
	output can_supply_last,
	output encryption_running,
	output [4:0] unmask_state,
	output [3:0] current_round,
	output [16*(v*8)-1:0] masked_cipher,
	output reg [16*8-1:0] ciphertext,
	output reg [16*8-1:0] ciphertext_cubed,
	output reg [16*8-1:0] ciphertext3,
	output reg is_busy
);

    wire [16*8*v-1:0] round_output;
	 
	 assign masked_cipher = round_output;
	 assign unmask_state = count;

    roundAES #(.v(v)) round(
        .clk(clk),
        .rst(rst),
        .en(en),
        .plaintext(plaintext),
        .round_ks(round_ks),
        .L1(L1),
        .L2(L2),
        .L1_hat(L1_hat),
        .L2_hat(L2_hat),
        .RNG_seed(RNG_seed),
        .can_supply_last(can_supply_last),
        .current_round(current_round),
        .ciphertext(round_output),
        .is_busy(encryption_running)
    );



    reg [8*v-1:0] unmask_in;
    reg [(v*8)-1:0] unmask_L1;
    reg [(v*8)-1:0] unmask_L2;
    wire [7:0] unmask_out;
    wire [7:0] unmask_out3;
    wire [7:0] cubed;
    reg [4:0] count;

    IPMREDUnmask #(.v(v)) IPMREDUnmask(
        .L1(unmask_L1),
        .L2(unmask_L2),
        .R(unmask_in),
        .S(unmask_out),
        .S3(unmask_out3)
    );

    cube8 c8(
        .x(unmask_out),
        .x3(cubed)
    );

    always @(posedge clk) begin
        if (!rst || !en) begin
            unmask_L1 <= {(v*8){1'b0}};
            unmask_L2 <= {(v*8){1'b0}};
            unmask_in <= {(v*8){1'b0}};
            ciphertext <= 128'b0;
            ciphertext3 <= 128'b0;
            ciphertext_cubed <= 128'b0;
            count <= 5'd31;
            is_busy <= 1'b1;
        end else begin
            count <= 5'd31;
            case (count)
                5'd31 : begin
                    if(!en || encryption_running || !is_busy) begin
                        count <= 5'd31;
                    end else begin
                        count <= 5'd0;
                    end
                end
                5'd0 : begin
                    count <= 5'd1;
                    unmask_L1 <= L1;
                    unmask_L2 <= L2;
                    unmask_in <= round_output[1*8*v-1 -: 8*v];
                end
                5'd1 : begin
                    count <= 5'd2;
                    unmask_in <= round_output[2*8*v-1 -: 8*v];
                    ciphertext[8*1-1 -: 8] <= unmask_out;
                    ciphertext3[8*1-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*1-1 -: 8] <= cubed;
                end
                5'd2 : begin
                    count <= 5'd3;
                    unmask_in <= round_output[3*8*v-1 -: 8*v];
                    ciphertext[8*2-1 -: 8] <= unmask_out;
                    ciphertext3[8*2-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*2-1 -: 8] <= cubed;
                end
                5'd3 : begin
                    count <= 5'd4;
                    unmask_in <= round_output[4*8*v-1 -: 8*v];
                    ciphertext[8*3-1 -: 8] <= unmask_out;
                    ciphertext3[8*3-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*3-1 -: 8] <= cubed;
                end
                5'd4 : begin
                    count <= 5'd5;
                    unmask_in <= round_output[5*8*v-1 -: 8*v];
                    ciphertext[8*4-1 -: 8] <= unmask_out;
                    ciphertext3[8*4-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*4-1 -: 8] <= cubed;
                end
                5'd5 : begin
                    count <= 5'd6;
                    unmask_in <= round_output[6*8*v-1 -: 8*v];
                    ciphertext[8*5-1 -: 8] <= unmask_out;
                    ciphertext3[8*5-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*5-1 -: 8] <= cubed;
                end
                5'd6 : begin
                    count <= 5'd7;
                    unmask_in <= round_output[7*8*v-1 -: 8*v];
                    ciphertext[8*6-1 -: 8] <= unmask_out;
                    ciphertext3[8*6-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*6-1 -: 8] <= cubed;
                end
                5'd7 : begin
                    count <= 5'd8;
                    unmask_in <= round_output[8*8*v-1 -: 8*v];
                    ciphertext[8*7-1 -: 8] <= unmask_out;
                    ciphertext3[8*7-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*7-1 -: 8] <= cubed;
                end
                5'd8 : begin
                    count <= 5'd9;
                    unmask_in <= round_output[9*8*v-1 -: 8*v];
                    ciphertext[8*8-1 -: 8] <= unmask_out;
                    ciphertext3[8*8-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*8-1 -: 8] <= cubed;
                end
                5'd9 : begin
                    count <= 5'd10;
                    unmask_in <= round_output[10*8*v-1 -: 8*v];
                    ciphertext[8*9-1 -: 8] <= unmask_out;
                    ciphertext3[8*9-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*9-1 -: 8] <= cubed;
                end
                5'd10 : begin
                    count <= 5'd11;
                    unmask_in <= round_output[11*8*v-1 -: 8*v];
                    ciphertext[8*10-1 -: 8] <= unmask_out;
                    ciphertext3[8*10-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*10-1 -: 8] <= cubed;
                end
                5'd11 : begin
                    count <= 5'd12;
                    unmask_in <= round_output[12*8*v-1 -: 8*v];
                    ciphertext[8*11-1 -: 8] <= unmask_out;
                    ciphertext3[8*11-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*11-1 -: 8] <= cubed;
                end
                5'd12 : begin
                    count <= 5'd13;
                    unmask_in <= round_output[13*8*v-1 -: 8*v];
                    ciphertext[8*12-1 -: 8] <= unmask_out;
                    ciphertext3[8*12-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*12-1 -: 8] <= cubed;
                end
                5'd13 : begin
                    count <= 5'd14;
                    unmask_in <= round_output[14*8*v-1 -: 8*v];
                    ciphertext[8*13-1 -: 8] <= unmask_out;
                    ciphertext3[8*13-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*13-1 -: 8] <= cubed;
                end
                5'd14 : begin
                    count <= 5'd15;
                    unmask_in <= round_output[15*8*v-1 -: 8*v];
                    ciphertext[8*14-1 -: 8] <= unmask_out;
                    ciphertext3[8*14-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*14-1 -: 8] <= cubed;
                end
                5'd15 : begin
                    count <= 5'd16;
                    unmask_in <= round_output[16*8*v-1 -: 8*v];
                    ciphertext[8*15-1 -: 8] <= unmask_out;
                    ciphertext3[8*15-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*15-1 -: 8] <= cubed;
                end
                5'd16 : begin
                    count <= 5'd31;
                    ciphertext[8*16-1 -: 8] <= unmask_out;
                    ciphertext3[8*16-1 -: 8] <= unmask_out3;
                    ciphertext_cubed[8*16-1 -: 8] <= cubed;
                    is_busy <= 0;
                end
                default : begin
                    count <= 5'd31;
                end
            endcase
        end
    end

endmodule

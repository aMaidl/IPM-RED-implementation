module Cipher (
	input  clk,
	input  rst,
	input  en,
	input [16*8-1:0] plaintext,
	input [16*8-1:0] round_ks,
	output can_supply_last,
	output [3:0] current_round,
	output [16*8-1:0] ciphertext,
	output is_busy
);


    roundAES round(
        .clk(clk),
        .rst(rst),
        .en(en),
        .plaintext(plaintext),
        .round_ks(round_ks),
        .can_supply_last(can_supply_last),
        .current_round(current_round),
        .ciphertext(ciphertext),
        .is_busy(is_busy)
    );

endmodule

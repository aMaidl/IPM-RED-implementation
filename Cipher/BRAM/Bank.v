module Bank #(parameter addr_bits = 6, parameter debug = 0) (
    input [9:0] DEBUG_STATE,
    input clk,
    input en,
    // pt and ks, this is just to keep things clean
	input [16*(3*8)-1:0] plaintext,
	input [16*(3*8)-1:0] round_ks,
    // write enables
    input add_en,
    input mul_en,
    input mc_en,
    input sq_en,
    // addr writes
    input[addr_bits-1 : 0] add_addr_w,
    input[addr_bits-1 : 0] mul_addr_w,
    input[addr_bits-1 : 0] mc_addr_w,
    input[addr_bits-1 : 0] sq_addr_w,
    // input data
    input[23:0] add_val_w,
    input[23:0] mul_val_w,
    input[23:0] mc_val_w,
    input[23:0] sq_val_w,
    // just pass masked value through for consistency
    input[23:0] mask_val_w,
    // addr reads PER PORT
    input[addr_bits-1 : 0] add0_addr_r,
    input[addr_bits-1 : 0] add1_addr_r,
    input[addr_bits-1 : 0] mul0_addr_r,
    input[addr_bits-1 : 0] mul1_addr_r,
    input[addr_bits-1 : 0] mc_addr_r,
    input[addr_bits-1 : 0] sq_addr_r,
    // read from which BRAM?
    input[2 : 0] add0_r_BRAM,
    input[2 : 0] add1_r_BRAM,
    input[2 : 0] mul0_r_BRAM,
    input[2 : 0] mul1_r_BRAM,
    input[2 : 0] mc_r_BRAM,
    input[2 : 0] sq_r_BRAM,
    // outputs
    output[23 : 0] add0_out,
    output[23 : 0] add1_out,
    output[23 : 0] mul0_out,
    output[23 : 0] mul1_out,
    output[23 : 0] mc_out,
    output[23 : 0] sq_out
);

    parameter BRAM_mul = 3'b000;
    parameter BRAM_add = 3'b001;
    parameter BRAM_sq = 3'b010;
    parameter BRAM_mc = 3'b011;
    parameter BRAM_PT = 3'b100;
    parameter BRAM_KS = 3'b101;
    parameter BRAM_mask = 3'b110;
    parameter BRAM_DEFAULT = 3'b111;


    reg [2 : 0] last_add0_r_BRAM;
    reg [2 : 0] last_add1_r_BRAM;
    reg [2 : 0] last_mul0_r_BRAM;
    reg [2 : 0] last_mul1_r_BRAM;
    reg [2 : 0] last_mc_r_BRAM;
    reg [2 : 0] last_sq_r_BRAM;

    reg [addr_bits-1 : 0] last_add0_addr_r;
    reg [addr_bits-1 : 0] last_add1_addr_r;

    wire [23:0] mul_to_mul0_OUT;
    wire [23:0] mul_to_mul1_OUT;
    wire [23:0] mul_to_add0_OUT;
    wire [23:0] mul_to_add1_OUT;
    wire [23:0] mul_to_mc_OUT;
    wire [23:0] mul_to_sq_OUT;
    wire [23:0] add_to_mul0_OUT;
    wire [23:0] add_to_mul1_OUT;
    wire [23:0] add_to_add0_OUT;
    wire [23:0] add_to_add1_OUT;
    wire [23:0] add_to_mc_OUT;
    wire [23:0] add_to_sq_OUT;
    wire [23:0] mc_to_mul0_OUT;
    wire [23:0] mc_to_mul1_OUT;
    wire [23:0] mc_to_add0_OUT;
    wire [23:0] mc_to_add1_OUT;
    wire [23:0] mc_to_mc_OUT;
    wire [23:0] mc_to_sq_OUT;
    wire [23:0] sq_to_mul0_OUT;
    wire [23:0] sq_to_mul1_OUT;
    wire [23:0] sq_to_add0_OUT;
    wire [23:0] sq_to_add1_OUT;
    wire [23:0] sq_to_mc_OUT;
    wire [23:0] sq_to_sq_OUT;

    reg [23:0] mul0_buffer;
    reg [23:0] mul1_buffer;
    reg [23:0] add0_buffer;
    reg [23:0] add1_buffer;
    reg [23:0] mc_buffer;
    reg [23:0] sq_buffer;
    reg mul0_pass;
    reg mul1_pass;
    reg add0_pass;
    reg add1_pass;
    reg mc_pass;
    reg sq_pass;

    wire mul0_needs_pass =
           (mul0_r_BRAM == BRAM_mul && mul_addr_w == mul0_addr_r)
        || (mul0_r_BRAM == BRAM_add && add_addr_w == mul0_addr_r)
        || (mul0_r_BRAM == BRAM_mc && mc_addr_w == mul0_addr_r)
        || (mul0_r_BRAM == BRAM_sq && sq_addr_w == mul0_addr_r);
    wire mul1_needs_pass =
           (mul1_r_BRAM == BRAM_mul && mul_addr_w == mul1_addr_r)
        || (mul1_r_BRAM == BRAM_add && add_addr_w == mul1_addr_r)
        || (mul1_r_BRAM == BRAM_mc && mc_addr_w == mul1_addr_r)
        || (mul1_r_BRAM == BRAM_sq && sq_addr_w == mul1_addr_r);
    wire add0_needs_pass =
        (add0_r_BRAM != BRAM_mask) &&
           ((add0_r_BRAM == BRAM_mul && mul_addr_w == add0_addr_r)
        ||  (add0_r_BRAM == BRAM_add && add_addr_w == add0_addr_r)
        ||  (add0_r_BRAM == BRAM_mc && mc_addr_w == add0_addr_r)
        ||  (add0_r_BRAM == BRAM_sq && sq_addr_w == add0_addr_r));
    wire add1_needs_pass =
        (add1_r_BRAM != BRAM_mask) &&
           ((add1_r_BRAM == BRAM_mul && mul_addr_w == add1_addr_r)
        ||  (add1_r_BRAM == BRAM_add && add_addr_w == add1_addr_r)
        ||  (add1_r_BRAM == BRAM_mc && mc_addr_w == add1_addr_r)
        ||  (add1_r_BRAM == BRAM_sq && sq_addr_w == add1_addr_r));
    wire mc_needs_pass =
           (mc_r_BRAM == BRAM_mul && mul_addr_w == mc_addr_r)
        || (mc_r_BRAM == BRAM_add && add_addr_w == mc_addr_r)
        || (mc_r_BRAM == BRAM_mc && mc_addr_w == mc_addr_r)
        || (mc_r_BRAM == BRAM_sq && sq_addr_w == mc_addr_r);
    wire sq_needs_pass =
           (sq_r_BRAM == BRAM_mul && mul_addr_w == sq_addr_r)
        || (sq_r_BRAM == BRAM_add && add_addr_w == sq_addr_r)
        || (sq_r_BRAM == BRAM_mc && mc_addr_w == sq_addr_r)
        || (sq_r_BRAM == BRAM_sq && sq_addr_w == sq_addr_r);

    assign mul0_out =
          mul0_pass ? mul0_buffer
        : (last_mul0_r_BRAM == BRAM_mul) ? mul_to_mul0_OUT
        : (last_mul0_r_BRAM == BRAM_add) ? add_to_mul0_OUT
        : (last_mul0_r_BRAM == BRAM_mc) ? mc_to_mul0_OUT
        : (last_mul0_r_BRAM == BRAM_sq) ? sq_to_mul0_OUT
        : 0;
    assign mul1_out =
          mul1_pass ? mul1_buffer
        : (last_mul1_r_BRAM == BRAM_mul) ? mul_to_mul1_OUT
        : (last_mul1_r_BRAM == BRAM_add) ? add_to_mul1_OUT
        : (last_mul1_r_BRAM == BRAM_mc) ? mc_to_mul1_OUT
        : (last_mul1_r_BRAM == BRAM_sq) ? sq_to_mul1_OUT
        : 0;
    assign add0_out =
          (last_add0_r_BRAM == BRAM_PT) ? plaintext[last_add0_addr_r*8*3-1 -: 8*3]
        : (last_add0_r_BRAM == BRAM_KS) ? round_ks[last_add0_addr_r*8*3-1 -: 8*3]
        : add0_pass ? add0_buffer
        : (last_add0_r_BRAM == BRAM_mul) ? mul_to_add0_OUT
        : (last_add0_r_BRAM == BRAM_add) ? add_to_add0_OUT
        : (last_add0_r_BRAM == BRAM_mc) ? mc_to_add0_OUT
        : (last_add0_r_BRAM == BRAM_sq) ? sq_to_add0_OUT
        : (last_add0_r_BRAM == BRAM_mask) ? mask_val_w
        : 0;
    assign add1_out =
          (last_add1_r_BRAM == BRAM_PT) ? plaintext[last_add1_addr_r*8*3-1 -: 8*3]
        : (last_add1_r_BRAM == BRAM_KS) ? round_ks[last_add1_addr_r*8*3-1 -: 8*3]
        : add1_pass ? add1_buffer
        : (last_add1_r_BRAM == BRAM_mul) ? mul_to_add1_OUT
        : (last_add1_r_BRAM == BRAM_add) ? add_to_add1_OUT
        : (last_add1_r_BRAM == BRAM_mc) ? mc_to_add1_OUT
        : (last_add1_r_BRAM == BRAM_sq) ? sq_to_add1_OUT
        : (last_add1_r_BRAM == BRAM_mask) ? mask_val_w
        : 0;
    assign mc_out =
          mc_pass ? mc_buffer
        : (last_mc_r_BRAM == BRAM_mul) ? mul_to_mc_OUT
        : (last_mc_r_BRAM == BRAM_add) ? add_to_mc_OUT
        : (last_mc_r_BRAM == BRAM_mc) ? mc_to_mc_OUT
        : (last_mc_r_BRAM == BRAM_sq) ? sq_to_mc_OUT
        : 0;
    assign sq_out =
          sq_pass ? sq_buffer
        : (last_sq_r_BRAM == BRAM_mul) ? mul_to_sq_OUT
        : (last_sq_r_BRAM == BRAM_add) ? add_to_sq_OUT
        : (last_sq_r_BRAM == BRAM_mc) ? mc_to_sq_OUT
        : (last_sq_r_BRAM == BRAM_sq) ? sq_to_sq_OUT
        : 0;

    BRAM #(.word_size(24), .addr_size(addr_bits)) mul_to_mul0 (
            .clk(clk),
            .en(en),
            .we(mul_en),
            .w_addr(mul_addr_w),
            .r_addr(mul0_addr_r),
            .di(mul_val_w),
            .dout(mul_to_mul0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mul_to_mul1 (
            .clk(clk),
            .en(en),
            .we(mul_en),
            .w_addr(mul_addr_w),
            .r_addr(mul1_addr_r),
            .di(mul_val_w),
            .dout(mul_to_mul1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mul_to_add0 (
            .clk(clk),
            .en(en),
            .we(mul_en),
            .w_addr(mul_addr_w),
            .r_addr(add0_addr_r),
            .di(mul_val_w),
            .dout(mul_to_add0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mul_to_add1 (
            .clk(clk),
            .en(en),
            .we(mul_en),
            .w_addr(mul_addr_w),
            .r_addr(add1_addr_r),
            .di(mul_val_w),
            .dout(mul_to_add1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mul_to_mc (
            .clk(clk),
            .en(en),
            .we(mul_en),
            .w_addr(mul_addr_w),
            .r_addr(mc_addr_r),
            .di(mul_val_w),
            .dout(mul_to_mc_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mul_to_sq (
            .clk(clk),
            .en(en),
            .we(mul_en),
            .w_addr(mul_addr_w),
            .r_addr(sq_addr_r),
            .di(mul_val_w),
            .dout(mul_to_sq_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) add_to_mul0 (
            .clk(clk),
            .en(en),
            .we(add_en),
            .w_addr(add_addr_w),
            .r_addr(mul0_addr_r),
            .di(add_val_w),
            .dout(add_to_mul0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) add_to_mul1 (
            .clk(clk),
            .en(en),
            .we(add_en),
            .w_addr(add_addr_w),
            .r_addr(mul1_addr_r),
            .di(add_val_w),
            .dout(add_to_mul1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) add_to_add0 (
            .clk(clk),
            .en(en),
            .we(add_en),
            .w_addr(add_addr_w),
            .r_addr(add0_addr_r),
            .di(add_val_w),
            .dout(add_to_add0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) add_to_add1 (
            .clk(clk),
            .en(en),
            .we(add_en),
            .w_addr(add_addr_w),
            .r_addr(add1_addr_r),
            .di(add_val_w),
            .dout(add_to_add1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) add_to_mc (
            .clk(clk),
            .en(en),
            .we(add_en),
            .w_addr(add_addr_w),
            .r_addr(mc_addr_r),
            .di(add_val_w),
            .dout(add_to_mc_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) add_to_sq (
            .clk(clk),
            .en(en),
            .we(add_en),
            .w_addr(add_addr_w),
            .r_addr(sq_addr_r),
            .di(add_val_w),
            .dout(add_to_sq_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mc_to_mul0 (
            .clk(clk),
            .en(en),
            .we(mc_en),
            .w_addr(mc_addr_w),
            .r_addr(mul0_addr_r),
            .di(mc_val_w),
            .dout(mc_to_mul0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mc_to_mul1 (
            .clk(clk),
            .en(en),
            .we(mc_en),
            .w_addr(mc_addr_w),
            .r_addr(mul1_addr_r),
            .di(mc_val_w),
            .dout(mc_to_mul1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mc_to_add0 (
            .clk(clk),
            .en(en),
            .we(mc_en),
            .w_addr(mc_addr_w),
            .r_addr(add0_addr_r),
            .di(mc_val_w),
            .dout(mc_to_add0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mc_to_add1 (
            .clk(clk),
            .en(en),
            .we(mc_en),
            .w_addr(mc_addr_w),
            .r_addr(add1_addr_r),
            .di(mc_val_w),
            .dout(mc_to_add1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mc_to_mc (
            .clk(clk),
            .en(en),
            .we(mc_en),
            .w_addr(mc_addr_w),
            .r_addr(mc_addr_r),
            .di(mc_val_w),
            .dout(mc_to_mc_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) mc_to_sq (
            .clk(clk),
            .en(en),
            .we(mc_en),
            .w_addr(mc_addr_w),
            .r_addr(sq_addr_r),
            .di(mc_val_w),
            .dout(mc_to_sq_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) sq_to_mul0 (
            .clk(clk),
            .en(en),
            .we(sq_en),
            .w_addr(sq_addr_w),
            .r_addr(mul0_addr_r),
            .di(sq_val_w),
            .dout(sq_to_mul0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) sq_to_mul1 (
            .clk(clk),
            .en(en),
            .we(sq_en),
            .w_addr(sq_addr_w),
            .r_addr(mul1_addr_r),
            .di(sq_val_w),
            .dout(sq_to_mul1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) sq_to_add0 (
            .clk(clk),
            .en(en),
            .we(sq_en),
            .w_addr(sq_addr_w),
            .r_addr(add0_addr_r),
            .di(sq_val_w),
            .dout(sq_to_add0_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) sq_to_add1 (
            .clk(clk),
            .en(en),
            .we(sq_en),
            .w_addr(sq_addr_w),
            .r_addr(add1_addr_r),
            .di(sq_val_w),
            .dout(sq_to_add1_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) sq_to_mc (
            .clk(clk),
            .en(en),
            .we(sq_en),
            .w_addr(sq_addr_w),
            .r_addr(mc_addr_r),
            .di(sq_val_w),
            .dout(sq_to_mc_OUT)
        );

    BRAM #(.word_size(24), .addr_size(addr_bits)) sq_to_sq (
            .clk(clk),
            .en(en),
            .we(sq_en),
            .w_addr(sq_addr_w),
            .r_addr(sq_addr_r),
            .di(sq_val_w),
            .dout(sq_to_sq_OUT)
        );



     always @(posedge clk) begin
        last_add0_r_BRAM <= BRAM_DEFAULT;
        last_add1_r_BRAM <= BRAM_DEFAULT;
        last_mul0_r_BRAM <= BRAM_DEFAULT;
        last_mul1_r_BRAM <= BRAM_DEFAULT;
        last_mc_r_BRAM <= BRAM_DEFAULT;
        last_sq_r_BRAM <= BRAM_DEFAULT;
        last_add0_addr_r <= 0;
        last_add1_addr_r <= 0;
        if (en) begin
            last_add0_addr_r <= add0_addr_r;
            last_add1_addr_r <= add1_addr_r;
            last_add0_r_BRAM <= add0_r_BRAM;
            last_add1_r_BRAM <= add1_r_BRAM;
            last_mul0_r_BRAM <= mul0_r_BRAM;
            last_mul1_r_BRAM <= mul1_r_BRAM;
            last_mc_r_BRAM <= mc_r_BRAM;
            last_sq_r_BRAM <= sq_r_BRAM;

            add0_pass <= add0_needs_pass;
            add1_pass <= add1_needs_pass;
            mul0_pass <= mul0_needs_pass;
            mul1_pass <= mul1_needs_pass;
            mc_pass <= mc_needs_pass;
            sq_pass <= sq_needs_pass;

            mul0_buffer <=
                  !mul0_needs_pass ? 32'h0 :
                  ((mul0_r_BRAM == BRAM_mul) ? mul_val_w
                 : (mul0_r_BRAM == BRAM_add) ? add_val_w
                 : (mul0_r_BRAM == BRAM_mc) ? mc_val_w
                 : (mul0_r_BRAM == BRAM_sq) ? sq_val_w
                 : 32'h0);
            mul1_buffer <=
                  !mul1_needs_pass ? 32'h0 :
                  ((mul1_r_BRAM == BRAM_mul) ? mul_val_w
                : (mul1_r_BRAM == BRAM_add) ? add_val_w
                : (mul1_r_BRAM == BRAM_mc) ? mc_val_w
                : (mul1_r_BRAM == BRAM_sq) ? sq_val_w
                : 32'h0);
            add0_buffer <=
                  !add0_needs_pass ? 32'h0 :
                  ((add0_r_BRAM == BRAM_mul) ? mul_val_w
                 : (add0_r_BRAM == BRAM_add) ? add_val_w
                 : (add0_r_BRAM == BRAM_mc) ? mc_val_w
                 : (add0_r_BRAM == BRAM_sq) ? sq_val_w
                 : (add0_r_BRAM == BRAM_mask) ? mask_val_w
                 : 32'h0);
            add1_buffer <=
                  !add1_needs_pass ? 32'h0 :
                  ((add1_r_BRAM == BRAM_mul) ? mul_val_w
                 : (add1_r_BRAM == BRAM_add) ? add_val_w
                 : (add1_r_BRAM == BRAM_mc) ? mc_val_w
                 : (add1_r_BRAM == BRAM_sq) ? sq_val_w
                 : (add1_r_BRAM == BRAM_mask) ? mask_val_w
                 : 32'h0);
            mc_buffer <=
                  !mc_needs_pass ? 32'h0 :
                  ((mc_r_BRAM == BRAM_mul) ? mul_val_w
                 : (mc_r_BRAM == BRAM_add) ? add_val_w
                 : (mc_r_BRAM == BRAM_mc) ? mc_val_w
                 : (mc_r_BRAM == BRAM_sq) ? sq_val_w
                 : 32'h0);
            sq_buffer <=
                  !sq_needs_pass ? 32'h0 :
                  ((sq_r_BRAM == BRAM_mul) ? mul_val_w
                 : (sq_r_BRAM == BRAM_add) ? add_val_w
                 : (sq_r_BRAM == BRAM_mc) ? mc_val_w
                 : (sq_r_BRAM == BRAM_sq) ? sq_val_w
                 : 32'h0);

        end
     end

endmodule

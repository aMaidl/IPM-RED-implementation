/****************************************************************************
 * AddKey.v
 ****************************************************************************/

/**
 * Module: AddKey
 *
 * TODO: Add module documentation
 */
module Trivium64 (
    input clk,
    input enable,
    input reseed,
    input [79:0] IV,
    input [79:0] seed,
    output isReady,
	output [63:0] random
);



    reg [4:0] initCounter = 0;
    assign isReady = (initCounter) == 5'd18; // (4*288) / 16
    reg [287:0] state;

    // wires
    wire [63:0] t1_ = state[66-1:66-64] ^ state[93-1:93-64];
    wire [63:0] t2_ = state[161:98] ^ state[176:113];
    wire [63:0] t3_ = state[242:179] ^ state[287:224];
    wire [63:0] t1 = t1_ ^ (state[91-1:91-64] & state[92-1:92-64]) ^ state[171-1:171-64];
    wire [63:0] t2 = t2_ ^ (state[174:111] & state[175:112]) ^ state[263:200];
    wire [63:0] t3 = t3_ ^ (state[285:222] & state[286:223]) ^ state[68:5];

    assign random = t1_ ^ t2_ ^ t3_;

    integer i;
	always @ (posedge clk) begin
	    // $display("IV = %h", IV);
	    if (reseed == 1) begin
            state <= {3'b111,108'b0,4'b0,IV,13'b0,seed};
            initCounter <= 11'b0;
        end else if (enable == 1) begin
            /*
            $display("");
            $display("state = %h", state);
            $display("s10   = %b", state[9:0]);
            $display("count = %d", initCounter);
            $display("t1    = %h", t1);
            $display("t1_10 = %b", t1[9:0]);
            $display("t2    = %h", t2);
            $display("t2_10 = %b", t2[9:0]);
            $display("t3    = %h", t3);
            $display("t3_10 = %b", t3[9:0]);

            $display("a     = %h", state[92:0]);
            $display("a_    = %h", {state[28:0], t3});
            $display("b     = %h", state[176:93]);
            $display("b_    = %h", {state[112:93], t1});
            $display("c     = %h", state[287:177]);
            $display("c_    = %h", {state[223:177], t2});
            $display("k     = %h", {state[223:177], t2,state[112:93], t1,state[28:0], t3});
            */
            state[92:0] <= {state[28:0], t3};
            state[176:93] <= {state[112:93], t1};
            state[287:177] <= {state[223:177], t2};

            if (isReady == 0) begin
                initCounter <= initCounter + 1;
            end
	    end
	end


endmodule
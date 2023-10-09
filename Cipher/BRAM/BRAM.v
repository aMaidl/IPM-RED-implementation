// Single-Port Block RAM Write-First Mode (recommended template)
// File: rams_sp_wf.v
module BRAM #(parameter word_size = 32, parameter addr_size = 6, parameter debug = 0) (clk, we, en, w_addr, r_addr, di, dout);
    input clk;
    input we;
    input en;
    input [addr_size-1:0] w_addr;
    input [addr_size-1:0] r_addr;
    input [word_size-1:0] di;
    output reg [word_size-1:0] dout;

    reg [word_size-1:0] RAM [2**addr_size-1:0];

    always @(posedge clk)  begin
        if (en) begin
            if (we) begin
                RAM[w_addr] <= di;
                if(debug == 1) begin
                    $display("BRAM: WRITE %h TO %h", di, w_addr);
                end
            end
            dout <= RAM[r_addr];
        end
        if(debug == 1) begin
            $display("\tpeak:\n\t[0] = %h\n\t[1] = %h\n\t[2] = %h\n\t[3] = %h", RAM[0], RAM[1], RAM[2], RAM[3]);
        end
    end
endmodule
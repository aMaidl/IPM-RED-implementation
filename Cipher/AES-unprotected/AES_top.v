module AES (
  // Host interface
  input         lbus_rstn,    // Reset from Control FPGA
  input         lbus_clk,     // Clock from Control FPGA

  output        lbus_rdy,     // Device ready
  input   [7:0] lbus_wd,      // Local bus data input
  input         lbus_we,      // Data write enable
  output        lbus_ful,     // Data write ready low
  output        lbus_aful,    // Data near write end
  output  [7:0] lbus_rd,      // Data output
  input         lbus_re,      // Data read enable
  output        lbus_emp,     // Data read ready low
  output        lbus_aemp,    // Data near read end
  output        TRGOUTn,      // AES start trigger (SAKURA-G Only)

  // LED display
  output  [6:0] led,          // M_LED (led[8], led[9] SAKURA-G Only)

  // Trigger output
  output  [4:0] M_HEADER,     // User Header Pin (SAKURA-G Only)
  output        M_CLK_EXT0_P, // J4 SMA  AES start (SAKURA-G Only)

  // FTDI USB interface portB (SAKURA-G Only)
  // FTDI side
  input         FTDI_BCBUS0_RXF_B,
  input         FTDI_BCBUS1_TXE_B,
  output        FTDI_BCBUS2_RD_B,
  output        FTDI_BCBUS3_WR_B,
  inout   [7:0] FTDI_BDBUS_D,

  // FTDI USB interface portB (SAKURA-G Only)
  // Control FPGA side
  output        PORT_B_RXF,
  output        PORT_B_TXE,
  input         PORT_B_RD,
  input         PORT_B_WR,
  input   [7:0] PORT_B_DIN,
  output  [7:0] PORT_B_DOUT,
  input         PORT_B_OEn,

  // Main FPGA Clock
  input         M_CLK_OSC
);

// ================================================================================
// Internal signals
// ================================================================================
  // Reset and clock
  wire encryption_running;
  wire [4:0] unmask_state;
  wire          resetn;       // Hardware reset
  wire          clock;        // System clock
  wire			 M_CLK_OSC_BUFFERED;
  reg				 M_CLK_DIV;
  parameter     DIV_FACTOR = 2;
  wire clock_temp;
  reg div_rst;
  IBUFG clkdrv_M_CLK (.I( M_CLK_OSC ), .O( clock_temp ));   // 48MHz input
  clk_div #(.PWIDTH(6)) clk_div (.clk(clock_temp), .rst(div_rst), .div_clk(M_CLK_OSC_BUFFERED));

  // Block cipher
  wire          enc_dec;      // Encrypt/Decrypt select. 0:Encrypt  1:Decrypt
  wire          start;        // Encrypt or Decrypt Start
  wire  [3:0]   n;            // Number of Rounds
  wire          star;		  // Last Round Omission
  wire  [63:0] key;           // Round Key input
  wire  [63:0] text_in;       // Cipher Text or Inverse Cipher Text input
  wire  [63:0] text_out;      // Cipher Text or Inverse Cipher Text output
  wire  		   debug;         // Debug Output Parameters
  wire          busy;         // AES unit Busy

  // etc
  wire internal_reset;


    // delayed start
  reg start_delayed;
  reg start_temp;
  always @( posedge clock) begin
	if (internal_reset == 1'b0) begin
	    start_delayed <= 0;
	    div_rst <= 0;
    end
	else begin
	    div_rst <= 1;
		if (start == 1'b1) begin
			start_delayed <= 1;
		end
	end
  end



    wire [3:0] data;
	wire write;

	// ================================================================================
    // Equasions
    // ================================================================================
      // ------------------------------------------------------------------------------
      // Clock input driver
      // ------------------------------------------------------------------------------
      IBUFG clkdrv (.I( lbus_clk ), .O( clock ));   // 48MHz input
      // ------------------------------------------------------------------------------
      // Triger signals output
      // ------------------------------------------------------------------------------
      assign M_HEADER[0] = encryption_running;      // trig_startn
      assign M_HEADER[1] = start;       // trig_exec
      assign M_HEADER[2] = 5'd31 == unmask_state;    // trig_mode
      assign M_HEADER[3] = busy;      // debug signal

      assign M_CLK_EXT0_P = start;     // SMA J4 output

      assign TRGOUTn = ~start;


    wire [8*16-1:0] out;


    reg [127:0] collect;
    wire [127:0] plaintext = collect[127:0];

    wire [8*16-1:0] round_key;

    reg [11:0] cycle_count = 0;
    reg [9:0] count = 0;


  host_if host_if (
    .RSTn( lbus_rstn ),
	.CLK( clock ),
    .RSTOUTn( resetn ),
    .DEVRDY( lbus_rdy ),
	.RRDYn( lbus_emp ),
	.WRDYn( lbus_ful ),
    .HRE( lbus_re ),
	.HWE( lbus_we ),
	.HDIN( lbus_wd ),
	.HDOUT( lbus_rd ),
	.DATA_EN( start ),
	.RESULT( out ), // FIX
	.DATA_FEED( data ),
	.WRITE( write ),
	.internal_reset(internal_reset),
	.isBusy( busy )
  );


  assign lbus_aful = 1'b1;
  assign lbus_aemp = 1'b1;


    reg ks_we = 1;
    reg [3:0] ks_addr = 0;
    reg [3:0] ks_read = 0;

	reg [127:0] ks_collect;
	// use this to count ks
	reg [6:0] ks_count = 0;

	// this is supplied by the cipher module
	wire  can_supply_last;
	wire  [3:0] round;

	always @ (posedge clock) begin // in other host this is (posedge clk or negedge internal_reset)
	    if (!internal_reset) begin
	        ks_count <= 0;
	        ks_addr <= 0;
	        ks_we <= 1;
	        count <= 0;
	        cycle_count <= 0;
	    end else if (write) begin
            // LOAD KS BEFORE PT!
            if (cycle_count < 352) begin
                cycle_count <= cycle_count + 1;
                // supplier expects lines of length
                //       v*8*16 = 4*8*16 = 512
                // each cycle supplies 4 bits
                //       512/4 = 128
                // write every 128 cycles to ram

                // collect next 4 bit
                ks_collect[(ks_count+1)*4-1-:4] <= data[3:0];
                // increase ks_count by one
                ks_count <= ks_count + 1;
                // write when ks_count == 0
                if (ks_count == 32 && cycle_count != 0) begin
                    $display("1\n\tcollect = %h\n\tcount = %h\n\taddr = %h", ks_collect, ks_count, ks_addr);
                        ks_addr <= ks_addr + 1;
                        ks_count <= 1;
                        ks_collect[3:0] <= data[3:0];
                end
            end else if (count < 6'b100000) begin
                count <= count + 1;
                ks_we <= 0;
                collect[(count+1)*4-1-:4] <= data[3:0];
            end else begin
                ks_we <= 0;
            end
        end
	end

	always @(posedge M_CLK_OSC_BUFFERED) begin
		case (round)
		  4'd1: ks_read <= 4'd0;
		  4'd2: ks_read <= 4'd1;
		  4'd3: ks_read <= 4'd2;
		  4'd4: ks_read <= 4'd3;
		  4'd5: ks_read <= 4'd4;
		  4'd6: ks_read <= 4'd5;
		  4'd7: ks_read <= 4'd6;
		  4'd8: ks_read <= 4'd7;
		  4'd9: ks_read <= 4'd8;
		  4'd10: begin
				if(!can_supply_last) begin
					 ks_read <= 4'd9;
				end else begin
					 ks_read <= 4'd10;
				end
		  end
		endcase
	end




	KeySupplier ks1 (
        .clk(M_CLK_OSC_BUFFERED),
        .we(ks_we),
        .en(1'b1),
        .w_addr(ks_addr),
        .r_addr(ks_read),
        .di(ks_collect),
        .dout(round_key)
	);


    // ------------------------------------------------------------------------------
    // LED display outputs
    // ------------------------------------------------------------------------------
    assign led[0] = 1;
    assign led[1] = 0;      // Main FPGA ready
    assign led[2] = 1;
    assign led[3] = 0;
    assign led[4] = 0;
    assign led[5] = 0;
    assign led[6] = 1;

    // ------------------------------------------------------------------------------
    // USB PORT B
    // ------------------------------------------------------------------------------
    assign PORT_B_RXF = FTDI_BCBUS0_RXF_B;
    assign PORT_B_TXE = FTDI_BCBUS1_TXE_B;
    assign FTDI_BCBUS2_RD_B = PORT_B_RD;
    assign FTDI_BCBUS3_WR_B = PORT_B_WR;
    assign FTDI_BDBUS_D = ( PORT_B_OEn == 1'b0 )? PORT_B_DIN : 8'hzz;
    assign PORT_B_DOUT = FTDI_BDBUS_D;

	Cipher c1 (
            .clk(M_CLK_OSC_BUFFERED),
            .rst(internal_reset),
            .en(start_delayed),
            .plaintext(plaintext),
            .round_ks(round_key),
            .can_supply_last(can_supply_last),
            .current_round(round),
            .ciphertext(out),
            .is_busy(busy)
    );

endmodule
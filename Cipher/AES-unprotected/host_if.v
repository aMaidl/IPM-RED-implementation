////////////////////////////////////////////////////////////////////////////////////////////////////
// Company				: ITI - Universitt Stuttgart
// Engineer				: Mal Gay
// 
// Create Date			: 04/02/2018 
// Module Name			: host_if
// Target Device		: 
// Description			: USB Host - Small Scale AES 444
//
// Version				: 1.0
// Additional Comments	: 
////////////////////////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module host_if(
  input          RSTn,     // Reset input
  input          CLK,      // Clock input

  output         DEVRDY,   // Device ready
  output         RRDYn,    // Read data empty
  output         WRDYn,    // Write buffer almost full
  input          HRE,      // Host read enable
  input          HWE,      // Host write enable
  input    [7:0] HDIN,     // Host data input
  output   [7:0] HDOUT,    // Host data output

  output         RSTOUTn,		// Internal reset output
  output         ENCn_DEC,		// Encrypt/Decrypt select
  output         DATA_EN,		// Encrypt or Decrypt Start
  output [3:0] 	 NB_ROUND,		// Number of Rounds
  output    	 STAR,			// Last Round Omission
  output [63:0]  KEY_OUT,		// Cipher key output
  output [63:0]  DATA_OUT,		// Cipher Text or Inverse Cipher Text output
  input  [128-1:0]  RESULT,		// Cipher Text or Inverse Cipher Text input
  input  [63:0]  EDC_FREE,		// EDC fault free input
  input  [63:0]  EDC_FAULTY,	// EDC faulty input

	// my ports
	output [3:0] DATA_FEED,
	output WRITE,
	input isBusy,
	output internal_reset
);


  parameter [3:0]  CMD = 4'h0, READ1 = 4'h1, READ2 = 4'h2, READ3 = 4'h3, READ4 = 4'h4,
                   WRITE1 = 4'h5, WRITE2 = 4'h6, WRITE3 = 4'h7, WRITE4 = 4'h8;

// ==================================================================
// Internal signals
// ==================================================================
  reg    [4:0] cnt;             // Reset delay counter
  reg    [4:0] icnt;             // IReset delay counter
  reg          lbus_we_reg;     // Write input register
  reg    [7:0] lbus_din_reg;    // Write data input register
  reg    [3:0] next_if_state;   // Host interface next state  machine registers
  reg    [3:0] now_if_state;    // Host interface now state machine registers
  reg   [15:0] addr_reg;        // Internal address bus register
  reg   [15:0] data_reg;        // Internal write data bus register
  reg          write_ena;       // Internal register write enable

  reg          rst;             // Internal reset
  reg          enc_dec;         // Encrypt/Decrypt select register
  reg          data_ena;        // Encrypt or Decrypt Start
  reg  [3:0]   nbround_reg;     // Number of Rounds
  reg          star_reg;		// Last Round Omission
  /*reg          fault_t_reg;		// Fault Trigger
  reg  [3:0]   f_round_reg;		// Faulty Round */
  reg  [127:0] key_reg;         // Cipher Key register
  reg  [127:0] din_reg;         // Text input register

  reg          wbusy_reg;       // Write busy register
  reg          rrdy_reg;        // Read ready register
  reg   [15:0] dout_mux;        // Read data multiplex
  reg    [7:0] hdout_reg;       // Read data register
  reg DEBUG_MAN_CLK_REG;
  reg internal_reset_reg;

	reg [3:0] data_feed_reg;
	assign DATA_FEED = data_feed_reg;
	reg write_reg;
	assign WRITE = write_reg;
 
// ================================================================================
// Equasions
// ================================================================================
  // Reset delay counter
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) cnt <= 5'h00;
    else if (~&cnt) cnt <= cnt + 1'b1;
  end
  
  // IReset delay counter
  always @( posedge CLK or posedge rst ) begin
    if ( rst == 1'b1 ) icnt <= 5'h00;
    else if (~&icnt) icnt <= icnt + 1'b1;
  end

  assign RSTOUTn = &icnt[3:0];
  assign DEVRDY  = &cnt;

  // Local bus input registers
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      lbus_we_reg <= 1'b0;
      lbus_din_reg <= 8'h00;
    end
    else begin
      lbus_we_reg <= HWE;

      if ( HWE == 1'b1 ) lbus_din_reg <= HDIN;
      else lbus_din_reg <= lbus_din_reg;
    end
  end

  // State machine register
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      now_if_state <= CMD;
    end
    else begin
      now_if_state <= next_if_state;
    end
  end

  // State machine control
  always @( now_if_state or lbus_we_reg or lbus_din_reg or HRE ) begin
    case ( now_if_state )
      CMD  : if ( lbus_we_reg == 1'b1 )
                if ( lbus_din_reg == 8'h00 ) next_if_state = READ1;
                else if ( lbus_din_reg == 8'h01 ) next_if_state = WRITE1;
                else next_if_state = CMD;
              else next_if_state = CMD;

      READ1 : if ( lbus_we_reg == 1'b1 ) next_if_state = READ2;   // Address High read
              else next_if_state = READ1;
      READ2 : if ( lbus_we_reg == 1'b1 ) next_if_state = READ3;   // Address Low read
              else next_if_state = READ2;
      READ3 : if ( HRE == 1'b1 ) next_if_state = READ4;           // Data High read
              else  next_if_state = READ3;
      READ4 : if ( HRE == 1'b1 ) next_if_state = CMD;            // Data Low read
              else  next_if_state = READ4;

      WRITE1: if ( lbus_we_reg == 1'b1 ) next_if_state = WRITE2;  // Address High read
              else next_if_state = WRITE1;
      WRITE2: if ( lbus_we_reg == 1'b1 ) next_if_state = WRITE3;  // Address Low read
              else next_if_state = WRITE2;
      WRITE3: if ( lbus_we_reg == 1'b1 ) next_if_state = WRITE4;  // Data High write
              else next_if_state = WRITE3;
      WRITE4: if ( lbus_we_reg == 1'b1 ) next_if_state = CMD;    // Data Low write
              else next_if_state = WRITE4;
     default: next_if_state = CMD; 
    endcase
  end

  // Internal bus 
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      addr_reg <= 16'h0000;
      data_reg <= 16'h0000;
      write_ena <= 1'b0;
    end
    else begin
      if (( now_if_state == READ1 ) || ( now_if_state == WRITE1 )) addr_reg[15:8] <= lbus_din_reg;
      else addr_reg[15:8] <= addr_reg[15:8];

      if (( now_if_state == READ2 ) || ( now_if_state == WRITE2 )) addr_reg[7:0] <= lbus_din_reg;
      else addr_reg[7:0] <= addr_reg[7:0];

      if ( now_if_state == WRITE3 ) data_reg[15:8] <= lbus_din_reg;
      else data_reg[15:8] <= data_reg[15:8];

      if ( now_if_state == WRITE4 ) data_reg[7:0] <= lbus_din_reg;
      else data_reg[7:0] <= data_reg[7:0];

      write_ena <= (( now_if_state == WRITE4 ) && ( next_if_state == CMD ))? 1'b1 : 1'b0;
    end
  end

  // AES register
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      data_ena <= 1'b0;
      rst <= 1'b0;
      enc_dec <= 1'b0;
	  nbround_reg <= 4'h0;
	  star_reg <= 1'b0;
	  /*fault_t_reg <= 1'b0;
	  f_round_reg <= 4'h0;*/
      key_reg <= 128'h00000000_00000000_00000000_00000000;
      din_reg <= 128'h00000000_00000000_00000000_00000000;
    end
    else begin
      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0002 ) && ( data_reg[0] == 1'b1 )) data_ena <= 1'b1;
      else data_ena <= 1'b0;

      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0002 ) && ( data_reg[2] == 1'b1 )) rst <= 1'b1;
      else rst <= 1'b0;

      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0004 ) && ( data_reg[0] == 1'b1 )) enc_dec <= data_reg[0];
      else enc_dec <= enc_dec;
	  
	  if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0006 )) nbround_reg[3:0] <= data_reg[3:0];
      else nbround_reg[3:0] <= nbround_reg[3:0];
	  
	  if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0008 )) star_reg <= data_reg[0];
      else star_reg <= star_reg;
	  
	  /*if (( write_ena == 1'b1 ) && ( addr_reg == 16'h000a )) fault_t_reg <= data_reg[0];
      else fault_t_reg <= fault_t_reg;
	  
	  if (( write_ena == 1'b1 ) && ( addr_reg == 16'h000c )) f_round_reg[3:0] <= data_reg[3:0];
      else f_round_reg[3:0] <= f_round_reg[3:0];*/


      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0600 )) data_feed_reg[ 3:0 ] <= data_reg[3:0];
      else data_feed_reg[ 3:0 ] <= data_feed_reg[ 3:0 ];
      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0800 )) write_reg <= 1;
      else write_reg <= 0;

      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0700 )) DEBUG_MAN_CLK_REG <= 1;
      else DEBUG_MAN_CLK_REG <= 0;

      if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0666 )) internal_reset_reg <= 0;
      else if (( write_ena == 1'b1 ) && ( addr_reg == 16'h0668 )) internal_reset_reg <= 1;
		else internal_reset_reg <= internal_reset_reg;
    end
  end


  // Read data multiplax
  always @( addr_reg or rst or enc_dec or data_ena or nbround_reg or star_reg or /*fault_t_reg or f_round_reg or*/ RESULT /*or EDC_FREE or EDC_FAULTY or DEBUG_P or DEBUG_S or DEBUG_SN*/ ) begin
    case( addr_reg )
      16'h0002: dout_mux = { 14'h0000, rst, data_ena };
      16'h0004: dout_mux = { enc_dec };
	  16'h0006: dout_mux = { nbround_reg };
	  16'h0008: dout_mux = { star_reg };
		16'h0140: dout_mux = { 12'h0, RESULT[3:0]};
        16'h0142: dout_mux = { 12'h0, RESULT[7:4]};
        16'h0144: dout_mux = { 12'h0, RESULT[11:8]};
        16'h0146: dout_mux = { 12'h0, RESULT[15:12]};
        16'h0148: dout_mux = { 12'h0, RESULT[19:16]};
        16'h014A: dout_mux = { 12'h0, RESULT[23:20]};
        16'h014C: dout_mux = { 12'h0, RESULT[27:24]};
        16'h014E: dout_mux = { 12'h0, RESULT[31:28]};
        16'h0150: dout_mux = { 12'h0, RESULT[35:32]};
        16'h0152: dout_mux = { 12'h0, RESULT[39:36]};
        16'h0154: dout_mux = { 12'h0, RESULT[43:40]};
        16'h0156: dout_mux = { 12'h0, RESULT[47:44]};
        16'h0158: dout_mux = { 12'h0, RESULT[51:48]};
        16'h015A: dout_mux = { 12'h0, RESULT[55:52]};
        16'h015C: dout_mux = { 12'h0, RESULT[59:56]};
        16'h015E: dout_mux = { 12'h0, RESULT[63:60]};
        16'h0160: dout_mux = { 12'h0, RESULT[67:64]};
        16'h0162: dout_mux = { 12'h0, RESULT[71:68]};
        16'h0164: dout_mux = { 12'h0, RESULT[75:72]};
        16'h0166: dout_mux = { 12'h0, RESULT[79:76]};
        16'h0168: dout_mux = { 12'h0, RESULT[83:80]};
        16'h016A: dout_mux = { 12'h0, RESULT[87:84]};
        16'h016C: dout_mux = { 12'h0, RESULT[91:88]};
        16'h016E: dout_mux = { 12'h0, RESULT[95:92]};
        16'h0170: dout_mux = { 12'h0, RESULT[99:96]};
        16'h0172: dout_mux = { 12'h0, RESULT[103:100]};
        16'h0174: dout_mux = { 12'h0, RESULT[107:104]};
        16'h0176: dout_mux = { 12'h0, RESULT[111:108]};
        16'h0178: dout_mux = { 12'h0, RESULT[115:112]};
        16'h017A: dout_mux = { 12'h0, RESULT[119:116]};
        16'h017C: dout_mux = { 12'h0, RESULT[123:120]};
        16'h017E: dout_mux = { 12'h0, RESULT[127:124]};

		  
      16'h0990: dout_mux = { 15'h0000, isBusy };


      16'hfffc: dout_mux = 16'h7eed;
       default: dout_mux = 16'h0000;
    endcase
  end

  //
  always @( posedge CLK or negedge RSTn ) begin
    if ( RSTn == 1'b0 ) begin
      wbusy_reg <= 1'b0;
      rrdy_reg <= 1'b0;
      hdout_reg <= 8'h00;
    end
    else begin
      if (( now_if_state == READ2 ) && ( HWE == 1'b1 )) wbusy_reg <= 1'b1;
      else if ( next_if_state == CMD ) wbusy_reg <= 1'b0;
      else wbusy_reg <= wbusy_reg;

      if ( now_if_state == READ3 ) rrdy_reg <= 1'b1;
      else if ( now_if_state == READ4 ) rrdy_reg <= 1'b1;
      else rrdy_reg <= 1'b0;

      if ( now_if_state == READ3 ) hdout_reg <= dout_mux[15:8];
      else if ( now_if_state == READ4 ) hdout_reg <= dout_mux[7:0];
      else hdout_reg <= hdout_reg;
    end
  end

  assign WRDYn = wbusy_reg;
  assign RRDYn = ~rrdy_reg;
  assign HDOUT = hdout_reg;

  assign ENCn_DEC = enc_dec;
  assign DATA_EN = data_ena;
  assign NB_ROUND = nbround_reg;
  assign STAR = star_reg;
  /*assign FAULT_T = fault_t_reg;
  assign F_ROUND = f_round_reg;*/
  assign internal_reset = internal_reset_reg;

endmodule

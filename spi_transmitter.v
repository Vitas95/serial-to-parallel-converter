// This module contains the SPI transmitter.  This transmitter can
// transmit 24 bits of serial data, and no parity bit.
// To start transmission start_transmission bit should be set, transmission
// will continue untill the FIFO is not empty.

module spi_transmitter (
  input 		 	 clock,
  input 		 	 reset,
  input [23:0] data,
  input			   fifo_empty,
  input			   start_transmit,
  output    	 fifo_read,
  output reg   sdo, sclk,
  output	   	 spi_busy, sync_n
);

reg		 	    busy_q				= 0;
reg [1:0] 	current_state = 0;
reg [1:0] 	next_state 		= 0;
reg [4:0] 	bit_counter		= 0;
reg [23:0]	tx_data 			= 0;

// States for the control state mashine
parameter [1:0] s_Wait 		  	  = 2'b00,
                s_LoadData 	 	  = 2'b01,
                s_Transmission 	= 2'b10;

// Conditions
wire transmission_started  = (start_transmit) & ~fifo_empty;
wire transmission_finished = (bit_counter == 24);
  
// SPI state machine
always @(*) begin
  case (current_state)
    s_Wait: begin
      if (transmission_started) next_state = s_LoadData;
      else next_state = s_Wait;
    end
	 
    s_LoadData: next_state = s_Transmission;
	 
    s_Transmission: begin
      if (transmission_finished) next_state = s_Wait;
      else next_state = s_Transmission;
    end		
	 
  endcase
end

// The sequentially part of the transmitter state machine
always @(posedge clock) begin
  if (reset) current_state = s_Wait;
  else current_state = next_state;
end

// Output logic
always @(posedge clock) begin
	if (reset | (next_state == s_Wait)) begin
	  sdo         <= 0;
	  bit_counter <= 0;
	end else if (next_state == s_LoadData) begin
	  tx_data <= data;
	end else if (next_state == s_Transmission) begin
	  sdo         <= tx_data[23];
	  tx_data     <= {tx_data[22:0],1'b0};	  
	  bit_counter <= bit_counter + 1'b1;
	end
end

assign sync_n    = (current_state == s_Wait) | (current_state == s_LoadData);
assign spi_busy  = (current_state != s_Wait);
assign fifo_read = (current_state == s_LoadData);

always @(*) begin
  if (current_state == s_Transmission) sclk = clock;
  else sclk = 0;
end

endmodule
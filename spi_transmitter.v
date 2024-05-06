// This module contains the SPI transmitter.  This transmitter can
// transmit 24 bits of serial data, and no parity bit.
// To start transmission start_transmission bit should be set, transmission
// will continue untill the FIFO is not empty.

module spi_transmitter (
  input 		 	clock,
  input 		 	reset,
  input [23:0] data,
  input			fifo_empty,
  input			start_transmit,
  output    	fifo_read,
  output reg   sdo, sclk,
  output	   	spi_busy, sync_n
);

reg		 	busy_q				= 0;
reg [1:0] 	current_state 		= 0;
reg [1:0] 	next_state 			= 0;
reg [4:0] 	bit_counter			= 0;
reg [23:0]	tx_data 				= 0;

// States for the control state mashine
parameter [1:0] Wait 		  	= 2'b00,
					 LoadData 	 	= 2'b01,
					 Transmission 	= 2'b10;

// Conditions
wire transmission_started  = (start_transmit) & ~fifo_empty;
wire transmission_finished = (bit_counter == 24);
  
// SPI state machine
always @(*) begin
  case (current_state)
    Wait: begin
	   if (transmission_started) next_state = LoadData;
		else next_state = Wait;
	 end
	 
	 LoadData: next_state = Transmission;
	 
	 Transmission: begin
	   if (transmission_finished) next_state = Wait;
		else next_state = Transmission;
    end		
	 
  endcase
end

// The sequentially part of the transmitter state machine
always @(posedge clock) begin
  if (reset) current_state = Wait;
  else current_state = next_state;
end

// Output logic
always @(posedge clock) begin
	if (reset | (next_state == Wait)) begin
	  sdo <= 0;
	  bit_counter <= 0;
	end else if (next_state == LoadData) begin
	  tx_data <= data;
	end else if (next_state == Transmission) begin
	  sdo <= tx_data[23];
	  tx_data <= {tx_data[22:0],1'b0};	  
	  bit_counter <= bit_counter + 1'b1;
	end
end

assign sync_n = (current_state == Wait) | (current_state == LoadData);
assign spi_busy = (current_state != Wait);
assign fifo_read = (current_state == LoadData);

always @(*) begin
  if (current_state == Transmission) sclk = clock;
  else sclk = 0;
end

endmodule
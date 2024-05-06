// This module contains the UART Transmitter.  This transmitter can
// transmit 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When transmission is ongoing, tx_busy is driven 
// high until the end of the stop bit.

// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = round((Frequency of clock)/(UART baud rate))
// Example: 1 MHz Clock, 115200 baud UART
// round((1000000)/(115200)) = 9

module uart_transmitter #(parameter CLKS_PER_BIT = 9) (
	input  	  	 clock,
	input  	  	 reset,
	input  [7:0] data,
	input  	  	 start_transmit,
	output reg 	 tx,
	output	 	 tx_busy
);

reg 		 start_transmit_q		= 0;
reg [7:0] tx_data					= 0;
reg [1:0] current_state 		= 0;
reg [1:0] next_state 			= 0;
reg [4:0] counter					= 0;
reg [3:0] bit_counter			= 0;

//States for the control state mashine
parameter [1:0] s_WAIT 		    = 2'b00, 
					 s_START_BIT    = 2'b01,
					 s_TRANSMIT_BIT = 2'b10,
					 s_STOP_BIT 	 = 2'b11;

// Conditions
wire transmission_started = (start_transmit_q == 1);
wire next_bit			  	  = (counter == CLKS_PER_BIT-1);
wire last_bit			  	  = (bit_counter == 7) & next_bit;

					 
// Buffer register to avoid metastability
always @(posedge clock) start_transmit_q <= start_transmit;
  
// Transmitter state machine
always @(*) begin
  case(current_state)
    s_WAIT: begin
	   if (transmission_started) next_state = s_START_BIT;
		else next_state = s_WAIT;
	 end
	 
	 s_START_BIT: begin
	   if (next_bit) next_state = s_TRANSMIT_BIT;
		else next_state = s_START_BIT;
	 end
	 
	 s_TRANSMIT_BIT: begin
	   if (last_bit) next_state = s_STOP_BIT;
		else next_state = s_TRANSMIT_BIT;
	 end
	 
	 s_STOP_BIT: begin
	   if (next_bit) next_state = s_WAIT;
		else next_state = s_STOP_BIT;
	 end
	
	 default: next_state = s_WAIT;
	 
  endcase
end

// The sequentially part of the transmitter state machine
always @(posedge clock) begin
  if (reset) current_state <= s_WAIT;
  else current_state <= next_state;
end

// Counter
always @(posedge clock) begin
  if (reset | next_bit) counter <= 0;
  else if (next_state != s_WAIT) counter <= counter + 1;
end

// Transmission logic
always @(posedge clock) begin
  if (reset | (next_state == s_WAIT)) begin
    tx <= 1;
	 bit_counter <= 0;
  end else if (next_state == s_START_BIT) begin 
    tx <= 0;
	 tx_data <= data;
	 //if (counter < 1) tx_data <= data;
  end else if (current_state == s_TRANSMIT_BIT) begin
    tx <= tx_data[0];
	 if (next_bit) begin
	   tx_data <= {1'b0,tx_data[7:1]};
	   bit_counter <= bit_counter + 1;
	 end
  end else if (next_state == s_STOP_BIT) begin
    tx <= 1;
  end
end

assign tx_busy = (next_state != s_WAIT);

endmodule
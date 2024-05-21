// This module contains the UART Receiver.  This receiver can
// receive 8 bits of serial data, one start bit, one stop bit,
// and no parity bit.  When receive is complete rx_byte_ready will be
// driven high for one clock cycle.

// Set Parameter CLKS_PER_BIT as follows:
// CLKS_PER_BIT = round((Frequency of clock)/(UART baud rate))
// Example: 1 MHz Clock, 115200 baud UART
// round((1000000)/(115200)) = 9

module uart_receiver #(parameter CLKS_PER_BIT = 9) (
  input 				   rx,
  input 				   clock,
  input 				   reset,
  output reg       rx_byte_ready,
  output reg [7:0] rx_data
);

reg 		  rx_q 			    = 1;
reg [2:0] current_state = 0;
reg [2:0] next_state 	  = 0;
reg [4:0] counter			  = 0;
reg [3:0] bit_counter	  = 0;

// States for the control state mashine
parameter [2:0] s_WAIT 	 = 3'b000, 
					 s_START_BIT 	 = 3'b001,
					 s_RECEIVE_BIT = 3'b010, 
					 s_STOP_BIT 	 = 3'b011,
					 s_CLEAN			 = 3'b100;

// Conditions
wire receiving_started = (rx_q == 0);
wire start_bit   	     = (rx_q == 0) & (counter == ((CLKS_PER_BIT-1)/2)-1);
wire next_bit			     = (counter == CLKS_PER_BIT-1);
wire last_bit			     = (bit_counter == 8);
wire stop_bit			     = (rx_q == 1) & (counter == CLKS_PER_BIT-1-1);
wire reset_counter	   = ((current_state == s_START_BIT) & start_bit) |
                         ((next_state == s_RECEIVE_BIT) & next_bit) |
                         ((next_state == s_STOP_BIT) & stop_bit);
					 
// Buffer register for input signals to avoid metastability
always @(posedge clock) rx_q <= rx;

// Receiver state machine
always @(*) begin
  case(current_state)
    s_WAIT: begin
	   if (receiving_started) next_state = s_START_BIT;
     else next_state = s_WAIT;
	 end
	 
  s_START_BIT: begin
    if (start_bit) begin
      if (receiving_started) next_state = s_RECEIVE_BIT;
      else next_state = s_WAIT;
		end else next_state = s_START_BIT;
	 end
	 
	 s_RECEIVE_BIT: begin
		 if (last_bit) next_state = s_STOP_BIT;
		 else next_state = s_RECEIVE_BIT;
	 end
	 
	 s_STOP_BIT: begin
	   if (stop_bit) next_state = s_CLEAN;
		 else next_state = s_STOP_BIT;
	 end
	 
	 s_CLEAN: next_state = s_WAIT;
	
	 default: next_state = s_WAIT;
	 
  endcase
end

// The sequentially part of the receiver state machine
always @(posedge clock) begin
  if (reset) current_state <= s_WAIT;
  else current_state <= next_state;
end

// Counter
always @(posedge clock) begin
  if (reset | reset_counter | (next_state == s_WAIT)) counter <= 0;
  else counter <= counter + 1;
end

// Receiving logic
always @(posedge clock) begin
  if (reset | (next_state == s_WAIT)) begin
	  bit_counter <= 0;
  end else if ((next_state == s_RECEIVE_BIT) & next_bit) begin
    rx_data     <= {rx_q,rx_data[7:1]};
	  bit_counter <= bit_counter + 1'b1;
  end
end

always @(posedge clock) rx_byte_ready <= (next_state == s_CLEAN);

endmodule
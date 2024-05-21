// This module contains control logic and state 
// machines to rule the UART and SPI modules.
// It retranslates the data to the required fifo module
// and rule the transmission process.

module control #(parameter DACN = 2) (
  input	clock,
  input	reset,
  
  // UART ports
  input       [7:0] uart_rx_data,
  input 					  uart_rx_byte_ready,
  output reg	[7:0]	uart_tx_data,
  output reg			  uart_tx_transmit,
  input					    uart_tx_busy,
 
  // FIFO memory ports
  output  reg [23:0]		 fifo_data[0:DACN-1],
  output	reg [DACN-1:0] fifo_write,
  input		    [DACN-1:0] fifo_full,
  input		    [DACN-1:0] fifo_empty,
  
  // SPI control ports
  input		   [DACN-1:0] spi_busy,
  output reg [DACN-1:0]	spi_start_transmit,
  
  // Direct to DACs
  output reg [DACN-1:0] dac_clr_n,
  output reg [DACN-1:0] dac_reset_n,
  output reg [DACN-1:0] dac_ldac_n,
  input  reg [DACN-1:0] dac_busy_n
);

reg [2:0] 		  current_state;
reg [2:0] 		  next_state;
reg 		 		    uart_rx_byte_ready_q = 0;
reg 		 		    uart_tx_busy_q       = 0;
reg [DACN-1:0]	dac_busy_n_q         = 0;

reg [7:0]	command;
reg [7:0]	voltage[2:0];
reg [1:0]	byte_counter;

integer i;

// States for the control state mashine.
parameter [2:0] 	s_Wait 				   = 3'b000,
                  s_AnalyzeCommand = 3'b001,
                  s_UploadVoltage  = 3'b010, // This is also a UART command
                  s_SendVoltage		 = 3'b011, // This is also a UART command
                  s_SettleVoltage	 = 3'b100; // This is also a UART command
						
// Conditions
wire uart_byte_received = uart_rx_byte_ready & ~uart_rx_byte_ready_q;
wire upload_voltage  	  = (command[6:4] == s_UploadVoltage);
wire send_voltage 		  = (command[6:4] == s_SendVoltage);
wire settle_voltage	 	  = (command[6:4] == s_SettleVoltage);
wire voltage_received 	= (byte_counter == 3) & |fifo_write;
wire voltage_sent		 	  = &fifo_empty & &dac_busy_n_q & ~|spi_busy;

// Buffer register for input signals to avoid metastability
always_ff @(posedge clock) begin
  uart_rx_byte_ready_q <= uart_rx_byte_ready;
  dac_busy_n_q         <= dac_busy_n;
end
						
// Control state mashine
always @(*) begin
  case(current_state)
    s_Wait: begin 
      if (uart_byte_received) next_state = s_AnalyzeCommand;
      else next_state = s_Wait;
    end
    
    s_AnalyzeCommand: begin
      if (upload_voltage) next_state = s_UploadVoltage;
      else if (send_voltage) next_state = s_SendVoltage;
      else if (settle_voltage) next_state = s_SettleVoltage;
      else next_state = s_AnalyzeCommand;
    end
	 
    s_UploadVoltage: begin
      if (voltage_received) next_state = s_Wait;
      else next_state = s_UploadVoltage;
    end
	 
    s_SendVoltage: begin
      if (voltage_sent) next_state = s_Wait;
      else next_state = s_SendVoltage;
    end
	 
    s_SettleVoltage: begin
      next_state = s_Wait;
    end
	 
    default: next_state = s_Wait;
  endcase
end
	
// The sequentially part of the control state machine	
always_ff @(posedge clock) begin
  if (reset) current_state <= s_Wait;
  else current_state <= next_state;
end

// Control logic
always_ff @(posedge clock) begin
  if (reset | (next_state == s_Wait)) begin
    command            <= '0;
    byte_counter       <= '0;
    fifo_write         <= '0;
    spi_start_transmit <= '0;
  end else begin
    if (next_state == s_AnalyzeCommand) begin
      command <= uart_rx_data;
    end
	 
	else if (next_state == s_UploadVoltage) begin
	  if (uart_byte_received) begin : CompleteVoltageWord
		  if (byte_counter < 3) begin
		    voltage[0] <= uart_rx_data;
		    for (i=2; i>0; i=i-1) voltage[i] <= voltage [i-1];
          byte_counter <= byte_counter + 1;
		  end 
		end : CompleteVoltageWord
		else if ((byte_counter == 3)) begin : SendToFIFO
		    fifo_write[command[3:0]] <= 1;
		end : SendToFIFO
  end
	 
	else if (next_state == s_SendVoltage) begin
    if (~voltage_sent) spi_start_transmit <= '1;
    else spi_start_transmit <= '0;
	end

  end
end

// Connect voltage register to the required DACs fifo module 
always_comb begin
  for(int i = 0; i < DACN; i++) begin
    dac_reset_n[i] = 1;
    dac_clr_n[i]   = 1;
    dac_ldac_n[i]  = ~(next_state == s_SettleVoltage);
    if (command[3:0] == i) fifo_data[i] = {voltage[2], voltage[1], voltage[0]};
    else fifo_data[i] = '0;
  end
end

endmodule
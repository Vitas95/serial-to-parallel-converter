// Testbench for UART modules. It consists of the connected receiver 
// and transmitter. During the test, TEST_BYTE is transmitted to the 
// receiver and simultaneously transmitted by the transmiter. Each of 
// these steps is automatically checked.

`timescale 1us / 1ns

module uart_transceiver_tb;

// Testbench uses a 1 MHz clock
// Baud rate of the UART is 115200
// CLOCK_PER_BIT = round(CLK_PERIOD_US * BIT_DURATION_US) = 9
parameter CLK_PERIOD		  = 1.0;	// In us
parameter BIT_DURATION	  = 8.7;	// In us
parameter CLK_PER_BIT 	  = 9;
parameter [7:0] TEST_BYTE = 8'b0110_1010;

reg 		  clock;
reg 		  reset;
reg 		  rx;
reg [7:0] rx_test = 0;

wire [7:0] data;
wire		   ready;
wire		   busy;
wire 		   tx;

integer i = 0;

// Test modules
uart_receiver #(
  .CLKS_PER_BIT(CLK_PER_BIT)
) receiver_dut (
  .rx(rx),
  .clock(clock),
  .reset(reset),
  .rx_byte_ready(ready),
  .rx_data(data)
);

uart_transmitter #(
  .CLKS_PER_BIT(CLK_PER_BIT)
) transmitter_dut (
  .clock(clock),
  .reset(reset),
  .data(data),
  .start_transmit(ready),
  .tx(tx),
  .tx_busy(busy)
);

// Clock signal
always #(CLK_PERIOD/2) clock <= ~clock;

// Initialisaton task
task init();
  begin
    clock <= 0;
    reset <= 0;
    rx    <= 1;
  end
endtask

// Reset task
task reset_pulse();
  begin
    reset <= 1;
	  #(CLK_PERIOD);
	  reset <= 0;
  end
endtask

// Send byte via UART
task send_byte (
	input [7:0] byte
);

  integer i;
  
  begin
    // Start bit
    rx <= 0;
    #(BIT_DURATION);
	 
    //Sending byte
    for (i=0; i < 8; i=i+1) begin
	    rx <= byte[i];
		  #(BIT_DURATION);
    end
	 
	 	// Checking if the receiving was successful.
    if (data == TEST_BYTE) $display("Reception succeed.");
    else $display("Reception failure!");
	 
    //Stop bit
    rx <= 1;
    #(BIT_DURATION);
  end
endtask

// Receive and check
always @(negedge tx) begin
  // Skip start bit
  #(BIT_DURATION);
  
  // Skip half of the first bit
  #(BIT_DURATION/2);
  
  // Receive byte
  for (i=0; i < 8; i=i+1) begin
    rx_test[i] <= tx;
    #(BIT_DURATION);
  end
  
  // Skip half of the last bit
  #(BIT_DURATION/2);
  
  // Skip stop bit
  #(BIT_DURATION);
  
  // Checking if the transmission was successful.
  if (rx_test == TEST_BYTE) $display("Transmission succeed.");
  else $display("Transmission failure!");
  
end

// Main simulation cycle
initial begin
  init();
  reset_pulse();
  
  send_byte(TEST_BYTE);

end
  
endmodule
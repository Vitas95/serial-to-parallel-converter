// Testbench for the main module. This test assumes 
// two DACs connected to the FPGA. During the 
// test, the FIFO for each DAC is filled with one data word, 
// and then they are sent into the DACs.

// NOT FINISHED  //

`timescale 1us / 1ns

module main_with_uart_tb;

// Testbench uses a 250 kHz clock
// Baud rate of the UART is 9600
// CLOCK_PER_BIT = round(CLK_PERIOD_US * BIT_DURATION_US) = 24
parameter 		  CLK_PERIOD   = 4.0;	// In us
parameter       BIT_DURATION = 104;	// In us
parameter 		  CLKS_PER_BIT = 26;
parameter [7:0] TEST_BYTE_1  = 8'b0010_0001,
                TEST_BYTE_2  = 8'b0010_0000,
                TEST_BYTE_3  = 8'b0011_0000,
                TEST_BYTE_4  = 8'b0100_0000;

reg		    reset_button;
reg 		  uart_rx;
reg [1:0] dac_busy_n;

wire        uart_tx;
wire        on_led,
            fifo_empty_led_and,
            fifo_empty_led_or;
wire [1:0]  dac_sdo, dac_sclk, dac_sync_n, 
            dac_reset_n, dac_clr_n, dac_ldac_n;

integer i;

// Tested modules
main #(
  .DACN(2),
  .CLKS_PER_BIT(CLKS_PER_BIT),
  .TESTBENCH(1)
) main_dut (
  
  // General purpose ports
  .clk_50			    (),
  .reset_button	(reset_button),
  
  // Test LEDs
  .on_led             (on_led),
  .fifo_empty_led_and (fifo_empty_led_and),
  .fifo_empty_led_or  (fifo_empty_led_or),
  
  // UART ports
  .uart_rx	(uart_rx),
  .uart_tx	(uart_tx),
  
  // DACs ports
  .dac_busy_n	  (dac_busy_n),
  .dac_sdo		  (dac_sdo),
  .dac_sclk		  (dac_sclk),
  .dac_sync_n	  (dac_sync_n),
  .dac_reset_n	(dac_reset_n),
  .dac_clr_n	  (dac_clr_n),
  .dac_ldac_n	  (dac_ldac_n)
);


// Clock signals
always #(CLK_PERIOD/2) begin
  main_dut.clk_1 <= ~main_dut.clk_1;
end

always #(CLK_PERIOD/2) begin
  main_dut.clk_1 <= ~main_dut.clk_1;
end


// Initialisation
task init();
  begin
    reset_button <= 1;
    main_dut.clk_1 <= 0;
    main_dut.clk_1 <= 0;
    uart_rx <= 1;
    dac_busy_n <= '1;
  end
endtask

// Reset pulse internally in main dut
task reset_pulse();
  begin
    #(CLK_PERIOD) main_dut.reset <= 1;
    #(CLK_PERIOD) main_dut.reset <= 0;
    #(CLK_PERIOD);
  end
endtask

// Send byte via UART
task send_byte (
	input [7:0] byte_to_transmit
);

  integer i;
  
  begin
    // Start bit
    uart_rx <= 0;
    #(BIT_DURATION);
	 
    //Sending byte
    for (i=0; i < 8; i=i+1) begin
      uart_rx <= byte_to_transmit[i];
      #(BIT_DURATION);
    end
	 
	 	 // Checking if the receiving was successful.
    if (main_dut.uart_rx_data == byte_to_transmit) $display("UART reception succeed.");
    else $display("UART reception failure!");
	 
    //Stop bit
    uart_rx <= 1;
    #(BIT_DURATION);
  end
endtask

task send_voltage (
  input [7:0] byte_in
);

  for (i=0; i<4; i=i+1) begin
    send_byte(byte_in);
    #(CLK_PERIOD);
  end
endtask

// Check SPI data transmission

// Main simulation cycle
initial begin
  init();
  reset_pulse();
  
  #(CLK_PERIOD);
  send_voltage(TEST_BYTE_1);
  #(CLK_PERIOD*10);
  send_voltage(TEST_BYTE_2);
  #(CLK_PERIOD*10);
  send_byte(TEST_BYTE_3);
  #(CLK_PERIOD*10);
  send_byte(TEST_BYTE_4);
end

endmodule
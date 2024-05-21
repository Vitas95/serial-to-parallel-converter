// Testbench for SPI module. It consists of the single SPI
// transmitter and fifo module. During the test, TEST_WORD is written in 
// fifo module. When SPI ransmitter receive start signal it starts transmission. 
// Transmitted data are automatically check.

`timescale 1us / 1ns

module spi_transmitter_tb;

// Testbench uses a 1 MHz clock
parameter        CLK_PERIOD	= 1.0;	// In us
parameter [23:0] TEST_WORD  = 24'b1110_1010_0011_1010_0011_0101;

reg 			  reset;
reg 			  clock;
reg			    start_transmit;
reg [23:0]	rx_test = 0;

wire 			  fifo_empty;
wire			  fifo_read;
wire [23:0]	data;
wire			  sdo;
wire			  sclk;
wire			  sync_n;


integer i = 0;

// Testing modules
spi_transmitter spi_transmitter_dut(
  .clock	(clock),
  .reset	(reset),
		
  // FIFO connection
  .data			  (data),
  .fifo_read	(fifo_read),
  .fifo_empty	(fifo_empty),
		
  // Control
  .start_transmit	(start_transmit),
  .spi_busy			  (),
		
  // DAC connetcion
  .sdo		(sdo),
  .sclk		(sclk),
  .sync_n	(sync_n)
);

fifo_buffer fifo_buffer_dut(
  .clock (clock),
  .reset (reset),
  
  // Write and read data ports
  .write_data	(),
  .data_in		(),
  .read_data	(fifo_read),
  .data_out		(data),
  
  // Status ports
  .full	  (),
  .empty	(fifo_empty)
);

// Clock signal
always #(CLK_PERIOD/2) clock <= ~clock;

// Initialisation
task init();
  begin
    clock <= 0;
    reset <= 0;
    start_transmit <= 0;
  end
endtask

// Configure fifo module for test
task fifo_config();
  begin
    fifo_buffer_dut.mem[0]        <= TEST_WORD;
    fifo_buffer_dut.mem[1]        <= TEST_WORD;
    fifo_buffer_dut.mem[2]        <= TEST_WORD;
    fifo_buffer_dut.write_pointer <= 6'b000011;
  end
endtask

task reset_pulse();
  begin
    #(CLK_PERIOD)	reset <= 1;
    #(CLK_PERIOD)	reset <= 0;
    #(CLK_PERIOD);
  end
endtask

// Receive word from transmitter
always @(negedge sync_n) begin
  // Skip half of the clock cycle
  #(CLK_PERIOD/2);
  
  // Receive word
  for (i=23; i>-1; i=i-1) begin
    rx_test[i] <= sdo;
    #(CLK_PERIOD);
  end
  
  // Skip half of the clock cycle
  #(CLK_PERIOD/2);
  
  // Checking if the transmission was successful.
  if (rx_test == TEST_WORD) $display("Transmission succeed.");
  else $display("Transmission failure!");
  
  i = 0;
end

// Main simulation cycle
initial begin
  init();
  reset_pulse();
  fifo_config();
  start_transmit <= 1;
end

endmodule
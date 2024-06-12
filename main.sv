// This file contains serial to parallel converter which is designed
// to control multiple Digital to Analog Converters (DAC) from AD53xx series.
// however it can be used in other applications.
// Data received from the computer via the UART interface are 
// collected in the FIFO buffers. Then  when sertain comand is received module
// simultaneously transmit data to the DACs.

// Parametrisation of the module allows to change clock frequency for 
// UART and the rest part of the control logic independently. Frequency of the 
// UART module should be less or equal to the frequency of the control logic. 
// Parameters: 
// - CLKS_PER_BIT is used by the UART modules.				
//					Set parameter CLKS_PER_BIT as follows:
// 				CLKS_PER_BIT = round((Frequency of clock)/(UART baud rate))
// 				Example: 1 MHz Clock, 115200 baud UART
// 				round((1000000)/(115200)) = 9
// - DACN is the number of used DACs in the project.
//					Equal to the number of devices conected to the FPGA chip.
// - TESTBENCH if high configure module for testbench.

module main #(
  parameter DACN         = 2,
  parameter CLKS_PER_BIT = 9,
  parameter TESTBENCH    = 0
) (  
  // General purpose ports
  input  clk_50,
  input  reset_button,
  
  // Debugging outputs
  output on_led,
  output fifo_empty_led_and,
  output fifo_empty_led_or,
  
  // UART ports
  input  uart_rx,
  output uart_tx,
  
  // DACs ports
  input  [DACN-1:0]	dac_busy_n,
  
  output [DACN-1:0]	dac_sdo, 
                    dac_sclk, 
                    dac_sync_n, 
                    dac_reset_n, 
                    dac_clr_n,
                    dac_ldac_n
);


logic	reset;
logic clk_1;
logic pll_locked;
logic	pll_locked_q;
logic reset_user;
logic reset_button_pressed;
logic reset_button_pressed_q;

genvar geni;

// Connections between uart and control
logic [7:0]	uart_rx_data;
logic			  uart_byte_ready;
logic [7:0] uart_tx_data;

// Connetions between control and spi
wire [DACN-1:0]	spi_busy;
wire [DACN-1:0]	spi_start_transmit;

// Connections between control and fifo
wire [23:0]			fifo_data_in[0:DACN-1];
wire [DACN-1:0]	fifo_write_data;
wire [DACN-1:0]	fifo_full;
wire [DACN-1:0]	fifo_empty;

// Connections between fifo and spi
wire [23:0] 		fifo_data_out[0:DACN-1];
wire [DACN-1:0]	fifo_read_data;

// Debugging interface
assign on_led             = 0;
assign fifo_empty_led_and = &fifo_empty;
assign fifo_empty_led_or  = |fifo_empty;

// Pll is used in design only. When it's testbench 
// clock should be driven manualy.
generate
  if (TESTBENCH == 0) begin
    pll pll_1_MHz_m (
      .inclk0	(clk_50),
      .c0		  (clk_1),
      .locked	(pll_locked)
    );
  end
endgenerate
  
// Reset button
button button_m (
  .button_in	(~reset_button),
  .clock			(clk_50),
  .out			  (reset_button_pressed)
);

// Reset processing
always @(posedge clk_1) begin
  pll_locked_q           <= pll_locked;
  reset_button_pressed_q <= reset_button_pressed;
end

assign pll_reset  = pll_locked & ~pll_locked_q;
assign reset_user = reset_button_pressed & ~reset_button_pressed_q;
assign reset      = reset_user | pll_reset;

// UART modules
uart_receiver #(
  .CLKS_PER_BIT(CLKS_PER_BIT)
) uart_receiver_m (
  .rx				     (uart_rx),
  .clock			   (clk_1),
  .reset			   (reset),
  .rx_byte_ready (uart_byte_ready),
  .rx_data		   (uart_rx_data)
);

uart_transmitter #(
  .CLKS_PER_BIT(CLKS_PER_BIT)
) uart_transmitter_m (
  .clock			    (clk_1),
  .reset			    (reset),
  .data				    (uart_tx_data),
  .start_transmit (uart_start_transmit),
  .tx				      (uart_tx),
  .tx_busy			  (uart_tx_busy)
);

// SPI modules
generate
  for (geni=0; geni<DACN; geni=geni+1) begin : generate_spi_modules
    spi_transmitter spi_transmitter_m (
      .clock	(clk_1),
      .reset	(reset),
		
		// FIFO connection
      .data			  (fifo_data_out[geni]),
      .fifo_read	(fifo_read_data[geni]),
      .fifo_empty (fifo_empty[geni]),
		
		// Control module
      .start_transmit	(spi_start_transmit[geni]),
      .spi_busy			  (spi_busy[geni]),
		
		// DAC connetcion
      .sdo		(dac_sdo[geni]),
      .sclk		(dac_sclk[geni]),
      .sync_n	(dac_sync_n[geni])
    );
  end
endgenerate

// FIFO modules
generate
  for (geni=0; geni<DACN; geni=geni+1) begin : generate_fifo_modules
    fifo_buffer fifo_buffer_m (
      .clock (clk_1),
      .reset (reset),
        
      // Write and read data ports
      .write_data	(fifo_write_data[geni]),
      .data_in		(fifo_data_in[geni]),
      .read_data	(fifo_read_data[geni]),
      .data_out	  (fifo_data_out[geni]),
  
      // Status outputs
      .full		(fifo_full[geni]),
      .empty	(fifo_empty[geni])
    );
  end 
endgenerate

// Main control module
control #(.DACN(DACN)) control_m (
  .clock	(clk_1),
  .reset	(reset),
  
  // UART ports
  .uart_rx_data			  (uart_rx_data),
  .uart_rx_byte_ready	(uart_byte_ready),
  .uart_tx_data			  (uart_tx_data),
  .uart_tx_transmit		(uart_start_transmit),
  .uart_tx_busy			  (uart_tx_busy),
 
  // FIFO memory ports
  .fifo_data	(fifo_data_in),
  .fifo_write	(fifo_write_data),
  .fifo_full	(fifo_full),
  .fifo_empty	(fifo_empty),
  
  // SPI control ports
  .spi_busy					  (spi_busy),
  .spi_start_transmit	(spi_start_transmit),
  
  // Direct to DACs
  .dac_clr_n	  (dac_clr_n),
  .dac_reset_n	(dac_reset_n),
  .dac_ldac_n	  (dac_ldac_n),
  .dac_busy_n	  (dac_busy_n)
);

endmodule
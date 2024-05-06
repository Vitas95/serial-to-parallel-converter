// This file contains controller for Analog Devices DACs.

module main #(parameter DACN = 1) (
  
  // General purpose ports
  input  clk_50,
  input  reset_button,
  
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

reg		pll_locked_q;

genvar 	geni;

// Connections between uart and control
wire [7:0] 	uart_rx_data;
wire [7:0] 	uart_tx_data;

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

// Pll
pll pll_m (
  .areset	(reset_0),
  .inclk0	(clk_50),
  .c0			(clk_16),
  .locked	(pll_locked)
);

// Reset button
button button_m (
  .button_in	(reset_button),
  .clock			(clk_50),
  .reset			(reset),
  .out			(reset_0)
);

// Reset processing
always @(posedge clk_50) pll_locked_q <= pll_locked;
assign pll_reset = pll_locked & ~pll_locked_q;
assign reset = reset_0 | pll_reset;

// UART modules
uart_receiver uart_receiver_m (
  .rx				  (uart_rx),
  .clock			  (clk_16),
  .reset			  (reset),
  .rx_byte_ready (uart_byte_ready),
  .rx_data		  (uart_rx_data)
);

uart_transmitter uart_transmitter_m (
  .clock			   (clk_16),
  .reset			   (reset),
  .data				(uart_tx_data),
  .start_transmit (uart_start_transmit),
  .tx				   (uart_tx),
  .tx_busy			(uart_tx_busy)
);

// SPI modules
generate
  for (geni=1; i<=DACN; i=i+1) begin : generate_spi_modules
    spi_transmitter spi_transmitter_m (
      .clock	(clk_50),
      .reset	(reset),
		
		// FIFO connection
      .data			(fifo_data_out[geni]),
		.fifo_read	(fifo_read_data[geni]),
		
		// Control module
      .start_transmit	(spi_start_transmit[geni]),
		.spi_busy			(spi_busy[geni]),
		
		// DAC connetcion
      .sdo		(dac_sdo[geni]),
      .sclk		(dac_sclk[geni]),
      .sync_n	(dac_sync_n[geni])
    );
  end
endgenerate

// FIFO modules
generate
  for (geni=1; i<=DACN; i=i+1) begin : generate_fifo_modules
    fifo_buffer fifo_buffer_m (
      .clock (clk_50),
      .reset (reset),
        
      // Write and read data ports
      .write_data	(fifo_write_data[geni]),
      .data_in		(fifo_data_in[geni]),
      .read_data	(fifo_read_data[geni]),
      .data_out	(fifo_data_out[geni]),
  
      // Status outputs
      .full		(fifo_full[geni]),
      .empty	(fifo_empty[geni])
    );
  end 
endgenerate

// Main control module
control #(.DACN(DACN)) control_m (
  .clock	(clk_50),
  .reset	(reset),
  
  // UART ports
  .uart_rx_data			(uart_rx_data),
  .uart_rx_byte_ready	(uart_byte_ready),
  .uart_tx_data			(uart_tx_data),
  .uart_tx_transmit		(uart_start_transmit),
  .uart_tx_busy			(uart_tx_busy),
 
  // FIFO memory ports
  .fifo_data	(fifo_data_in),
  .fifo_write	(fifo_write_data),
  .fifo_full	(fifo_full),
  .fifo_empty	(fifo_empty),
  
  // SPI control ports
  .spi_busy					(spi_busy),
  .spi_start_transmit	(spi_start_transmit),
  
  // Direct to DACs
  .dac_clr_n	(dac_clr_n),
  .dac_reset_n	(dac_reset_n),
  .dac_ldac_n	(dac_ldac_n),
  .dac_busy_n	(dac_busy_n)
);

endmodule
// Testbench for the FIFO memory module. During the 
// test, it fills with the cyclic generated data, and 
// after that, all the data is read from the module 
// and automatically checked.

`timescale 1us / 1ns

module fifo_buffer_tb;

// Testbench uses a 1 MHz clock
parameter CLK_PERIOD = 1.0;	// In us
parameter ENDSIM = 100;

reg 				clock;
reg 				reset;
reg 		 		write_enable;
reg [23:0]  data_in;
reg				  read_enable;

wire [23:0]	data_out;
wire				full;
wire				empty;

integer i = 0;

// Test module
fifo_buffer fifo_buffer_dut (
  .clock	(clock),
  .reset	(reset),
  
  // Write and read data ports
  .write_data	(write_enable),
  .data_in		(data_in),
  .read_data	(read_enable),
  .data_out		(data_out),
  
  // Status outputs
  .full	(full),
  .empty	(empty)
);

// Clock signal
always #(CLK_PERIOD/2) clock <= ~clock;

// Initialisation
task init();
  begin
    clock 			  <= 0;
    reset 			  <= 0;
    write_enable	<= 0; 
    read_enable	<= 0;
    data_in			<= 0;
  end
endtask

// Reset
task reset_pulse();
  begin
    #(CLK_PERIOD) 	reset <= 1;
    #(CLK_PERIOD)		reset <= 0;
    #(CLK_PERIOD/2);
  end
endtask

// Write data in the fifo module untill it full
task write_data();
  begin
    write_enable <= 1;
    data_in <= 0;
	 
    for (i=0; i<31; i=i+1) begin
      #(CLK_PERIOD);
      data_in <= data_in + 1'b1;
    end
	 
    write_enable <= 0;
    data_in <= 0;
  end
endtask

// Read some data and compare wthem
task read_data();
  begin
    read_enable <= 1;
    data_in <= 0;
	 
    for (i=0; i<34; i=i+1) begin
      if (!empty) begin
        // Check readed data
        if (data_out == data_in) $display("Readed data okay.");
        else $display("Error!");
		
        // Calculate data to compare
        data_in <= data_in + 1'b1;
      end else begin
        read_enable <= 0;
        $display("Buffer is empty");
      end
		
		#(CLK_PERIOD);
    end
	 
    read_enable <= 0;
	 
  end
endtask


// Main simulation cycle
initial begin
  init();
  reset_pulse();
  
  write_data();
  #(CLK_PERIOD);
  read_data();
  $stop(ENDSIM);
end

endmodule
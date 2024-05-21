// This module is for button processing connected to reset the FPGA manually.
// Input of the module should be directly connected to the button.
// Output of the module is high when button until button is pressed.
// In order to suppress contact bouncing counter register is used to filter
// input noice from the button. Size of this counter is taken to be 16 bits for 
// 50 MHz frequency clock.

module button (
	input button_in,
	input clock,
	output out
);

//// Registers
reg button_in_q;
reg rs_trigger, rs_trigger_q;
reg [15:0] counter;

//// Conditions
wire increment = button_in_q & ~&counter;
wire decrement = ~button_in_q & |counter;
wire set_rs    = &counter;
wire reset_rs  = ~|counter; 

always @(posedge clock) begin
    button_in_q <= button_in;
	
    if (increment) counter <= counter + 1'b1;
    else if (decrement) counter <= counter - 1'b1;
			
    if (set_rs) rs_trigger <= 1;
    else if (reset_rs) rs_trigger <= 0;
    
	 rs_trigger_q <= rs_trigger;
			
end

// Output signal
assign out = rs_trigger & ~rs_trigger_q;

endmodule

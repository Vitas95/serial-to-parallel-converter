// This module contains the FIFO memory buffer for
// 32 24-bit words.

module fifo_buffer (
  input	clock,
  input	reset,
  
  // Write and read data ports
  input				write_data,
  input  [23:0]	data_in,
  input				read_data,
  output [23:0]	data_out,
  
  // Status ports
  output	full,
  output	empty
);

reg [23:0] 	mem [0:31];
reg [5:0]	write_pointer;
reg [5:0]	read_pointer;

always @(posedge clock) begin
  if (reset) begin
    write_pointer <= 0;
	 read_pointer <= 0;
  end else begin
    if (write_data) begin
	   mem[write_pointer] <= data_in;
		write_pointer <= write_pointer + 1;
	 end else if (read_data) begin
	   read_pointer <= read_pointer + 1;
	 end else begin
	   write_pointer <= write_pointer;
		read_pointer <= read_pointer;
	 end
  end
end

assign data_out = mem[read_pointer];

assign empty = (read_pointer[5] == write_pointer[5]) & (read_pointer[4:0] == write_pointer[4:0]);
assign full =  (read_pointer[5] != write_pointer[5]) & (read_pointer[4:0] == write_pointer[4:0]);

endmodule
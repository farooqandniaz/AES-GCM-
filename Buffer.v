/*
 * Module Name  : Buffer
 * Author       : Farooq Niaz
 * Created      : May 22, 2025
 * Last Modified: May 22, 2025, 13:35
 * Version      : 1.0
 * Description  : This buffer of 28 slots(128 bits each) is used at input to accomodate incoming data during the process of key expansion   
*/
module Buffer#	(
				parameter DATA_WIDTH = 128, // Data width
				parameter DELAY_CYCLES = 28 // Number of cycles to delay
				)
				(
				input  wire                  clk,        // Clock
				input  wire                  rst,      // Active-low reset
				input  wire					 enable,
				input  wire [DATA_WIDTH-1:0] data_in,    // Input data
				output reg  [DATA_WIDTH-1:0] data_out = 0    // Delayed output data
				);

    // Shift register to store data for 28 cycles
    reg [DATA_WIDTH-1:0] buffer [0:DELAY_CYCLES-1];

    integer j;
	
	initial
		for (j = 0; j < DELAY_CYCLES; j = j + 1) 
			buffer[j] = 0; // Shift data to the next stage
			
			
			
			
	integer i;

    // Shift register logic
    always @(posedge clk) 
	begin
        if (rst) 
			begin
			//loop is unrolled otherwise simulator is using more clock cycles to reset it
            // Clear the buffer and output on reset
                buffer[0]  <= 0;
				buffer[1 ] <= 0;
				buffer[2 ] <= 0;
				buffer[3 ] <= 0;
				buffer[4 ] <= 0;
				buffer[5 ] <= 0;
				buffer[6 ] <= 0;
				buffer[7 ] <= 0;
				buffer[8 ] <= 0;
				buffer[9 ] <= 0;
				buffer[10] <= 0;
				buffer[11] <= 0;
				buffer[12] <= 0;
				buffer[13] <= 0;
				buffer[14] <= 0;
				buffer[15] <= 0;
				buffer[16] <= 0;
				buffer[17] <= 0;
				buffer[18] <= 0;
				buffer[19] <= 0;
				buffer[20] <= 0;
				buffer[21] <= 0;
				buffer[22] <= 0;
				buffer[23] <= 0;
				buffer[24] <= 0;
				buffer[25] <= 0;
				buffer[26] <= 0;
				buffer[27] <= 0;
	            data_out   <= 0;
			end
        else if (enable)
			begin
				// Shift data through the buffer
				buffer[0] <= data_in; // Input data goes into the first stage
				for (i = 1; i < DELAY_CYCLES; i = i + 1) 
				begin
					buffer[i] <= buffer[i-1]; // Shift data to the next stage
				end
				data_out <= buffer[DELAY_CYCLES-1]; // Output the last stage
			end
    end


endmodule

`timescale 1ns / 1ps

module round1to12	(
					output	reg  [127 : 0]	round_out = 0,
					input 	wire [127 : 0]	round_key,
					input 	wire [127 : 0]	round_in,
					input	wire 			AES_en,
					input	wire 			clk,
					input 	wire			rst
					);

reg 	[127:0] subbytes_out = 0;
wire 	[127:0] subbytes_out_wire;
wire	[31:0]	b0,b1,b2,b3;
wire 	[7:0] a0,a1,a2,a3,a4,a5,a6,a7,a8,a9,a10,a11,a12,a13,a14,a15;
wire 	[7:0] key0,key1,key2,key3,key4,key5,key6,key7,key8,key9,key10,key11,key12,key13,key14,key15;

/* Note: As per FIPS-197 input a0--a15 and key0---key15 is alligned in columns before performing the operations

         a0  a4  a8   a12
		 a1  a5  a9   a13
		 a2  a6  a10  a14 
         a3  a7  a11  a15
		 
*/		 
always@(posedge clk)
if (rst)
	subbytes_out <= 0;
else if (AES_en)
	subbytes_out <= subbytes_out_wire;	
					
aes_subbytes sbox_sub	(
    .subbytes_in(round_in),				// 128-bit input
    .subbytes_out(subbytes_out_wire)	// 128-bit output
	);

assign a15 = subbytes_out [7   : 0  ];
assign a14 = subbytes_out [15  : 8  ];
assign a13 = subbytes_out [23  : 16 ];
assign a12 = subbytes_out [31  : 24 ];
assign a11 = subbytes_out [39  : 32 ];
assign a10 = subbytes_out [47  : 40 ];
assign a9  = subbytes_out [55  : 48 ];
assign a8  = subbytes_out [63  : 56 ];
assign a7  = subbytes_out [71  : 64 ];
assign a6  = subbytes_out [79  : 72 ];
assign a5  = subbytes_out [87  : 80 ];
assign a4  = subbytes_out [95  : 88 ];
assign a3  = subbytes_out [103 : 96 ];
assign a2  = subbytes_out [111 : 104];
assign a1  = subbytes_out [119 : 112];
assign a0  = subbytes_out [127 : 120];

assign key15 = round_key [7   : 0  ];
assign key14 = round_key [15  : 8  ];
assign key13 = round_key [23  : 16 ];
assign key12 = round_key [31  : 24 ];
assign key11 = round_key [39  : 32 ];
assign key10 = round_key [47  : 40 ];
assign key9  = round_key [55  : 48 ];
assign key8  = round_key [63  : 56 ];
assign key7  = round_key [71  : 64 ];
assign key6  = round_key [79  : 72 ];
assign key5  = round_key [87  : 80 ];
assign key4  = round_key [95  : 88 ];
assign key3  = round_key [103 : 96 ];
assign key2  = round_key [111 : 104];
assign key1  = round_key [119 : 112];
assign key0  = round_key [127 : 120];

/*  Mix Column Matrix    shifted rowed input Matrix
    -----------------    -------------------------
	02 03 01 01             a0   a4   a8   a12
	01 02 03 01       X     a5   a9   a13  a1 
	01 01 02 03				a10  a14  a2   a6
	03 01 01 02				a15  a3   a7   a11 
	
*/
assign b0 = shiftrow_mixcolumn_roundkey({a15,a10,a5 ,a0}, {key3 ,key2 ,key1 ,key0} );
assign b1 = shiftrow_mixcolumn_roundkey({a3 ,a14,a9 ,a4}, {key7 ,key6 ,key5 ,key4} );
assign b2 = shiftrow_mixcolumn_roundkey({a7 ,a2 ,a13,a8}, {key11,key10,key9 ,key8} );
assign b3 = shiftrow_mixcolumn_roundkey({a11,a6 ,a1 ,a12},{key15,key14,key13,key12});

always@(posedge clk)
if (rst)
	round_out <= 0;
else if (AES_en)
/*	round_out <= {b0[31:24]	,b1[31:24]	,b2[31:24]	,b3[31:24]	,
				  b0[23:16]	,b1[23:16]	,b2[23:16]	,b3[23:16]	,
				  b0[15:8]	,b1[15:8]	,b2[15:8]	,b3[15:8]	,
				  b0[7:0]	,b1[7:0]	,b2[7:0]	,b3[7:0]	};
*/

	round_out <= {b0, b1, b2, b3};



//This function will do shift rows, mix columns then xoring with round key
function [31:0] shiftrow_mixcolumn_roundkey; 
    input [31:0] c;
    input [31:0] keys;
    
    reg [7:0] c0, c1, c2, c3;
    reg [7:0] k0, k1, k2, k3;
    reg [7:0] d0, d1, d2, d3;

    begin

    // Extract 8-bit chunks from the 32-bit input
		c0 = c[7:0];    // Least significant byte
		c1 = c[15:8];
		c2 = c[23:16];
		c3 = c[31:24]; // Most significant byte
		
		// Extract 8-bit chunks from the 32-bit key
		k0 = keys[7:0];    // Least significant byte
		k1 = keys[15:8];
		k2 = keys[23:16];
		k3 = keys[31:24]; // Most significant byte	
		
		// multiplying Mix_Column with shift_Rows 
		// (a0<<1)modp ^ ((a5<<1) ^a5)modp ^ a10 ^ a15 ^ k0      
		
		// Perform MixColumns-like transformation
		d0 = ({c0[6:0], 1'b0} ^ ({8{c0[7]}} & 8'h1b)) ^ (({c1[6:0], 1'b0} ^ c1) ^ ({8{c1[7]}} & 8'h1b)) ^ c2 ^ c3 ^ k0;
		d1 = ({c1[6:0], 1'b0} ^ ({8{c1[7]}} & 8'h1b)) ^ (({c2[6:0], 1'b0} ^ c2) ^ ({8{c2[7]}} & 8'h1b)) ^ c0 ^ c3 ^ k1;
		d2 = ({c2[6:0], 1'b0} ^ ({8{c2[7]}} & 8'h1b)) ^ (({c3[6:0], 1'b0} ^ c3) ^ ({8{c3[7]}} & 8'h1b)) ^ c0 ^ c1 ^ k2;
		d3 = ({c3[6:0], 1'b0} ^ ({8{c3[7]}} & 8'h1b)) ^ (({c0[6:0], 1'b0} ^ c0) ^ ({8{c0[7]}} & 8'h1b)) ^ c1 ^ c2 ^ k3;
	
		// Return the 32-bit result
		shiftrow_mixcolumn_roundkey = {d0, d1, d2, d3};
	end
endfunction
	
	
	
endmodule	
	
	
	
	
	
	
	
	
	
	






// Top-level module for 128-bit AES S-Box substitution
//module aes_subbytes (
//    input  wire [127:0] subbytes_in,   // 128-bit input
//    output wire [127:0] subbytes_out   // 128-bit output
//);
//
//    // Wires to connect the outputs of each S-Box
//    wire [7:0] sbox_out [15:0];
//
//    // Instantiate 16 S-Box modules for each 8-bit segment
//    genvar i;
//    generate
//        for (i = 0; i < 16; i = i + 1) begin : sbox_inst
//            aes_sbox sbox (
//                .sbox_in(subbytes_in[8*i + 7 : 8*i]),  // Extract 8-bit chunk
//                .sbox_out(sbox_out[i])                 // Connect to output wire
//            );
//        end
//    endgenerate
//
//    // Concatenate the 16 S-Box outputs into a 128-bit output
//    assign subbytes_out = {sbox_out[15], sbox_out[14], sbox_out[13], sbox_out[12],
//                           sbox_out[11], sbox_out[10], sbox_out[9], sbox_out[8],
//                           sbox_out[7], sbox_out[6], sbox_out[5], sbox_out[4],
//                           sbox_out[3], sbox_out[2], sbox_out[1], sbox_out[0]};
//
//endmodule

`timescale 1ns / 1ps

module aes_subbytes (
    input  wire [127:0] subbytes_in,   // 128-bit input
    output wire [127:0] subbytes_out   // 128-bit output
);

    // Wires for individual S-Box outputs
    wire [7:0] sbox_out0;
    wire [7:0] sbox_out1;
    wire [7:0] sbox_out2;
    wire [7:0] sbox_out3;
    wire [7:0] sbox_out4;
    wire [7:0] sbox_out5;
    wire [7:0] sbox_out6;
    wire [7:0] sbox_out7;
    wire [7:0] sbox_out8;
    wire [7:0] sbox_out9;
    wire [7:0] sbox_out10;
    wire [7:0] sbox_out11;
    wire [7:0] sbox_out12;
    wire [7:0] sbox_out13;
    wire [7:0] sbox_out14;
    wire [7:0] sbox_out15;

    // Instantiate S-Boxes (one per byte)
    aes_sbox sbox0 (.sbox_in(subbytes_in[127:120]), .sbox_out(sbox_out0));
    aes_sbox sbox1 (.sbox_in(subbytes_in[119:112]), .sbox_out(sbox_out1));
    aes_sbox sbox2 (.sbox_in(subbytes_in[111:104]), .sbox_out(sbox_out2));
    aes_sbox sbox3 (.sbox_in(subbytes_in[103:96]),  .sbox_out(sbox_out3));
    aes_sbox sbox4 (.sbox_in(subbytes_in[95:88]),   .sbox_out(sbox_out4));
    aes_sbox sbox5 (.sbox_in(subbytes_in[87:80]),   .sbox_out(sbox_out5));
    aes_sbox sbox6 (.sbox_in(subbytes_in[79:72]),   .sbox_out(sbox_out6));
    aes_sbox sbox7 (.sbox_in(subbytes_in[71:64]),   .sbox_out(sbox_out7));
    aes_sbox sbox8 (.sbox_in(subbytes_in[63:56]),   .sbox_out(sbox_out8));
    aes_sbox sbox9 (.sbox_in(subbytes_in[55:48]),   .sbox_out(sbox_out9));
    aes_sbox sbox10(.sbox_in(subbytes_in[47:40]),   .sbox_out(sbox_out10));
    aes_sbox sbox11(.sbox_in(subbytes_in[39:32]),   .sbox_out(sbox_out11));
    aes_sbox sbox12(.sbox_in(subbytes_in[31:24]),   .sbox_out(sbox_out12));
    aes_sbox sbox13(.sbox_in(subbytes_in[23:16]),   .sbox_out(sbox_out13));
    aes_sbox sbox14(.sbox_in(subbytes_in[15:8]),    .sbox_out(sbox_out14));
    aes_sbox sbox15(.sbox_in(subbytes_in[7:0]),     .sbox_out(sbox_out15));

    // Concatenate all output bytes
    assign subbytes_out = {sbox_out0,  sbox_out1,  sbox_out2,  sbox_out3,
                           sbox_out4,  sbox_out5,  sbox_out6,  sbox_out7,
                           sbox_out8,  sbox_out9,  sbox_out10, sbox_out11,
                           sbox_out12, sbox_out13, sbox_out14, sbox_out15};

endmodule

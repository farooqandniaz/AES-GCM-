/*
 * Module Name  : AES_top
 * Author       : Farooq Niaz
 * Created      : May 22, 2025
 * Last Modified: May 22, 2025, 13:35
 * Version      : 1.0
 * Description  : AES 256 core wrapper integrating AES Rounds

`timescale 1ns / 1ps


module AES_top (
    output reg [127:0] enc_text = 0,
    input  wire [127:0] IV,
    input  wire [1919:0] round_keys_flat,  // 15*128 = 1920 bits
    input  wire clk,
    input  wire AES_en,
    input  wire rst,
    output wire [127:0] r1_out, output wire [127:0] r2_out,output wire [127:0] r3_out,output wire [127:0] r4_out,output wire [127:0] r5_out,output wire [127:0] r6_out,output wire [127:0] r7_out,
    output wire [127:0] r8_out, output wire [127:0] r9_out, output wire [127:0] r10_out, output wire [127:0] r11_out, output wire [127:0] r12_out,output wire [127:0] r13_out,output wire [127:0] r14_out
);

    // Unpack the round keys manually
    wire [127:0] rk0  = round_keys_flat[127 :0   ];    // ROUND 0
    wire [127:0] rk1  = round_keys_flat[255 :128 ];
    wire [127:0] rk2  = round_keys_flat[383 :256 ];
    wire [127:0] rk3  = round_keys_flat[511 :384 ];
    wire [127:0] rk4  = round_keys_flat[639 :512 ];
    wire [127:0] rk5  = round_keys_flat[767 :640 ];
    wire [127:0] rk6  = round_keys_flat[895 :768 ];
    wire [127:0] rk7  = round_keys_flat[1023:896 ];
    wire [127:0] rk8  = round_keys_flat[1151:1024];
    wire [127:0] rk9  = round_keys_flat[1279:1152];
    wire [127:0] rk10 = round_keys_flat[1407:1280];
    wire [127:0] rk11 = round_keys_flat[1535:1408];
    wire [127:0] rk12 = round_keys_flat[1663:1536];
    wire [127:0] rk13 = round_keys_flat[1791:1664];
    wire [127:0] rk14 = round_keys_flat[1919:1792];
    
    
    

    reg [127:0] r0_out = 0;
    always @(posedge clk)
        if (rst)
            r0_out <= 0;
        else if (AES_en)
            r0_out <= IV ^ rk0;

    round1to12 r1 (.round_out(r2_out), .round_key(rk1),  .round_in(r0_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r2 (.round_out(r3_out), .round_key(rk2),  .round_in(r2_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r3 (.round_out(r4_out), .round_key(rk3),  .round_in(r3_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r4 (.round_out(r5_out), .round_key(rk4),  .round_in(r4_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r5 (.round_out(r6_out), .round_key(rk5),  .round_in(r5_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r6 (.round_out(r7_out), .round_key(rk6),  .round_in(r6_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r7 (.round_out(r8_out), .round_key(rk7),  .round_in(r7_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r8 (.round_out(r9_out), .round_key(rk8),  .round_in(r8_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r9 (.round_out(r10_out),.round_key(rk9),  .round_in(r9_out),  .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r10(.round_out(r11_out),.round_key(rk10), .round_in(r10_out), .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r11(.round_out(r12_out),.round_key(rk11), .round_in(r11_out), .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r12(.round_out(r13_out),.round_key(rk12), .round_in(r12_out), .clk(clk), .AES_en(AES_en), .rst(rst));
    round1to12 r13(.round_out(r14_out),.round_key(rk13), .round_in(r13_out), .clk(clk), .AES_en(AES_en), .rst(rst));

    // Final round: SubBytes only
    wire [127:0] subbytes_out;
    aes_subbytes sbox_final (
        .subbytes_in(r14_out),
        .subbytes_out(subbytes_out)
    );

    // Extract bytes for ShiftRows
    wire [7:0] a0, a1, a2, a3, a4, a5, a6, a7;
    wire [7:0] a8, a9, a10, a11, a12, a13, a14, a15;

    assign a15 = subbytes_out[7   : 0   ];
    assign a14 = subbytes_out[15  : 8   ];
    assign a13 = subbytes_out[23  : 16  ];
    assign a12 = subbytes_out[31  : 24  ];
    assign a11 = subbytes_out[39  : 32  ];
    assign a10 = subbytes_out[47  : 40  ];
    assign a9  = subbytes_out[55  : 48  ];
    assign a8  = subbytes_out[63  : 56  ];
    assign a7  = subbytes_out[71  : 64  ];
    assign a6  = subbytes_out[79  : 72  ];
    assign a5  = subbytes_out[87  : 80  ];
    assign a4  = subbytes_out[95  : 88  ];
    assign a3  = subbytes_out[103 : 96  ];
    assign a2  = subbytes_out[111 : 104 ];
    assign a1  = subbytes_out[119 : 112 ];
    assign a0  = subbytes_out[127 : 120 ];

    wire [127:0] shiftrows_out;
    assign shiftrows_out = {
        a0,  a5,  a10, a15,   // Row 0
        a4,  a9,  a14, a3,    // Row 1: left shift 1
        a8,  a13, a2,  a7,    // Row 2: left shift 2
        a12, a1,  a6,  a11    // Row 3: left shift 3
    };

    // Final encryption output
    always @(posedge clk) begin
        if (rst)
            enc_text <= 0;
        else if (AES_en)
            enc_text <= shiftrows_out ^ rk14;
    end

endmodule



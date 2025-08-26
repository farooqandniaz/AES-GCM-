/*
 * Module Name  : aes_256_key_expansion
 * Author       : Farooq Niaz
 * Created      : April 22, 2025
 * Last Modified: April 22, 2025, 13:35
 * Version      : 1.0
 * Description  : This module implements the AES-256 key expansion algorithm in a pipelined manner.
 *                It generates 15 round keys (128 bits each) from a 256-bit input key, following the AES-256 standard.
 *				  The process of key expansion isd divided in two parts. 
 *                1st part contains rotate words (RotWords) and SubWord step is performed and registered in 1st pipeline Register	
 *                In 2nd Part Xoring is performed and registered. This whole process takes 27 cycles after start signal and final round key is avaialble at 28th cycle after start signal
*/				  //For process details refere to document FIPS 197 A.3 Page 30

module aes_256_key_expansion_pipelined (
    output wire [15*128-1:0] round_keys_flat,
    input  wire [127:0] key,
    input  wire         KE_enable,
    input  wire         load_key_0,
    input  wire         load_key_1,
    input  wire         clk,
    input  wire         rst
);

    reg [3:0] loop_counter = 0;

    // Individual round key registers
    reg [127:0] round_keys_0  = 0;
    reg [127:0] round_keys_1  = 0;
    reg [127:0] round_keys_2  = 0;
    reg [127:0] round_keys_3  = 0;
    reg [127:0] round_keys_4  = 0;
    reg [127:0] round_keys_5  = 0;
    reg [127:0] round_keys_6  = 0;
    reg [127:0] round_keys_7  = 0;
    reg [127:0] round_keys_8  = 0;
    reg [127:0] round_keys_9  = 0;
    reg [127:0] round_keys_10 = 0;
    reg [127:0] round_keys_11 = 0;
    reg [127:0] round_keys_12 = 0;
    reg [127:0] round_keys_13 = 0;
    reg [127:0] round_keys_14 = 0;

    assign round_keys_flat = {
        round_keys_14,  round_keys_13,  round_keys_12,  round_keys_11,  round_keys_10,
        round_keys_9,  round_keys_8,  round_keys_7,  round_keys_6,  round_keys_5,
        round_keys_4, round_keys_3, round_keys_2, round_keys_1, round_keys_0
    };

    always @(posedge clk) begin
        if (rst) round_keys_0 <= 0;
        else if (load_key_0) round_keys_0 <= key;
    end

    always @(posedge clk) begin
        if (rst) round_keys_1 <= 0;
        else if (load_key_1) round_keys_1 <= key;
    end

    localparam IDLE = 2'd0, REGISTER = 2'd1, LOAD_PL1 = 2'd2, LOAD_KEYS = 2'd3;
    reg [1:0] state = IDLE, next_state = IDLE;
    reg en_PL1_reg = 0, loop_counter_en = 0, loop_counter_rst = 0;

    always @(posedge clk)
        if (rst) state <= IDLE;
        else state <= next_state;

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (KE_enable) next_state = REGISTER;
            REGISTER: next_state = LOAD_PL1;
            LOAD_PL1: next_state = (loop_counter == 13) ? IDLE : LOAD_KEYS;
            LOAD_KEYS: next_state = LOAD_PL1;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            loop_counter_en <= 0;
            en_PL1_reg <= 0;
            loop_counter_rst <= 1;
        end else begin
            loop_counter_en <= 0;
            en_PL1_reg <= 0;
            loop_counter_rst <= 0;
            case (next_state)
                IDLE: loop_counter_rst <= 1;
                LOAD_PL1: en_PL1_reg <= 1;
                LOAD_KEYS: loop_counter_en <= 1; 
            endcase
        end
    end

    always @(posedge clk)
        if (loop_counter_rst || rst) loop_counter <= 0;
        else if (loop_counter_en) loop_counter <= loop_counter + 1;

    function [31:0] rotate_left_8(input [31:0] data);
        rotate_left_8 = {data[23:0], data[31:24]};
    endfunction

    reg [31:0] temp;
    always @(*) begin
        case (loop_counter)
            4'd0:  temp = rotate_left_8(round_keys_1[31:0]);
            4'd1:  temp = round_keys_2[31:0];
            4'd2:  temp = rotate_left_8(round_keys_3[31:0]);
            4'd3:  temp = round_keys_4[31:0];
            4'd4:  temp = rotate_left_8(round_keys_5[31:0]);
            4'd5:  temp = round_keys_6[31:0];
            4'd6:  temp = rotate_left_8(round_keys_7[31:0]);
            4'd7:  temp = round_keys_8[31:0];
            4'd8:  temp = rotate_left_8(round_keys_9[31:0]);
            4'd9:  temp = round_keys_10[31:0];
            4'd10: temp = rotate_left_8(round_keys_11[31:0]);
            4'd11: temp = round_keys_12[31:0];
            4'd12: temp = rotate_left_8(round_keys_13[31:0]);
            default: temp = 32'b0;
        endcase
    end

    reg [31:0] PL1_reg = 0;
    wire [7:0] sbox_out0, sbox_out1, sbox_out2, sbox_out3;

    aes_sbox sbox0 (.sbox_in(temp[7:0]),   .sbox_out(sbox_out0));
    aes_sbox sbox1 (.sbox_in(temp[15:8]),  .sbox_out(sbox_out1));
    aes_sbox sbox2 (.sbox_in(temp[23:16]), .sbox_out(sbox_out2));
    aes_sbox sbox3 (.sbox_in(temp[31:24]), .sbox_out(sbox_out3));

    always @(posedge clk) begin
        if (rst) PL1_reg <= 0;
        else if (en_PL1_reg) PL1_reg <= {sbox_out3, sbox_out2, sbox_out1, sbox_out0};
    end

    wire [31:0] rcon [0:6];
    assign rcon[0] = 32'h01000000;
    assign rcon[1] = 32'h02000000;
    assign rcon[2] = 32'h04000000;
    assign rcon[3] = 32'h08000000;
    assign rcon[4] = 32'h10000000;
    assign rcon[5] = 32'h20000000;
    assign rcon[6] = 32'h40000000;

    always @(posedge clk) begin
        if (rst)
        begin
            round_keys_2 <= 0; round_keys_3 <= 0; round_keys_4 <= 0; round_keys_5 <= 0;
            round_keys_6 <= 0; round_keys_7 <= 0; round_keys_8 <= 0; round_keys_9 <= 0;
            round_keys_10 <= 0; round_keys_11 <= 0; round_keys_12 <= 0;
            round_keys_13 <= 0; round_keys_14 <= 0;
        end
        //end else if (key_enable) begin
        else if (state == LOAD_KEYS) begin
            case (loop_counter)
                4'd0:  round_keys_2  <= transform(round_keys_0, PL1_reg, rcon[0]);
                4'd1:  round_keys_3  <= transform_no_rcon(round_keys_1, PL1_reg);
                4'd2:  round_keys_4  <= transform(round_keys_2, PL1_reg, rcon[1]);
                4'd3:  round_keys_5  <= transform_no_rcon(round_keys_3, PL1_reg);
                4'd4:  round_keys_6  <= transform(round_keys_4, PL1_reg, rcon[2]);
                4'd5:  round_keys_7  <= transform_no_rcon(round_keys_5, PL1_reg);
                4'd6:  round_keys_8  <= transform(round_keys_6, PL1_reg, rcon[3]);
                4'd7:  round_keys_9  <= transform_no_rcon(round_keys_7, PL1_reg);
                4'd8:  round_keys_10 <= transform(round_keys_8, PL1_reg, rcon[4]);
                4'd9:  round_keys_11 <= transform_no_rcon(round_keys_9, PL1_reg);
                4'd10: round_keys_12 <= transform(round_keys_10, PL1_reg, rcon[5]);
                4'd11: round_keys_13 <= transform_no_rcon(round_keys_11, PL1_reg);
                4'd12: round_keys_14 <= transform(round_keys_12, PL1_reg, rcon[6]);
            endcase
        end
    end

    function [127:0] transform;
        input [127:0] prev;
        input [31:0] pl;
        input [31:0] rc;
        reg [31:0] a, b, c, d;
        begin
            a = prev[127:96] ^ pl ^ rc;
            b = prev[95:64]  ^ a;
            c = prev[63:32]  ^ b;
            d = prev[31:0]   ^ c;
            transform = {a, b, c, d};
        end
    endfunction

    function [127:0] transform_no_rcon;
        input [127:0] prev;
        input [31:0] pl;
        reg [31:0] a, b, c, d;
        begin
            a = prev[127:96] ^ pl;
            b = prev[95:64]  ^ a;
            c = prev[63:32]  ^ b;
            d = prev[31:0]   ^ c;
            transform_no_rcon = {a, b, c, d};
        end
    endfunction

endmodule



/*
module TB_KEY_Expansion;
    reg clk = 0;
    reg rst = 0;
	reg KE_enable = 0;
    reg [255:0] key = 0;
    wire [127:0] round_keys [0:14];

    aes_256_key_expansion_pipelined uut (
										.clk(clk),
										.rst(rst),
										.key(key),
										.round_keys(round_keys),
										.KE_enable(KE_enable)
										);

initial 
begin
	clk = 1;
	forever #5 clk = ~clk; // 300 MHz
end
  

    integer i;
    initial begin
        rst = 1;
        key = 256'h0;
        #10;
        rst = 0;
		key = 256'h603deb1015ca71be2b73aef0857d7781_1f352c073b6108d72d9810a30914dff4;
		#100
		KE_enable = 1;
		#10
		KE_enable = 0;
		#10
		key = 256'h603deb1015ca71be2b73aef0857d7784_1f352c073b6108d72d9810a30914dff1;
		
		
		
		#270
		KE_enable = 1;
		#10
		KE_enable = 0;
		

		#10
		key = 256'h603deb1015ca71be2b73aef0857d7781_1f352c073b6108d72d9810a30914dff4;
		
		
		
		#270
		KE_enable = 1;
		#10
		KE_enable = 0;


		end


endmodule */
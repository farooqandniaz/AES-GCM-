/*
 * Module Name  : TB_Full
 * Author       : Farooq Niaz
 * Created      : May 22, 2025
 * Last Modified: May 22, 2025, 13:35
 * Version      : 1.0
 * Description  : Top level GCM testbench driving streaming payloads/AAD and checking timing.
 *                Simulates all possible combinations of the m_axis_tready signal to evaluate 
 *				  the design's response to different output backpressure conditions.
*/

/********************* Include High and Low cycles ***********************/


`timescale 1ns / 1ps

module TB_Full;

  //───────────────────────────────────────────────────────
  // PARAMETERS & I/O
  //───────────────────────────────────────────────────────
  parameter DATA_WIDTH = 128;
  parameter CLK_PERIOD = 10;   // 100 MHz
  localparam MAX_PKTS   = 100; // must exceed any num_packets in test file

  // DUT interface
  reg                    s_clk, s_aresetn;
  reg  [DATA_WIDTH-1:0]  s_axis_tdata;
  reg                    s_axis_tvalid, s_axis_tlast;
  wire                   s_axis_tready;
  wire [DATA_WIDTH-1:0]  m_axis_tdata;
  wire                   m_axis_tvalid, m_axis_tlast;
  reg                    m_axis_tready;

  // plaintext memory
  reg [DATA_WIDTH-1:0] plaintext [0:MAX_PKTS-1];

  // file I/O & runtime vars
  integer test_f, pkt_i, num_packets, code;
  integer i, h, l;
  reg   [DATA_WIDTH-1:0] expected_last,captured_first,captured_last;
  reg   [31:0]           var_bitlen;

  // monitoring variables
  integer tvalid_high;          // count cycles where m_axis_tvalid && m_axis_tready
  reg     last_high_flag;       // detect multi-cycle tlast
  reg     last_duration_error;  // flag for tlast duration violation

  // back-pressure parameters
  integer high_cycles, low_cycles;
  
  parameter expected_first = 128'h8b1df1d6_65d77de5_592f346d_897c6ae8;

  //───────────────────────────────────────────────────────
  // DUT instantiation
  //───────────────────────────────────────────────────────
  GCM_Controller #(
    .DATA_WIDTH(DATA_WIDTH),
    .USER_WIDTH(32)
  ) GCM_DUT (
    .s_clk        (s_clk),
    .s_aresetn    (s_aresetn),
    .s_axis_tdata (s_axis_tdata),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast (s_axis_tlast),
    .s_axis_tready(s_axis_tready),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast (m_axis_tlast),
    .m_axis_tready(m_axis_tready)
  );

  //───────────────────────────────────────────────────────
  // CLOCK GENERATION
  //───────────────────────────────────────────────────────
  initial begin
    s_clk = 0;
    forever #(CLK_PERIOD/2) s_clk = ~s_clk;
  end

  //───────────────────────────────────────────────────────
  // BACK-PRESSURE (varies high_cycles/low_cycles from 1..31)
  //───────────────────────────────────────────────────────
  initial begin
    m_axis_tready = 0;
    wait (s_aresetn);
    @(posedge s_clk);

    forever begin
      // hold ready=1 for high_cycles cycles
      repeat (high_cycles) begin
        @(posedge s_clk);
        m_axis_tready = 1;
      end

      // then hold ready=0 for low_cycles cycles
      repeat (low_cycles) begin
        @(posedge s_clk);
        m_axis_tready = 0;
      end
    end
  end

  //───────────────────────────────────────────────────────
  // MONITOR: count tvalid_high and check tlast duration
  //───────────────────────────────────────────────────────
  initial begin
    tvalid_high        = 0;
    last_high_flag     = 0;
    last_duration_error = 0;

    forever @(posedge s_clk) begin
      if (m_axis_tvalid && m_axis_tready) begin
        tvalid_high = tvalid_high + 1;
      end

      if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
        if (last_high_flag) begin
          last_duration_error = 1;
          $display("***************************************************************");
          $display("Error: m_axis_tlast high for more than one cycle at time %0t", $time);
          $display("***************************************************************");
        end
        last_high_flag = 1;
      end
      else if (m_axis_tvalid && m_axis_tready) begin
        last_high_flag = 0;
      end
    end
  end


 	initial
	begin
		forever @(posedge s_clk) 
		begin
				// wait for 1st-beat to check expected value
				if(m_axis_tvalid && m_axis_tready && (captured_first == 0))
				captured_first = m_axis_tdata;

		end
	end
  //───────────────────────────────────────────────────────
  // MAIN INITIAL: plaintext init + file-driven tests
  //───────────────────────────────────────────────────────
  initial begin
    for (h = 1; h <= 31; h = h + 1) 
	begin
      high_cycles = h;
      for (l = 1; l <= 31; l = l + 1) 
	  begin
        low_cycles = l;

        // 1) Plaintext memory setup (16 unique words, then repeat)
        plaintext[ 0] = 128'h00010203_04050607_08090A0B_0C0D0E0F;
        plaintext[ 1] = 128'h10111213_14151617_18191A1B_1C1D1E1F;
        plaintext[ 2] = 128'h20212223_24252627_28292A2B_2C2D2E2F;
        plaintext[ 3] = 128'h30313233_34353637_38393A3B_3C3D3E3F;
        plaintext[ 4] = 128'h40414243_44454647_48494A4B_4C4D4E4F;
        plaintext[ 5] = 128'h50515253_54555657_58595A5B_5C5D5E5F;
        plaintext[ 6] = 128'h60616263_64656667_68696A6B_6C6D6E6F;
        plaintext[ 7] = 128'h70717273_74757677_78797A7B_7C7D7E7F;
        plaintext[ 8] = 128'h80818283_84858687_88898A8B_8C8D8E8F;
        plaintext[ 9] = 128'h90919293_94959697_98999A9B_9C9D9E9F;
        plaintext[10] = 128'hA0A1A2A3_A4A5A6A7_A8A9AAAB_ACADAEAF;
        plaintext[11] = 128'hB0B1B2B3_B4B5B6B7_B8B9BABB_BCBDBEBF;
        plaintext[12] = 128'hC0C1C2C3_C4C5C6C7_C8C9CACB_CCCDCECF;
        plaintext[13] = 128'hD0D1D2D3_D4D5D6D7_D8D9DADB_DCDDDEDF;
        plaintext[14] = 128'hE0E1E2E3_E4E5E6E7_E8E9EAEB_ECEDEEEF;
        plaintext[15] = 128'hF0F1F2F3_F4F5F6F7_F8F9FAFB_FCFDFEFF;
      
		for (i = 16; i < MAX_PKTS; i = i + 1)
          plaintext[i] = plaintext[i % 16];

        // 2) Open testcases file
        test_f = $fopen("testcases.txt", "r");
        if (test_f == 0) begin
          $display("ERROR: Cannot open testcases.txt (in %m at time %0t)", $time);
          $finish;
        end

        // 3) Process each line: "<num_packets> <expected_last_hex>"
        while (!$feof(test_f)) begin
          code = $fscanf(test_f, "%d  %h\n", num_packets, expected_last);
          if (code != 2)
            continue;

          if (num_packets > MAX_PKTS)
            $fatal("num_packets (%0d) > MAX_PKTS", num_packets);

          // reset monitors
          tvalid_high        = 0;
          last_high_flag     = 0;
          last_duration_error = 0;

          var_bitlen = num_packets * DATA_WIDTH;

          // reset DUT
          s_aresetn     = 0;
          s_axis_tvalid = 0;
          s_axis_tlast  = 0;
          #(2*CLK_PERIOD);
          s_aresetn     = 1;
          #(2*CLK_PERIOD);

          // 1) Send lengths
          @(posedge s_clk);
          s_axis_tdata  = {96'h00000000000000A0_00000000, var_bitlen};
          s_axis_tvalid = 1;
          s_axis_tlast  = 0;
          wait (s_axis_tready);
          @(posedge s_clk);

          // 2) Key (2 beats)
          s_axis_tdata = 128'hFEFFE9928665731C_6D6A8F9467308308; wait(s_axis_tready); @(posedge s_clk);
          s_axis_tdata = 128'hFEFFE9928665731C_6D6A8F9467308308; wait(s_axis_tready); @(posedge s_clk);

          // 3) AAD (2 beats)
          s_axis_tdata = 128'hFEEDFACEDEADBEEF_FEEDFACEDEADBEEF; wait(s_axis_tready); @(posedge s_clk);
          s_axis_tdata = 128'hABADDAD200000000_0000000000000000; wait(s_axis_tready); @(posedge s_clk);

          // 4) IV (1 beat)
          s_axis_tdata = 128'h00000000CAFEBABE_FACEDBADDECAF888; wait(s_axis_tready);

          // 5) Plaintext
          pkt_i = 0;
          s_axis_tvalid = 1;
          while (pkt_i < num_packets) begin
            @(posedge s_clk);
            if (s_axis_tready) begin
              s_axis_tdata = plaintext[pkt_i];
              s_axis_tlast = (pkt_i == num_packets-1);
              pkt_i = pkt_i + 1;
            end
          end
          @(posedge s_clk);
          if (s_axis_tready) begin
            s_axis_tvalid = 0;
            s_axis_tlast  = 0;
          end

/*           // wait for 1st-beat to check expected value
		  wait (m_axis_tvalid && m_axis_tready);
          captured_first = m_axis_tdata; */
		  
		  // 6) Wait for last-beat out
          wait (m_axis_tvalid && m_axis_tready && m_axis_tlast);
          captured_last = m_axis_tdata;

		  
		  // 7) Report
          @(posedge s_clk);
         // $display("num_packets = %0d, high_cycles = %0d, low_cycles = %0d",num_packets, high_cycles, low_cycles);

          
			if (tvalid_high != num_packets + 1) 
			begin
			$display("  ERROR: tvalid_high = %0d, expected = %0d",tvalid_high, num_packets + 1);
			$display("num_packets = %0d, high_cycles = %0d, low_cycles = %0d",num_packets, high_cycles, low_cycles);
  			end

          if (captured_last != expected_last) 
		  begin
            $display("  ERROR: captured_last = %h, expected_last = %h",
                     captured_last, expected_last);
			$display("num_packets = %0d, high_cycles = %0d, low_cycles = %0d",num_packets, high_cycles, low_cycles);
 
          end 
          if (captured_first != expected_first) 
		  begin
            $display("  ERROR: captured_first = %h, expected_first = %h",
                     captured_first, expected_first);
		  $display("num_packets = %0d, high_cycles = %0d, low_cycles = %0d",num_packets, high_cycles, low_cycles);
 
          end 
/*		  else  $display("  PASS: captured_last matches expected_last"); */
          

          if (last_duration_error) begin
            $display("  ERROR: m_axis_tlast was high >1 valid-ready cycle");
			$display("num_packets = %0d, high_cycles = %0d, low_cycles = %0d",num_packets, high_cycles, low_cycles);

          end
        end

        $fclose(test_f);
      end
	  $display("high_cycles = %0d",high_cycles);

    end

    #100 $stop;
  end

endmodule


/*************************************************************************/







`timescale 1ns / 1ps

module TB;

  //───────────────────────────────────────────────────────
  // PARAMETERS & I/O
  //───────────────────────────────────────────────────────
  parameter DATA_WIDTH = 128;
  parameter CLK_PERIOD = 10;   		// 100 MHz
  parameter REPEAT_DELAY = 2;  		// used to control s_axis_tvalid signal
  localparam MAX_PKTS   = 100; 		// must exceed any num_packets in test file
  localparam MAX_TEST_CASES = 90;   // No of packets that needs to be simulated maximum value is 90
  localparam LOOP_SIZE = 31;         // this loop will traverse from 1 to 31  
  
  parameter expected_first = 128'h8b1df1d6_65d77de5_592f346d_897c6ae8;

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
  reg [DATA_WIDTH-1:0] AUTH_TAG[0:89];
              


  // file I/O & runtime vars
  //integer test_counter = MAX_TEST_CASES - 1;    // for complete run set this to 0 
  integer test_counter = 0;    // for complete run set this to 0 
  
  integer test_f, pkt_i, num_packets, code;

  reg [DATA_WIDTH-1:0] expected_last = 0;
  reg [DATA_WIDTH-1:0] captured_first = 0;
  reg [DATA_WIDTH-1:0] captured_last = 0;
  reg [31:0]           var_bitlen = 0;

  // New variables for monitoring
  integer tvalid_high;       // Count cycles where m_axis_tvalid && m_axis_tready
  integer high_cycles = 0;
  integer low_cycles  = 0;
  integer high_s = 0,low_s = 0;
  reg     last_high_flag;    // Flag to detect m_axis_tlast duration
  reg     last_duration_error; // Flag for m_axis_tlast duration violation

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
  // CLOCK
  //───────────────────────────────────────────────────────
  initial begin
    s_clk = 0;
    forever #(CLK_PERIOD/2) s_clk = ~s_clk;
  end

  //───────────────────────────────────────────────────────
  // BACK-PRESSURE
  //───────────────────────────────────────────────────────
  initial begin
    m_axis_tready = 0;
    wait (s_aresetn);
    @(posedge s_clk);
    forever begin						//1-0 ok now testing following which is not working
      repeat (1) @(posedge s_clk) m_axis_tready <= 1;
      repeat (1) @(posedge s_clk) m_axis_tready <= 1;
    end
//	 m_axis_tready = 1;
  end

  //───────────────────────────────────────────────────────
  // MONITOR: Count tvalid_high cycles and check m_axis_tlast duration
  //───────────────────────────────────────────────────────
  initial 
  begin
    tvalid_high = 0;
    last_high_flag = 0;
    last_duration_error = 0;

    forever @(posedge s_clk) 
	begin
      // Count cycles where m_axis_tvalid and m_axis_tready are high
      if (m_axis_tvalid && m_axis_tready) begin
        tvalid_high = tvalid_high + 1;
      end

      // Check m_axis_tlast duration
      if (m_axis_tvalid && m_axis_tready && m_axis_tlast) begin
        if (last_high_flag) begin
          // m_axis_tlast was high in the previous valid-ready cycle
          // m_axis_tlast was high in the previous valid-ready cycle
          last_duration_error = 1;
          $display("*********************************************************************", $time);
          $display("Error: m_axis_tlast high for more than one cycle at time %0t", $time);
          $display("*********************************************************************", $time);
        end
        last_high_flag = 1;
      end else if (m_axis_tvalid && m_axis_tready) begin
        // Reset flag when valid-ready cycle occurs without tlast
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
			
/* 				//---------------------------------------------------
				// 6) Wait for last-beat and capture it
				//---------------------------------------------------
				if(m_axis_tvalid && m_axis_tready && m_axis_tlast)
				captured_last = m_axis_tdata; */
		end
	end
  //───────────────────────────────────────────────────────
  // MAIN INITIAL: plaintext init + file-driven tests
  //───────────────────────────────────────────────────────
	integer i;	  
	initial 
	begin
		for (high_s = 1; high_s <= LOOP_SIZE; high_s = high_s + 1)
		begin	
			for (low_s = 1; low_s <= LOOP_SIZE; low_s = low_s + 1)
			begin
				//$display("Testing tvalid High cycles: %0d :: tvalid_low_cycles: %0d",high_s,low_s);
			
			  //───────────────────────────────────────────────────────
			  // CALCULATED AUTHENTICATION TAGS
			  //───────────────────────────────────────────────────────
				AUTH_TAG[0]  = 128'h9F9A4E3A49120494D7F7C626A0A51DAD;
				AUTH_TAG[1]  = 128'h2F694A124C4B36A49FA1CE448CF742F1;
				AUTH_TAG[2]  = 128'hA55479EA6689C0F9638E308CB190D7B6;
				AUTH_TAG[3]  = 128'h1197FEB0CC3FFC9FFCB253C213640F2E;
				AUTH_TAG[4]  = 128'h61B1217F461B6D5012F41E61F5FFB5ED;
				AUTH_TAG[5]  = 128'hF23B021A7B2567F475F081E114A254EA;
				AUTH_TAG[6]  = 128'h4DC8648C743B05D840DA17CF7389962E;
				AUTH_TAG[7]  = 128'hF13BFD6F9B0302D13DD3541C4387732C;
				AUTH_TAG[8]  = 128'h1D35746EBB4F8DFB8D921F896729C64F;
				AUTH_TAG[9]  = 128'h654884DBA08D389AC134B3214B433F6A;
				AUTH_TAG[10] = 128'h433AB0E1459491EC94B798486F3C5502;
				AUTH_TAG[11] = 128'h76F86D60B4FBD9C13D398888ED43C1A1;
				AUTH_TAG[12] = 128'h5B67A359F66E79703B81BE8BB023D92C;
				AUTH_TAG[13] = 128'h3403188D4369FD9EFD133E66BD96D937;
				AUTH_TAG[14] = 128'hAA2C908EB4BC34C6F555F4CDBE9258D6;
				AUTH_TAG[15] = 128'hB3ABCAB93457AE9E68F3E21814EC9241;
				AUTH_TAG[16] = 128'hB0CD420373708E73284E6FAC67D4BB27;
				AUTH_TAG[17] = 128'h2A2AEBA701A3830910DC704B7CD7B6D1;
				AUTH_TAG[18] = 128'h6CDEA214528465F500E67B9B4AE86AD9;
				AUTH_TAG[19] = 128'h68E2D4D09F30FB97552A4E296AF267D5;
				AUTH_TAG[20] = 128'hF7FBE001EC396A7822DBB3CCA968F8EA;
				AUTH_TAG[21] = 128'hBB49A18B854E0DFC922620691A82B27F;
				AUTH_TAG[22] = 128'hF7DB2890E4314DC17D05AC15F88FDD1F;
				AUTH_TAG[23] = 128'h2C2F6C7DA9DA7421CC6C61B7584EB934;
				AUTH_TAG[24] = 128'hA6C448B06AE6652AD06FE46DA08CEEB7;
				AUTH_TAG[25] = 128'h5A39E7AE2B8BC2C76EF396EF592A85DF;
				AUTH_TAG[26] = 128'h780438782691543F1BAD92838BC4A6EF;
				AUTH_TAG[27] = 128'h55921B446C6899597C28CB4477C55371;
				AUTH_TAG[28] = 128'hE36429C2D3485DB5366D4F15614A5FB7;
				AUTH_TAG[29] = 128'h3615848B4061D826F718D31008F97BA7;
				AUTH_TAG[30] = 128'hE792A6861BDE64D4C4F3962F7ED7664A;
				AUTH_TAG[31] = 128'h3AC4A5517B3555755B360F0C1C78D58B;
				AUTH_TAG[32] = 128'hBA485FDA2654BDF5DA0F6A3555044EE0;
				AUTH_TAG[33] = 128'hDE23BB511251374682CF47922CAF207D;
				AUTH_TAG[34] = 128'h634602FDA427A8B1F990C01E43819564;
				AUTH_TAG[35] = 128'h1EFFDE3530178CDA8EF88090112BD845;
				AUTH_TAG[36] = 128'hD44C697ECD1FD50C9A979AF9EB2871E4;
				AUTH_TAG[37] = 128'h24CEC83A0D47F4B65D7CF0A9ED046D74;
				AUTH_TAG[38] = 128'h2DE3ADACCC13503D7BBA0B9E77B432D0;
				AUTH_TAG[39] = 128'h43E7F324DD744982AFFC246477AE4228;
				AUTH_TAG[40] = 128'h7F9F052E30285925DEAF6A1A15CB8EAB;
				AUTH_TAG[41] = 128'h08C2A2B6623673E7C0002A7D6C76650D;
				AUTH_TAG[42] = 128'h6639736B2983445714F00C1C49D1E170;
				AUTH_TAG[43] = 128'hE92C04CBC0F77BE8EAC337161058F66A;
				AUTH_TAG[44] = 128'h3D834749817444F3868367E85C82C394;
				AUTH_TAG[45] = 128'hF109E0579B764F6BC37F00A73D576E05;
				AUTH_TAG[46] = 128'h4F73F844182D96E815C87594DA5CC8C3;
				AUTH_TAG[47] = 128'h881D84682B4FFBCD7023276535B26F14;
				AUTH_TAG[48] = 128'hF6B2F9362F87D4DB81A210C29E585EAB;
				AUTH_TAG[49] = 128'h69AD351D71809AC2E0EAEB75E0841996;
				AUTH_TAG[50] = 128'hA8D71CD881500C71ACF2A28153E8F4FA;
				AUTH_TAG[51] = 128'h6F16DF377041C6D199091EC47BB6CD0B;
				AUTH_TAG[52] = 128'h79F6FDFA86EC48D1E1963CCF97E0E87A;
				AUTH_TAG[53] = 128'h5AF7D0DAF711E72FE6BB821BCF0825C2;
				AUTH_TAG[54] = 128'hA6116E555FE89EA37012738FEADC704B;
				AUTH_TAG[55] = 128'h970681237FC75F882E56F33BCBE54781;
				AUTH_TAG[56] = 128'hF6F379007A43F542830957A6B378EBA0;
				AUTH_TAG[57] = 128'h2D40647C10AD25E82D5453D80428CA7E;
				AUTH_TAG[58] = 128'h8780B5AB6D16498CFA6E880D07DE8B48;
				AUTH_TAG[59] = 128'h910D69489532F95FAE7E4EC1756A8148;
				AUTH_TAG[60] = 128'hBB9E91DAD8517A9A693B5332ED1274DC;
				AUTH_TAG[61] = 128'hAEAF15FD2445E58932612E4FFCA75784;
				AUTH_TAG[62] = 128'hB00E8BCFC82AD2712910A199E85A7455;
				AUTH_TAG[63] = 128'hED5FE18AF2DAAED7932A10E298F8DA86;
				AUTH_TAG[64] = 128'h8B72F127AAAE9A5B0B7775D3FA82073A;
				AUTH_TAG[65] = 128'hC70CEDFC554746799207DE72CDA94097;
				AUTH_TAG[66] = 128'h1416FE8E37A490B45AA3E549E8B99487;
				AUTH_TAG[67] = 128'h1760FA70E1D9686D89941C2B90A678A0;
				AUTH_TAG[68] = 128'hF3F24E9B422C65F1FF375BE3D348C5DF;
				AUTH_TAG[69] = 128'h3BACF5AD2EA717B57CD224E97891CD64;
				AUTH_TAG[70] = 128'h09F4D6A5CA97316CFF070FB050622F6C;
				AUTH_TAG[71] = 128'h5D5D94C55029DB5A64875E93EB50A8DE;
				AUTH_TAG[72] = 128'hC43AA96971BE4B9272F5B96FFB21A1AC;
				AUTH_TAG[73] = 128'hDD463A29C65D2A36F4F4FEBEA48D5DEA;
				AUTH_TAG[74] = 128'h4690527E2A71027B8903A166D42E52B7;
				AUTH_TAG[75] = 128'h15652C96100C9CA5E30949F5F4315465;
				AUTH_TAG[76] = 128'hF6800CD7560AEDDB3DEEF8660D00B433;
				AUTH_TAG[77] = 128'hC750B63838E00B13A1CBF35A815E0316;
				AUTH_TAG[78] = 128'h3B376304D62DE9A42D3AC88280F6D716;
				AUTH_TAG[79] = 128'h9047CDB92D860F0E2CEB267CBD3D7FB9;
				AUTH_TAG[80] = 128'h3FB53FC9C41A6D6B48EA2C413B376D68;
				AUTH_TAG[81] = 128'h9E4F0CAB02ABDB54CA713CDDAED4EAC2;
				AUTH_TAG[82] = 128'h829A4AE1D6A58064B7A6F3762A0A5C33;
				AUTH_TAG[83] = 128'h17D8AA3F1080066ADCB1F8FB684AA0EF;
				AUTH_TAG[84] = 128'hFBD9A67D6121B7B6A1C019F549A1FFBE;
				AUTH_TAG[85] = 128'h582585C4B5CDF61B3720080B9B262079;
				AUTH_TAG[86] = 128'hA3CE48D270AF350AC317B4C0FF8DCB13;
				AUTH_TAG[87] = 128'h43ACB3834758FAB0B0423C042FC85D35;
				AUTH_TAG[88] = 128'h71599E42D3D45E81FBD809E14D400559;
				AUTH_TAG[89] = 128'hF02420C4E41491AEC122C24A81913383;		
				
		  //───────────────────────────────────────────────────────
		  // PLAIN TEXT DATA
		  //───────────────────────────────────────────────────────

				// 1) Plaintext memory setup: first 16 unique entries  // NIST Test case 16
		/*      plaintext[0] = 128'hd9313225f88406e5a55909c5aff5269a;
				plaintext[1] = 128'h86a7a9531534f7da2e4c303d8a318a72;
				plaintext[2] = 128'h1c3c0c95956809532fcf0e2449a6b525;
				plaintext[3] = 128'hb16aedf5aa0de657ba637b3900000000; */

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
			
				// 2) Repeat those 16 to fill the rest
				for (i = 16; i < MAX_PKTS; i = i + 1)
				plaintext[i] = plaintext[i % 16];	
			
				test_counter = 0;
	//			test_counter = MAX_TEST_CASES -1;
				// 4) For each line "<num_packets> <expected_last_hex>"
				while (test_counter != MAX_TEST_CASES) 
				begin
					
					num_packets = test_counter + 1;
					expected_last = AUTH_TAG[test_counter];
					
					// sanity
					if (num_packets > MAX_PKTS)
					$display("num_packets (%0d) > MAX_PKTS", num_packets);
					
					// Reset monitoring variables for each test case
					tvalid_high = 0;
					last_high_flag = 0;
					last_duration_error = 0;
					
					// compute bit-length for ciphertext
					var_bitlen = num_packets * DATA_WIDTH;
					
					//---------------------------------------------------
					// reset DUT & control signals
					//---------------------------------------------------
					s_aresetn     = 0;
					s_axis_tvalid = 0;
					s_axis_tlast  = 0;
					#(2*CLK_PERIOD);
					s_aresetn     = 1;
					#(2*CLK_PERIOD);
					
					//---------------------------------------------------
					// 1) Send GCM length (lenA=160, lenC=var_bitlen)
					//---------------------------------------------------
					@(posedge s_clk);
					s_axis_tdata  = {96'h00000000000000A0_00000000, var_bitlen};
		//			s_axis_tdata  = {96'h00000000000000A0_00000000000001E0; //NIST Test case 16
					s_axis_tvalid = 1;
					s_axis_tlast  = 0;
					wait (s_axis_tready);
					@(posedge s_clk);
					
					//---------------------------------------------------
					// 2) Send 256-bit key (2 × 128-bit beats)
					//---------------------------------------------------
					s_axis_tdata = 128'hFEFFE9928665731C_6D6A8F9467308308; s_axis_tvalid = 1; wait(s_axis_tready); @(posedge s_clk);
					s_axis_tdata = 128'hFEFFE9928665731C_6D6A8F9467308308; s_axis_tvalid = 0; wait(s_axis_tready); @(posedge s_clk);
					s_axis_tdata = 128'hFEFFE9928665731C_6D6A8F9467308308; s_axis_tvalid = 1; wait(s_axis_tready); @(posedge s_clk);
					
					//---------------------------------------------------
					// 3) Send AAD (2 × 128-bit beats)
					//---------------------------------------------------
		/* 			s_axis_tvalid = 0;
					
					repeat(REPEAT_DELAY)
					@ (posedge s_clk); */
					
					s_axis_tdata = 128'hFEEDFACEDEADBEEF_FEEDFACEDEADBEEF; s_axis_tvalid = 1; wait(s_axis_tready); @(posedge s_clk);
					s_axis_tdata = 128'hABADDAD200000000_0000000000000000; s_axis_tvalid = 0; wait(s_axis_tready); @(posedge s_clk);
					s_axis_tdata = 128'hABADDAD200000000_0000000000000000; s_axis_tvalid = 1; wait(s_axis_tready); @(posedge s_clk);
					
					//---------------------------------------------------
					// 4) Send IV (1 × 128-bit beat)
					//---------------------------------------------------
					s_axis_tdata = 128'h00000000CAFEBABE_FACEDBADDECAF888; s_axis_tvalid = 1; 

					
					//---------------------------------------------------
					// 5) Drive plaintext stream modified
					//---------------------------------------------------
					pkt_i = 0;
					high_cycles = 0;
					low_cycles  = 0;				

					while (pkt_i < num_packets) 
					begin
					  wait(s_axis_tready);
					  @(posedge s_clk);
					  // Randomize s_axis_tvalid (pseudo-random or fixed pattern)
		//			  if ($urandom_range(0, 1)) begin
					  if (high_cycles != high_s) 
					  begin
						s_axis_tvalid = 1;
						high_cycles = high_cycles + 1;
					  end else if(low_cycles != low_s)
					  begin
						s_axis_tvalid = 0;
						low_cycles = low_cycles + 1;
						continue;  // Skip this cycle (no data driven)
					  end else 
					  begin
						high_cycles = 0;
						low_cycles  = 0;
						s_axis_tvalid = 0;
					  end

					  // Only transmit when both valid and ready
					  if (s_axis_tvalid && s_axis_tready) begin
						s_axis_tdata = plaintext[pkt_i];
						s_axis_tlast = (pkt_i == num_packets - 1);
						pkt_i = pkt_i + 1;
					  end
					end

					// After loop, clean up valid/last
					@(posedge s_clk);
					s_axis_tvalid = 0;
					
					wait(s_axis_tready);
					@(posedge s_clk)
					s_axis_tlast  = 0;

					////////////////////// modified code ends here ///////////////////
				
		/* 			// wait for 1st-beat to check expected value
					@(posedge s_clk);
					wait (m_axis_tvalid && m_axis_tready);
					captured_first = m_axis_tdata;
		*/		
					//---------------------------------------------------
					// 6) Wait for last-beat and capture it
					//---------------------------------------------------
					wait (m_axis_tvalid && m_axis_tready && m_axis_tlast);
					captured_last = m_axis_tdata; 
				
					//---------------------------------------------------
					// 7) PASS/FAIL and report tvalid_high
					//---------------------------------------------------
					@(posedge s_clk);
					/* $display("Test case with num_packets=%0d:", num_packets); */
					if (tvalid_high != num_packets + 1) begin
					$display("  Error: i=%0d, expected=%0d", tvalid_high, num_packets + 1);
					end /* else begin
					$display("  tvalid_high=%0d (matches expected %0d)", tvalid_high, num_packets + 1);
					end   */
					if (captured_last != expected_last) begin
					$display("  Test case %0d Failed: captured_last=%h, expected_last=%h",num_packets, captured_last, expected_last);
					end  else
					begin
					//$display(" %0d Passed",num_packets);
					end
					
					if (captured_first != expected_first) 
					begin
					$display("  ERROR: captured_first = %h, expected_first = %h",		 captured_first, expected_first);
					end 
					
					if (last_duration_error) begin
					$display("  Error: m_axis_tlast was high for more than one valid-ready cycle");
					end /* else begin
					$display("  m_axis_tlast duration check: Passed (high for exactly one valid-ready cycle)");
					end  */
					
					test_counter = test_counter + 1;
				end
			end
			$display("tvalid High cycles %0d: passed ",high_s);
		end	
		#100 $stop;		
	end

endmodule


/* 			//---------------------------------------------------
			// 5) Drive plaintext stream actual
			//---------------------------------------------------
			pkt_i = 0;
			s_axis_tvalid = 1;
			while (pkt_i < num_packets) 
			begin
				@(posedge s_clk);
				if (s_axis_tready) 
				begin
					s_axis_tdata = plaintext[pkt_i];
					s_axis_tlast = (pkt_i == num_packets-1);
					pkt_i = pkt_i + 1;
				end
			end
			@(posedge s_clk);
			if (s_axis_tready) 
			begin
				s_axis_tvalid = 0;
				s_axis_tlast  = 0;
			end */
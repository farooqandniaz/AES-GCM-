
module GCM_Controller	#	(
							parameter DATA_WIDTH = 128, // AXI-Stream data width (e.g., 256 bits)
							//parameter KEEP_WIDTH = DATA_WIDTH/8, // TKEEP width
							parameter USER_WIDTH = 32 // TUSER width, adjust based on QDMA config
							)
							(
							// Clock and reset
							input  wire                  s_clk,
							input  wire                  s_aresetn,
							
							// AXI-Stream Slave Interface (from QDMA to module)
							input  wire [DATA_WIDTH-1:0] s_axis_tdata,
							//input  wire [KEEP_WIDTH-1:0] s_axis_tkeep,
							input  wire                  s_axis_tvalid,
							input  wire                  s_axis_tlast,
							//input  wire [USER_WIDTH-1:0] s_axis_tuser,
							output wire                  s_axis_tready,
							
							// AXI-Stream Master Interface (from module to QDMA)
							output reg [DATA_WIDTH-1:0] m_axis_tdata = 0,
							//output wire [KEEP_WIDTH-1:0] m_axis_tkeep,
							output reg                  m_axis_tvalid = 0,
							output reg					m_axis_tlast = 0,
							//output wire [USER_WIDTH-1:0] m_axis_tuser,
							input  wire                  m_axis_tready
							
                            
							);


wire rst = !s_aresetn;

//output wire [127:0] test

                            
localparam CIPHER_PROCESSING_DELAY = 28;
// State machine parameters
localparam	RESET							= 5'd0,  // RESET State
			READY_LOAD_LENAC 				= 5'd1,  					
			REGISTER_KEY_LOW    			= 5'd2,  // Round Keys 2 to 14 calculated here
			REGISTER_KEY_HIGH				= 5'd3,
			REGISTER_AAD_LOW				= 5'd4,
			REGISTER_AAD_HIGH				= 5'd5,
			LOAD_IV							= 5'd6,
			START_IV_COUNTER				= 5'd7,
			WAIT_AES_LATENCY				= 5'd8,
			WAIT_AES_LATENCY_WAIT   		= 5'd9,
			LOAD_H							= 5'd10,
			LOAD_EKJ0						= 5'd11,
			CALC_X2							= 5'd12, //We are now calculating X2 using AAD high value
			PROCESSING_BUFFER				= 5'd13,	
			PROCESSING_BUFFER_WAIT			= 5'd14,	
			START_DATA_OUT					= 5'd15,
			START_DATA_OUT_WAIT				= 5'd16,
			TWO_P_SECOND_LAST_MULTH			= 5'd17,
			TWO_P_SECOND_LAST_MULTH_WAIT	= 5'd18,
			SECOND_LAST_MULTH				= 5'd19,
			SECOND_LAST_MULTH_WAIT			= 5'd20,
			ONE_P_SECOND_LAST_MULTH			= 5'd21,
			ONE_P_SECOND_LAST_MULTH_WAIT	= 5'd22,
			SEND_LAST_CT					= 5'd23,
			SEND_LAST_CT_WAIT				= 5'd24,
			AUTH_TAG						= 5'd25;


//State Machine control Signals	

reg [4:0] state = 		0;
reg [4:0] next_state = 	0;


reg load_key_0					= 0;	//This signal will enable loading least significant 128 bits of 256bits key			
reg load_key_1					= 0;	//This signal will enable loading most significant 128 bits of 256bits key
reg enable_key_expansion		= 0;	//This signal will enable key expansion module
reg AES_en 	  					= 0;	//This signal will enable AES module 		
reg reset_all_reg				= 0;	//This signal will reset all submodules in READY_AND_LOAD_LENA&C state				
reg load_H_en					= 0;	//This signal will enable loading of H calculated after Ek(0^128)
reg load_Auth_data_low_en		= 0;	//This signal will enable loading of lower 128 bits of AAD data to its register
reg load_Auth_data_high_en		= 0;	//This signal will enable loading of highier 128 AAD data to its register
reg load_lenA_lenC_en			= 0;	//This signal will enable loading length of AAD and no of plain text bytes
reg [1:0] mult_H_mux_sel_b		= 0;	//Mux selection signal for calculating GHASH 0-AAD,1-cipher_text,2-lenA_lenC 
reg load_IV_en					= 0;	//This signal will load 96bits IV to IV register
reg IV_counter_en				= 0;
reg wait_counter_en				= 0;	//This will enable the WAIT_AES_LATENCY wait_counter
reg AES_input_all_zero			= 0;
reg load_counter0_enc_text_en	= 0;
reg [DATA_WIDTH-1:0] H 			= 0;
reg auth_tag_en					= 0;

    
reg [31:0]wait_counter          = 0;     
reg s_axis_frame_end			= 0;	//A signal to mention that frame has ended
reg s_axis_frame_end_buff		= 0;	//A delay signal to mention that frame has ended
reg wait_counter_rst 			= 0;

reg load_EKJ0_en				= 0;
reg s_axis_tready_reg			= 0;
reg single_packet_flag_s15      = 0;

reg multH_reg_en_flag_s21       = 0;
reg m_axis_tdata_flag           = 0;
reg m_axis_tvalid_en            = 0;
reg m_axis_tready_based_freeze	= 0;
reg s_axis_tvalid_based_freeze	= 0;
reg s_axis_tvalid_flag  = 0;
reg back_pressure_control_reg   = 0; 


// Declaration of 1920-bit flat round key wire
wire [15*128-1:0] round_keys_flat;


wire [DATA_WIDTH-1:0] enc_text;
wire [DATA_WIDTH-1:0] mult_H;
reg  [DATA_WIDTH-1:0] mult_H_reg = 0;
wire [DATA_WIDTH-1:0] delayed_tdata;
wire [DATA_WIDTH-1:0] b [0:3];			//GHash input either AAD low or AAD high or X or x|lenA|lenC
wire [DATA_WIDTH-1:0] a [0:1];			//GHASH input either EK(IV=0) or H
wire [DATA_WIDTH-1:0] cipher_text = delayed_tdata ^ enc_text ;


//This 4 byte counter will be appended with IV 
reg [31:0] IV_counter = 0;
reg [DATA_WIDTH-1:0] lenA_lenC = 0;
reg [DATA_WIDTH-1:0] Auth_data_low = 0;
reg [DATA_WIDTH-1:0] Auth_data_high = 0;
reg [DATA_WIDTH-1:0] EKJ0 = 0;
reg [DATA_WIDTH-1:0] counter0_enc_text= 0;
reg [DATA_WIDTH-1:0] lenc_mask_reg= 0;
reg [DATA_WIDTH-1:0] m_axis_tdata_buf= 0;
reg [DATA_WIDTH-1-32:0] IV = 0;			//IV is a 96 bits value


reg trig_in=0;
		 
// State transition (synchronous)
always @(posedge s_clk) 
    if (rst)
        state <= RESET;
    else 
        state <= next_state;


// Next state logic (combinational)
always @(*) 
		begin
			next_state = state;

			case (state)
/* 0 */		RESET:															next_state = READY_LOAD_LENAC;
//======	===============================================================================================================
/* 1 */		READY_LOAD_LENAC: 			if (s_axis_tvalid == 1)				next_state = REGISTER_KEY_LOW;                                   // Every Round keys is calculated in 2 clock cycles
//======	===============================================================================================================
/* 2 */		REGISTER_KEY_LOW:    		if (s_axis_tvalid == 1)				next_state = REGISTER_KEY_HIGH;
//======	===============================================================================================================
/* 3 */		REGISTER_KEY_HIGH:			if (s_axis_tvalid == 1)				next_state = REGISTER_AAD_LOW;
//======	===============================================================================================================
/* 4 */		REGISTER_AAD_LOW:			if (s_axis_tvalid == 1)				next_state = REGISTER_AAD_HIGH;
//======	===============================================================================================================
/* 5 */		REGISTER_AAD_HIGH:			if (s_axis_tvalid == 1)				next_state = LOAD_IV;
//======	===============================================================================================================
/* 6 */		LOAD_IV:					if (s_axis_tvalid == 1)				next_state = START_IV_COUNTER;
//======	===============================================================================================================
/* 7 */		START_IV_COUNTER:			if (s_axis_tvalid == 1)				next_state = WAIT_AES_LATENCY;
//======	===============================================================================================================
/* 8 */		WAIT_AES_LATENCY:			if ((wait_counter == CIPHER_PROCESSING_DELAY-3) && (s_axis_tvalid ==1 | s_axis_frame_end))	
																			next_state = LOAD_H;				//AES takes 28 cycles to complete
																			
										else if((wait_counter != CIPHER_PROCESSING_DELAY-3))
																			next_state = WAIT_AES_LATENCY;
																			
										else                                next_state = WAIT_AES_LATENCY_WAIT; 
//======	===============================================================================================================
/* 9 */		WAIT_AES_LATENCY_WAIT:		if ((wait_counter == CIPHER_PROCESSING_DELAY-3) && (s_axis_tvalid ==1 | s_axis_frame_end))	
																			next_state = LOAD_H;				//AES takes 28 cycles to complete
//======	===============================================================================================================
																														//Here wait counter is taking 27 cycles 
																														//but since counter enable also takes one cycle which makes whole tp equal to 28 cycles
																														//Therefore we have kept wait_counter == CIPHER_PROCESSING_DELAY is 25 to move to next transition
/* 10 */	LOAD_H:		    			if (s_axis_tvalid == 1 | s_axis_frame_end)
																			next_state = LOAD_EKJ0;  			//At this state we have calculated H, 
//======	===============================================================================================================
/* 11*/		LOAD_EKJ0:		    		if (s_axis_tvalid == 1 | s_axis_frame_end)
																			next_state = CALC_X2; 				//EKJ0 is calculated 
//======	===============================================================================================================
/* 12*/		CALC_X2:					if (s_axis_frame_end && IV_counter ==2 )
																			next_state = ONE_P_SECOND_LAST_MULTH;	//First packet of CT is ready in this state
										else if (s_axis_tvalid == 1 | s_axis_frame_end) 
																			next_state = PROCESSING_BUFFER;		
//======	===============================================================================================================
/* 13*/		PROCESSING_BUFFER:			if (s_axis_frame_end && IV_counter == 3 && m_axis_tready == 0)	
																			next_state = PROCESSING_BUFFER_WAIT; //if we have only 128 bits or less data to encrypt
										else if (s_axis_frame_end && IV_counter == 3 && m_axis_tready == 1)	
																			next_state = TWO_P_SECOND_LAST_MULTH;//if we have only 129 bits to 256 bits data to encrypt
										else if (s_axis_tvalid == 1 | (s_axis_frame_end && IV_counter != 2))
																			next_state = START_DATA_OUT;		//if data to encrypt is more than 128 bits
//======	===============================================================================================================
/* 14*/		PROCESSING_BUFFER_WAIT:		if (s_axis_frame_end && IV_counter == 3 && m_axis_tready == 0)	
																			next_state = PROCESSING_BUFFER_WAIT; //if we have only 128 bits or less data to encrypt
										else if (s_axis_frame_end && IV_counter == 3 && m_axis_tready == 1)	
																			next_state = TWO_P_SECOND_LAST_MULTH;//if we have only 129 bits to 256 bits data to encrypt
										else if (s_axis_tvalid == 1 | (s_axis_frame_end && IV_counter >= 4))
																			next_state = START_DATA_OUT;		//if data to encrypt is more than 256 bits
//======	================================================================================================================
/* 15*/		START_DATA_OUT:		    		if ((wait_counter == IV_counter-1) & (m_axis_tready == 1))
																			next_state = SECOND_LAST_MULTH;
																			
											else if(s_axis_tvalid ==1 | s_axis_frame_end)
																			next_state = START_DATA_OUT_WAIT;
											else 															
																			next_state = START_DATA_OUT;
//======	================================================================================================================
/* 16*/		START_DATA_OUT_WAIT:	   		if ((wait_counter == IV_counter-1) & (m_axis_tready == 1))
																				next_state = SECOND_LAST_MULTH;
//======	================================================================================================================
/* 17*/		TWO_P_SECOND_LAST_MULTH:		if (m_axis_tready == 1)				next_state = SEND_LAST_CT;
											else								next_state = TWO_P_SECOND_LAST_MULTH_WAIT;
//======	================================================================================================================
/* 18*/		TWO_P_SECOND_LAST_MULTH_WAIT:	if (m_axis_tready == 1)				next_state = SEND_LAST_CT; 
//======	================================================================================================================
/* 19*/		SECOND_LAST_MULTH:				if (m_axis_tready == 1)				next_state = SEND_LAST_CT;
											else								next_state = SECOND_LAST_MULTH_WAIT;
//======	================================================================================================================
/* 20*/		SECOND_LAST_MULTH_WAIT:			if (m_axis_tready == 1)				next_state = SEND_LAST_CT; 
//======	================================================================================================================
/* 21*/		ONE_P_SECOND_LAST_MULTH:		if (m_axis_tready == 1)				next_state = SEND_LAST_CT;
											else								next_state = ONE_P_SECOND_LAST_MULTH_WAIT;
//======	================================================================================================================
/* 22*/		ONE_P_SECOND_LAST_MULTH_WAIT:	if (m_axis_tready == 1)				next_state = SEND_LAST_CT; 
//======	================================================================================================================
/* 23*/		SEND_LAST_CT:					if (m_axis_tready == 1)	     		next_state = AUTH_TAG;     // this state does not calculate encrypted text
											else								next_state = SEND_LAST_CT_WAIT; 
//======	================================================================================================================
/* 24*/		SEND_LAST_CT_WAIT:				if (m_axis_tready == 1)	     		next_state = AUTH_TAG;     // this state does not calculate encrypted text
//======	================================================================================================================
/* 25*/		AUTH_TAG:			    		if (m_axis_tready == 1)				next_state = RESET;
//======	================================================================================================================
			endcase
		end

    // Control signal updates (synchronous)
    always @(posedge s_clk) 
	    if (rst) 
			begin

			s_axis_tready_reg 			<= 1;
			load_key_0					<= 0;
			load_key_1					<= 0;
			enable_key_expansion		<= 0;
			AES_en 	  					<= 0;
			reset_all_reg				<= 1;
			load_H_en					<= 0;
			load_Auth_data_low_en		<= 0;
			load_Auth_data_high_en		<= 0;
			load_lenA_lenC_en			<= 0;
			mult_H_mux_sel_b			<= 2'd0;
			load_IV_en					<= 0;
			IV_counter_en				<= 0;
			AES_input_all_zero			<= 0;
			auth_tag_en					<= 0;

			single_packet_flag_s15      <= 0;
			m_axis_tdata_flag           <= 0;
		
			multH_reg_en_flag_s21       <= 0;
			wait_counter_en				<= 0;
			wait_counter_rst 			<= 0;
			load_EKJ0_en				<= 0;
			m_axis_tvalid_en				<= 0;
			m_axis_tlast				<= 0;
			m_axis_tready_based_freeze	<= 0;
			s_axis_tvalid_based_freeze	<= 0;
			s_axis_tvalid_flag  <= 0;

			end 
		else 
			begin

			s_axis_tready_reg	 		<= 1;
			load_key_0					<= 0;
			load_key_1					<= 0;
			enable_key_expansion		<= 0;
			AES_en 	  					<= 0;
			reset_all_reg				<= 0;
			load_H_en					<= 0;
			load_Auth_data_low_en		<= 0;
			load_Auth_data_high_en		<= 0;
			load_lenA_lenC_en			<= 0;
			mult_H_mux_sel_b			<= 2'd0;   
			load_IV_en					<= 0;
			IV_counter_en				<= 0;
			AES_input_all_zero			<= 1;
			auth_tag_en					<= 0;

			single_packet_flag_s15      <= 0;

			m_axis_tdata_flag           <= 0;
			multH_reg_en_flag_s21       <= 1;
			wait_counter_en				<= 0;
			wait_counter_rst 			<= 0;
			load_EKJ0_en				<= 0;
			m_axis_tvalid_en				<= 0;
			m_axis_tlast				<= 0;
			m_axis_tready_based_freeze	<= 0;
			s_axis_tvalid_based_freeze	<= 0;
			s_axis_tvalid_flag  <= 0;
				
			case (next_state)	
/* 0 	*/ 	RESET:							begin reset_all_reg <= 1; s_axis_tready_reg <= 0; end		//what about this signal didn't mention it anywhere else
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 1 	*/ 	READY_LOAD_LENAC:				begin load_lenA_lenC_en <= 1; end	
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 2 	*/ 	REGISTER_KEY_LOW:   			begin load_key_0 <= 1;enable_key_expansion <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 3 	*/ 	REGISTER_KEY_HIGH:				begin load_key_1 <= 1;enable_key_expansion <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 4 	*/ 	REGISTER_AAD_LOW:				begin load_Auth_data_low_en <= 1; enable_key_expansion <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 5 	*/ 	REGISTER_AAD_HIGH:				begin load_Auth_data_high_en <= 1; enable_key_expansion <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 6 	*/	LOAD_IV:						begin load_IV_en <= 1; AES_en <=1; enable_key_expansion <= 1; IV_counter_en <= 1;AES_input_all_zero <=0;end		
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 7 	*/	START_IV_COUNTER:				begin AES_en <=1; enable_key_expansion <= 1; IV_counter_en <= 1; end		
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 8 	*/	WAIT_AES_LATENCY:				begin IV_counter_en <= 1; wait_counter_en <= 1; AES_en <=1; enable_key_expansion <= 1;  end		
//--------------------------------------    ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 9 	*/	WAIT_AES_LATENCY_WAIT:			begin IV_counter_en <= 1; wait_counter_en <= 0; AES_en <=1; enable_key_expansion <= 1;  end		
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 10 	*/ 	LOAD_H:							begin IV_counter_en <= 1; AES_en <=1; load_H_en <= 1; wait_counter_rst <= 1'b1;  end	
//--------------------------------------	--------------------------------------------------------------------------------------------------------------
/* 11	*/ 	LOAD_EKJ0:						begin IV_counter_en <= 1; AES_en <=1; load_EKJ0_en <= 1;wait_counter_en <= 1; mult_H_mux_sel_b <= 2'b00;  end	
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 12	*/ 	CALC_X2:						begin IV_counter_en <= 1; AES_en <=1; wait_counter_en <= 1; mult_H_mux_sel_b <= 2'b01;  s_axis_tvalid_based_freeze <= 1; m_axis_tdata_flag <= 1;end	
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 13	*/	PROCESSING_BUFFER:				begin IV_counter_en <= 1; AES_en <=1; mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1; s_axis_tvalid_based_freeze <= 1; single_packet_flag_s15 <=1;m_axis_tdata_flag <= 1;end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 14	*/	PROCESSING_BUFFER_WAIT:			begin IV_counter_en <= 1; AES_en <=1; mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1; s_axis_tvalid_based_freeze <= 1; single_packet_flag_s15 <=1; multH_reg_en_flag_s21 <= 0;end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 15	*/	START_DATA_OUT:					begin IV_counter_en <= 1; AES_en <=1; mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1; s_axis_tvalid_based_freeze <= 1; s_axis_tvalid_flag  <= 1; m_axis_tvalid_en <= 1; m_axis_tready_based_freeze <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 16	*/	START_DATA_OUT_WAIT:			begin IV_counter_en <= 1; AES_en <=1; mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1; s_axis_tvalid_based_freeze <= 1; s_axis_tvalid_flag  <= 1; m_axis_tvalid_en <= 1; m_axis_tready_based_freeze <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 17	*/	TWO_P_SECOND_LAST_MULTH:		begin mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1;	m_axis_tvalid_en <= 1;    end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 18	*/	TWO_P_SECOND_LAST_MULTH_WAIT:	begin mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 0;	m_axis_tvalid_en <= 1;    m_axis_tready_based_freeze <= 1; multH_reg_en_flag_s21 <= 0; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 19	*/	SECOND_LAST_MULTH:				begin mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1;	m_axis_tvalid_en <= 1;   m_axis_tready_based_freeze <= 1; single_packet_flag_s15 <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 20	*/	SECOND_LAST_MULTH_WAIT:			begin mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1;	m_axis_tvalid_en <= 1;    m_axis_tready_based_freeze <= 1; end
//--------------------------------------	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 21	*/	ONE_P_SECOND_LAST_MULTH:		begin mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 1;	 m_axis_tready_based_freeze <= 1; single_packet_flag_s15 <=1; end
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 22	*/	ONE_P_SECOND_LAST_MULTH_WAIT:	begin mult_H_mux_sel_b <= 2'b10;  wait_counter_en <= 0;	 m_axis_tready_based_freeze <= 1; multH_reg_en_flag_s21 <= 0; end
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 23	*/	SEND_LAST_CT:					begin mult_H_mux_sel_b <= 2'b11;  m_axis_tvalid_en <= 1;  auth_tag_en <= 1; m_axis_tready_based_freeze <= 1; end
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 24	*/	SEND_LAST_CT_WAIT:				begin mult_H_mux_sel_b <= 2'b11;  m_axis_tvalid_en <= 1;  auth_tag_en <= 1; m_axis_tready_based_freeze <= 1; end
//------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
/* 25	*/	AUTH_TAG:						begin m_axis_tvalid_en <= 1; m_axis_tlast <= 1; end
			endcase
        end
    
//=======================================================================================================================================================================================================================================


wire back_pressure_control= m_axis_tready_based_freeze ? m_axis_tready : 1'b1;		//This line will freeze AES module when output is not ready to accept data

wire forward_halt = (s_axis_tvalid_based_freeze && (!s_axis_frame_end))? s_axis_tvalid : 1'b1; // this line wil freeze multH reg assignment based upon s_axis_tvalid

always@ (*)		
	if (reset_all_reg)
		m_axis_tvalid <= 0;
	else if (s_axis_tvalid_flag && (!s_axis_frame_end))
		m_axis_tvalid <= s_axis_tvalid ;
	else
		m_axis_tvalid <= m_axis_tvalid_en;

//Detection mechanism to find out that input data frame has ended
//buffering

always@ (posedge s_clk)
	if (reset_all_reg)
		s_axis_frame_end <= 0;
	else if (s_axis_tlast && s_axis_tready)
		s_axis_frame_end <= 1 ;	

	

assign s_axis_tready = s_axis_tready_reg & (!s_axis_frame_end) & back_pressure_control ;
wire enable_flag = (s_axis_tvalid | s_axis_frame_end) & back_pressure_control;   


always@ (posedge s_clk)
	if (reset_all_reg)
		IV_counter <= 0; 
	else if (IV_counter_en && s_axis_tvalid && back_pressure_control & (!s_axis_frame_end)) 	//IV will only increment only in the case if more data is coming and device is also ready to read the data
		IV_counter <= IV_counter + 1;

wire wait_counter_en_write = wait_counter_en && enable_flag;

always@ (posedge s_clk)
	if (reset_all_reg | wait_counter_rst)
		wait_counter <= 0;
	else if (wait_counter_en_write) 
		wait_counter <= wait_counter + 1;
	
always@(posedge s_clk)
if (reset_all_reg)
	H <= 0;
else if (load_H_en &&(s_axis_tvalid | s_axis_frame_end)) 
	H <= enc_text;

always@(posedge s_clk)
if (reset_all_reg)
	lenc_mask_reg <= {128{1'b1}};		//this initial value will not alter any value passing as op2 in ghash128
else if (next_state == SECOND_LAST_MULTH) //SECOND_LAST_MULTH = 5'd14
	lenc_mask_reg <= barrel_shifter128(lenA_lenC[6:0]);			//Least significant 7 bits will generate the masking register to control no. of bits to be passed on to the 2nd last multH call

always@(posedge s_clk)                                    // change
if (reset_all_reg)
	back_pressure_control_reg <= 0;
else 
    back_pressure_control_reg <= back_pressure_control;   // Delay introduced in back pressure control reg to control mult_H_reg

wire multH_reg_en = (state == SEND_LAST_CT) ? back_pressure_control : back_pressure_control_reg;


wire mult_H_reg_write_en =	(multH_reg_en || single_packet_flag_s15 ) 
							&&
							(multH_reg_en_flag_s21) && forward_halt;

always@(posedge s_clk)
if (reset_all_reg)
	mult_H_reg <= 0;
else if (mult_H_reg_write_en )
	mult_H_reg <= mult_H;


//Pipelining to align the results with GHASH Values 
//wire test_pin = (m_axis_tready | m_axis_tdata_flag) && (state != PROCESSING_BUFFER_WAIT) && forward_halt; //&& (next_state != START_DATA_OUT);*/
always@(posedge s_clk)
if (reset_all_reg)
	begin
	m_axis_tdata_buf	<= 0;
	m_axis_tdata		<= 0;
	end
else if ((auth_tag_en == 1) & back_pressure_control) 
	m_axis_tdata  <= mult_H ^ EKJ0;
else if ((m_axis_tready | m_axis_tdata_flag) && (state != PROCESSING_BUFFER_WAIT) && forward_halt)
	begin
	m_axis_tdata_buf  <= cipher_text;
	m_axis_tdata  <= m_axis_tdata_buf & lenc_mask_reg;		//This will mask the last 128 bit LSB to zeros as required in lenC
	end

always@(posedge s_clk)
if (reset_all_reg)
	EKJ0 <= 0;
else if (load_EKJ0_en)
	EKJ0 <= enc_text;


always@(posedge s_clk)
if (reset_all_reg)
	Auth_data_low <= 0;
else if (load_Auth_data_low_en)
	Auth_data_low <= s_axis_tdata;			//128 bits AAD data from computer

always@(posedge s_clk)
if (reset_all_reg)
	Auth_data_high <= 0;
else if (load_Auth_data_high_en)
	Auth_data_high <= s_axis_tdata;			//128 bits AAD data from computer


always@(posedge s_clk)
if (reset_all_reg)
	lenA_lenC <= 0;
else if (load_lenA_lenC_en)
	lenA_lenC <= s_axis_tdata;


always@(posedge s_clk)
if (reset_all_reg)
	IV <= 0;
else if (load_IV_en)
	IV <= s_axis_tdata[DATA_WIDTH -1-32:0];	//IV will be placed in the lower 96 bits of 128 AXI bus

//=======================================================================================================================================================================================================================================
/*  always @(posedge s_clk) 
     if ((s_axis_tvalid && s_axis_tready) || (m_axis_tvalid_en && m_axis_tready))
           trig_in <= 1;
    else //if(s_axis_tvalid==0 || s_axis_tready==0)
           trig_in <=0;  */
		   
		   
assign b[0] = Auth_data_low;	
assign b[1] = Auth_data_high ^ mult_H_reg;	
assign b[2] = (m_axis_tdata_buf & lenc_mask_reg ) ^ mult_H_reg ;
assign b[3] = lenA_lenC ^ mult_H_reg ;

	 


ghash128	GHASH(
				.hash	(mult_H),
				.op1	(H),
				.op2	(b[mult_H_mux_sel_b])
				);
				
				

Buffer#	(
		.DATA_WIDTH(DATA_WIDTH),
		.DELAY_CYCLES(28)
		)
delay_tdata	(
			.clk(s_clk),
			.rst(reset_all_reg),
			.enable(s_axis_tready_reg && enable_flag),
			.data_in(s_axis_tdata),
			.data_out(delayed_tdata)
			);
//assign test = enc_text;	


// Updated AES encryption top-level instance
AES_top AES (
    .enc_text       (enc_text),
    .IV             ({IV, IV_counter} & {128{AES_input_all_zero}}),
    .round_keys_flat(round_keys_flat),  // Updated signal name
    .AES_en         (AES_en & enable_flag),
    .clk            (s_clk),
    .rst            (reset_all_reg)
);

// Updated Key Expansion instance
aes_256_key_expansion_pipelined KE (
    .round_keys_flat(round_keys_flat),  // Updated signal name
    .key            (s_axis_tdata),
    .KE_enable      (enable_key_expansion),
    .load_key_0     (load_key_0),
    .load_key_1     (load_key_1),
    .clk            (s_clk),
    .rst            (reset_all_reg)
);





//------------------------------------------------------------------------------
// Function: barrel_shifter128
// Description:
//   128-bit left barrel shifter as a function.  Shifts data_in left by
//   shift_amt (0…255), producing zeros for any bits shifted in.  If
//   shift_amt ≥ 128, the result is all zeros.
//------------------------------------------------------------------------------

function [127:0] barrel_shifter128;
  input [6:0]  shift_amt;
  reg   [127:0] s0, s1, s2, s3, s4, s5, s6, s7;
  begin
    if(shift_amt == 0)     // I we have only one packet then we need to xor this packet with all one's
		s0 = {128{1'b1}};
	else
		s0 = {128{1'b0}};
    s1 = shift_amt[0] ? { 1'b1 		, s0[127:1]}  : s0;        // << 1
    s2 = shift_amt[1] ? { {2{1'b1}} , s1[127:2]}  : s1;        // << 2
    s3 = shift_amt[2] ? { {4{1'b1}} , s2[127:4]}  : s2;        // << 4
    s4 = shift_amt[3] ? { {8{1'b1}} , s3[127:8]}  : s3;        // << 8
    s5 = shift_amt[4] ? {{16{1'b1}} , s4[127:16]} : s4;        // <<16
    s6 = shift_amt[5] ? {{32{1'b1}} , s5[127:32] }: s5;        // <<32
    s7 = shift_amt[6] ? {{64{1'b1}} , s6[127:64] }: s6;        // <<64

 
    barrel_shifter128 = s7;
  end
endfunction

endmodule



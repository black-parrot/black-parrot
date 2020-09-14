module bp_me_cce_mem_to_axi_wrapper

 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 import bp_cce_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

  // AXI WRITE DATA CHANNEL PARAMS
  , localparam axi_data_width_lp = 64
  , localparam axi_strb_width_lp = axi_data_width_lp/8

  // AXI WRITE/READ ADDRESS CHANNEL PARAMS	
  , localparam axi_id_width_lp   = 1
  , localparam axi_addr_width_lp = 64
  , localparam axi_burst_type_lp = 2'b01                                     //INCR type
  , localparam axi_len_lp        = cce_block_width_p/axi_data_width_lp - 1   //(512/64) - 1 = 7 (but it's 8 transfers since AxLEN+1)
  , localparam axi_size_lp       = 3                                         //8 Bytes, or 64bits, per transfer (this is done in power of 2's)
  //, localparam axi_user_width_lp = 1 
  
  // FIFO depth for PISO and SIPO
  , localparam fifo_els_lp       = cce_block_width_p/axi_data_width_lp       //in most cases, it'll be 512/64 = 8
  )

  ( input 	aclk_i  
  , input 	aresetn_i

  //========================= BP side =========================
  // memory commands from the ME into the axi wrapper
  , input  [cce_mem_msg_width_lp-1:0]  mem_cmd_i
  , input                              mem_cmd_v_i
  , output                             mem_cmd_ready_o

  // memory responses from the axi wrapper into ME
  , output [cce_mem_msg_width_lp-1:0]  mem_resp_o
  , output                             mem_resp_v_o
  , input                              mem_resp_yumi_i
  //===========================================================

  //======================== AXI side =========================
  // GLOBAL SIGNALS
  //, output axi_aclk_o  
  //, output axi_aresetn_o

  // WRITE ADDRESS CHANNEL SIGNALS
  , output [axi_id_width_lp-1:0]        axi_awid_o      //write addr ID    
  , output [axi_addr_width_lp-1:0]      axi_awaddr_o	//write address
  , output [7:0]                        axi_awlen_o     //burst length (# of transfers 0-256)
  , output [2:0]                        axi_awsize_o	//burst size (# of bytes in transfer 0-128)
  , output [1:0]                        axi_awburst_o	//burst type (FIXED, INCR, or WRAP)
  , output [3:0]                        axi_awcache_o	//memory type (write-through, write-back, etc.)
  , output [2:0]                        axi_awprot_o	//protection type (unpriv, secure, etc)
  , output [3:0]                        axi_awqos_o     //QoS (use default 0000 if no QoS scheme)
  , output                              axi_awvalid_o	//master device write addr validity
  , input                               axi_awready_i	//slave device readiness
  //, output                            axi_awlock_o	//lock type (not supported by AXI-4)
  //, output [axi_user_width_lp-1:0]    axi_awuser_o	//user-defined signals (optional, recommended for interconnect)
  //, output [3:0]                      axi_awregion_o	//region identifier (optional)

  // WRITE DATA CHANNEL SIGNALS
  , output [axi_id_width_lp-1:0]        axi_wid_o      //write data ID
  , output [axi_data_width_lp-1:0]      axi_wdata_o    //write data
  , output [axi_strb_width_lp-1:0]      axi_wstrb_o    //write strobes (indicates valid data byte lane)
  , output								axi_wlast_o		//write last (indicates last transfer in a write burst)
  , output								axi_wvalid_o	//master device write validity
  , input								axi_wready_i	//slave device readiness
  //, output [axi_user_width_lp-1:0]	axi_wuser_o		//user-defined signals (optional)

  // WRITE RESPONSE CHANNEL SIGNALS
  , input [axi_id_width_lp-1:0]         axi_bid_i		//slave response ID
  , input [1:0]                         axi_bresp_i     //status of the write transaction (OKAY, EXOKAY, SLVERR, or DECERR)
  , input								axi_bvalid_i	//slave device write reponse validity
  , output 							    axi_bready_o	//master device write response readiness 
   //, input [axi_user_width_lp-1:0]    axi_buser_o 	//user-defined signals (optional)
  
  // READ ADDRESS CHANNEL SIGNALS
  , output [axi_id_width_lp-1:0] 		axi_arid_o		//read addr ID
  , output [axi_addr_width_lp-1:0]		axi_araddr_o	//read address
  , output [7:0]						axi_arlen_o		//burst length (# of transfers 0-256)
  , output [2:0]						axi_arsize_o	//burst size (# of bytes in transfer 0-128)
  , output [1:0]						axi_arburst_o	//burst type (FIXED, INCR, or WRAP)
  , output [3:0]						axi_arcache_o	//memory type (write-through, write-back, etc.)
  , output [2:0]						axi_arprot_o	//protection type (unpriv, secure, etc)
  , output [3:0]						axi_arqos_o		//QoS (use default 0000 if no QoS scheme)
  , output								axi_arvalid_o	//master device read addr validity
  , input 								axi_arready_i	//slave device readiness
  //, output 							axi_arlock_o	//lock type (not supported by AXI-4)
  //, output [axi_user_width_lp-1:0]	axi_aruser_o	//user-defined signals (optional)
  //, output [3:0]						axi_arregion_o  //region identifier (optional)

  // READ DATA CHANNEL SIGNALS
  , input [axi_id_width_lp-1:0]         axi_rid_i		//read data ID
  , input [axi_data_width_lp-1:0]		axi_rdata_i		//read data
  , input [1:0]						    axi_rresp_i		//read response
  , input								axi_rlast_i		//read last
  , input								axi_rvalid_i	//slave device read data validity
  , output								axi_rready_o	//master device read data readiness
  //, input							    axi_ruser_i		//user-defined signals (optional)
  //===========================================================
 );

  // unused wires
  wire unused_0 = axi_rid_i;
  wire unused_1 = axi_bid_i;

  // declaring mem command and response struct type and size
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  bp_cce_mem_msg_s mem_cmd_cast_i, mem_resp_cast_o;

  assign mem_resp_o      = mem_resp_cast_o;
  assign mem_cmd_cast_i  = mem_cmd_i;

  // SIPO and PISO related signals
  Logic							axi_read_sipo_ready_lo;
  logic							axi_read_sipo_v_lo;
  logic [cce_block_width_p-1:0]	axi_read_sipo_data_lo;

  logic							axi_write_piso_ready_lo;
  logic							axi_write_piso_v_lo;
  logic [axi_data_width_lp-1:0]	axi_write_piso_data_lo;

  // Write counter for sending the last bit
  logic [`BSG_SAFE_CLOG2(axi_len_lp)-1:0] axi_awburst_cnt_r, axi_awburst_cnt_n;

  // storing mem_cmd's header for mem_resp's use
  // only accepts changes when mem_cmd is valid and the axi receiver is ready
  bp_cce_mem_msg_header_s mem_cmd_header_r;
  
  bsg_dff_reset_en
   #(.width_p(cce_mem_msg_header_width_lp))
   mem_header_reg
    (.clk_i(aclk_i)
    ,.reset_i(~aresetn_i)
    ,.en_i(mem_cmd_v_i)
    ,.data_i(mem_cmd_i.header)
    ,.data_o(mem_cmd_header_r)
    );

  // Declaring all possible states
  typedef enum logic [3:0] {
  	WAIT,
  	READ_ADDR_SEND,
  	READ_ERR,
  	READ_DONE,
  	WRITE_ADDR_SEND,
  	WRITE_DATA_SEND,
  	WRITE_ERR
  } state_e;

  state_e state_r, state_n;

  // Combinational Logic
  always_comb begin
  
  	// BP side
  	mem_cmd_ready_o			= axi_write_piso_ready_lo;
  	mem_resp_cast_o.header 	= mem_cmd_header_r;
  	mem_resp_cast_o.data 	= axi_read_sipo_data_lo;
  	mem_resp_v_o			= '0;

  	// READ ADDRESS CHANNEL SIGNALS
  	axi_araddr_o 	= '0;
  	axi_arlen_o		= axi_len_lp;
  	axi_arsize_o	= axi_size_lp;
  	axi_arburst_o	= axi_burst_type_lp;
  	axi_arvalid_o 	= '0;
  	axi_arid_o 		= '0;
	axi_arcache_o  	= 4'b0011;	//normal non-cacheable bufferable (recommended for Xilinx IP)
	axi_arprot_o  	= '0; 		//unprivileged access
	axi_arqos_o		= '0;		//no QoS scheme

  	// READ DATA CHANNEL SIGNALS
  	axi_rready_o	= '0;

  	// WRITE ADDRRESS CHANNEL SIGNALS
  	axi_awaddr_o 	= '0;
  	axi_awlen_o		= axi_len_lp;
  	axi_awsize_o 	= axi_size_lp;
  	axi_awburst_o 	= axi_burst_type_lp;
  	axi_awvalid_o 	= '0;
  	axi_awid_o 		= '0;
  	axi_awcache_o	= 4'b0011; 	//normal non-cacheable bufferable (recommended for Xilinx IP)
  	axi_awprot_o  	= '0; 		//unprivileged access
  	axi_awqos_o		= '0;		//no QoS scheme

  	// WRITE DATA CHANNEL SIGNALS
  	axi_wdata_o 	= '0;
  	axi_wstrb_o		= '0;
  	axi_wlast_o		= '0; 
  	axi_wvalid_o 	= '0;
  	axi_wid_o 		= '0;

  	// WRITE RESPONSE CHANNEL SIGNALS
  	axi_bready_o	= '0;

  	case (state_r)
  		WAIT: begin
  			if (mem_cmd_v_i & axi_arready_i & mem_cmd_cast_i.header.msg_type == (e_cce_mem_rd || e_cce_mem_uc_rd || e_cce_mem_pre))
  				state_n = READ_ADDR_SEND;
  			else if (mem_cmd_v_i & axi_awready_i & mem_cmd_cast_i.header.msg_type == (e_cce_mem_wr || e_cce_mem_uc_wr))
  				state_n = WRITE_ADDR_SEND;
  			else
  				state_n = WAIT;
  		end
  		
  		// READ STATES
  		READ_ADDR_SEND: begin
  			// sending read addr signals
  			axi_araddr_o  = {(axi_addr_width_lp - paddr_width_p){1'b0}, mem_cmd_cast_i.header.addr}; //64-bit address with top bits all 0
  			axi_arvalid_o = 1'b1;
  			// sending read data signals
  			axi_rready_o  = axi_read_data_sipo_ready_lo
  			// if read data response is not ok
  			if (axi_rresp_i != '0)
  				state_n = READ_ERR;
  			else if (axi_rlast_i)
  				state_n	= READ_DONE;
  			else
  				state_n = READ_ADDR_SEND;
  		end

  		READ_DONE: begin
  			// bp signals
  			mem_resp_v_o = axi_read_sipo_v_lo;
  			// if mem_resp is ready to accept the data, then return to WAIT
  			if (mem_resp_yumi_i)
  				state_n	= WAIT;
  			else
  				state_n = READ_DONE;
  		end

  		READ_ERR: begin
  			// do something when data read back is not OKAY
  		end

  		// WRITE STATES
  		WRITE_ADDR_SEND: begin
  			// sending write addr signals
  			axi_awaddr_o  = {(axi_addr_width_lp - paddr_width_p){1'b0}, mem_cmd_cast_i.header.addr};
  			axi_awvalid_o = 1'b1;
  			// if the receiving slave device is ready, then proceed to send data
  			if (axi_wready_i)
  				state_n	= WRITE_DATA_SEND;
  			else
  				state_n = WRITE_ADDR_SEND;
  		end

  		WRITE_DATA_SEND: begin
  			// sending write data signals
  			axi_wdata_o 	= axi_read_sipo_data_lo;
  			axi_wstrb_o 	= {axi_strb_width_lp{1'b1}};
  			axi_wvalid_o 	= 1'b1;
  			axi_wlast_o 	= (axi_awburst_cnt_r == axi_awlen_lp);
  			axi_awburst_cnt_n = (axi_wready_i) 
  								? axi_awburst_cnt_r + 1
  								: axi_awburst_cnt_n;
  			// if a valid write response returns not okay, then go to write error state
  			if (axi_bresp_i != '0) & axi_bvalid_i
  				state_n = WRITE_ERR;
  			// else if a valid write response returns OKAY, then go back to wait state
  			else if (axi_bresp_i == '0) & axi_bvalid_i
  				state_n = WAIT;
  		end

  		WRITE_ERR: begin
  			// do something if there is an write error
  		end
  	endcase
  end

  // Sequential Logic
  always_comb @(posedge clk_i) begin
  	if (~aresetn_i) begin
  		state_r	          <= WAIT;
  		axi_awburst_cnt_r <= '0;
  	end
  	else begin
  		state_r           <= state_n;
  		axi_awburst_cnt_r <= axi_awburst_cnt_n;
  	end
  end

  // SIPO for read data
  bsg_serial_in_parallel_out_full 
  	#(.width_p 	(axi_data_width_lp)
  	 ,.els_p 	(fifo_els_lp)
  	 )
  	axi_read_data_sipo
  	(.clk_i 	(aclk_i)
  	,.reset_i 	(~aresetn_i)

  	,.v_i 		(axi_rvalid_i)
  	,.ready_o 	(axi_read_sipo_ready_lo)
  	,.data_i 	(axi_rdata_i)	

  	,.data_o 	(axi_read_sipo_data_lo)
  	,.v_o 		(axi_read_sipo_v_lo)
  	,.yumi_i 	(mem_resp_yumi_i)
  	);

  // PISO for write data
  bsg_parallel_in_serial_out
    #(.width_p 	(axi_data_width_lp)
     ,.els_p 	(fifo_els_lp)
     ) 
    axi_write_data_piso
    (.clk_i 	(aclk_i)
    ,.reset_i	(~aresetn_i)

    ,.valid_i 	(mem_cmd_v_i)
    ,.data_i 	(mem_cmd_cast_i.data)
    ,.ready_o 	(axi_write_piso_ready_lo)

    ,.valid_o	(axi_write_piso_v_lo)
    ,.data_o 	(axi_write_piso_data_lo)
    ,.input 	(axi_wready_i)
    );

endmodule

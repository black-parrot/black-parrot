module bp_mem_to_axi_client

 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_noc_pkg::*;

  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, bp_out)
 
   // AXI WRITE DATA CHANNEL PARAMS
   , parameter  axi_data_width_p             = 64
   , localparam axi_strb_width_lp            = axi_data_width_p/8
   , localparam lg_axi_data_width_in_byte_lp = `BSG_SAFE_CLOG2(axi_data_width_p/8)
 
   // AXI WRITE/READ ADDRESS CHANNEL PARAMS  
   , parameter  axi_device_cnt_p             = 16    //BP supports up to 16 devices
   , parameter  axi_addr_width_p             = 64
   , localparam lg_axi_id_width_lp           = `BSG_SAFE_CLOG2(axi_device_cnt_p)    
   //, localparam axi_user_width_lp = 1 
   )

  (//==================== GLOBAL SIGNALS =======================
   input aclk_i  
   , input aresetn_i
 
   //======================== BP SIDE ==========================
   // client driven memory commands
   , output logic [bp_out_mem_msg_header_width_lp-1:0] mem_cmd_header_o
   , output logic                                     mem_cmd_header_v_o
   , input                                            mem_cmd_header_ready_i
 
   , output logic [axi_data_width_p-1:0]            mem_cmd_data_o
   , output logic                                   mem_cmd_data_v_o
   , input                                          mem_cmd_data_ready_i
 
   // bp driven memory responses
   , input [bp_out_mem_msg_header_width_lp-1:0]     mem_resp_header_i
   , input                                          mem_resp_header_v_i
   , output logic                                   mem_resp_header_ready_o
 
   , input [axi_data_width_p-1:0]                   mem_resp_data_i
   , input                                          mem_resp_data_v_i
   , output logic                                   mem_resp_data_ready_o
 
   //======================= AXI side ==========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [lg_axi_id_width_lp-1:0]         s_axi_awid_i     //write addr ID    
   , input [axi_addr_width_p-1:0]           s_axi_awaddr_i   //write address
   , input [7:0]                            s_axi_awlen_i    //burst length (# of transfers 0-256)
   , input [2:0]                            s_axi_awsize_i   //burst size (# of bytes in transfer 0-128)
   , input [1:0]                            s_axi_awburst_i  //burst type (FIXED, INCR, or WRAP)
   , input [3:0]                            s_axi_awcache_i  //memory type (write-through, write-back, etc.)
   , input [2:0]                            s_axi_awprot_i   //protection type (unpriv, secure, etc)
   , input [3:0]                            s_axi_awqos_i    //QoS (use default 0000 if no QoS scheme)
   , input                                  s_axi_awvalid_i  //master device write addr validity
   , output logic                           s_axi_awready_o  //slave device readiness
   //, input                                s_axi_awlock_i   //lock type (not supported by AXI-4)
   //, input [axi_user_width_lp-1:0]        s_axi_awuser_i   //user-defined signals (optional, recommended for interconnect)
   //, input [3:0]                          s_axi_awregion_i //region identifier (optional)
 
   // WRITE DATA CHANNEL SIGNALS
   , input [lg_axi_id_width_lp-1:0]         s_axi_wid_i      //write data ID
   , input [axi_data_width_p-1:0]           s_axi_wdata_i    //write data
   , input [axi_strb_width_lp-1:0]          s_axi_wstrb_i    //write strobes (indicates valid data byte lane)
   , input                                  s_axi_wlast_i    //write last (indicates last transfer in a write burst)
   , input                                  s_axi_wvalid_i   //master device write validity
   , output logic                           s_axi_wready_o   //slave device readiness
   //, input [axi_user_width_lp-1:0]        s_axi_wuser_i    //user-defined signals (optional)
 
   // WRITE RESPONSE CHANNEL SIGNALS
   , output logic [lg_axi_id_width_lp-1:0]  s_axi_bid_o      //slave response ID
   , output logic [1:0]                     s_axi_bresp_o    //status of the write transaction (OKAY, EXOKAY, SLVERR, or DECERR)
   , output logic                           s_axi_bvalid_o   //slave device write reponse validity
   , input                                  s_axi_bready_i   //master device write response readiness 
   //, output logic [axi_user_width_lp-1:0] s_axi_buser_o    //user-defined signals (optional)
   
   // READ ADDRESS CHANNEL SIGNALS
   , input [lg_axi_id_width_lp-1:0]         s_axi_arid_i     //read addr ID
   , input [axi_addr_width_p-1:0]           s_axi_araddr_i   //read address
   , input [7:0]                            s_axi_arlen_i    //burst length (# of transfers 0-256)
   , input [2:0]                            s_axi_arsize_i   //burst size (# of bytes in transfer 0-128)
   , input [1:0]                            s_axi_arburst_i  //burst type (FIXED, INCR, or WRAP)
   , input [3:0]                            s_axi_arcache_i  //memory type (write-through, write-back, etc.)
   , input [2:0]                            s_axi_arprot_i   //protection type (unpriv, secure, etc)
   , input [3:0]                            s_axi_arqos_i    //QoS (use default 0000 if no QoS scheme)
   , input                                  s_axi_arvalid_i  //master device read addr validity
   , output logic                           s_axi_arready_o  //slave device readiness
   //, input                                s_axi_arlock_i   //lock type (not supported by AXI-4)
   //, input [axi_user_width_lp-1:0]        s_axi_aruser_i   //user-defined signals (optional)
   //, input [3:0]                          s_axi_arregion_i //region identifier (optional)
 
   // READ DATA CHANNEL SIGNALS
   , output logic [lg_axi_id_width_lp-1:0]  s_axi_rid_o      //read data ID
   , output logic [axi_data_width_p-1:0]    s_axi_rdata_o    //read data
   , output logic [1:0]                     s_axi_rresp_o    //read response
   , output logic                           s_axi_rlast_o    //read last
   , output logic                           s_axi_rvalid_o   //slave device read data validity
   , input                                  s_axi_rready_i   //master device read data readiness
   //, output logic                         s_axi_ruser_o    //user-defined signals (optional)
  );

  wire unused_0 = s_axi_awcache_i;
  wire unused_1 = s_axi_awprot_i; 
  wire unused_2 = s_axi_awqos_i;
  wire unused_3 = s_axi_awid_i;
  wire unused_4 = s_axi_wid_i;

  // declaring mem command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, bp_out);

  //mem headers
  bp_bedrock_bp_out_mem_msg_header_s mem_cmd_header_cast_o, mem_resp_header_cast_i, mem_cmd_header_r;

  assign mem_resp_cast_header_i = mem_resp_header_i;
  assign mem_cmd_header_o = mem_cmd_header_cast_o;

  // store axi write address id for response, assuming awid and wid will always be the same
  logic [lg_axi_id_width_lp-1:0] device_id_r, device_id_n;

  // read counters
  logic [7:0] r_last_cnt_r, r_last_cnt_n, r_msg_maxlen_r, r_msg_maxlen_n;

  // intermediate values for mem_cmd_data_o resulted from a generate block
  logic [axi_data_width_p-1:0] mem_cmd_data_lo;
  for (genvar i = 0; i < axi_strb_width_lp; i++) begin : mem_cmd_data
    if (s_axi_wstrb_i[i]) begin
        assign mem_cmd_data_lo[i*8+:8] = s_axi_wdata_i[i*8+:8];
    end
  end

  // Declaring all possible states
  typedef enum logic [2:0] {
    e_wait           = 3'b000
    ,e_read_data_tx  = 3'b001
    ,e_read_done     = 3'b010
    ,e_write_resp_tx = 3'b011
    ,e_write_data_tx = 3'b100
    ,e_write_err     = 3'b110
  } state_e;

  state_e state_r, state_n;

  // Combinational Logic
  always_comb begin
  
    // BP side: mem_cmd
    mem_cmd_header_cast_o   = '0;
    mem_cmd_header_v_o      = '0;
    mem_cmd_data_o          = '0;
    mem_cmd_data_v_o        = '0;

    // BP side: mem_resp 
    mem_resp_header_ready_o = '0;
    mem_resp_data_ready_o   = '0;

    // READ ADDRESS CHANNEL SIGNALS
    s_axi_arready_o = mem_cmd_header_ready_i;

    // READ DATA CHANNEL SIGNALS
    s_axi_rid_o     = '0;
    s_axi_rdata_o   = '0;
    s_axi_rresp_o   = '0; 
    s_axi_rlast_o   = '0;
    s_axi_rvalid_o  = '0;

    // WRITE ADDRRESS CHANNEL SIGNALS
    s_axi_awready_o = mem_cmd_header_ready_i;     

    // WRITE DATA CHANNEL SIGNALS
    s_axi_wready_o  = '0;

    // WRITE RESPONSE CHANNEL SIGNALS
    s_axi_bid_o     = '0;
    s_axi_bresp_o   = '0;
    s_axi_bvalid_o  = '0;

    // other logic
    state_n         = state_r;
    device_id_n     = device_id_r;
    r_last_cnt_n    = '0;
    r_msg_maxlen_n  = r_msg_maxlen_r;

    case(state_r)
      e_wait : begin
      	// if the slave device wants to write to BP
      	if (s_axi_awvalid_i) begin
          mem_cmd_header_cast_o.payload     = '0;
          mem_cmd_header_cast_o.size        = s_axi_awsize_i;          
          mem_cmd_header_cast_o.addr        = s_axi_awaddr_i;
          mem_cmd_header_cast_o.addr[23:20] = '0;              //device ID = 0
          mem_cmd_header_cast_o.msg_type    = e_bedrock_mem_uc_wr;
          mem_cmd_header_v_o                = s_axi_awvalid_i;
          // if the mem cmd header is accepted, move onto write data transfer state
          if (mem_cmd_header_ready_i) begin
            state_n = e_write_data_tx;
          end
        end

        // else if the slave device wants to read from BP
        else if (s_axi_arvalid_i) begin
          mem_cmd_header_cast_o.payload     = '0;
          mem_cmd_header_cast_o.size        = s_axi_arsize_i;
          mem_cmd_header_cast_o.addr        = s_axi_awaddr_i;
          mem_cmd_header_cast_o.addr[23:20] = '0;
          mem_cmd_header_cast_o.msg_type    = e_bedrock_mem_uc_rd;
          mem_cmd_header_v_o                = s_axi_arvalid_i;
          
          r_msg_maxlen_n = ((2**s_axi_arsize_i << 3) > axi_data_width_p)
                         ? (2**(s_axi_arsize_i - lg_axi_data_width_in_byte_lp)) - 1
                         : 8'h01;

          if (mem_cmd_header_ready_i) begin
          	state_n = e_read_data_tx;
          end
        end

        device_id_n = s_axi_awid_i;
      end

      // WRITE STATES
      e_write_data_tx : begin
        // BP mem cmd ready for data transfer
        s_axi_wready_o   = mem_cmd_data_ready_i;
        
        // BP mem data writes
        mem_cmd_data_v_o = s_axi_wvalid_i;
        mem_cmd_data_o   = mem_cmd_data_lo;
        /*for (genvar i = 0; i < axi_strb_width_lp; i++) begin
          if (s_axi_wstrb_i[i]) begin
          	mem_cmd_data_o[i*8+:8] = s_axi_wdata_i[i*8+:8];
          end
        end*/

        if (s_axi_wlast_i) begin
        	state_n = e_write_resp_tx;
        end
      end

      e_write_resp_tx : begin
        // Responding to slave device after writing to BP
        s_axi_bid_o    = device_id_r;
        s_axi_bvalid_o = 1'b1;
        if (s_axi_bready_i) begin
        	state_n = e_wait;
        end
      end

      // READ STATES
      e_read_data_tx : begin

      	//bp side:
      	mem_resp_data_ready_o   = s_axi_rready_i;
        mem_resp_header_ready_o = 1'b1;

        s_axi_rid_o    = device_id_r;
        s_axi_rdata_o  = mem_resp_data_i;
        s_axi_rvalid_o = mem_resp_data_v_i;
        s_axi_rlast_o  = (r_last_cnt_r == r_msg_maxlen_r);

        r_last_cnt_n   = (s_axi_rready_i & mem_resp_data_v_i)
                       ? r_last_cnt_r + 1
                       : r_last_cnt_r;
        
        state_n        = (s_axi_rlast_o)
                       ? e_wait
                       : e_read_data_tx;

      end
    endcase
  end

  // Sequential Logic
  always_ff @(posedge aclk_i) begin
    if (~aresetn_i) begin
      state_r           <= e_wait;
      device_id_r       <= '0;
      r_last_cnt_r	    <= '0;
      r_msg_maxlen_r	<= '0;
    end
    else begin
      state_r           <= state_n;
      device_id_r       <= device_id_n;
      r_last_cnt_r	    <= r_last_cnt_n	;
      r_msg_maxlen_r	<= r_msg_maxlen_n;
    end
  end
  
endmodule
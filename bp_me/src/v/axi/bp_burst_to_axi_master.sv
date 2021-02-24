
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_burst_to_axi_master
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, bp_in)

  // AXI WRITE DATA CHANNEL PARAMS
  , parameter  axi_data_width_p             = 64
  , localparam axi_strb_width_lp            = axi_data_width_p/8
  , localparam lg_axi_data_width_in_byte_lp = `BSG_SAFE_CLOG2(axi_data_width_p/8)

  // AXI WRITE/READ ADDRESS CHANNEL PARAMS  
  , parameter axi_id_width_p                = 1
  , parameter axi_addr_width_p              = 64
  )

  ( //==================== GLOBAL SIGNALS =======================
   input aclk_i  
   , input aresetn_i
 
   //======================== BP SIDE ==========================
   // memory commands
   , input [bp_in_mem_msg_header_width_lp-1:0]        mem_cmd_header_i
   , input                                            mem_cmd_header_v_i
   , output logic                                     mem_cmd_header_ready_o
 
   , input [axi_data_width_p-1:0]                     mem_cmd_data_i
   , input                                            mem_cmd_data_v_i
   , output logic                                     mem_cmd_data_ready_o
 
   // memory responses
   , output logic [bp_in_mem_msg_header_width_lp-1:0] mem_resp_header_o
   , output logic                                     mem_resp_header_v_o
   , input                                            mem_resp_header_ready_i
 
   , output logic [axi_data_width_p-1:0]              mem_resp_data_o
   , output logic                                     mem_resp_data_v_o
   , input                                            mem_resp_data_ready_i
 
   //======================= AXI SIDE ==========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , output logic [axi_id_width_p-1:0]       m_axi_awid_o     //write addr ID    
   , output logic [axi_addr_width_p-1:0]     m_axi_awaddr_o   //write address
   , output logic axi_len_e                  m_axi_awlen_o    //burst length (# of transfers 0-256)
   , output logic axi_size_e                 m_axi_awsize_o   //burst size (# of bytes in transfer 0-128)
   , output logic axi_burst_type_e           m_axi_awburst_o  //burst type (FIXED, INCR, or WRAP)
   , output logic axi_cache_type_e           m_axi_awcache_o  //memory type (write-through, write-back, etc.)
   , output logic axi_prot_type_e            m_axi_awprot_o   //protection type (unpriv, secure, etc)
   , output logic axi_qos_type_e             m_axi_awqos_o    //QoS (use default 0000 if no QoS scheme)
   , output logic                            m_axi_awvalid_o  //master device write addr validity
   , input                                   m_axi_awready_i  //slave device readiness
 
   // WRITE DATA CHANNEL SIGNALS
   , output logic [axi_id_width_p-1:0]       m_axi_wid_o      //write data ID
   , output logic [axi_data_width_p-1:0]     m_axi_wdata_o    //write data
   , output logic [axi_strb_width_lp-1:0]    m_axi_wstrb_o    //write strobes (indicates valid data byte lane)
   , output logic                            m_axi_wlast_o    //write last (indicates last transfer in a write burst)
   , output logic                            m_axi_wvalid_o   //master device write validity
   , input                                   m_axi_wready_i   //slave device readiness
 
   // WRITE RESPONSE CHANNEL SIGNALS
   , input [axi_id_width_p-1:0]              m_axi_bid_i      //slave response ID
   , input axi_resp_type_e                   m_axi_bresp_i    //status of the write transaction (OKAY, EXOKAY, SLVERR, or DECERR)
   , input                                   m_axi_bvalid_i   //slave device write reponse validity
   , output logic                            m_axi_bready_o   //master device write response readiness 
   
   // READ ADDRESS CHANNEL SIGNALS
   , output logic [axi_id_width_p-1:0]       m_axi_arid_o     //read addr ID
   , output logic [axi_addr_width_p-1:0]     m_axi_araddr_o   //read address
   , output logic axi_len_e                  m_axi_arlen_o    //burst length (# of transfers 0-256)
   , output logic axi_size_e                 m_axi_arsize_o   //burst size (# of bytes in transfer 0-128)
   , output logic axi_burst_type_e           m_axi_arburst_o  //burst type (FIXED, INCR, or WRAP)
   , output logic axi_cache_type_e           m_axi_arcache_o  //memory type (write-through, write-back, etc.)
   , output logic axi_prot_type_e            m_axi_arprot_o   //protection type (unpriv, secure, etc)
   , output logic axi_qos_type_e             m_axi_arqos_o    //QoS (use default 0000 if no QoS scheme)
   , output logic                            m_axi_arvalid_o  //master device read addr validity
   , input                                   m_axi_arready_i  //slave device readiness
 
   // READ DATA CHANNEL SIGNALS
   , input [axi_id_width_p-1:0]              m_axi_rid_i      //read data ID
   , input [axi_data_width_p-1:0]            m_axi_rdata_i    //read data
   , input axi_resp_type_e                   m_axi_rresp_i    //read response
   , input                                   m_axi_rlast_i    //read last
   , input                                   m_axi_rvalid_i   //slave device read data validity
   , output logic                            m_axi_rready_o   //master device read data readiness
   //, input                                 m_axi_ruser_i    //user-defined signals (optional)
  );

  // unused wires
  wire unused_0 = m_axi_rid_i;
  wire unused_1 = m_axi_bid_i;

  // declaring mem command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, bp_in);

  //mem headers
  bp_bedrock_bp_in_mem_msg_header_s mem_cmd_header_cast_i, mem_resp_header_cast_o, mem_cmd_header_r;

  assign mem_resp_header_o = mem_resp_header_cast_o;
  assign mem_cmd_header_cast_i = mem_cmd_header_i;

  // Declaring all possible states
  enum {e_wait, e_read_data_rx, e_write_data_tx, e_write_resp_rx} state_r, state_n;

  // storing mem_cmd's header for mem_resp's use
  // only accepts changes when mem_cmd is valid
  bsg_dff_reset_en
   #(.width_p(bp_in_mem_msg_header_width_lp))
   mem_header_reg
    (.clk_i(aclk_i)
    ,.reset_i(~aresetn_i)
    ,.en_i(mem_cmd_header_v_i & (state_r == e_wait))
    ,.data_i(mem_cmd_header_i)
    ,.data_o(mem_cmd_header_r)
    );

  // memory command read/write validity
  wire mem_cmd_header_read_v  = mem_cmd_header_v_i & mem_cmd_header_cast_i.msg_type inside {e_bedrock_mem_rd, e_bedrock_mem_uc_rd, e_bedrock_mem_pre};
  wire mem_cmd_header_write_v = mem_cmd_header_v_i & mem_cmd_header_cast_i.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr};

  // Write counters and burst logic
  logic [7:0] awburst_cnt_r, awburst_cnt_n;
  logic rready_r; 

  function automatic [7:0] len_calc;
    input [2:0] size;
    len_calc   = ((2**size << 3) > axi_data_width_p) 
               ? (2**(size  - lg_axi_data_width_in_byte_lp)) - 1
               : 8'h00;
  endfunction

  function automatic [2:0] size_calc;
    input [2:0] size;
    size_calc = ((2**size << 3) > axi_data_width_p) 
              ? 3'b011
              : size;
  endfunction

  // Special section for unaligned mem writes. 64-bit DDR3 writes will mask last 3-bits of
  // axi write address. The following logics address that issue
  wire [axi_addr_width_p-1:0] awaddr_temp = {mem_cmd_header_cast_i.addr[axi_addr_width_p-1:3], 3'b000};

  logic [axi_data_width_p-1:0] wdata_temp;
  logic [axi_strb_width_lp-1:0] wstrb_temp;

  for (genvar i=0; i < axi_strb_width_lp; i++) begin
    assign wdata_temp[i*8+:8] = ((i >= mem_cmd_header_cast_i.addr[2:0]) && (i < (mem_cmd_header_cast_i.addr[2:0] + 2**mem_cmd_header_cast_i.size)))
                                ? mem_cmd_data_i[(i-mem_cmd_header_cast_i.addr[2:0])*8+:8]
                                : 8'b0;

    assign wstrb_temp[i] = ((i >= mem_cmd_header_cast_i.addr[2:0]) && (i < (mem_cmd_header_cast_i.addr[2:0] + 2**mem_cmd_header_cast_i.size)))
                         ? 1'b1
                         : 1'b0;
  end

  // Combinational Logic
  always_comb
    begin
      // BP side: mem_cmd
      mem_cmd_header_ready_o = (m_axi_awready_i | m_axi_arready_i) & (state_r == e_wait);
      mem_cmd_data_ready_o   = (m_axi_wready_i) & (state_r inside {e_wait, e_write_data_tx});

      // BP side: mem_resp 
      mem_resp_header_cast_o = mem_cmd_header_r;
      mem_resp_header_v_o    = '0;
      mem_resp_data_o        = '0;
      mem_resp_data_v_o      = '0;

      // READ ADDRESS CHANNEL SIGNALS
      m_axi_araddr_o  = mem_cmd_header_cast_i.addr;
      m_axi_arlen_o   = len_calc(mem_cmd_header_cast_i.size);
      m_axi_arsize_o  = size_calc(mem_cmd_header_cast_i.size);              
      m_axi_arburst_o = e_axi_burst_incr;
      m_axi_arvalid_o = mem_cmd_header_read_v & mem_cmd_header_ready_o;
      m_axi_arid_o    = '0;      //device ID default to 0
      m_axi_arcache_o = 4'b0011; //normal non-cacheable bufferable (recommended for Xilinx IP)
      m_axi_arprot_o  = '0;      //unprivileged access
      m_axi_arqos_o   = '0;      //no QoS scheme

      // READ DATA CHANNEL SIGNALS
      m_axi_rready_o  = '0;

      // WRITE ADDRESS CHANNEL SIGNALS
      m_axi_awaddr_o  = awaddr_temp;
      m_axi_awlen_o   = len_calc(mem_cmd_header_cast_i.size);
      m_axi_awsize_o  = size_calc(mem_cmd_header_cast_i.size);
      m_axi_awburst_o = e_axi_burst_incr;
      m_axi_awvalid_o = mem_cmd_header_write_v;
      m_axi_awid_o    = '0;
      m_axi_awcache_o = 4'b0011; 
      m_axi_awprot_o  = '0;      
      m_axi_awqos_o   = '0;      

      // WRITE DATA CHANNEL SIGNALS
      m_axi_wdata_o   = wdata_temp;
      m_axi_wstrb_o   = wstrb_temp;
      m_axi_wlast_o   = (awburst_cnt_r == len_calc(mem_cmd_header_cast_i.size)); 
      m_axi_wvalid_o  = mem_cmd_data_v_i;
      m_axi_wid_o     = '0;
      awburst_cnt_n   = '0;

      // WRITE RESPONSE CHANNEL SIGNALS
      m_axi_bready_o  = 1'b1;

      // other logic
      state_n         = state_r;
    
    case(state_r)
      e_wait : begin
        // if the header signals a valid read, transition to read_tx state
        // set mem_resp header to valid
        if (mem_cmd_header_read_v & m_axi_arready_i)
          state_n = e_read_data_rx;


        // if the header signals a valid write, state transition depends
        // on the readiness of write address of the slave device
        else if (mem_cmd_header_write_v & m_axi_awready_i & m_axi_wready_i & m_axi_wlast_o)
          state_n = e_write_resp_rx;

        else if (mem_cmd_header_write_v & m_axi_awready_i)
          begin
            awburst_cnt_n = (m_axi_wready_i) ? awburst_cnt_r + 1 : '0;	
            state_n = e_write_data_tx;
          end
      end

      // READ STATES
      e_read_data_rx : begin
      	mem_resp_header_v_o = ~rready_r & mem_resp_data_ready_i;
        m_axi_arlen_o       = len_calc(mem_cmd_header_r.size);
        m_axi_awsize_o      = size_calc(mem_cmd_header_r.size);
        m_axi_rready_o      = mem_resp_data_ready_i;
        mem_resp_data_o     = (m_axi_rresp_i == '0)
                            ? m_axi_rdata_i
                            : '0;               
        mem_resp_data_v_o   = m_axi_rvalid_i;

        // if read last signal is asserted, we go to read done state
        if (m_axi_rlast_i & m_axi_rvalid_i) 
          state_n = e_wait;
          
      end

      // WRITE STATES
      e_write_data_tx : begin
        // sending write addr signals
        awburst_cnt_n = awburst_cnt_r;
        m_axi_wlast_o = (awburst_cnt_r == len_calc(mem_cmd_header_r.size));
        awburst_cnt_n = (m_axi_wready_i & mem_cmd_data_v_i)
                      ? awburst_cnt_r + 1
                      : awburst_cnt_r;
        state_n       = (m_axi_wlast_o)
                      ? e_write_resp_rx
                      : state_r;
        end

      e_write_resp_rx : begin              
        // if the response is valid, give warning if it's not OKAY
        if (m_axi_bvalid_i) 
          begin
          mem_resp_header_v_o = 1'b1;
          state_n = e_wait;
          end
      end

    endcase
  end

  // Sequential Logic
  always_ff @(posedge aclk_i) 
    begin
     if (~aresetn_i) 
       begin
         state_r       <= e_wait;
         awburst_cnt_r <= '0;
         rready_r      <= '0;
       end
      else 
        begin
          state_r       <= state_n;
          awburst_cnt_r <= awburst_cnt_n;
          rready_r      <= mem_resp_data_ready_i;
        end
    end
  
  //synopsys translate_off
  initial
    begin
      // give a warning if DRAM gives an error response
      if (m_axi_rlast_i & m_axi_rvalid_i)
        assert (m_axi_rresp_i == '0) else $warning("DRAM has an error response to memory reads");
      if (m_axi_bvalid_i)
        assert (m_axi_bresp_i == '0) else $warning("DRAM has an error response to memory writes");
    end
endmodule


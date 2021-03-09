
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_unicore_axi
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // AXI4-LITE PARAMS
   , parameter axi_lite_addr_width_p   = 64
   , parameter axi_lite_data_width_p   = 64
   , localparam axi_lite_strb_width_lp = axi_lite_data_width_p/8
   
   // AXI4-FULL PARAMS
   , parameter axi_full_addr_width_p   = 64
   , parameter axi_full_data_width_p   = 512
   , parameter axi_full_id_width_p     = 6
   , localparam axi_full_strb_width_lp = axi_full_data_width_p>>8
   , localparam axi_full_burst_len_p   = `BSG_CDIV(cce_block_width_p, axi_full_data_width_p)

   , localparam uce_mem_data_width_lp = `BSG_MAX(icache_fill_width_p, dcache_fill_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce)
   )

  (input clk_i
  , input reset_i
  
  //========================Outgoing I/O==========================
  , output logic [axi_lite_addr_width_p-1:0]  m_axi_lite_awaddr_o
  , output axi_prot_type_e                    m_axi_lite_awprot_o
  , output logic                              m_axi_lite_awvalid_o
  , input                                     m_axi_lite_awready_i
  
  , output logic [axi_lite_data_width_p-1:0]  m_axi_lite_wdata_o
  , output logic [axi_lite_strb_width_lp-1:0] m_axi_lite_wstrb_o
  , output logic                              m_axi_lite_wvalid_o
  , input                                     m_axi_lite_wready_i
  
  , input axi_resp_type_e                     m_axi_lite_bresp_i 
  , input                                     m_axi_lite_bvalid_i
  , output logic                              m_axi_lite_bready_o

  , output logic [axi_lite_addr_width_p-1:0]  m_axi_lite_araddr_o
  , output axi_prot_type_e                    m_axi_lite_arprot_o
  , output logic                              m_axi_lite_arvalid_o
  , input                                     m_axi_lite_arready_i

  , input [axi_lite_data_width_p-1:0]         m_axi_lite_rdata_i
  , input axi_resp_type_e                     m_axi_lite_rresp_i
  , input                                     m_axi_lite_rvalid_i
  , output logic                              m_axi_lite_rready_o

  //========================Incoming I/O========================
  , input [axi_lite_addr_width_p-1:0]         s_axi_lite_awaddr_i
  , input axi_prot_type_e                     s_axi_lite_awprot_i
  , input                                     s_axi_lite_awvalid_i
  , output logic                              s_axi_lite_awready_o

  , input [axi_lite_data_width_p-1:0]         s_axi_lite_wdata_i
  , input [axi_lite_strb_width_lp-1:0]        s_axi_lite_wstrb_i
  , input                                     s_axi_lite_wvalid_i
  , output logic                              s_axi_lite_wready_o

  , output axi_resp_type_e                    s_axi_lite_bresp_o 
  , output logic                              s_axi_lite_bvalid_o
  , input                                     s_axi_lite_bready_i

  , input [axi_lite_addr_width_p-1:0]         s_axi_lite_araddr_i
  , input axi_prot_type_e                     s_axi_lite_arprot_i
  , input                                     s_axi_lite_arvalid_i
  , output logic                              s_axi_lite_arready_o

  , output logic [axi_lite_data_width_p-1:0]  s_axi_lite_rdata_o
  , output axi_resp_type_e                    s_axi_lite_rresp_o
  , output logic                              s_axi_lite_rvalid_o
  , input                                     s_axi_lite_rready_i

  //======================Memory Requests======================
  , output logic [axi_full_id_width_p-1:0]    m_axi_awid_o   
  , output logic [axi_full_addr_width_p-1:0]  m_axi_awaddr_o 
  , output axi_len_e                          m_axi_awlen_o  
  , output axi_size_e                         m_axi_awsize_o 
  , output axi_burst_type_e                   m_axi_awburst_o
  , output axi_cache_type_e                   m_axi_awcache_o
  , output axi_prot_type_e                    m_axi_awprot_o 
  , output axi_qos_type_e                     m_axi_awqos_o  
  , output logic                              m_axi_awvalid_o
  , input                                     m_axi_awready_i

  , output logic [axi_full_id_width_p-1:0]    m_axi_wid_o   
  , output logic [axi_full_data_width_p-1:0]  m_axi_wdata_o 
  , output logic [axi_full_strb_width_lp-1:0] m_axi_wstrb_o 
  , output logic                              m_axi_wlast_o 
  , output logic                              m_axi_wvalid_o
  , input                                     m_axi_wready_i

  , input [axi_full_id_width_p-1:0]           m_axi_bid_i   
  , input axi_resp_type_e                     m_axi_bresp_i 
  , input                                     m_axi_bvalid_i
  , output logic                              m_axi_bready_o

  , output logic [axi_full_id_width_p-1:0]    m_axi_arid_o   
  , output logic [axi_full_addr_width_p-1:0]  m_axi_araddr_o 
  , output axi_len_e                          m_axi_arlen_o  
  , output axi_size_e                         m_axi_arsize_o 
  , output axi_burst_type_e                   m_axi_arburst_o
  , output axi_cache_type_e                   m_axi_arcache_o
  , output axi_prot_type_e                    m_axi_arprot_o
  , output axi_qos_type_e                     m_axi_arqos_o  
  , output logic                              m_axi_arvalid_o
  , input                                     m_axi_arready_i

  , input [axi_full_id_width_p-1:0]           m_axi_rid_i   
  , input [axi_full_data_width_p-1:0]         m_axi_rdata_i 
  , input axi_resp_type_e                     m_axi_rresp_i 
  , input                                     m_axi_rlast_i 
  , input                                     m_axi_rvalid_i
  , output logic                              m_axi_rready_o
  );

  // unicore declaration
  `declare_bp_bedrock_mem_if(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce);
  bp_bedrock_uce_mem_msg_s io_cmd_lo, io_cmd_li;
  bp_bedrock_uce_mem_msg_s io_resp_lo, io_resp_li;
  logic io_cmd_v_lo, io_cmd_v_li, io_cmd_ready_li, io_cmd_yumi_lo;
  logic io_resp_v_li, io_resp_v_lo, io_resp_yumi_lo, io_resp_ready_li;
  
  `declare_bsg_cache_dma_pkt_s(caddr_width_p);
  bsg_cache_dma_pkt_s dma_pkt_lo;
  logic dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [mem_noc_flit_width_p-1:0] dma_data_li;
  logic dma_data_v_li, dma_data_ready_lo;
  logic [mem_noc_flit_width_p-1:0] dma_data_lo;
  logic dma_data_v_lo, dma_data_yumi_li;

  bp_unicore
   #(.bp_params_p(bp_params_p))
   unicore
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    // Outgoing I/O
    ,.io_cmd_o(io_cmd_lo)
    ,.io_cmd_v_o(io_cmd_v_lo)
    ,.io_cmd_ready_i(io_cmd_ready_li)

    ,.io_resp_i(io_resp_li)
    ,.io_resp_v_i(io_resp_v_li)
    ,.io_resp_yumi_o(io_resp_yumi_lo)

    // Incoming I/O
    ,.io_cmd_i(io_cmd_li)
    ,.io_cmd_v_i(io_cmd_v_li)
    ,.io_cmd_yumi_o(io_cmd_yumi_lo)

    ,.io_resp_o(io_resp_lo) 
    ,.io_resp_v_o(io_resp_v_lo)
    ,.io_resp_ready_i(io_resp_ready_li)

    ,.dma_pkt_o(dma_pkt_lo)
    ,.dma_pkt_v_o(dma_pkt_v_lo)
    ,.dma_pkt_yumi_i(dma_pkt_yumi_li)

    ,.dma_data_i(dma_data_li)
    ,.dma_data_v_i(dma_data_v_li)
    ,.dma_data_ready_o(dma_data_ready_lo)

    ,.dma_data_o(dma_data_lo)
    ,.dma_data_v_o(dma_data_v_lo)
    ,.dma_data_yumi_i(dma_data_yumi_li)
    );
  
  // outgoing io wrapper
  bp_lite_to_axi_lite_master 
   #(.bp_params_p(bp_params_p)
     ,.axi_data_width_p(axi_lite_data_width_p)
     ,.axi_addr_width_p(axi_lite_addr_width_p)
     )
   io2axil
    (.aclk_i(clk_i)
     ,.aresetn_i(~reset_i)

     ,.io_cmd_i(io_cmd_lo)
     ,.io_cmd_v_i(io_cmd_v_lo & io_cmd_ready_li)
     ,.io_cmd_ready_o(io_cmd_ready_li)

     ,.io_resp_o(io_resp_li)
     ,.io_resp_v_o(io_resp_v_li)
     ,.io_resp_yumi_i(io_resp_yumi_lo)

     ,.*
     );
  
  // incoming io wrapper
  axi_lite_to_bp_lite_client
   #(.bp_params_p(bp_params_p)
     ,.axi_data_width_p(axi_lite_data_width_p)
     ,.axi_addr_width_p(axi_lite_addr_width_p)
     )
   axil2io
    (.aclk_i(clk_i)
     ,.aresetn_i(~reset_i)

     ,.io_cmd_o(io_cmd_li)
     ,.io_cmd_v_o(io_cmd_v_li)
     ,.io_cmd_yumi_i(io_cmd_yumi_lo)

     ,.io_resp_i(io_resp_lo)
     ,.io_resp_v_i(io_resp_v_lo)
     ,.io_resp_ready_o(io_resp_ready_li)

     ,.*
     );

  bsg_cache_to_axi
   #(.addr_width_p(caddr_width_p)
     ,.block_size_in_words_p(cce_block_width_p/dword_width_gp)
     ,.data_width_p(dword_width_gp)
     ,.num_cache_p(1)
     ,.axi_id_width_p(axi_full_id_width_p)
     ,.axi_addr_width_p(axi_full_addr_width_p)
     ,.axi_data_width_p(axi_full_data_width_p)
     ,.axi_burst_len_p(axi_full_burst_len_p)
     )
   cache2axi
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.dma_pkt_i(dma_pkt_i)
     ,.dma_pkt_v_i(dma_pkt_v_i)
     ,.dma_pkt_yumi_o(dma_pkt_yumi_o)

     ,.dma_data_o(dma_data_o)
     ,.dma_data_v_o(dma_data_v_o)
     ,.dma_data_ready_i(dma_data_ready_i)

     ,.dma_data_i(dma_data_i)
     ,.dma_data_v_i(dma_data_v_i)
     ,.dma_data_yumi_o(dma_data_yumi_o)

     ,.axi_awid_o(axi_awid)
     ,.axi_awaddr_o(axi_awaddr)
     ,.axi_awlen_o(axi_awlen)
     ,.axi_awsize_o(axi_awsize)
     ,.axi_awburst_o(axi_awburst)
     ,.axi_awcache_o(axi_awcache)
     ,.axi_awprot_o(axi_awprot)
     ,.axi_awlock_o(axi_awlock)
     ,.axi_awvalid_o(axi_awvalid)
     ,.axi_awready_i(axi_awready)

     ,.axi_wdata_o(axi_wdata)
     ,.axi_wstrb_o(axi_wstrb)
     ,.axi_wlast_o(axi_wlast)
     ,.axi_wvalid_o(axi_wvalid)
     ,.axi_wready_i(axi_wready)

     ,.axi_bid_i(axi_bid)
     ,.axi_bresp_i(axi_bresp)
     ,.axi_bvalid_i(axi_bvalid)
     ,.axi_bready_o(axi_bready)
     ,.axi_arid_o(axi_arid)
     ,.axi_araddr_o(axi_araddr)
     ,.axi_arlen_o(axi_arlen)
     ,.axi_arsize_o(axi_arsize)
     ,.axi_arburst_o(axi_arburst)
     ,.axi_arcache_o(axi_arcache)
     ,.axi_arprot_o(axi_arprot)
     ,.axi_arlock_o(axi_arlock)
     ,.axi_arvalid_o(axi_arvalid)
     ,.axi_arready_i(axi_arready)

     ,.axi_rid_i(axi_rid)
     ,.axi_rdata_i(axi_rdata)
     ,.axi_rresp_i(axi_rresp)
     ,.axi_rlast_i(axi_rlast)
     ,.axi_rvalid_i(axi_rvalid)
     ,.axi_rready_o(axi_rready)
     );
  
endmodule


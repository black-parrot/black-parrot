
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
   , parameter axi_full_data_width_p   = 64
   , parameter axi_full_id_width_p     = 1
   , localparam axi_full_strb_width_lp = axi_full_data_width_p/8

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
  
  bp_bedrock_uce_mem_msg_header_s mem_cmd_header_lo;
  logic mem_cmd_header_v_lo, mem_cmd_header_ready_li;
  logic [dword_width_gp-1:0] mem_cmd_data_lo;
  logic mem_cmd_data_v_lo, mem_cmd_data_ready_li;
  
  bp_bedrock_uce_mem_msg_header_s mem_resp_header_li;
  logic mem_resp_header_v_li, mem_resp_header_yumi_lo;
  logic [dword_width_gp-1:0] mem_resp_data_li;
  logic mem_resp_data_v_li, mem_resp_data_yumi_lo;
  
  bp_unicore
   #(.bp_params_p(bp_params_p))
   unicore
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    // Outgoing I/O
    ,.io_cmd_o               (io_cmd_lo)
    ,.io_cmd_v_o             (io_cmd_v_lo)
    ,.io_cmd_ready_i         (io_cmd_ready_li)

    ,.io_resp_i              (io_resp_li)
    ,.io_resp_v_i            (io_resp_v_li)
    ,.io_resp_yumi_o         (io_resp_yumi_lo)

    // Incoming I/O
    ,.io_cmd_i               (io_cmd_li)
    ,.io_cmd_v_i             (io_cmd_v_li)
    ,.io_cmd_yumi_o          (io_cmd_yumi_lo)

    ,.io_resp_o              (io_resp_lo) 
    ,.io_resp_v_o            (io_resp_v_lo)
    ,.io_resp_ready_i        (io_resp_ready_li)

    // DRAM interface
    ,.mem_cmd_header_o       (mem_cmd_header_lo)
    ,.mem_cmd_header_v_o     (mem_cmd_header_v_lo)
    ,.mem_cmd_header_ready_i (mem_cmd_header_ready_li)

    ,.mem_cmd_data_o         (mem_cmd_data_lo)
    ,.mem_cmd_data_v_o       (mem_cmd_data_v_lo)
    ,.mem_cmd_data_ready_i   (mem_cmd_data_ready_li)

    ,.mem_resp_header_i      (mem_resp_header_li)
    ,.mem_resp_header_v_i    (mem_resp_header_v_li)
    ,.mem_resp_header_yumi_o (mem_resp_header_yumi_lo)

    ,.mem_resp_data_i        (mem_resp_data_li)
    ,.mem_resp_data_v_i      (mem_resp_data_v_li)
    ,.mem_resp_data_yumi_o   (mem_resp_data_yumi_lo)
    );
  
  // outgoing io wrapper
  bp_lite_to_axi_lite_master 
   #(.bp_params_p(bp_params_p)
     ,.axi_data_width_p(axi_lite_data_width_p)
     ,.axi_addr_width_p(axi_lite_addr_width_p)
     )
   io2axil
   (.aclk_i               (clk_i)
    ,.aresetn_i           (~reset_i)

    ,.io_cmd_i            (io_cmd_lo)
    ,.io_cmd_v_i          (io_cmd_v_lo & io_cmd_ready_li)
    ,.io_cmd_ready_o      (io_cmd_ready_li)

    ,.io_resp_o           (io_resp_li)
    ,.io_resp_v_o         (io_resp_v_li)
    ,.io_resp_yumi_i      (io_resp_yumi_lo)

    ,.*
    );
  
  // incoming io wrapper
  axi_lite_to_bp_lite_client
   #(.bp_params_p(bp_params_p)
     ,.axi_data_width_p(axi_lite_data_width_p)
     ,.axi_addr_width_p(axi_lite_addr_width_p)
     )
   axil2io
   (.aclk_i               (clk_i)
    ,.aresetn_i           (~reset_i)

    ,.io_cmd_o            (io_cmd_li)
    ,.io_cmd_v_o          (io_cmd_v_li)
    ,.io_cmd_yumi_i       (io_cmd_yumi_lo)

    ,.io_resp_i           (io_resp_lo)
    ,.io_resp_v_i         (io_resp_v_lo)
    ,.io_resp_ready_o     (io_resp_ready_li)

    ,.*
    );
  
  // dram interface wrapper
  bp_mem_to_axi_master
   #(.bp_params_p(bp_params_p)
     ,.axi_data_width_p(axi_full_data_width_p)
     ,.axi_addr_width_p(axi_full_addr_width_p)
     ,.axi_id_width_p(axi_full_id_width_p)
     )
   mem2axi
   (.aclk_i               (clk_i)
    ,.aresetn_i           (~reset_i)
  
    ,.mem_cmd_header_i        (mem_cmd_header_lo)
    ,.mem_cmd_header_v_i      (mem_cmd_header_v_lo)
    ,.mem_cmd_header_ready_o  (mem_cmd_header_ready_li)  
  
    ,.mem_cmd_data_i          (mem_cmd_data_lo)      
    ,.mem_cmd_data_v_i        (mem_cmd_data_v_lo)
    ,.mem_cmd_data_ready_o    (mem_cmd_data_ready_li)

    ,.mem_resp_header_o       (mem_resp_header_li)
    ,.mem_resp_header_v_o     (mem_resp_header_v_li)
    ,.mem_resp_header_ready_i (mem_resp_header_yumi_lo)

    ,.mem_resp_data_o         (mem_resp_data_li)
    ,.mem_resp_data_v_o       (mem_resp_data_v_li)
    ,.mem_resp_data_ready_i   (mem_resp_data_yumi_lo)

    ,.*
    );

endmodule


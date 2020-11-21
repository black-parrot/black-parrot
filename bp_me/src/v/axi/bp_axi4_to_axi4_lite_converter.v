`include "bsg_defines.v"

module bp_axi4_to_axi4_lite_converter

 #(// AXI WRITE DATA CHANNEL PARAMS
   parameter  axi_data_width_p             = 64 //or 32, has to be either 32 or 64 for axi-lite
  , localparam axi_strb_width_lp            = axi_data_width_p/8
  , localparam lg_axi_data_width_in_byte_lp = `BSG_SAFE_CLOG2(axi_data_width_p/8)

  // AXI WRITE/READ ADDRESS CHANNEL PARAMS  
  , parameter  axi_addr_width_p             = 64 //or 32, has to be either 32 or 64 for axi-lite
  , parameter  axi_id_width_p               = 1
  )

  (//==================== GLOBAL SIGNALS =======================
   input aclk_i  
   , input aresetn_i

   //====================== AXI-4 FULL =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axi_id_width_p-1:0]           m_axi_awid_i   
   , input [axi_addr_width_p-1:0]         m_axi_awaddr_i 
   , input [7:0]                          m_axi_awlen_i  
   , input [2:0]                          m_axi_awsize_i 
   , input [1:0]                          m_axi_awburst_i
   , input [3:0]                          m_axi_awcache_i
   , input [2:0]                          m_axi_awprot_i 
   , input [3:0]                          m_axi_awqos_i  
   , input                                m_axi_awvalid_i
   , output logic                         m_axi_awready_o
 
   // WRITE DATA CHANNEL SIGNALS
   , input [axi_id_width_p-1:0]           m_axi_wid_i  
   , input [axi_data_width_p-1:0]         m_axi_wdata_i
   , input [axi_strb_width_lp-1:0]        m_axi_wstrb_i
   , input                                m_axi_wlast_i
   , input                                m_axi_wvalid_i
   , output logic                         m_axi_wready_o
   //, input [axi_user_width_lp-1:0]      m_axi_wuser_i 
 
   // WRITE RESPONSE CHANNEL SIGNALS
   , output logic [axi_id_width_p-1:0]    m_axi_bid_o
   , output logic [1:0]                   m_axi_bresp_o 
   , output logic                         m_axi_bvalid_o
   , input                                m_axi_bready_i
   //, input [axi_user_width_lp-1:0]      m_axi_buser_i 
   
   // READ ADDRESS CHANNEL SIGNALS
   , input [axi_id_width_p-1:0]           m_axi_arid_i    
   , input [axi_addr_width_p-1:0]         m_axi_araddr_i  
   , input [7:0]                          m_axi_arlen_i   
   , input [2:0]                          m_axi_arsize_i  
   , input [1:0]                          m_axi_arburst_i 
   , input [3:0]                          m_axi_arcache_i 
   , input [2:0]                          m_axi_arprot_i  
   , input [3:0]                          m_axi_arqos_i   
   , input                                m_axi_arvalid_i 
   , output logic                         m_axi_arready_o 
   //, input                              m_axi_arlock_i  
   //, input [axi_user_width_lp-1:0]      m_axi_aruser_i  
   //, input [3:0]                        m_axi_arregion_i
 
   // READ DATA CHANNEL SIGNALS
   , output logic [axi_id_width_p-1:0]    m_axi_rid_o
   , output logic [axi_data_width_p-1:0]  m_axi_rdata_o
   , output logic [1:0]                   m_axi_rresp_o
   , output logic                         m_axi_rlast_o
   , output logic                         m_axi_rvalid_o
   , input                                m_axi_rready_i
   //, input logic                        m_axi_ruser_i 

   //====================== AXI-4 LITE =========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , output logic [axi_addr_width_p-1:0]  m_axi_lite_awaddr_o
   , output logic [2:0]                   m_axi_lite_awprot_o
   , output logic                         m_axi_lite_awvalid_o
   , input                                m_axi_lite_awready_i

   // WRITE DATA CHANNEL SIGNALS
   , output logic [axi_data_width_p-1:0]  m_axi_lite_wdata_o
   , output logic [axi_strb_width_lp-1:0] m_axi_lite_wstrb_o
   , output logic                         m_axi_lite_wvalid_o
   , input                                m_axi_lite_wready_i

   // WRITE RESPONSE CHANNEL SIGNALS
   , input [1:0]                          m_axi_lite_bresp_i   
   , input                                m_axi_lite_bvalid_i   
   , output logic                         m_axi_lite_bready_o

   // READ ADDRESS CHANNEL SIGNALS
   , output logic [axi_addr_width_p-1:0]  m_axi_lite_araddr_o
   , output logic [2:0]                   m_axi_lite_arprot_o
   , output logic                         m_axi_lite_arvalid_o
   , input                                m_axi_lite_arready_i

   // READ DATA CHANNEL SIGNALS
   , input [axi_data_width_p-1:0]         m_axi_lite_rdata_i
   , input [1:0]                          m_axi_lite_rresp_i
   , input                                m_axi_lite_rvalid_i
   , output logic                         m_axi_lite_rready_o
  );

  wire [axi_id_width_p-1:0] unused_0 = m_axi_wid_i;
  wire [7:0]                unused_1 = m_axi_awlen_i;
  wire [2:0]                unused_2 = m_axi_awsize_i;
  wire [1:0]                unused_3 = m_axi_awburst_i;
  wire [3:0]                unused_4 = m_axi_awcache_i;
  wire [3:0]                unused_5 = m_axi_awqos_i;
  wire [2:0]                unused_6 = m_axi_arsize_i; 
  wire [1:0]                unused_7 = m_axi_arburst_i;
  wire [3:0]                unused_8 = m_axi_arcache_i;
  wire [3:0]                unused_9 = m_axi_arqos_i;

  logic [1:0] bresp_r, bresp_n;
  logic [7:0] r_last_cnt_r, r_last_cnt_n;
  logic [axi_addr_width_p-1:0] waddr_r, waddr_n;

  // Declaring all possible states
  typedef enum logic [1:0] {
    e_wait        = 2'b00
    ,e_read_tx    = 2'b01
    ,e_write_tx   = 2'b10
    ,e_write_resp = 2'b11
  } state_e;

  state_e state_r, state_n;

  always_comb begin
    
    // READ ADDRESS CHANNEL SIGNALS
    m_axi_lite_araddr_o  = m_axi_araddr_i;
    m_axi_lite_arprot_o  = m_axi_arprot_i;
    m_axi_lite_arvalid_o = m_axi_arvalid_i;
    m_axi_arready_o      = m_axi_lite_arready_i;

    // READ DATA CHANNEL SIGNALS
    m_axi_rid_o          = m_axi_arid_i;
    m_axi_rdata_o        = m_axi_lite_rdata_i; 
    m_axi_rresp_o        = m_axi_lite_rresp_i;
    m_axi_rlast_o        = '0;
    m_axi_rvalid_o       = m_axi_lite_rvalid_i;
    m_axi_lite_rready_o  = m_axi_rready_i;

    // WRITE ADDRESS CHANNEL SIGNALS
    m_axi_lite_awaddr_o  = m_axi_awaddr_i;
    m_axi_lite_awprot_o  = m_axi_awprot_i;
    m_axi_lite_awvalid_o = m_axi_awvalid_i;
    m_axi_awready_o      = m_axi_lite_awready_i;

    // WRITE DATA CHANNEL SIGNALS
    m_axi_lite_wdata_o   = m_axi_wdata_i;
    m_axi_lite_wstrb_o   = m_axi_wstrb_i;
    m_axi_lite_wvalid_o  = m_axi_wvalid_i;
    m_axi_wready_o       = m_axi_lite_wready_i;

    // WRITE RESPONSE CHANNEL SIGNALS
    m_axi_bid_o          = m_axi_awid_i;
    m_axi_bresp_o        = m_axi_lite_bresp_i;
    m_axi_bvalid_o       = '0;
    m_axi_lite_bready_o  = m_axi_bready_i;

    // other logic
    state_n              = state_r;
    waddr_n              = waddr_r;
    r_last_cnt_n         = '0;
    bresp_n              = '0;

    case (state_r)
      e_wait : begin
        if (m_axi_awvalid_i) begin
          state_n = e_write_tx;
          waddr_n = m_axi_awaddr_i;
        end

        else if (m_axi_arvalid_i) begin
          state_n = e_read_tx;
        end
      end

      e_write_tx : begin
        m_axi_lite_awaddr_o  = waddr_r;
        m_axi_lite_awvalid_o = 1'b1;

        bresp_n = (m_axi_lite_bvalid_i)
                ? (bresp_r | m_axi_lite_bresp_i)
                : bresp_r;

        waddr_n = (m_axi_wvalid_i & m_axi_lite_wready_i)
                ? waddr_r + (axi_data_width_p >> 3)
                : waddr_r; 
        
        state_n = (m_axi_wlast_i)
                ? e_write_resp
                : e_write_tx;
      end

      e_write_resp : begin
        m_axi_bvalid_o = m_axi_lite_bvalid_i;
        m_axi_bresp_o  = bresp_r;

        state_n = (m_axi_lite_bvalid_i)
                ? e_wait
                : e_write_resp;
      end

      e_read_tx : begin
        m_axi_rlast_o = (r_last_cnt_r == m_axi_arlen_i);
        r_last_cnt_n  = (m_axi_lite_rvalid_i)
                      ? r_last_cnt_r + 1
                      : r_last_cnt_r;
      end
    endcase
  end

  always_ff @(posedge aclk_i) begin
    if (~aresetn_i) begin
      state_r      <= e_wait;
      bresp_r      <= '0;
      r_last_cnt_r <= '0;
      waddr_r      <= '0;
    end

    else begin
      state_r      <= state_n;
      bresp_r      <= bresp_n;
      r_last_cnt_r <= r_last_cnt_n;
      waddr_r      <= waddr_n;
    end
  end
endmodule
module bp_lite_to_axi_lite_master

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
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, bp_in)

   // AXI WRITE DATA CHANNEL PARAMS
   , parameter  axi_data_width_p             = 32
   , localparam axi_strb_width_lp            = axi_data_width_p/8

   // AXI WRITE/READ ADDRESS CHANNEL PARAMS  
   , parameter axi_addr_width_p              = 32
   )

  (//==================== GLOBAL SIGNALS =======================
   input aclk_i  
   , input aresetn_i

   //==================== BP-LITE SIGNALS ======================
   , input [bp_in_mem_msg_width_lp-1:0]        io_cmd_i
   , input                                     io_cmd_v_i
   , output logic                              io_cmd_ready_o

   , output logic [bp_in_mem_msg_width_lp-1:0] io_resp_o
   , output logic                              io_resp_v_o
   , input                                     io_resp_yumi_i

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

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, bp_in);

  // io cmd and resp structure cast
  bp_bedrock_bp_in_mem_msg_s io_cmd_cast_i, io_resp_cast_o;

  assign io_cmd_cast_i = io_cmd_i;
  assign io_resp_o     = io_resp_cast_o;

  // storing io cmd header
  bp_bedrock_bp_in_mem_msg_header_s io_cmd_header_r;

  bsg_dff_reset_en
   #(.width_p(bp_in_mem_msg_header_width_lp))
   mem_header_reg
    (.clk_i(aclk_i)
    ,.reset_i(~aresetn_i)
    ,.en_i(io_cmd_v_i)
    ,.data_i(io_cmd_cast_i.header)
    ,.data_o(io_cmd_header_r)
    );

  // io cmd read/write validity
  logic io_cmd_w_v, io_cmd_r_v;

  assign io_cmd_w_v = io_cmd_v_i & (io_cmd_cast_i.header.msg_type == e_bedrock_mem_uc_wr);
  assign io_cmd_r_v = io_cmd_v_i & (io_cmd_cast_i.header.msg_type == e_bedrock_mem_uc_rd);

  // write strobe manipulation
  logic [axi_strb_width_lp-1:0] write_strb;

  // declaring all possible states
  typedef enum logic [2:0] {
    e_wait           = 3'b000
    ,e_read_addr_tx  = 3'b001
    ,e_read_data_tx  = 3'b010
    ,e_write_addr_tx = 3'b011
    ,e_write_data_tx = 3'b100
  } state_e;

  state_e state_r, state_n;

  // combinational Logic
  always_comb begin

    // BP IO
    io_cmd_ready_o        = '0;
    io_resp_cast_o        = '{header: io_cmd_header_r, data: '0};
    io_resp_v_o           = '0;

    // WRITE ADDRESS CHANNEL SIGNALS
    m_axi_lite_awaddr_o  = io_cmd_cast_i.header.addr[31:0];
    m_axi_lite_awprot_o  = '0;
    m_axi_lite_awvalid_o = io_cmd_w_v;

    // WRITE DATA CHANNEL SIGNALS
    m_axi_lite_wdata_o   = '0;
    m_axi_lite_wstrb_o   = '0;
    m_axi_lite_wvalid_o  = '0;

    // READ ADDRESS CHANNEL SIGNALS
    m_axi_lite_araddr_o  = io_cmd_cast_i.header.addr[31:0];
    m_axi_lite_arprot_o  = '0;
    m_axi_lite_arvalid_o = io_cmd_r_v;

    // READ DATA CHANNEL SIGNALS
    m_axi_lite_rready_o  = '0;

    // WRITE RESPONSE CHANNEL SIGNALS
    m_axi_lite_bready_o  = 1'b1;

    // other logic
    state_n    = state_r;
    write_strb = '1;

    case(state_r) 
      e_wait : begin
        // if the io_cmd write is valid and the client device is not ready to receive, 
        // transition to write address state
        if (io_cmd_w_v & ~m_axi_lite_awready_i) begin
          state_n = e_write_addr_tx;
        end
        
        // if the client device is ready to receive, send the data along with the address
        // this reduces a cycle if the write channel of the client device is ready to receive    
        else if (io_cmd_w_v & m_axi_lite_awready_i) begin
          io_cmd_ready_o      = m_axi_lite_wready_i;
     
          m_axi_lite_wdata_o  = io_cmd_cast_i.data[31:0];
          m_axi_lite_wvalid_o = io_cmd_v_i;
        
          write_strb          = write_strb << (axi_strb_width_lp - 2**io_cmd_header_r.size);
          write_strb          = write_strb >> (axi_strb_width_lp - 2**io_cmd_header_r.size);
          m_axi_lite_wstrb_o  = ((2**io_cmd_header_r.size) < axi_strb_width_lp)
                              ? write_strb
                              : '1;
          state_n = e_write_data_tx;
        end

        else if (io_cmd_r_v & ~m_axi_lite_arready_i) begin
          state_n = e_read_addr_tx;
        end
     
        // if bp io read is valid and client device read address channel is ready to receive
        // pass the valid read data to io_resp channel if io_resp is ready
        else if (io_cmd_r_v & m_axi_lite_arready_i) begin
          io_resp_v_o                               = m_axi_lite_rvalid_i;	
          io_resp_cast_o.data[axi_data_width_p-1:0] = (m_axi_lite_rresp_i == '0)
                                                    ? m_axi_lite_rdata_i
                                                    : {(axi_data_width_p-1){1'b1}};
          m_axi_lite_rready_o = io_resp_yumi_i;
          if (io_resp_yumi_i) begin
            state_n = e_wait;
          end          
          else begin
            state_n = e_read_data_tx;
          end
        end
      end

      // WRITE STATE
      e_write_addr_tx : begin 
        m_axi_lite_awaddr_o  = io_cmd_header_r.addr[31:0];
        m_axi_lite_awvalid_o = io_cmd_v_i;
        if (m_axi_lite_awready_i) begin
          state_n = e_write_data_tx;
        end
      end

      e_write_data_tx : begin
        io_cmd_ready_o      = m_axi_lite_wready_i;

        m_axi_lite_wdata_o  = io_cmd_cast_i.data[31:0];
        m_axi_lite_wvalid_o = io_cmd_v_i;

        write_strb          = write_strb << (axi_strb_width_lp - 2**io_cmd_header_r.size);
        write_strb          = write_strb >> (axi_strb_width_lp - 2**io_cmd_header_r.size);
        m_axi_lite_wstrb_o  = ((2**io_cmd_header_r.size) < axi_strb_width_lp)
                            ? write_strb
                            : '1;

        if (m_axi_lite_bvalid_i) begin
          io_resp_cast_o.data[31:0] = 32'hFFFF_FFFF;
          io_resp_v_o               = 1'b1;
          state_n                   = e_wait;
        end
      end

      // READ STATE
      e_read_addr_tx : begin
        m_axi_lite_araddr_o  = io_cmd_header_r.addr[31:0];
        m_axi_lite_arvalid_o = 1'b1;

        // if the client device is ready to accept the read addr/control info, move to read transaction state
        if (m_axi_lite_arready_i) begin
          state_n = e_read_data_tx;
        end
      end

     e_read_data_tx : begin
       io_resp_v_o                               = m_axi_lite_rvalid_i;	
       io_resp_cast_o.data[axi_data_width_p-1:0] = (m_axi_lite_rresp_i == '0)
                                                 ? m_axi_lite_rdata_i
                                                 : {(axi_data_width_p-1){1'b1}};
       m_axi_lite_rready_o = io_resp_yumi_i;

       if (io_resp_yumi_i) begin
         state_n = e_wait;
       end
     end
    endcase
  end

  // Sequential Logic
  always_ff @(posedge aclk_i) begin
    if (~aresetn_i) begin
      state_r <= e_wait;
    end
    else begin
      state_r <= state_n;
    end
  end

  //synopsys translate_off
  initial begin
    assert (axi_data_width_p==64 || axi_data_width_p==32) else $error("AXI4-LITE only supports a data width of 32 or 64bits");
    assert (m_axi_lite_bresp_i == '0) else $warning("Client device has an error response");
  end
  //synopsys translate_on
endmodule
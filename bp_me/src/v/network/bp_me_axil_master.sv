
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_axil_master
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)

  // AXI WRITE DATA CHANNEL PARAMS
  , parameter axil_data_width_p = 32
  , parameter axil_addr_width_p  = 32
  )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i

  //==================== BP-LITE SIGNALS ======================
  , input [cce_mem_header_width_lp-1:0]        io_cmd_header_i
  , input [axil_data_width_p-1:0]              io_cmd_data_i
  , input                                      io_cmd_v_i
  , output logic                               io_cmd_ready_and_o

  , output logic [cce_mem_header_width_lp-1:0] io_resp_header_o
  , output logic [axil_data_width_p-1:0]       io_resp_data_o
  , output logic                               io_resp_v_o
  , input                                      io_resp_ready_and_i

  //====================== AXI-4 LITE =========================
  // WRITE ADDRESS CHANNEL SIGNALS
  , output logic [axil_addr_width_p-1:0]       m_axil_awaddr_o
  , output axi_prot_type_e                     m_axil_awprot_o
  , output logic                               m_axil_awvalid_o
  , input                                      m_axil_awready_i

  // WRITE DATA CHANNEL SIGNALS
  , output logic [axil_data_width_p-1:0]       m_axil_wdata_o
  , output logic [(axil_data_width_p>>3)-1:0]  m_axil_wstrb_o
  , output logic                               m_axil_wvalid_o
  , input                                      m_axil_wready_i

  // WRITE RESPONSE CHANNEL SIGNALS
  , input axi_resp_type_e                      m_axil_bresp_i
  , input                                      m_axil_bvalid_i
  , output logic                               m_axil_bready_o

  // READ ADDRESS CHANNEL SIGNALS
  , output logic [axil_addr_width_p-1:0]       m_axil_araddr_o
  , output axi_prot_type_e                     m_axil_arprot_o
  , output logic                               m_axil_arvalid_o
  , input                                      m_axil_arready_i

  // READ DATA CHANNEL SIGNALS
  , input [axil_data_width_p-1:0]              m_axil_rdata_i
  , input axi_resp_type_e                      m_axil_rresp_i
  , input                                      m_axil_rvalid_i
  , output logic                               m_axil_rready_o
  );

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);
  `bp_cast_i(bp_bedrock_cce_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_cce_mem_header_s, io_resp_header);

  // declaring all possible states
  enum {e_ready, e_read_data_tx, e_write_data_tx, e_write_resp_rx} state_r, state_n;

  // storing io cmd header
  bp_bedrock_cce_mem_header_s io_cmd_header_r;
  bsg_dff_reset_en
   #(.width_p(cce_mem_header_width_lp))
   mem_header_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i((io_cmd_ready_and_o & io_cmd_v_i))
    ,.data_i(io_cmd_header_cast_i)
    ,.data_o(io_cmd_header_r)
    );

  // combinational Logic
  always_comb
    begin
      state_n = state_r;

      io_cmd_ready_and_o    = 1'b0;
      io_resp_header_cast_o = io_cmd_header_r;
      io_resp_data_o        = m_axil_rdata_i;
      io_resp_v_o           = '0;

      // WRITE ADDRESS CHANNEL SIGNALS
      m_axil_awaddr_o  = io_cmd_header_cast_i.addr[0+:axil_addr_width_p];
      m_axil_awprot_o  = e_axi_prot_default;
      m_axil_awvalid_o = 1'b0;

      // WRITE DATA CHANNEL SIGNALS
      m_axil_wdata_o   = io_cmd_data_i;
      m_axil_wvalid_o  = 1'b0;

      // READ ADDRESS CHANNEL SIGNALS
      m_axil_araddr_o  = io_cmd_header_cast_i.addr[0+:axil_addr_width_p];
      m_axil_arprot_o  = e_axi_prot_default;
      m_axil_arvalid_o = 1'b0;

      // READ DATA CHANNEL SIGNALS
      m_axil_rready_o  = 1'b0;

      // WRITE RESPONSE CHANNEL SIGNALS
      m_axil_bready_o  = 1'b0;

      case (io_cmd_header_cast_i.size)
        e_bedrock_msg_size_1 : m_axil_wstrb_o = (axil_data_width_p>>3)'('h1);
        e_bedrock_msg_size_2 : m_axil_wstrb_o = (axil_data_width_p>>3)'('h3);
        e_bedrock_msg_size_4 : m_axil_wstrb_o = (axil_data_width_p>>3)'('hF);
        e_bedrock_msg_size_8 : m_axil_wstrb_o = (axil_data_width_p>>3)'('hFF);
        default              : m_axil_wstrb_o = (axil_data_width_p>>3)'('h0);
      endcase

      case (state_r)
        e_ready:
          begin
            // if the client device is ready to receive, send the data along with the address
            if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_wr))
              begin
                m_axil_awvalid_o   = 1'b1;
                m_axil_wvalid_o    = 1'b1;
                io_cmd_ready_and_o = m_axil_awready_i;

                state_n = (m_axil_wready_i & m_axil_wvalid_o)
                  ? e_write_resp_rx
                  : (m_axil_awready_i & m_axil_awvalid_o)
                    ? e_write_data_tx
                    : e_ready;
              end

            // if the io_cmd read is valid and client device read address channel is ready to receive
            // pass the valid read data to io_resp channel if io_resp is ready
            else if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_rd))
              begin
                m_axil_arvalid_o   = 1'b1;
                io_resp_v_o        = m_axil_rvalid_i;
                m_axil_rready_o    = io_resp_ready_and_i;
                io_cmd_ready_and_o = m_axil_arready_i;

                state_n = (m_axil_rready_o & m_axil_rvalid_i)
                          ? e_ready
                          : (m_axil_arready_i & m_axil_arvalid_o)
                            ? e_read_data_tx
                            : e_ready;
              end
          end

        e_write_data_tx:
          begin
            m_axil_wvalid_o    = 1'b1;
            io_cmd_ready_and_o = m_axil_wready_i;

            state_n = (m_axil_wready_i & m_axil_wvalid_o) ? e_ready : e_write_data_tx;
          end

        e_write_resp_rx:
          begin
            m_axil_bready_o = io_resp_ready_and_i;
            io_resp_v_o     = m_axil_bvalid_i;

            state_n     = (io_resp_ready_and_i & io_resp_v_o) ? e_ready : state_r;
          end

       e_read_data_tx:
         begin
           m_axil_rready_o = io_resp_ready_and_i;
           io_resp_v_o     = m_axil_rvalid_i;

           state_n = (io_resp_ready_and_i & io_resp_v_o) ? e_ready : state_r;
         end

        default: state_n = state_r;
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    begin
      if (reset_i)
        state_r <= e_ready;
      else
        state_r <= state_n;
    end

  //synopsys translate_off
  initial
    begin
      assert (axil_data_width_p==64 || axil_data_width_p==32) else $error("AXI4-LITE only supports a data width of 32 or 64bits");
      // give a warning if the client device has an error response
      if (m_axil_rvalid_i)
        assert (m_axil_rresp_i == '0) else $warning("Client device has an error response to reads");
      if (m_axil_bvalid_i)
        assert (m_axil_bresp_i == '0) else $warning("Client device has an error response to writes");
    end
  //synopsys translate_on

endmodule

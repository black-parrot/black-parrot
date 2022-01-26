
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

// This module is a minimal axi-lite master, supporting a single outgoing request.
// It could be extended to support pipelined accesses by adding input skid
//   buffers at the cost of additional area.

module bp_me_axil_master
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)

  , parameter io_data_width_p = multicore_p ? cce_block_width_p : uce_fill_width_p
  // AXI WRITE DATA CHANNEL PARAMS
  , parameter axil_data_width_p = 32
  , parameter axil_addr_width_p  = 32
  )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i

  //==================== BP-LITE SIGNALS ======================
  , input [cce_mem_header_width_lp-1:0]        io_cmd_header_i
  , input [io_data_width_p-1:0]                io_cmd_data_i
  , input                                      io_cmd_v_i
  , output logic                               io_cmd_yumi_o

  , output logic [cce_mem_header_width_lp-1:0] io_resp_header_o
  , output logic [io_data_width_p-1:0]         io_resp_data_o
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
  enum {e_ready, e_read_data_rx, e_write_data_tx, e_write_addr_tx, e_write_resp_rx} state_n, state_r;
  wire is_ready         = (state_r == e_ready);
  wire is_read_data_rx  = (state_r == e_read_data_rx);
  wire is_write_data_tx = (state_r == e_write_data_tx);
  wire is_write_addr_tx = (state_r == e_write_addr_tx);
  wire is_write_resp_rx = (state_r == e_write_resp_rx);

  localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(axil_data_width_p>>3);
  localparam size_width_lp = `BSG_WIDTH(byte_offset_width_lp);

  wire [byte_offset_width_lp-1:0] resp_sel_li = io_cmd_header_cast_i.addr[0+:byte_offset_width_lp];
  wire [size_width_lp-1:0] resp_size_li = io_cmd_header_cast_i.size;
  bsg_bus_pack
   #(.in_width_p(axil_data_width_p), .out_width_p(io_data_width_p))
   resp_data_bus_pack
    (.data_i(m_axil_rdata_i)
     ,.sel_i(resp_sel_li)
     ,.size_i(resp_size_li)
     ,.data_o(io_resp_data_o)
     );

  // combinational Logic
  always_comb
    begin
      state_n = state_r;

      io_cmd_yumi_o         = 1'b0;
      io_resp_header_cast_o = io_cmd_header_cast_i;
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
        // e_bedrock_msg_size_8 :
        default : m_axil_wstrb_o = (axil_data_width_p>>3)'('hFF);
      endcase

      case (state_r)
        e_ready:
          begin
            // if the client device is ready to receive, send the data along with the address
            if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr}))
              begin
                m_axil_awvalid_o   = 1'b1;
                m_axil_wvalid_o    = 1'b1;

                state_n = (m_axil_awready_i & m_axil_wready_i)
                  ? e_write_resp_rx
                  : m_axil_awready_i
                    ? e_write_data_tx
                    : m_axil_wready_i
                      ? e_write_addr_tx
                      : e_ready;
              end

            // if the io_cmd read is valid and client device read address channel is ready to receive
            // pass the valid read data to io_resp channel if io_resp is ready
            else if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd}))
              begin
                m_axil_arvalid_o = 1'b1;

                state_n = m_axil_arready_i ? e_read_data_rx : e_ready;
              end
          end

        e_write_data_tx:
          begin
            m_axil_wvalid_o = 1'b1;

            state_n = m_axil_wready_i ? e_write_resp_rx : e_write_data_tx;
          end

        e_write_addr_tx:
          begin
            m_axil_awvalid_o = 1'b1;

            state_n = m_axil_awready_i ? e_write_resp_rx : e_write_data_tx;
          end

        e_write_resp_rx:
          begin
            m_axil_bready_o = io_resp_ready_and_i;
            io_resp_v_o     = m_axil_bvalid_i;
            io_cmd_yumi_o   = (io_resp_ready_and_i & io_resp_v_o);

            state_n = io_cmd_yumi_o ? e_ready : e_write_resp_rx;
          end

       e_read_data_rx:
         begin
           m_axil_rready_o = io_resp_ready_and_i;
           io_resp_v_o     = m_axil_rvalid_i;
           io_cmd_yumi_o   = (io_resp_ready_and_i & io_resp_v_o);

           state_n = io_cmd_yumi_o ? e_ready : e_read_data_rx;
         end

        default : begin end
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

  if (axil_data_width_p != 32 && axil_data_width_p != 64)
    $error("AXI4-LITE only supports a data width of 32 or 64 bits");

  if (io_data_width_p < axil_data_width_p)
    $error("I/O data width must be at least AXI4-LITE data width");

  //synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      // give a warning if the client device has an error response
      assert (reset_i !== '0 || ~m_axil_rvalid_i || m_axil_rresp_i == '0) else $error("Client device has an error response to reads");
      assert (reset_i !== '0 || ~m_axil_bvalid_i || m_axil_bresp_i == '0) else $error("Client device has an error response to writes");
    end
  //synopsys translate_on

endmodule

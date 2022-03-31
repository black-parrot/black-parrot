/*
 * Name:
 *  bp_me_burst_to_axil.sv
 *
 * Description:
 *  This module converts an BP Bedrock Burst Command In / Response Out
 *  to an AXI4-Lite Manager interface. This module is a minimal AXI4-Lite
 *  Manager, supporting one request at a time. IO write commands are
 *  restricted to single data beat writes.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_burst_to_axil
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
  , parameter io_data_width_p = (cce_type_p == e_cce_uce) ? uce_fill_width_p : bedrock_data_width_p

  , parameter axil_data_width_p = 32
  , parameter axil_addr_width_p  = 32
  )
 (//==================== GLOBAL SIGNALS =======================
  input                                        clk_i
  , input                                      reset_i

  //==================== BP-BURST SIGNALS =====================
  , input [mem_header_width_lp-1:0]            io_cmd_header_i
  , input                                      io_cmd_header_v_i
  , input                                      io_cmd_has_data_i
  , output logic                               io_cmd_header_ready_and_o
  , input [io_data_width_p-1:0]                io_cmd_data_i
  , input                                      io_cmd_data_v_i
  , input                                      io_cmd_last_i
  , output logic                               io_cmd_data_ready_and_o

  , output logic [mem_header_width_lp-1:0]     io_resp_header_o
  , output logic                               io_resp_header_v_o
  , output logic                               io_resp_has_data_o
  , input                                      io_resp_header_ready_and_i
  , output logic [io_data_width_p-1:0]         io_resp_data_o
  , output logic                               io_resp_data_v_o
  , output logic                               io_resp_last_o
  , input                                      io_resp_data_ready_and_i

  //====================== AXI4-LITE ==========================
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
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_resp_header);

  // command header buffer
  bp_bedrock_mem_header_s io_cmd_header_li;
  logic io_cmd_has_data_li;
  bsg_dff_reset_en
   #(.width_p($bits(bp_bedrock_mem_header_s)+1))
   cmd_header_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({io_cmd_has_data_i, io_cmd_header_cast_i})
     ,.en_i(io_cmd_header_v_i & io_cmd_header_ready_and_o)
     ,.data_o({io_cmd_has_data_li, io_cmd_header_li})
     );

  // read data out select
  localparam byte_offset_width_lp = `BSG_SAFE_CLOG2(axil_data_width_p>>3);
  localparam size_width_lp = `BSG_WIDTH(byte_offset_width_lp);
  wire [byte_offset_width_lp-1:0] resp_sel_li = io_cmd_header_li.addr[0+:byte_offset_width_lp];
  wire [size_width_lp-1:0] resp_size_li = io_cmd_header_li.size;
  bsg_bus_pack
   #(.in_width_p(axil_data_width_p), .out_width_p(io_data_width_p))
   resp_data_bus_pack
    (.data_i(m_axil_rdata_i)
     ,.sel_i(resp_sel_li)
     ,.size_i(resp_size_li)
     ,.data_o(io_resp_data_o)
     );

  // declaring all possible states
  typedef enum logic [2:0]
  {
    e_ready
    , e_read_addr
    , e_read_header
    , e_read_data
    , e_write_addr_and_data
    , e_write_addr
    , e_write_data
    , e_write_resp
  } state_e;
  state_e state_n, state_r;

  // combinational Logic
  always_comb
    begin
      state_n = state_r;

      io_cmd_header_ready_and_o = 1'b0;
      io_cmd_data_ready_and_o = 1'b0;

      io_resp_header_v_o = 1'b0;
      io_resp_header_cast_o = io_cmd_header_li;
      // response has data is opposite of command has data
      io_resp_has_data_o = ~io_cmd_has_data_li;
      io_resp_data_v_o = 1'b0;
      io_resp_last_o = 1'b1;

      // WRITE ADDRESS CHANNEL SIGNALS
      m_axil_awaddr_o  = io_cmd_header_li.addr[0+:axil_addr_width_p];
      m_axil_awprot_o  = e_axi_prot_default;
      m_axil_awvalid_o = 1'b0;

      // WRITE DATA CHANNEL SIGNALS
      m_axil_wdata_o   = io_cmd_data_i;
      m_axil_wvalid_o  = 1'b0;

      // READ ADDRESS CHANNEL SIGNALS
      m_axil_araddr_o  = io_cmd_header_li.addr[0+:axil_addr_width_p];
      m_axil_arprot_o  = e_axi_prot_default;
      m_axil_arvalid_o = 1'b0;

      // READ DATA CHANNEL SIGNALS
      m_axil_rready_o  = 1'b0;

      // WRITE RESPONSE CHANNEL SIGNALS
      m_axil_bready_o  = 1'b0;

      case (io_cmd_header_li.size)
        e_bedrock_msg_size_1 : m_axil_wstrb_o = (axil_data_width_p>>3)'('h1);
        e_bedrock_msg_size_2 : m_axil_wstrb_o = (axil_data_width_p>>3)'('h3);
        e_bedrock_msg_size_4 : m_axil_wstrb_o = (axil_data_width_p>>3)'('hF);
        // e_bedrock_msg_size_8 :
        default : m_axil_wstrb_o = (axil_data_width_p>>3)'('hFF);
      endcase

      case (state_r)
        // consume io cmd
        e_ready: begin
          io_cmd_header_ready_and_o = 1'b1;
          state_n = (io_cmd_header_v_i & io_cmd_header_ready_and_o)
                    ? io_cmd_has_data_i
                      ? e_write_addr_and_data
                      : e_read_addr
                    : state_r;
        end

        // send write address and data
        // subordinate is allowed to wait for both to be valid
        e_write_addr_and_data: begin
          m_axil_awvalid_o = 1'b1;
          m_axil_wvalid_o = io_cmd_data_v_i;
          io_cmd_data_ready_and_o = m_axil_wready_i;
          state_n = (m_axil_awvalid_o & m_axil_awready_i) & (m_axil_wvalid_o & m_axil_wready_i)
                    ? e_write_resp
                    : (m_axil_awvalid_o & m_axil_awready_i)
                      ? e_write_data
                      : (m_axil_wvalid_o & m_axil_wready_i)
                        ? e_write_addr
                        : state_r;
        end

        // send write address, data already sent
        e_write_addr: begin
          m_axil_awvalid_o = 1'b1;
          state_n = m_axil_awready_i ? e_write_resp : state_r;
        end

        // send write data, address already sent
        e_write_data: begin
          m_axil_wvalid_o = 1'b1;
          io_cmd_data_ready_and_o = m_axil_wready_i;
          state_n = m_axil_wready_i ? e_write_resp : state_r;
        end

        // consume write response, issue response header
        e_write_resp: begin
          m_axil_bready_o = io_resp_header_ready_and_i;
          io_resp_header_v_o = m_axil_bvalid_i;
          state_n = (io_resp_header_v_o & io_resp_header_ready_and_i)
                    ? e_ready
                    : state_r;
        end

        // send read address
        e_read_addr: begin
          m_axil_arvalid_o = 1'b1;
          state_n = m_axil_arready_i ? e_read_header : state_r;
        end

        // send read response header
        e_read_header: begin
          io_resp_header_v_o = 1'b1;
          state_n = (io_resp_header_v_o & io_resp_header_ready_and_i)
                    ? e_read_data
                    : state_r;
        end

        // consume read data, issue response data
        e_read_data: begin
          m_axil_rready_o = io_resp_data_ready_and_i;
          io_resp_data_v_o = m_axil_rvalid_i;
          state_n = (io_resp_data_v_o & io_resp_data_ready_and_i)
                    ? e_ready
                    : state_r;
        end

        default : begin end
      endcase
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_ready;
    end
    else begin
      state_r <= state_n;
    end
  end

  if (axil_data_width_p != 32 && axil_data_width_p != 64)
    $error("AXI4-LITE only supports a data width of 32 or 64 bits");

  if (io_data_width_p < axil_data_width_p)
    $error("I/O data width must be at least AXI4-LITE data width");

  //synopsys translate_off
  initial begin
    $display("## bp_me_burst_to_axil: instantiating with axil_data_width_p=%d, axil_addr_width_p=%d (%m)\n",axil_data_width_p,axil_addr_width_p);
  end

  always_ff @(negedge clk_i) begin
    // give a warning if the client device has an error response
    assert (reset_i !== '0 || ~m_axil_rvalid_i || m_axil_rresp_i == '0)
      else $error("Client device has an error response to reads");
    assert (reset_i !== '0 || ~m_axil_bvalid_i || m_axil_bresp_i == '0)
      else $error("Client device has an error response to writes");
    assert (reset_i !== '0 || ~io_cmd_header_v_i
            || io_cmd_header_cast_i.size <= e_bedrock_msg_size_8
            || axil_data_width_p == 64)
      else $error("64-bit BedRock command not supported with 32-bit AXIL data width");
    assert (reset_i !== '0 || ~io_cmd_header_v_i
            || (io_cmd_header_cast_i.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd} && ~io_cmd_has_data_i)
            || (io_cmd_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr} && io_cmd_has_data_i)
           )
      else $error("BedRock command type and has data signal inconsistent");
    assert (reset_i !== '0 || ~io_cmd_data_v_i || io_cmd_last_i)
      else $error("BedRock command data must be single beat");
  end
  //synopsys translate_on

endmodule

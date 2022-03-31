/*
 * Name:
 *  bp_me_axil_to_burst.sv
 *
 * Description:
 *  This module converts an AXI4-Lite Subordinate interface to
 *  BP BedRock Burst Command Out / Response In. This module is a
 *  minimal AXI4-Lite Subordinate, and assumes IO responses are
 *  returned in order with respect to IO commands issued.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_axil_to_burst
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
  , parameter io_data_width_p = (cce_type_p == e_cce_uce) ? uce_fill_width_p : bedrock_data_width_p

  , parameter axil_data_width_p = 32
  , parameter axil_addr_width_p = 32
  )

  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== BP-BURST SIGNALS =====================
   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , output logic [mem_header_width_lp-1:0]     io_cmd_header_o
   , output logic                               io_cmd_header_v_o
   , output logic                               io_cmd_has_data_o
   , input                                      io_cmd_header_ready_and_i
   , output logic [io_data_width_p-1:0]         io_cmd_data_o
   , output logic                               io_cmd_data_v_o
   , output logic                               io_cmd_last_o
   , input                                      io_cmd_data_ready_and_i

   , input [mem_header_width_lp-1:0]            io_resp_header_i
   , input                                      io_resp_header_v_i
   , input                                      io_resp_has_data_i
   , output logic                               io_resp_header_ready_and_o
   , input [io_data_width_p-1:0]                io_resp_data_i
   , input                                      io_resp_data_v_i
   , input                                      io_resp_last_i
   , output logic                               io_resp_data_ready_and_o

   //====================== AXI4-LITE ==========================
   // WRITE ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_awaddr_i
   , input axi_prot_type_e                      s_axil_awprot_i
   , input                                      s_axil_awvalid_i
   , output logic                               s_axil_awready_o

   // WRITE DATA CHANNEL SIGNALS
   , input [axil_data_width_p-1:0]              s_axil_wdata_i
   , input [(axil_data_width_p>>3)-1:0]         s_axil_wstrb_i
   , input                                      s_axil_wvalid_i
   , output logic                               s_axil_wready_o

   // WRITE RESPONSE CHANNEL SIGNALS
   , output axi_resp_type_e                     s_axil_bresp_o
   , output logic                               s_axil_bvalid_o
   , input                                      s_axil_bready_i

   // READ ADDRESS CHANNEL SIGNALS
   , input [axil_addr_width_p-1:0]              s_axil_araddr_i
   , input axi_prot_type_e                      s_axil_arprot_i
   , input                                      s_axil_arvalid_i
   , output logic                               s_axil_arready_o

   // READ DATA CHANNEL SIGNALS
   , output logic [axil_data_width_p-1:0]       s_axil_rdata_o
   , output axi_resp_type_e                     s_axil_rresp_o
   , output logic                               s_axil_rvalid_o
   , input                                      s_axil_rready_i
  );

  wire unused = &{s_axil_awprot_i, s_axil_arprot_i, io_resp_has_data_i, io_resp_last_i};

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, io_resp_header);

  // buffer response headers for s_axil_rresp_o and saxil_bresp_o arbitration
  bp_bedrock_mem_header_s io_resp_header_li;
  logic io_resp_header_v_li, io_resp_header_yumi_lo;
  bsg_two_fifo
   #(.width_p($bits(bp_bedrock_mem_header_s)))
   resp_header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(io_resp_header_v_i)
     ,.data_i(io_resp_header_cast_i)
     ,.ready_o(io_resp_header_ready_and_o)
     ,.v_o(io_resp_header_v_li)
     ,.data_o(io_resp_header_li)
     ,.yumi_i(io_resp_header_yumi_lo)
     );

  // Declaring all possible states
  typedef enum logic [1:0]
  {
    e_ready
    , e_write_addr_rx
    , e_write_data_rx
    , e_read_addr_rx
  } state_e;
  state_e state_n, state_r;

  bp_bedrock_msg_size_e wsize, rsize;
  always_comb
    case (s_axil_wstrb_i)
      (axil_data_width_p>>3)'('h1): wsize = e_bedrock_msg_size_1;
      (axil_data_width_p>>3)'('h3): wsize = e_bedrock_msg_size_2;
      (axil_data_width_p>>3)'('hF): wsize = e_bedrock_msg_size_4;
      // (axil_data_width_p>>3)'('hFF):
      default: wsize = e_bedrock_msg_size_8;
    endcase

  // read accesses are sized by AXI4-Lite data bus size
  assign rsize = (axil_data_width_p == 64) ? e_bedrock_msg_size_8 : e_bedrock_msg_size_4;

  // AXIL read/write to IO command out
  always_comb begin
    state_n = state_r;

    // BP side
    io_cmd_header_v_o                   = 1'b0;
    io_cmd_has_data_o                   = 1'b0;
    io_cmd_header_cast_o                = '0;
    io_cmd_header_cast_o.payload.lce_id = lce_id_i;
    io_cmd_header_cast_o.payload.did    = did_i;
    io_cmd_data_v_o                     = 1'b0;
    io_cmd_last_o                       = 1'b1;
    io_cmd_data_o                       = s_axil_wdata_i;

    // WRITE ADDRESS CHANNEL SIGNALS
    s_axil_awready_o = '0;

    // WRITE DATA CHANNEL SIGNALS
    s_axil_wready_o  = '0;

    // READ ADDRESS CHANNEL SIGNALS
    s_axil_arready_o = '0;

    unique case (state_r)
      // check for incoming write or read, prioritize write
      e_ready: begin
        state_n = s_axil_awvalid_i
                  ? e_write_addr_rx
                  : s_axil_arvalid_i
                    ? e_read_addr_rx
                    : state_r;
      end

      // send IO write command
      e_write_addr_rx: begin
        io_cmd_header_cast_o.addr     = s_axil_awaddr_i;
        io_cmd_header_cast_o.msg_type = e_bedrock_mem_uc_wr;
        io_cmd_header_cast_o.size     = wsize;
        io_cmd_header_v_o             = s_axil_awvalid_i;
        io_cmd_has_data_o             = 1'b1;
        s_axil_awready_o              = io_cmd_header_ready_and_i;
        state_n = (io_cmd_header_v_o & io_cmd_header_ready_and_i)
                  ? e_write_data_rx
                  : state_r;
      end

      // send IO write data
      e_write_data_rx: begin
        io_cmd_data_v_o = s_axil_wvalid_i;
        s_axil_wready_o = io_cmd_data_ready_and_i;
        state_n = (io_cmd_data_v_o & io_cmd_data_ready_and_i)
                  ? e_ready
                  : state_r;
      end

      // send IO read command
      e_read_addr_rx: begin
        io_cmd_header_cast_o.addr     = s_axil_araddr_i;
        io_cmd_header_cast_o.msg_type = e_bedrock_mem_uc_rd;
        io_cmd_header_cast_o.size     = rsize;
        io_cmd_header_v_o             = s_axil_arvalid_i;
        s_axil_arready_o              = io_cmd_header_ready_and_i;
        state_n = (io_cmd_header_v_o & io_cmd_header_ready_and_i)
                  ? e_ready
                  : state_r;
      end

      default: begin end
    endcase
  end

  // IO response in to AXIL rd/wr response
  always_comb begin

    // read responses have data, send if header and data ready
    // consume response data only if header also valid in buffer
    s_axil_rresp_o  = e_axi_resp_okay;
    s_axil_rdata_o  = io_resp_data_i;
    s_axil_rvalid_o = io_resp_header_v_li & io_resp_data_v_i
                      & io_resp_header_li.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd};
    io_resp_data_ready_and_o = io_resp_header_v_li & s_axil_rready_i;

    // write responses have no data, send if header is write response
    s_axil_bresp_o  = e_axi_resp_okay;
    s_axil_bvalid_o = io_resp_header_v_li
                      & io_resp_header_li.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr};

    io_resp_header_yumi_lo = (s_axil_rvalid_o & s_axil_rready_i) | (s_axil_bvalid_o & s_axil_bready_i);
  end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

  if (axil_data_width_p != 64 && axil_data_width_p != 32)
    $error("AXI4-LITE only supports a data width of 32 or 64 bits.");

  if (io_data_width_p < axil_data_width_p)
    $error("I/O data width must be at least AXI4-LITE data width");

  //synopsys translate_off
  initial begin
    $display("## bp_me_axil_to_burst: instantiating with axil_data_width_p=%d, axil_addr_width_p=%d (%m)\n",axil_data_width_p,axil_addr_width_p);
  end

  always_ff @(negedge clk_i) begin
    assert (reset_i !== '0 || s_axil_awprot_i == 3'b000)
      else $error("AXI4-LITE access permission mode is not supported.");
    assert (reset_i !== '0 || ~s_axil_wvalid_i || (s_axil_wstrb_i inside {'h1, 'h3, 'hf, 'hff}))
      else $error("Invalid write strobe encountered");
    assert (reset_i !== '0 || ~io_resp_header_v_i
            || io_resp_header_cast_i.size <= e_bedrock_msg_size_8
            || axil_data_width_p == 64)
      else $error("64-bit BedRock response not supported with 32-bit AXIL data width");
    assert (reset_i !== '0 || ~io_resp_header_v_i
            || (io_resp_header_cast_i.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd} && io_resp_has_data_i)
            || (io_resp_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr} && ~io_resp_has_data_i)
           )
      else $error("BedRock response type and has data signal inconsistent");
    assert (reset_i !== '0 || ~io_resp_data_v_i || io_resp_last_i)
      else $error("BedRock response data must be single beat");
  end
  // synopsys translate_on

endmodule


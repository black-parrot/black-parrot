
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_axil_client
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce)

  // AXI CHANNEL PARAMS
  , parameter axil_data_width_p = 32
  , parameter axil_addr_width_p = 32
  )

  (//==================== GLOBAL SIGNALS =======================
   input                                        clk_i
   , input                                      reset_i

   //==================== BP-LITE SIGNALS ======================
   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , output logic [cce_mem_header_width_lp-1:0] io_cmd_header_o
   , output logic [axil_data_width_p-1:0]       io_cmd_data_o
   , output logic                               io_cmd_v_o
   , input                                      io_cmd_ready_and_i

   , input [cce_mem_header_width_lp-1:0]        io_resp_header_i
   , input [axil_data_width_p-1:0]              io_resp_data_i
   , input                                      io_resp_v_i
   , output logic                               io_resp_yumi_o

   //====================== AXI-4 LITE =========================
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

  wire unused = &{s_axil_awprot_i, s_axil_arprot_i};

  // declaring i/o command and response struct type and size
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p, cce);
  `bp_cast_o(bp_bedrock_cce_mem_header_s, io_cmd_header);
  `bp_cast_i(bp_bedrock_cce_mem_header_s, io_resp_header);

  // Declaring all possible states
  enum {e_ready, e_send_read_addr, e_send_write_addr, e_send_write_data} state_n, state_r;
  wire is_ready = (state_r == e_ready);
  wire is_send_read_addr = (state_r == e_send_read_addr);
  wire is_send_write_addr = (state_r == e_send_write_addr);
  wire is_send_write_data = (state_r == e_send_write_addr);

  // AW buffer
  logic [axil_addr_width_p-1:0] s_axil_awaddr_r;
  bsg_dff_en_bypass
   #(.width_p(axil_addr_width_p))
   awaddr_reg
    (.clk_i(clk_i)
     ,.en_i(s_axil_awready_o & s_axil_awvalid_i)
     ,.data_i(s_axil_awaddr_i)
     ,.data_o(s_axil_awaddr_r)
     );

  // W buffer
  logic [axil_data_width_p-1:0] s_axil_wdata_r;
  bsg_dff_en_bypass
   #(.width_p(axil_data_width_p))
   wdata_reg
    (.clk_i(clk_i)
     ,.en_i(s_axil_wready_o & s_axil_wvalid_i)
     ,.data_i(s_axil_wdata_i)
     ,.data_o(s_axil_wdata_r)
     );

  // Command Logic
  always_comb
    begin
      state_n = state_r;

      // BP side
      io_cmd_header_cast_o      = '0;
      io_cmd_data_o             = s_axil_wdata_r;
      io_cmd_v_o                = '0;

      // WRITE ADDRESS CHANNEL SIGNALS
      s_axil_awready_o = '0;

      // WRITE DATA CHANNEL SIGNALS
      s_axil_wready_o  = '0;

      // READ ADDRESS CHANNEL SIGNALS
      s_axil_arready_o = '0;

      case (s_axil_wstrb_i)
        (axil_data_width_p>>3)'('h1)  : io_cmd_header_cast_o.size = e_bedrock_msg_size_1;
        (axil_data_width_p>>3)'('h3)  : io_cmd_header_cast_o.size = e_bedrock_msg_size_2;
        (axil_data_width_p>>3)'('hF)  : io_cmd_header_cast_o.size = e_bedrock_msg_size_4;
        (axil_data_width_p>>3)'('hFF) : io_cmd_header_cast_o.size = e_bedrock_msg_size_8;
        default:
          // does nothing in verilator 4.202
          `BSG_HIDE_FROM_VERILATOR(assert final (reset_i !== '0 || s_axil_wvalid_i == 0) else)
           if (s_axil_wvalid_i)
              $warning("%m: received unhandled strobe pattern %b\n",s_axil_wstrb_i);
      endcase

      unique casez (state_r)
        // Can send writes immediately if both aw/w are available, else read/write with 1 cycle delay
        e_ready:
          begin
            s_axil_awready_o = io_cmd_ready_and_i;
            s_axil_wready_o = io_cmd_ready_and_i;

            io_cmd_header_cast_o.addr                = s_axil_awaddr_r;
            io_cmd_header_cast_o.msg_type            = e_bedrock_mem_uc_wr;
            io_cmd_header_cast_o.payload.lce_id      = lce_id_i;
            io_cmd_header_cast_o.payload.did         = did_i;
            io_cmd_v_o                               = (s_axil_awvalid_i & s_axil_wvalid_i);

            // Send          
            state_n = (s_axil_awvalid_i & ~s_axil_wvalid_i)
                      ? e_send_write_data
                      : (~s_axil_awvalid_i & s_axil_wvalid_i)
                        ? e_send_write_addr
                        : s_axil_arvalid_i
                          ? e_send_read_addr
                          : e_ready;
          end

        e_send_read_addr:
          begin
            s_axil_arready_o = io_cmd_ready_and_i;

            io_cmd_header_cast_o.addr                = s_axil_araddr_i;
            io_cmd_header_cast_o.msg_type            = e_bedrock_mem_uc_rd;
            io_cmd_header_cast_o.payload.lce_id      = lce_id_i;
            io_cmd_header_cast_o.payload.did         = did_i;
            io_cmd_v_o                               = s_axil_arvalid_i;

            state_n = (io_cmd_ready_and_i & io_cmd_v_o) ? e_ready : e_send_read_addr;
          end

        e_send_write_data:
          begin
            s_axil_wready_o = io_cmd_ready_and_i;
           
            io_cmd_header_cast_o.addr                = s_axil_awaddr_r;
            io_cmd_header_cast_o.msg_type            = e_bedrock_mem_uc_wr;
            io_cmd_header_cast_o.payload.lce_id      = lce_id_i;
            io_cmd_header_cast_o.payload.did         = did_i;
            io_cmd_v_o                               = s_axil_wvalid_i;

            state_n = (io_cmd_ready_and_i & io_cmd_v_o) ? e_ready : e_send_write_data;
          end

        e_send_write_addr:
          begin
            s_axil_awready_o = io_cmd_ready_and_i;

            io_cmd_header_cast_o.addr                = s_axil_awaddr_r;
            io_cmd_header_cast_o.msg_type            = e_bedrock_mem_uc_wr;
            io_cmd_header_cast_o.payload.lce_id      = lce_id_i;
            io_cmd_header_cast_o.payload.did         = did_i;
            io_cmd_v_o                               = s_axil_awvalid_i;

            state_n = (io_cmd_ready_and_i & io_cmd_v_o) ? e_ready : e_send_write_addr;
          end

        default: state_n = state_r;
      endcase
    end

  // Resp logic, redirect responses based on type
  always_comb
    begin
      s_axil_rresp_o  = e_axi_resp_okay;
      s_axil_rdata_o  = io_resp_data_i;
      s_axil_rvalid_o = io_resp_v_i & io_resp_header_cast_i.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd};

      s_axil_bresp_o  = e_axi_resp_okay;
      s_axil_bvalid_o = io_resp_v_i & io_resp_header_cast_i.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr};

      io_resp_yumi_o  = (s_axil_rvalid_o & s_axil_rready_i) | (s_axil_bvalid_o & s_axil_bready_i);
    end

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_ready;
    else
      state_r <= state_n;

  if (axil_data_width_p != 64 && axil_data_width_p != 32)
    $fatal("AXI4-LITE only supports a data width of 32 or 64 bits.");

  //synopsys translate_off
  initial
    begin
       $display("## axil_to_bp_lite_client: instantiating with axil_data_width_p=%d, axil_addr_width_p=%d (%m)\n",axil_data_width_p,axil_addr_width_p);
    end

  always_ff @(negedge clk_i)
    begin
      if (s_axil_awprot_i != 3'b000)
        $error("AXI4-LITE access permission mode is not supported.");
    end
  // synopsys translate_on

endmodule


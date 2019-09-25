/**
 *
 * Name:
 *   bp_cce_msg.v
 *
 * Description:
 *   This module handles sending and receiving of all messages in the CCE.
 *
 *   Processing of a Memory Data Response takes priority over processing of any other memory
 *   messages being sent or received. This arbitration is handled by the instruction decoder.
 *
 */

module bp_cce_msg
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter cfg_p                        = "inv"
    `declare_bp_proc_params(cfg_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)
    , localparam lg_lce_assoc_lp           = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp            = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam num_way_groups_lp         = (lce_sets_p/num_cce_p)
    , localparam lg_num_way_groups_lp      = `BSG_SAFE_CLOG2(num_way_groups_lp)
    , localparam mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)

    // interface widths
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  )
  (input                                               clk_i
   , input                                             reset_i

   , input [lg_num_cce_lp-1:0]                         cce_id_i
   , input bp_cce_mode_e                               cce_mode_i

   // LCE-CCE Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects directly to ME network)
   , input [lce_cce_req_width_lp-1:0]                  lce_req_i
   , input                                             lce_req_v_i
   , output logic                                      lce_req_yumi_o

   , input [lce_cce_resp_width_lp-1:0]                 lce_resp_i
   , input                                             lce_resp_v_i
   , output logic                                      lce_resp_yumi_o

   , output logic [lce_cmd_width_lp-1:0]               lce_cmd_o
   , output logic                                      lce_cmd_v_o
   , input                                             lce_cmd_ready_i

   // CCE-MEM Interface
   // inbound: valid->ready (a.k.a., valid->yumi), demanding consumer (connects to FIFO)
   // outbound: ready&valid (connects to FIFO)
   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output logic                                      mem_resp_yumi_o

   , input [cce_mem_msg_width_lp-1:0]                  mem_cmd_i
   , input                                             mem_cmd_v_i
   , output logic                                      mem_cmd_yumi_o

   , output logic [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , output logic                                      mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , output logic [cce_mem_msg_width_lp-1:0]           mem_resp_o
   , output logic                                      mem_resp_v_o
   , input                                             mem_resp_ready_i

   // MSHR
   , input [mshr_width_lp-1:0]                         mshr_i

   // Decoded Instruction
   , input bp_cce_inst_decoded_s                       decoded_inst_i

   // Pending bit write
   , output logic                                      pending_w_v_o
   , output logic [lg_num_way_groups_lp-1:0]           pending_w_way_group_o
   , output logic                                      pending_o

   // arbitration signals to instruction decode
   , output logic                                      pending_w_busy_o
   , output logic                                      lce_cmd_busy_o

   , input [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_i

   , input [num_lce_p-1:0][lg_lce_assoc_lp-1:0]        sharers_ways_i

   , input [dword_width_p-1:0]                         nc_data_i

   , output logic                                      fence_zero_o
  );

  // Define structure variables for output queues
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s  lce_req_li;
  bp_lce_cce_resp_s lce_resp_li;
  bp_lce_cmd_s      lce_cmd_lo;

  bp_cce_mem_msg_s  mem_cmd_li, mem_cmd_lo, mem_resp_li, mem_resp_lo;

  // assign output queue ports to structure variables
  assign lce_cmd_o = lce_cmd_lo;
  assign mem_cmd_o = mem_cmd_lo;
  assign mem_resp_o = mem_resp_lo;

  // cast input messages with data
  assign mem_resp_li = mem_resp_i;
  assign mem_cmd_li = mem_cmd_i;
  assign lce_resp_li = lce_resp_i;
  assign lce_req_li = lce_req_i;

  // Message Unit Signals
  logic                                          lce_req_yumi_from_msg;
  logic                                          lce_resp_yumi_from_msg;
  logic [lce_cmd_width_lp-1:0]                   lce_cmd_from_msg;
  logic                                          lce_cmd_v_from_msg;
  logic                                          mem_resp_yumi_from_msg;
  logic                                          mem_cmd_yumi_from_msg;
  logic [cce_mem_msg_width_lp-1:0]               mem_cmd_from_msg;
  logic                                          mem_cmd_v_from_msg;
  logic [cce_mem_msg_width_lp-1:0]               mem_resp_from_msg;
  logic                                          mem_resp_v_from_msg;

  // Uncached Module Signals
  logic                                          lce_req_yumi_from_uc;
  logic                                          lce_resp_yumi_from_uc;
  logic [lce_cmd_width_lp-1:0]                   lce_cmd_from_uc;
  logic                                          lce_cmd_v_from_uc;
  logic                                          mem_resp_yumi_from_uc;
  logic                                          mem_cmd_yumi_from_uc;
  logic [cce_mem_msg_width_lp-1:0]               mem_cmd_from_uc;
  logic                                          mem_cmd_v_from_uc;
  logic [cce_mem_msg_width_lp-1:0]               mem_resp_from_uc;
  logic                                          mem_resp_v_from_uc;

  // Message unit
  bp_cce_msg_cached
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      ,.lce_req_data_width_p(dword_width_p)
      ,.num_way_groups_p(num_way_groups_lp)
      ,.cce_block_width_p(cce_block_width_p)
      ,.dword_width_p(dword_width_p)
      )
    bp_cce_msg_cached
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cce_id_i(cce_id_i)
      ,.cce_mode_i(cce_mode_i)

      // To CCE
      ,.lce_req_i(lce_req_li)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_yumi_o(lce_req_yumi_from_msg)

      ,.lce_resp_i(lce_resp_li)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_yumi_o(lce_resp_yumi_from_msg)

      // From CCE
      ,.lce_cmd_o(lce_cmd_from_msg)
      ,.lce_cmd_v_o(lce_cmd_v_from_msg)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp_li)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_yumi_o(mem_resp_yumi_from_msg)
      ,.mem_cmd_i(mem_cmd_li)
      ,.mem_cmd_v_i(mem_cmd_v_i)
      ,.mem_cmd_yumi_o(mem_cmd_yumi_from_msg)

      // From CCE
      ,.mem_cmd_o(mem_cmd_from_msg)
      ,.mem_cmd_v_o(mem_cmd_v_from_msg)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)
      ,.mem_resp_o(mem_resp_from_msg)
      ,.mem_resp_v_o(mem_resp_v_from_msg)
      ,.mem_resp_ready_i(mem_resp_ready_i)

      ,.mshr_i(mshr_i)
      ,.decoded_inst_i(decoded_inst_i)

      ,.pending_w_v_o(pending_w_v_o)
      ,.pending_w_way_group_o(pending_w_way_group_o)
      ,.pending_o(pending_o)

      ,.pending_w_busy_o(pending_w_busy_o)
      ,.lce_cmd_busy_o(lce_cmd_busy_o)

      ,.gpr_i(gpr_i)
      ,.sharers_ways_i(sharers_ways_i)
      ,.nc_data_i(nc_data_i)

      ,.fence_zero_o(fence_zero_o)
      );

  // Uncached access module
  bp_cce_msg_uncached
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      ,.lce_req_data_width_p(dword_width_p)
      )
    bp_cce_msg_uncached
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cce_id_i(cce_id_i)
      ,.cce_mode_i(cce_mode_i)

      // To CCE
      ,.lce_req_i(lce_req_li)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_yumi_o(lce_req_yumi_from_uc)

//      ,.lce_resp_i(lce_resp_li)
//      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_yumi_o(lce_resp_yumi_from_uc)

      // From CCE
      ,.lce_cmd_o(lce_cmd_from_uc)
      ,.lce_cmd_v_o(lce_cmd_v_from_uc)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp_li)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_yumi_o(mem_resp_yumi_from_uc)
      ,.mem_cmd_i(mem_cmd_li)
      ,.mem_cmd_v_i(mem_cmd_v_i)
      ,.mem_cmd_yumi_o(mem_cmd_yumi_from_uc)

      // From CCE
      ,.mem_cmd_o(mem_cmd_from_uc)
      ,.mem_cmd_v_o(mem_cmd_v_from_uc)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)
      ,.mem_resp_o(mem_resp_from_uc)
      ,.mem_resp_v_o(mem_resp_v_from_uc)
      ,.mem_resp_ready_i(mem_resp_ready_i)

      );

  // Output Message Formation
  //
  // Input messages to the CCE are buffered by two element FIFOs in bp_cce_top.v, thus
  // the outbound signal is a yumi.
  //
  // Outbound queues all use ready&valid handshaking. Outbound messages going to LCEs are not
  // buffered by bp_cce_top.v, but messages to memory are.
  always_comb
  begin
    if (cce_mode_i == e_cce_mode_uncached) begin
      lce_resp_yumi_o = '0;
      lce_req_yumi_o = lce_req_yumi_from_uc;

      mem_resp_yumi_o = mem_resp_yumi_from_uc;
      mem_cmd_yumi_o = mem_cmd_yumi_from_uc;
      lce_cmd_v_o = lce_cmd_v_from_uc;
      mem_cmd_v_o = mem_cmd_v_from_uc;
      mem_resp_v_o = mem_resp_v_from_uc;

      lce_cmd_lo = lce_cmd_from_uc;
      mem_cmd_lo = mem_cmd_from_uc;
      mem_resp_lo = mem_resp_from_uc;
    end else begin
      lce_req_yumi_o = lce_req_yumi_from_msg;
      lce_resp_yumi_o = lce_resp_yumi_from_msg;

      mem_resp_yumi_o = mem_resp_yumi_from_msg;
      mem_cmd_yumi_o = mem_cmd_yumi_from_msg;
      lce_cmd_v_o = lce_cmd_v_from_msg;
      mem_cmd_v_o = mem_cmd_v_from_msg;
      mem_resp_v_o = mem_resp_v_from_msg;

      lce_cmd_lo = lce_cmd_from_msg;
      mem_cmd_lo = mem_cmd_from_msg;
      mem_resp_lo = mem_resp_from_msg;
    end
  end

endmodule

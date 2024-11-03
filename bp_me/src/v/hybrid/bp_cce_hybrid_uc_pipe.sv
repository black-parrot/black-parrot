/**
 *
 * Name:
 *   bp_cce_hybrid_uc_pipe.sv
 *
 * Description:
 *   This module processes uncached LCE requests targeting uncacheable memory.
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_uc_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    // interface widths
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // control signals
   , output logic                                   empty_o

   // LCE Request
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_v_i
   , output logic                                   lce_req_ready_and_o
   , input [bedrock_fill_width_p-1:0]               lce_req_data_i

   // Memory command
   , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_fwd_data_o
   , output logic                                   mem_fwd_v_o
   , input                                          mem_fwd_ready_and_i
   );

  // Define structure variables for output queues
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);

  // LCE Request Stream Pump
  bp_bedrock_lce_req_header_s fsm_req_header_li;
  logic [bedrock_fill_width_p-1:0] fsm_req_data_li;
  logic fsm_req_v_li, fsm_req_yumi_lo;
  logic [paddr_width_p-1:0] fsm_req_addr_li;
  logic fsm_req_new_li, fsm_req_critical_li, fsm_req_last_li;
  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.msg_stream_mask_p(lce_req_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_req_stream_mask_gp)
     )
   lce_req_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(lce_req_header_cast_i)
     ,.msg_data_i(lce_req_data_i)
     ,.msg_v_i(lce_req_v_i)
     ,.msg_ready_and_o(lce_req_ready_and_o)

     ,.fsm_header_o(fsm_req_header_li)
     ,.fsm_data_o(fsm_req_data_li)
     ,.fsm_v_o(fsm_req_v_li)
     ,.fsm_yumi_i(fsm_req_yumi_lo)
     ,.fsm_addr_o(fsm_req_addr_li)
     ,.fsm_new_o(fsm_req_new_li)
     ,.fsm_critical_o(fsm_req_critical_li)
     ,.fsm_last_o(fsm_req_last_li)
     );

  // Memory Fwd Stream Pump
  bp_bedrock_mem_fwd_header_s fsm_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] fsm_fwd_data_lo;
  logic fsm_fwd_v_lo, fsm_fwd_ready_then_li;
  logic [paddr_width_p-1:0] fsm_fwd_addr_li;
  logic fsm_fwd_new_li, fsm_fwd_critical_li, fsm_fwd_last_li;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(bedrock_fill_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp)
     )
   fwd_stream_pump
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // to memory command output
     ,.msg_header_o(mem_fwd_header_cast_o)
     ,.msg_data_o(mem_fwd_data_o)
     ,.msg_v_o(mem_fwd_v_o)
     ,.msg_ready_and_i(mem_fwd_ready_and_i)
     // from FSM CCE
     ,.fsm_header_i(fsm_fwd_header_lo)
     ,.fsm_data_i(fsm_fwd_data_lo)
     ,.fsm_v_i(fsm_fwd_v_lo)
     ,.fsm_ready_then_o(fsm_fwd_ready_then_li)
     ,.fsm_addr_o(fsm_fwd_addr_li)
     ,.fsm_new_o(fsm_fwd_new_li)
     ,.fsm_critical_o(fsm_fwd_critical_li)
     ,.fsm_last_o(fsm_fwd_last_li)
     );

  // TODO: sufficient?
  assign empty_o = ~fsm_req_v_li;

  // Combinational Logic
  always_comb begin
    fsm_req_yumi_lo = 1'b0;

    // memory command defaults
    fsm_fwd_header_lo = '0;
    fsm_fwd_header_lo.msg_type.fwd = e_bedrock_mem_rd;
    fsm_fwd_header_lo.addr = fsm_req_header_li.addr;
    fsm_fwd_header_lo.size = fsm_req_header_li.size;
    fsm_fwd_header_lo.subop = fsm_req_header_li.subop;
    fsm_fwd_header_lo.payload.lce_id = fsm_req_header_li.payload.src_id;
    fsm_fwd_header_lo.payload.src_did = fsm_req_header_li.payload.src_did;
    fsm_fwd_header_lo.payload.way_id = fsm_req_header_li.payload.lru_way_id;
    fsm_fwd_header_lo.payload.uncached = 1'b1;
    fsm_fwd_data_lo = fsm_req_data_li;
    fsm_fwd_v_lo = 1'b0;

    unique case (fsm_req_header_li.msg_type.req)
      e_bedrock_req_uc_rd : begin
        fsm_fwd_header_lo.msg_type.fwd = e_bedrock_mem_rd;
        fsm_fwd_v_lo = fsm_req_v_li & fsm_fwd_ready_then_li;
        fsm_req_yumi_lo = fsm_fwd_v_lo;
      end
      e_bedrock_req_uc_wr: begin
        fsm_fwd_header_lo.msg_type.fwd = e_bedrock_mem_wr;
        fsm_fwd_v_lo = fsm_req_v_li & fsm_fwd_ready_then_li;
        fsm_req_yumi_lo = fsm_fwd_v_lo;
      end
      // LCE sent cacheable read/write miss (cache block fetches)
      // do not set uncached access bit in payload to indicate that LCE request was cacheable
      // set state based on read or write miss type - this allows the response to set a valid
      // state when it returns and is forwarded to LCE, but no coherence is enforced.
      e_bedrock_req_rd_miss
      ,e_bedrock_req_wr_miss: begin
        fsm_fwd_header_lo.msg_type.fwd = e_bedrock_mem_rd;
        fsm_fwd_header_lo.payload.uncached = 1'b0;
        fsm_fwd_header_lo.payload.state = (fsm_req_header_li.msg_type.req == e_bedrock_req_rd_miss)
                                               ? e_COH_S
                                               : e_COH_M;
        fsm_fwd_v_lo = fsm_req_v_li & fsm_fwd_ready_then_li;
        fsm_req_yumi_lo = fsm_fwd_v_lo;
      end
      e_bedrock_req_uc_amo: begin
        fsm_fwd_header_lo.msg_type.fwd = e_bedrock_mem_amo;
        fsm_fwd_v_lo = fsm_req_v_li & fsm_fwd_ready_then_li;
        fsm_req_yumi_lo = fsm_fwd_v_lo;
      end
      default: begin
      end
    endcase
  end // combinational logic

endmodule

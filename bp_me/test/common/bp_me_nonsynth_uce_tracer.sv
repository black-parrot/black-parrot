/**
 *
 * Name:
 *   bp_me_nonsynth_uce_tracer.v
 *
 * Description:
 *
 */

`include "bp_common_test_defines.svh"
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_nonsynth_uce_tracer
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(writeback_p)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(tag_width_p)
   , parameter `BSG_INV_PARAM(id_width_p)

   , parameter string trace_str_p = ""
   )
  (input                                            clk_i
   , input                                          reset_i
   , input                                          en_i
   );

  `declare_bp_common_if(vaddr_width_p, hio_width_p, core_id_width_p, lce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, lce_id_width_p, did_width_p, lce_assoc_p);

  `define FWD  bp_uce.fwd_pump_out
  `define REV  bp_uce.rev_pump_in

  // snoop
  wire bp_bedrock_mem_fwd_header_s mem_fwd_header = `FWD.fsm_header_i;
  wire bp_bedrock_mem_rev_header_s mem_rev_header = `REV.fsm_header_o;

  wire [bedrock_fill_width_p-1:0] mem_fwd_data = `FWD.fsm_data_i;
  wire [bedrock_fill_width_p-1:0] mem_rev_data = `REV.fsm_data_o;

  wire mem_fwd_ack = `FWD.fsm_ready_then_o & `FWD.fsm_v_i;
  wire mem_rev_ack = `REV.fsm_yumi_i & `REV.fsm_v_o;

  wire mem_fwd_first = `FWD.fsm_new_o;
  wire mem_rev_first = `REV.fsm_new_o;

  wire [lce_id_width_p-1:0] lce_id = bp_uce.lce_id_i;

  `undef FWD
  `undef REV

  wire mem_fwd_rd = mem_fwd_header.msg_type inside {e_bedrock_mem_rd};
  wire mem_fwd_wr = mem_fwd_header.msg_type inside {e_bedrock_mem_wr};
  wire mem_rev_rd = mem_rev_header.msg_type inside {e_bedrock_mem_rd};
  wire mem_rev_wr = mem_rev_header.msg_type inside {e_bedrock_mem_wr};

  wire mem_fwd_has_data = mem_fwd_stream_mask_gp[mem_fwd_header.msg_type];
  wire mem_rev_has_data = mem_rev_stream_mask_gp[mem_rev_header.msg_type];

  // record
  `declare_bp_tracer_control(clk_i, reset_i, en_i, trace_str_p, lce_id);

  always_ff @(posedge clk_i)
    if (is_go)
      begin
        if (mem_fwd_ack & mem_fwd_first & mem_fwd_rd)
          $fdisplay(file, "%12t |: UCE[%0d] MEM FWD RD addr[%H] way [%0d]"
                    ,$time, lce_id, mem_fwd_header.addr, mem_fwd_header.payload.way_id
                    );
        if (mem_fwd_ack & mem_fwd_first & mem_fwd_wr)
          $fdisplay(file, "%12t |: UCE[%0d] MEM FWD WR addr[%H] way [%0d]"
                    ,$time, lce_id, mem_fwd_header.addr, mem_fwd_header.payload.way_id
                    );
        if (mem_fwd_ack & mem_fwd_has_data)
          $fdisplay(file, "\tMEM FWD DATA %H", $time, mem_fwd_data);

        if (mem_rev_ack & mem_rev_first & mem_rev_rd)
          $fdisplay(file, "%12t |: UCE[%0d] MEM REV RD addr[%H] way [%0d]"
                    ,$time, lce_id, mem_rev_header.addr, mem_rev_header.payload.way_id
                    );
        if (mem_rev_ack & mem_fwd_first & mem_fwd_wr)
          $fdisplay(file, "%12t |: UCE[%0d] MEM REV WR addr[%H] way[%0d]"
                    ,$time, lce_id, mem_rev_header.addr, mem_rev_header.payload.way_id
                    );
        if (mem_rev_ack & mem_rev_has_data)
          $fdisplay(file, "%12t |: MEM REV DATA %H", $time, mem_rev_data);
      end

endmodule

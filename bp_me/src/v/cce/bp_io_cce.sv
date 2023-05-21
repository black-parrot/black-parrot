
/*
 * Name:
 *   bp_io_cce.sv
 *
 * Description:
 *   This module acts as a CCE for uncacheable IO memory accesses.
 *
 *   It converts uncached load and store LCE requests to IO requests, and
 *   converts uncached IO responses to uncached LCE command messages.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_io_cce
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                          clk_i
   , input                                        reset_i

   , input [did_width_p-1:0]                      did_i
   , input [cce_id_width_p-1:0]                   cce_id_i

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]          lce_req_header_i
   , input [bedrock_fill_width_p-1:0]             lce_req_data_i
   , input                                        lce_req_v_i
   , output logic                                 lce_req_ready_and_o

   , output logic [lce_cmd_header_width_lp-1:0]   lce_cmd_header_o
   , output logic [bedrock_fill_width_p-1:0]      lce_cmd_data_o
   , output logic                                 lce_cmd_v_o
   , input                                        lce_cmd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]          mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]             mem_rev_data_i
   , input                                        mem_rev_v_i
   , output logic                                 mem_rev_ready_and_o

   , output logic [mem_fwd_header_width_lp-1:0]   mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]      mem_fwd_data_o
   , output logic                                 mem_fwd_v_o
   , input                                        mem_fwd_ready_and_i
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  // LCE Request to IO Command
  wire lce_req_wr_not_rd = (lce_req_header_cast_i.msg_type.req == e_bedrock_req_uc_wr);
  always_comb begin
    // header
    mem_fwd_header_cast_o                  = '0;
    mem_fwd_header_cast_o.msg_type.fwd     = lce_req_wr_not_rd ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
    mem_fwd_header_cast_o.addr             = lce_req_header_cast_i.addr;
    mem_fwd_header_cast_o.size             = lce_req_header_cast_i.size;
    mem_fwd_header_cast_o.payload.lce_id   = lce_req_header_cast_i.payload.src_id;
    mem_fwd_header_cast_o.payload.did      = did_i;
    mem_fwd_header_cast_o.payload.uncached = 1'b1;
    // data
    mem_fwd_data_o                         = lce_req_data_i;
    mem_fwd_v_o                            = lce_req_v_i;
    lce_req_ready_and_o                   = mem_fwd_ready_and_i;
  end

  // IO Response to LCE Cmd
  wire mem_rev_wr_not_rd = (mem_rev_header_cast_i.msg_type.rev == e_bedrock_mem_uc_wr);
  always_comb begin
    // header
    lce_cmd_header_cast_o                = '0;
    lce_cmd_header_cast_o.msg_type.cmd   = mem_rev_wr_not_rd ? e_bedrock_cmd_uc_st_done : e_bedrock_cmd_uc_data;
    lce_cmd_header_cast_o.addr           = mem_rev_header_cast_i.addr;
    lce_cmd_header_cast_o.size           = mem_rev_header_cast_i.size;
    lce_cmd_header_cast_o.payload.dst_id = mem_rev_header_cast_i.payload.lce_id;
    lce_cmd_header_cast_o.payload.src_id = cce_id_i;
    // data
    lce_cmd_data_o                       = mem_rev_data_i;
    lce_cmd_v_o                          = mem_rev_v_i;
    mem_rev_ready_and_o                   = lce_cmd_ready_and_i;
  end

endmodule


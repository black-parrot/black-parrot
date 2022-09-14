
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
   , input                                        lce_req_header_v_i
   , output logic                                 lce_req_header_ready_and_o
   , input                                        lce_req_has_data_i
   , input [bedrock_data_width_p-1:0]             lce_req_data_i
   , input                                        lce_req_data_v_i
   , output logic                                 lce_req_data_ready_and_o
   , input                                        lce_req_last_i

   , output logic [lce_cmd_header_width_lp-1:0]   lce_cmd_header_o
   , output logic                                 lce_cmd_header_v_o
   , input                                        lce_cmd_header_ready_and_i
   , output logic                                 lce_cmd_has_data_o
   , output logic [bedrock_data_width_p-1:0]      lce_cmd_data_o
   , output logic                                 lce_cmd_data_v_o
   , input                                        lce_cmd_data_ready_and_i
   , output logic                                 lce_cmd_last_o

   , input [mem_rev_header_width_lp-1:0]          io_rev_header_i
   , input                                        io_rev_header_v_i
   , output logic                                 io_rev_header_ready_and_o
   , input                                        io_rev_has_data_i
   , input [bedrock_data_width_p-1:0]             io_rev_data_i
   , input                                        io_rev_data_v_i
   , output logic                                 io_rev_data_ready_and_o
   , input                                        io_rev_last_i

   , output logic [mem_fwd_header_width_lp-1:0]   io_fwd_header_o
   , output logic                                 io_fwd_header_v_o
   , input                                        io_fwd_header_ready_and_i
   , output logic                                 io_fwd_has_data_o
   , output logic [bedrock_data_width_p-1:0]      io_fwd_data_o
   , output logic                                 io_fwd_data_v_o
   , input                                        io_fwd_data_ready_and_i
   , output logic                                 io_fwd_last_o
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, io_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, io_rev_header);

  // LCE Request to IO Command
  wire lce_req_wr_not_rd = (lce_req_header_cast_i.msg_type.req == e_bedrock_req_uc_wr);
  always_comb begin
    // header
    lce_req_header_ready_and_o            = io_fwd_header_ready_and_i;
    io_fwd_header_v_o                     = lce_req_header_v_i;
    io_fwd_header_cast_o                  = '0;
    io_fwd_header_cast_o.msg_type.fwd     = lce_req_wr_not_rd ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
    io_fwd_header_cast_o.addr             = lce_req_header_cast_i.addr;
    io_fwd_header_cast_o.size             = lce_req_header_cast_i.size;
    io_fwd_header_cast_o.payload.lce_id   = lce_req_header_cast_i.payload.src_id;
    io_fwd_header_cast_o.payload.did      = did_i;
    io_fwd_header_cast_o.payload.uncached = 1'b1;
    io_fwd_has_data_o                     = lce_req_has_data_i;
    // data
    lce_req_data_ready_and_o              = io_fwd_data_ready_and_i;
    io_fwd_data_v_o                       = lce_req_data_v_i;
    io_fwd_data_o                         = lce_req_data_i;
    io_fwd_last_o                         = lce_req_last_i;
  end

  // IO Response to LCE Cmd
  wire io_rev_wr_not_rd = (io_rev_header_cast_i.msg_type.rev == e_bedrock_mem_uc_wr);
  always_comb begin
    // header
    io_rev_header_ready_and_o            = lce_cmd_header_ready_and_i;
    lce_cmd_header_v_o                   = io_rev_header_v_i;
    lce_cmd_header_cast_o                = '0;
    lce_cmd_header_cast_o.msg_type.cmd   = io_rev_wr_not_rd ? e_bedrock_cmd_uc_st_done : e_bedrock_cmd_uc_data;
    lce_cmd_header_cast_o.addr           = io_rev_header_cast_i.addr;
    lce_cmd_header_cast_o.size           = io_rev_header_cast_i.size;
    lce_cmd_header_cast_o.payload.dst_id = io_rev_header_cast_i.payload.lce_id;
    lce_cmd_header_cast_o.payload.src_id = cce_id_i;
    lce_cmd_has_data_o                   = io_rev_has_data_i;
    // data
    io_rev_data_ready_and_o              = lce_cmd_data_ready_and_i;
    lce_cmd_data_v_o                     = io_rev_data_v_i;
    lce_cmd_data_o                       = io_rev_data_i;
    lce_cmd_last_o                       = io_rev_last_i;
  end

endmodule


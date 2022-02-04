
/*
 * Name:
 *   bp_io_cce.sv
 *
 * Description:
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
  (input                                        clk_i
   , input                                      reset_i

   , input [did_width_p-1:0]                    did_i
   , input [cce_id_width_p-1:0]                 cce_id_i

   , input [lce_req_header_width_lp-1:0]        lce_req_header_i
   , input [cce_block_width_p-1:0]              lce_req_data_i
   , input                                      lce_req_v_i
   , output logic                               lce_req_ready_and_o

   , output logic [lce_cmd_header_width_lp-1:0] lce_cmd_header_o
   , output logic [cce_block_width_p-1:0]       lce_cmd_data_o
   , output logic                               lce_cmd_v_o
   , input                                      lce_cmd_ready_and_i

   , input [mem_header_width_lp-1:0]            io_resp_header_i
   , input [cce_block_width_p-1:0]              io_resp_data_i
   , input                                      io_resp_v_i
   , output logic                               io_resp_ready_and_o

   , output logic [mem_header_width_lp-1:0]     io_cmd_header_o
   , output logic [cce_block_width_p-1:0]       io_cmd_data_o
   , output logic                               io_cmd_v_o
   , input                                      io_cmd_ready_and_i
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_cmd_header_s, lce_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_i(bp_bedrock_mem_header_s, io_resp_header);

  assign lce_req_ready_and_o = io_cmd_ready_and_i;
  assign io_cmd_v_o          = lce_req_v_i;
  wire lce_req_wr_not_rd = (lce_req_header_cast_i.msg_type.req == e_bedrock_req_uc_wr);
  always_comb
    begin
      io_cmd_header_cast_o = '0;
      io_cmd_header_cast_o.msg_type.mem     = lce_req_wr_not_rd ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
      io_cmd_header_cast_o.addr             = lce_req_header_cast_i.addr;
      io_cmd_header_cast_o.size             = lce_req_header_cast_i.size;
      io_cmd_header_cast_o.payload.lce_id   = lce_req_header_cast_i.payload.src_id;
      io_cmd_header_cast_o.payload.did      = did_i;
      io_cmd_header_cast_o.payload.uncached = 1'b1;
      io_cmd_data_o                         = lce_req_data_i;
    end

  assign io_resp_ready_and_o = lce_cmd_ready_and_i;
  assign lce_cmd_v_o         = io_resp_v_i;
  wire io_resp_wr_not_rd = (io_resp_header_cast_i.msg_type.mem == e_bedrock_mem_uc_wr);
  always_comb
    begin
      lce_cmd_header_cast_o = '0;
      lce_cmd_header_cast_o.msg_type.cmd   = io_resp_wr_not_rd ? e_bedrock_cmd_uc_st_done : e_bedrock_cmd_uc_data;
      lce_cmd_header_cast_o.addr           = io_resp_header_cast_i.addr;
      lce_cmd_header_cast_o.size           = io_resp_header_cast_i.size;
      lce_cmd_header_cast_o.payload.dst_id = io_resp_header_cast_i.payload.lce_id;
      lce_cmd_header_cast_o.payload.src_id = cce_id_i;
      lce_cmd_data_o                       = io_resp_data_i;
    end

endmodule


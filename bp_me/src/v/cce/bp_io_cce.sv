
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_io_cce
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
   )
  (input                                      clk_i
   , input                                    reset_i

   , input [cce_id_width_p-1:0]               cce_id_i

   , input [lce_req_msg_width_lp-1:0]         lce_req_i
   , input                                    lce_req_v_i
   , output logic                             lce_req_yumi_o

   , output logic [lce_cmd_msg_width_lp-1:0]  lce_cmd_o
   , output logic                             lce_cmd_v_o
   , input                                    lce_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]         io_resp_i
   , input                                    io_resp_v_i
   , output logic                             io_resp_yumi_o

   , output logic [cce_mem_msg_width_lp-1:0]  io_cmd_o
   , output logic                             io_cmd_v_o
   , input                                    io_cmd_ready_i

   );

  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  bp_bedrock_lce_req_msg_s        lce_req_cast_i;
  bp_bedrock_lce_cmd_msg_s        lce_cmd_cast_o;
  bp_bedrock_lce_req_payload_s    lce_req_payload;
  bp_bedrock_lce_cmd_payload_s    lce_cmd_payload;
  assign lce_req_payload = lce_req_cast_i.header.payload;

  bp_bedrock_cce_mem_msg_s  io_cmd_cast_o;
  bp_bedrock_cce_mem_msg_s  io_resp_cast_i;
  bp_bedrock_cce_mem_payload_s io_resp_cast_payload, io_cmd_cast_payload;
  assign io_resp_cast_payload = io_resp_cast_i.header.payload;

  assign lce_req_cast_i  = lce_req_i;
  assign lce_cmd_o       = lce_cmd_cast_o;

  assign io_resp_cast_i = io_resp_i;
  assign io_cmd_o       = io_cmd_cast_o;

  assign lce_req_yumi_o  = lce_req_v_i & io_cmd_ready_i;
  assign io_cmd_v_o      = lce_req_yumi_o;
  wire lce_req_wr_not_rd = (lce_req_cast_i.header.msg_type.req == e_bedrock_req_uc_wr);
  always_comb begin
    io_cmd_cast_o                         = '0;
    io_cmd_cast_payload                   = '0;
    io_cmd_cast_o.header.msg_type.mem     = (lce_req_wr_not_rd) ? e_bedrock_mem_uc_wr : e_bedrock_mem_uc_rd;
    io_cmd_cast_o.header.addr             = lce_req_cast_i.header.addr;
    io_cmd_cast_o.header.size             = lce_req_cast_i.header.size;
    io_cmd_cast_payload.lce_id            = lce_req_payload.src_id;
    io_cmd_cast_payload.uncached          = 1'b1;
    io_cmd_cast_o.header.payload          = io_cmd_cast_payload;
    io_cmd_cast_o.data                    = lce_req_cast_i.data;
  end

  assign io_resp_yumi_o  = io_resp_v_i & lce_cmd_ready_i;
  assign lce_cmd_v_o     = io_resp_yumi_o;
  wire io_resp_wr_not_rd = (io_resp_cast_i.header.msg_type.mem == e_bedrock_mem_uc_wr);
  always_comb
    if (io_resp_wr_not_rd)
      begin
        lce_cmd_cast_o                     = '0;
        lce_cmd_payload                    = '0;
        lce_cmd_payload.dst_id             = io_resp_cast_payload.lce_id;
        lce_cmd_cast_o.header.msg_type.cmd = e_bedrock_cmd_uc_st_done;
        // no data, size is '0 equivalent
        lce_cmd_cast_o.header.addr         = io_resp_cast_i.header.addr;
        lce_cmd_payload.src_id             = cce_id_i;
        lce_cmd_cast_o.header.payload      = lce_cmd_payload;
      end
    else
      begin
        lce_cmd_cast_o                     = '0;
        lce_cmd_payload                    = '0;
        lce_cmd_payload.dst_id             = io_resp_cast_payload.lce_id;
        lce_cmd_cast_o.header.msg_type.cmd = e_bedrock_cmd_uc_data;
        lce_cmd_cast_o.header.size         = io_resp_cast_i.header.size;
        lce_cmd_cast_o.data                = io_resp_cast_i.data;
        lce_cmd_cast_o.header.addr         = io_resp_cast_i.header.addr;
        lce_cmd_payload.src_id             = cce_id_i;
        lce_cmd_cast_o.header.payload      = lce_cmd_payload;
      end

endmodule


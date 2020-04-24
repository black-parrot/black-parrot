
module bp_io_cce
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cce_id_width_p-1:0]         cce_id_i

   , input [lce_cce_req_width_lp-1:0]   lce_req_i
   , input                              lce_req_v_i
   , output                             lce_req_yumi_o

   , output [lce_cmd_width_lp-1:0]      lce_cmd_o
   , output                             lce_cmd_v_o
   , input                              lce_cmd_ready_i

   , output [cce_mem_msg_width_lp-1:0]   io_cmd_o
   , output                             io_cmd_v_o
   , input                              io_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]    io_resp_i
   , input                              io_resp_v_i
   , output                             io_resp_yumi_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s  lce_req_cast_i;
  bp_lce_cmd_s      lce_cmd_cast_o;

  bp_cce_mem_msg_s  io_cmd_cast_o;
  bp_cce_mem_msg_s  io_resp_cast_i;

  assign lce_req_cast_i  = lce_req_i;
  assign lce_cmd_o       = lce_cmd_cast_o;

  assign io_resp_cast_i = io_resp_i;
  assign io_cmd_o       = io_cmd_cast_o;

  assign lce_req_yumi_o  = lce_req_v_i & io_cmd_ready_i;
  assign io_cmd_v_o      = lce_req_yumi_o;
  wire lce_req_wr_not_rd = (lce_req_cast_i.header.msg_type == e_lce_req_type_uc_wr);
  always_comb
    if (lce_req_wr_not_rd)
      begin
        io_cmd_cast_o                       = '0;
        io_cmd_cast_o.header.msg_type       = e_cce_mem_uc_wr;
        io_cmd_cast_o.header.addr           = lce_req_cast_i.header.addr;
        io_cmd_cast_o.header.size           = lce_req_cast_i.header.size;
        io_cmd_cast_o.header.payload.lce_id = lce_req_cast_i.header.src_id;
        io_cmd_cast_o.data                  = lce_req_cast_i.data;
      end
    else
      begin
        io_cmd_cast_o                       = '0;
        io_cmd_cast_o.header.msg_type       = e_cce_mem_uc_rd;
        io_cmd_cast_o.header.addr           = lce_req_cast_i.header.addr;
        io_cmd_cast_o.header.size           = lce_req_cast_i.header.size;
        io_cmd_cast_o.header.payload.lce_id = lce_req_cast_i.header.src_id;
        io_cmd_cast_o.data                  = lce_req_cast_i.data;
      end

  assign io_resp_yumi_o  = io_resp_v_i & lce_cmd_ready_i;
  assign lce_cmd_v_o     = io_resp_yumi_o;
  wire io_resp_wr_not_rd = (io_resp_cast_i.header.msg_type == e_cce_mem_uc_wr);
  always_comb
    if (io_resp_wr_not_rd)
      begin
        lce_cmd_cast_o                 = '0;
        lce_cmd_cast_o.header.dst_id   = io_resp_cast_i.header.payload.lce_id;
        lce_cmd_cast_o.header.msg_type = e_lce_cmd_uc_st_done;
        lce_cmd_cast_o.header.addr     = io_resp_cast_i.header.addr;
        lce_cmd_cast_o.header.src_id   = cce_id_i;
      end
    else
      begin
        lce_cmd_cast_o                  = '0;
        lce_cmd_cast_o.header.dst_id    = io_resp_cast_i.header.payload.lce_id;
        lce_cmd_cast_o.header.msg_type  = e_lce_cmd_uc_data;
        lce_cmd_cast_o.header.size      = io_resp_cast_i.header.size;
        lce_cmd_cast_o.data             = io_resp_cast_i.data;
        lce_cmd_cast_o.header.addr      = io_resp_cast_i.header.addr;
      end

endmodule


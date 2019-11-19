
module bp_io_cce
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam lg_num_cce_lp = `BSG_SAFE_CLOG2(num_cce_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [lg_num_cce_lp-1:0]          cce_id_i

   , input [lce_cce_req_width_lp-1:0]   lce_req_i
   , input                              lce_req_v_i
   , output                             lce_req_yumi_o

   , output [lce_cmd_width_lp-1:0]      lce_cmd_o
   , output                             lce_cmd_v_o
   , input                              lce_cmd_ready_i

   , output [cce_mem_msg_width_lp-1:0]  mem_cmd_o
   , output                             mem_cmd_v_o
   , input                              mem_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]   mem_resp_i
   , input                              mem_resp_v_i
   , output                             mem_resp_yumi_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s  lce_req_cast_i;
  bp_lce_cmd_s      lce_cmd_cast_o;

  bp_cce_mem_msg_s  mem_cmd_cast_o;
  bp_cce_mem_msg_s  mem_resp_cast_i;

  assign lce_req_cast_i  = lce_req_i;
  assign lce_cmd_o       = lce_cmd_cast_o;

  assign mem_resp_cast_i = mem_resp_i;
  assign mem_cmd_o       = mem_cmd_cast_o;

  bp_cce_mem_req_size_e mem_cmd_size;
  assign mem_cmd_size = (lce_req_cast_i.msg.uc_req.uc_size == e_lce_uc_req_1)
                        ? e_mem_size_1
                        : (lce_req_cast_i.msg.uc_req.uc_size == e_lce_uc_req_2)
                          ? e_mem_size_2
                          : (lce_req_cast_i.msg.uc_req.uc_size == e_lce_uc_req_4)
                            ? e_mem_size_4
                            : e_mem_size_8;

  assign lce_req_yumi_o  = lce_req_v_i & mem_cmd_ready_i;
  assign mem_cmd_v_o     = lce_req_yumi_o;
  wire lce_req_wr_not_rd = (lce_req_cast_i.msg_type == e_lce_req_type_uc_wr);
  always_comb
    if (lce_req_wr_not_rd)
      begin
        mem_cmd_cast_o                     = '0;
        mem_cmd_cast_o.msg_type            = e_cce_mem_uc_wr;
        mem_cmd_cast_o.addr                = lce_req_cast_i.addr;
        mem_cmd_cast_o.size                = mem_cmd_size;
        mem_cmd_cast_o.payload.lce_id      = lce_req_cast_i.src_id;
        mem_cmd_cast_o.data                = lce_req_cast_i.msg.uc_req.data;
      end
    else
      begin
        mem_cmd_cast_o                     = '0;
        mem_cmd_cast_o.msg_type            = e_cce_mem_uc_rd;
        mem_cmd_cast_o.addr                = lce_req_cast_i.addr;
        mem_cmd_cast_o.size                = mem_cmd_size;
        mem_cmd_cast_o.payload.lce_id      = lce_req_cast_i.src_id;
        mem_cmd_cast_o.data                = lce_req_cast_i.msg.uc_req.data;
      end

  assign mem_resp_yumi_o  = mem_resp_v_i & lce_cmd_ready_i;
  assign lce_cmd_v_o      = mem_resp_yumi_o;
  wire mem_resp_wr_not_rd = (mem_resp_cast_i.msg_type.cce_mem_cmd == e_cce_mem_uc_wr);
  always_comb
    if (mem_resp_wr_not_rd)
      begin
        lce_cmd_cast_o                = '0;
        lce_cmd_cast_o.dst_id         = mem_resp_cast_i.payload.lce_id;
        lce_cmd_cast_o.msg_type       = e_lce_cmd_uc_st_done;
        lce_cmd_cast_o.msg.cmd.addr   = mem_resp_cast_i.addr;
        lce_cmd_cast_o.msg.cmd.src_id = (lg_num_cce_lp)'(cce_id_i);
      end
    else
      begin
        lce_cmd_cast_o                = '0;
        lce_cmd_cast_o.dst_id           = mem_resp_cast_i.payload.lce_id;
        lce_cmd_cast_o.msg_type         = e_lce_cmd_uc_data;
        lce_cmd_cast_o.msg.dt_cmd.data  = mem_resp_cast_i.data;
        lce_cmd_cast_o.msg.dt_cmd.addr  = mem_resp_cast_i.addr;
      end

endmodule


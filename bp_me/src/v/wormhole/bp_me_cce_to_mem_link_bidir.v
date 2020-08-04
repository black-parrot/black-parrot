
module bp_me_cce_to_mem_link_bidir
 import bp_cce_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)

   , parameter num_outstanding_req_p = "inv"

   , parameter flit_width_p = "inv"
   , parameter cord_width_p = "inv"
   , parameter cid_width_p  = "inv"
   , parameter len_width_p  = "inv"

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )

  (input                                          clk_i
   , input                                        reset_i

   // Configuration
   , input [cord_width_p-1:0]                     my_cord_i
   , input [cid_width_p-1:0]                      my_cid_i
   , input [cord_width_p-1:0]                     dst_cord_i
   , input [cid_width_p-1:0]                      dst_cid_i

   // Master link
   , input  [cce_mem_msg_width_lp-1:0]            mem_cmd_i
   , input                                        mem_cmd_v_i
   , output                                       mem_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]            mem_resp_o
   , output                                       mem_resp_v_o
   , input                                        mem_resp_yumi_i

   // Client link
   , output  [cce_mem_msg_width_lp-1:0]           mem_cmd_o
   , output                                       mem_cmd_v_o
   , input                                        mem_cmd_yumi_i

   , input [cce_mem_msg_width_lp-1:0]             mem_resp_i
   , input                                        mem_resp_v_i
   , output                                       mem_resp_ready_o

   // NOC interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );

`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s cmd_link_cast_i, cmd_link_cast_o, resp_link_cast_i, resp_link_cast_o;
bsg_ready_and_link_sif_s master_cmd_link_lo, master_resp_link_li;
bsg_ready_and_link_sif_s client_cmd_link_li, client_resp_link_lo;

assign cmd_link_cast_i = cmd_link_i;
assign resp_link_cast_i = resp_link_i;
assign cmd_link_o  = cmd_link_cast_o;
assign resp_link_o = resp_link_cast_o;

// Swizzle ready_and_rev 
assign client_cmd_link_li  = '{data          : cmd_link_cast_i.data
                               ,v            : cmd_link_cast_i.v
                               ,ready_and_rev: resp_link_cast_i.ready_and_rev
                               };
assign cmd_link_cast_o     = '{data          : master_cmd_link_lo.data
                               ,v            : master_cmd_link_lo.v
                               ,ready_and_rev: client_resp_link_lo.ready_and_rev
                               };

assign master_resp_link_li = '{data          : resp_link_cast_i.data
                               ,v            : resp_link_cast_i.v
                               ,ready_and_rev: cmd_link_cast_i.ready_and_rev
                               };
assign resp_link_cast_o    = '{data          : client_resp_link_lo.data
                               ,v            : client_resp_link_lo.v
                               ,ready_and_rev: master_cmd_link_lo.ready_and_rev
                               };


bp_me_cce_to_mem_link_master
 #(.bp_params_p(bp_params_p)
   ,.flit_width_p(flit_width_p)
   ,.cord_width_p(cord_width_p)
   ,.cid_width_p(cid_width_p)
   ,.len_width_p(len_width_p)
   )
  master_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(mem_cmd_i)
  ,.mem_cmd_v_i(mem_cmd_v_i)
  ,.mem_cmd_ready_o(mem_cmd_ready_o)

  ,.mem_resp_o(mem_resp_o)
  ,.mem_resp_v_o(mem_resp_v_o)
  ,.mem_resp_yumi_i(mem_resp_yumi_i)

  ,.my_cord_i(my_cord_i)
  ,.my_cid_i(my_cid_i)
  ,.dst_cord_i(dst_cord_i)
  ,.dst_cid_i(dst_cid_i)
  
  ,.cmd_link_o(master_cmd_link_lo)
  ,.resp_link_i(master_resp_link_li)
  );

bp_me_cce_to_mem_link_client
 #(.bp_params_p(bp_params_p)
   ,.num_outstanding_req_p(num_outstanding_req_p)
   ,.flit_width_p(flit_width_p)
   ,.cord_width_p(cord_width_p)
   ,.cid_width_p(cid_width_p)
   ,.len_width_p(len_width_p)
   )
  client_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_o(mem_cmd_o)
  ,.mem_cmd_v_o(mem_cmd_v_o)
  ,.mem_cmd_yumi_i(mem_cmd_yumi_i)

  ,.mem_resp_i(mem_resp_i)
  ,.mem_resp_v_i(mem_resp_v_i)
  ,.mem_resp_ready_o(mem_resp_ready_o)

  ,.cmd_link_i(client_cmd_link_li)
  ,.resp_link_o(client_resp_link_lo)
  );

endmodule


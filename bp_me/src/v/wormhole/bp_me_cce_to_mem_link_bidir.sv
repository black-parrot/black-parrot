
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_cce_to_mem_link_bidir
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   , parameter num_outstanding_req_p = "inv"

   , parameter flit_width_p = "inv"
   , parameter cord_width_p = "inv"
   , parameter cid_width_p  = "inv"
   , parameter len_width_p  = "inv"

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
   )
  (input                                                clk_i
   , input                                              reset_i

   // Configuration
   , input [cord_width_p-1:0]                           my_cord_i
   , input [cid_width_p-1:0]                            my_cid_i
   , input [cord_width_p-1:0]                           dst_cord_i
   , input [cid_width_p-1:0]                            dst_cid_i

   // Master link
   , input [cce_mem_msg_header_width_lp-1:0]            mem_cmd_header_i
   , input [cce_block_width_p-1:0]                      mem_cmd_data_i
   , input                                              mem_cmd_v_i
   , output logic                                       mem_cmd_ready_and_o
   , input                                              mem_cmd_last_i

   , output logic [cce_mem_msg_header_width_lp-1:0]     mem_resp_header_o
   , output logic [cce_block_width_p-1:0]               mem_resp_data_o
   , output                                             mem_resp_v_o
   , input                                              mem_resp_yumi_i
   , output logic                                       mem_resp_last_o

   // Client link
   , output logic [cce_mem_msg_header_width_lp-1:0]     mem_cmd_header_o
   , output logic [cce_block_width_p-1:0]               mem_cmd_data_o
   , output logic                                       mem_cmd_v_o
   , input                                              mem_cmd_yumi_i
   , output logic                                       mem_cmd_last_o

   , input [cce_mem_msg_header_width_lp-1:0]            mem_resp_header_i
   , input [cce_block_width_p-1:0]                      mem_resp_data_i
   , input                                              mem_resp_v_i
   , output logic                                       mem_resp_ready_and_o
   , input                                              mem_resp_last_i

   // NOC interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]        cmd_link_i
   , output logic [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]        resp_link_i
   , output logic [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );

  `declare_bsg_ready_and_link_sif_s(flit_width_p, bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s cmd_link_cast_i, cmd_link_cast_o, resp_link_cast_i, resp_link_cast_o;
  bsg_ready_and_link_sif_s send_cmd_link_lo, send_resp_link_li;
  bsg_ready_and_link_sif_s recv_cmd_link_li, recv_resp_link_lo;
  
  assign cmd_link_cast_i = cmd_link_i;
  assign resp_link_cast_i = resp_link_i;
  assign cmd_link_o  = cmd_link_cast_o;
  assign resp_link_o = resp_link_cast_o;
  
  // Swizzle ready_and_rev
  assign recv_cmd_link_li  = '{data          : cmd_link_cast_i.data
                                 ,v            : cmd_link_cast_i.v
                                 ,ready_and_rev: resp_link_cast_i.ready_and_rev
                                 };
  assign cmd_link_cast_o     = '{data          : send_cmd_link_lo.data
                                 ,v            : send_cmd_link_lo.v
                                 ,ready_and_rev: recv_resp_link_lo.ready_and_rev
                                 };
  
  assign send_resp_link_li = '{data          : resp_link_cast_i.data
                                 ,v            : resp_link_cast_i.v
                                 ,ready_and_rev: cmd_link_cast_i.ready_and_rev
                                 };
  assign resp_link_cast_o    = '{data          : recv_resp_link_lo.data
                                 ,v            : recv_resp_link_lo.v
                                 ,ready_and_rev: send_cmd_link_lo.ready_and_rev
                                 };
  
  
  bp_me_cce_to_mem_link_send
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     )
   send_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.my_cord_i(my_cord_i)
     ,.my_cid_i(my_cid_i)
     ,.dst_cord_i(dst_cord_i)
     ,.dst_cid_i(dst_cid_i)
  

     ,.mem_cmd_header_i(mem_cmd_header_i)
     ,.mem_cmd_data_i(mem_cmd_data_i)
     ,.mem_cmd_v_i(mem_cmd_v_i)
     ,.mem_cmd_ready_and_o(mem_cmd_ready_and_o)
     ,.mem_cmd_last_i(mem_cmd_last_i)
  
     ,.mem_resp_header_o(mem_resp_header_o)
     ,.mem_resp_data_o(mem_resp_data_o)
     ,.mem_resp_v_o(mem_resp_v_o)
     ,.mem_resp_yumi_i(mem_resp_yumi_i)
     ,.mem_resp_last_o(mem_resp_last_o)  

     ,.cmd_link_o(send_cmd_link_lo)
     ,.resp_link_i(send_resp_link_li)
     );
  
  bp_me_cce_to_mem_link_recv
   #(.bp_params_p(bp_params_p)
     ,.num_outstanding_req_p(num_outstanding_req_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     )
   recv_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.mem_cmd_header_o(mem_cmd_header_o)
     ,.mem_cmd_data_o(mem_cmd_data_o)
     ,.mem_cmd_v_o(mem_cmd_v_o)
     ,.mem_cmd_yumi_i(mem_cmd_yumi_i)
     ,.mem_cmd_last_o(mem_cmd_last_o)
  
     ,.mem_resp_header_i(mem_resp_header_i)
     ,.mem_resp_data_i(mem_resp_data_i)
     ,.mem_resp_v_i(mem_resp_v_i)
     ,.mem_resp_ready_and_o(mem_resp_ready_and_o)
     ,.mem_resp_last_i(mem_resp_last_i)  

     ,.cmd_link_i(recv_cmd_link_li)
     ,.resp_link_o(recv_resp_link_lo)
     );

endmodule


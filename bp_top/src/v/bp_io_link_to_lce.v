
module bp_io_link_to_lce
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                 clk_i
   , input                               reset_i

   , input [lce_id_width_p-1:0]          lce_id_i

   , input [cce_mem_msg_width_lp-1:0]    io_cmd_i
   , input                               io_cmd_v_i
   , output                              io_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]   io_resp_o
   , output                              io_resp_v_o
   , input                               io_resp_ready_i

   , output [lce_cce_req_width_lp-1:0]   lce_req_o
   , output                              lce_req_v_o
   , input                               lce_req_ready_i

   , input [lce_cmd_width_lp-1:0]        lce_cmd_i
   , input                               lce_cmd_v_i
   , output                              lce_cmd_yumi_o

   // No lce_resp acknowledgements for I/O (uncached) accesses
   );

  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp, lce_req_packet_s);
  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cmd_width_lp, lce_cmd_packet_s);

  bp_cce_mem_msg_s io_cmd_li;
  bp_cce_mem_msg_s io_resp_lo;
  bp_lce_cce_req_s lce_req_lo;
  bp_lce_cmd_s lce_cmd_li; 

  assign io_cmd_li  = io_cmd_i;
  assign io_resp_o  = io_resp_lo;
  assign lce_req_o  = lce_req_lo;
  assign lce_cmd_li = lce_cmd_i;

  assign lce_req_v_o    = lce_req_ready_i & io_cmd_v_i;
  assign io_cmd_yumi_o  = lce_req_v_o;

  assign io_resp_v_o    = io_resp_ready_i & lce_cmd_v_i;
  assign lce_cmd_yumi_o = io_resp_v_o;

  bp_lce_cce_uc_req_size_e lce_req_size;
  assign lce_req_size = (io_cmd_li.size == e_mem_size_1)
                        ? e_lce_uc_req_1
                        : (io_cmd_li.size == e_mem_size_2)
                          ? e_lce_uc_req_2
                          : (io_cmd_li.size == e_mem_size_4)
                            ? e_lce_uc_req_4
                            : e_lce_uc_req_8;

  // TODO: Since we don't send size along with lce_cmd, 
  //         we need to assume all uncached load accesses are 8 bytes.
  bp_cce_mem_req_size_e mem_resp_size;
  assign mem_resp_size = e_mem_size_8;
  //assign mem_resp_size = (lce_cmd_li.msg.uc_req.uc_size == e_lce_uc_req_1)
  //                       ? e_mem_size_1
  //                       : (lce_cmd_li.msg.uc_req.uc_size == e_lce_uc_req_2)
  //                         ? e_mem_size_2
  //                         : (lce_cmd_li.msg.uc_req.uc_size == e_lce_uc_req_4)
  //                           ? e_mem_size_4
  //                           : e_mem_size_8;

  logic [cce_id_width_p-1:0] cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   addr_map
    (.paddr_i(io_cmd_li.addr)

     ,.cce_id_o(cce_id_lo)
     );

  wire mem_cmd_wr_not_rd = (io_cmd_li.msg_type == e_cce_mem_uc_wr);
  wire lce_cmd_wr_not_rd = (lce_cmd_li.msg_type == e_lce_cmd_uc_st_done);
  always_comb
    begin
      lce_req_lo                    = '0;
      lce_req_lo.msg.uc_req.data    = io_cmd_li.data;
      lce_req_lo.msg.uc_req.uc_size = lce_req_size;
      lce_req_lo.addr               = io_cmd_li.addr;
      lce_req_lo.msg_type           = mem_cmd_wr_not_rd ? e_lce_req_type_uc_wr : e_lce_req_type_uc_rd;
      lce_req_lo.src_id             = lce_id_i;
      lce_req_lo.dst_id             = cce_id_lo;

      io_resp_lo                = '0;
      io_resp_lo.data           = lce_cmd_li.msg.dt_cmd.data;
      io_resp_lo.size           = mem_resp_size;
      io_resp_lo.addr           = lce_cmd_li.msg.dt_cmd.addr;
      io_resp_lo.msg_type       = lce_cmd_wr_not_rd ? e_cce_mem_uc_wr : e_cce_mem_uc_rd;
    end

endmodule


/**
 *  bp_nbf_loader_node.v
 *
 */

module bp_nbf_loader_node

  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_me_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
  )

  (input  clk_i
  ,input  reset_i
  ,output done_o

  ,input   [mem_noc_cord_width_p-1:0]            my_cord_i
  ,input   [mem_noc_cord_width_p-1:0]            dram_cord_i
  ,input   [mem_noc_cord_width_p-1:0]            host_cord_i
  ,input   [mem_noc_cord_width_p-1:0]            clint_cord_i
  
  // bsg_noc_wormhole interface
  , input  [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_i
  , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

  , input  [bsg_ready_and_link_sif_width_lp-1:0] resp_link_i
  , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
  );
  
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  
  // nbf loader
  bp_cce_mem_msg_s nbf_resp_li, nbf_cmd_lo;
  logic nbf_resp_v_li, nbf_resp_yumi_lo, nbf_cmd_v_lo, nbf_cmd_ready_li;
  
  bp_nonsynth_nbf_loader
 #(.bp_params_p(bp_params_p)
  ) loader
  (.clk_i           (clk_i)
  ,.reset_i         (reset_i)
  ,.done_o          (done_o)
  
  ,.mem_cmd_o       (nbf_cmd_lo)
  ,.mem_cmd_v_o     (nbf_cmd_v_lo)
  ,.mem_cmd_ready_i (nbf_cmd_ready_li)
  
  ,.mem_resp_i      (nbf_resp_li)
  ,.mem_resp_v_i    (nbf_resp_v_li)
  ,.mem_resp_yumi_o (nbf_resp_yumi_lo)
  );
  
  // addr_map to multiple caches
  logic [mem_noc_cord_width_p-1:0] dest_cord_lo;
  
  bp_addr_map
 #(.bp_params_p(bp_params_p)
  ) cmd_map
  (.paddr_i     (nbf_cmd_lo.addr)
  ,.clint_cord_i(clint_cord_i)
  ,.dram_cord_i (dram_cord_i)
  ,.host_cord_i (host_cord_i)
  ,.dst_cid_o   ()
  ,.dst_cord_o  (dest_cord_lo)
  );
  
  // master adapter
  bp_me_cce_to_wormhole_link_master
 #(.bp_params_p(bp_params_p)
  ) master
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i      (nbf_cmd_lo)
  ,.mem_cmd_v_i    (nbf_cmd_v_lo)
  ,.mem_cmd_ready_o(nbf_cmd_ready_li)

  ,.mem_resp_o     (nbf_resp_li)
  ,.mem_resp_v_o   (nbf_resp_v_li)
  ,.mem_resp_yumi_i(nbf_resp_yumi_lo)

  ,.my_cord_i      (my_cord_i)
  ,.my_cid_i       ('0)
  ,.dst_cord_i     (dest_cord_lo)
  ,.dst_cid_i      ('0)

  ,.cmd_link_i     (cmd_link_i)
  ,.cmd_link_o     (cmd_link_o)

  ,.resp_link_i    (resp_link_i)
  ,.resp_link_o    (resp_link_o)
  );

endmodule

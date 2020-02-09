
module bp_stream_host

  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_me_pkg::*;
  
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  
  ,parameter stream_addr_width_p = 32
  ,parameter stream_data_width_p = 32

  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
  )

  (input                                        clk_i
  ,input                                        reset_i
  ,output                                       prog_done_o

  ,input  [io_noc_cord_width_p-1:0]             my_cord_i
  ,input  [io_noc_cord_width_p-1:0]             dst_cord_i

  ,input  [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_i
  ,output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

  ,input  [bsg_ready_and_link_sif_width_lp-1:0] resp_link_i
  ,output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
  
  ,input                                        stream_v_i
  ,input  [stream_addr_width_p-1:0]             stream_addr_i
  ,input  [stream_data_width_p-1:0]             stream_data_i
  ,output                                       stream_yumi_o
  
  ,output                                       stream_v_o
  ,output [stream_data_width_p-1:0]             stream_data_o
  ,input                                        stream_ready_i
  );
  
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  
  // Client
  bp_cce_mem_msg_s       cce_resp_lo;
  logic                  cce_resp_v_lo, cce_resp_ready_li;
  bp_cce_mem_msg_s       cce_cmd_li;
  logic                  cce_cmd_v_li, cce_cmd_yumi_lo;
  
  // Master
  bp_cce_mem_msg_s       cce_cmd_lo;
  logic                  cce_cmd_v_lo, cce_cmd_ready_li;
  bp_cce_mem_msg_s       cce_resp_li;
  logic                  cce_resp_v_li, cce_resp_yumi_lo;
  
  // cce to wormhole link
  bp_me_cce_to_mem_link_bidir
 #(.bp_params_p          (bp_params_p)
  ,.num_outstanding_req_p(io_noc_max_credits_p)
  ,.flit_width_p         (io_noc_flit_width_p)
  ,.cord_width_p         (io_noc_cord_width_p)
  ,.cid_width_p          (io_noc_cid_width_p)
  ,.len_width_p          (io_noc_len_width_p)
  ) bidir_link
  (.clk_i           (clk_i)
  ,.reset_i         (reset_i)
  // Master
  ,.mem_cmd_i       (cce_cmd_lo)
  ,.mem_cmd_v_i     (cce_cmd_v_lo)
  ,.mem_cmd_ready_o (cce_cmd_ready_li)

  ,.mem_resp_o      (cce_resp_li)
  ,.mem_resp_v_o    (cce_resp_v_li)
  ,.mem_resp_yumi_i (cce_resp_yumi_lo)
  // Client
  ,.mem_cmd_o       (cce_cmd_li)
  ,.mem_cmd_v_o     (cce_cmd_v_li)
  ,.mem_cmd_yumi_i  (cce_cmd_yumi_lo)

  ,.mem_resp_i      (cce_resp_lo)
  ,.mem_resp_v_i    (cce_resp_v_lo)
  ,.mem_resp_ready_o(cce_resp_ready_li)

  ,.my_cord_i(my_cord_i)
  ,.my_cid_i('0)
  ,.dst_cord_i(dst_cord_i)
  ,.dst_cid_i('0)
     
  ,.cmd_link_i      (cmd_link_i)
  ,.cmd_link_o      (cmd_link_o)

  ,.resp_link_i     (resp_link_i)
  ,.resp_link_o     (resp_link_o)
  );
  
  // Stream address map
  logic nbf_v_li, mmio_v_li;
  logic nbf_ready_lo, mmio_ready_lo;;
  
  assign nbf_v_li  = stream_v_i & (stream_addr_i == 32'h00000010);
  assign mmio_v_li = stream_v_i & (stream_addr_i == 32'h00000020);
  
  assign stream_yumi_o = (nbf_v_li & nbf_ready_lo) | (mmio_v_li & mmio_ready_lo);
  
  // nbf loader
  bp_stream_nbf_loader
 #(.bp_params_p(bp_params_p)
  ,.stream_data_width_p(stream_data_width_p)
  ) nbf_loader
  (.clk_i          (clk_i)
  ,.reset_i        (reset_i)
  ,.done_o         (prog_done_o)

  ,.io_cmd_o       (cce_cmd_lo)
  ,.io_cmd_v_o     (cce_cmd_v_lo)
  ,.io_cmd_ready_i (cce_cmd_ready_li)

  ,.io_resp_i      (cce_resp_li)
  ,.io_resp_v_i    (cce_resp_v_li)
  ,.io_resp_yumi_o (cce_resp_yumi_lo)

  ,.stream_v_i     (nbf_v_li)
  ,.stream_data_i  (stream_data_i)
  ,.stream_ready_o (nbf_ready_lo)
  );
  
  // mmio
  bp_stream_mmio
 #(.bp_params_p(bp_params_p)
  ,.stream_data_width_p(stream_data_width_p)
  ) mmio
  (.clk_i           (clk_i)
  ,.reset_i         (reset_i)

  ,.io_cmd_i        (cce_cmd_li)
  ,.io_cmd_v_i      (cce_cmd_v_li)
  ,.io_cmd_yumi_o   (cce_cmd_yumi_lo)

  ,.io_resp_o       (cce_resp_lo)
  ,.io_resp_v_o     (cce_resp_v_lo)
  ,.io_resp_ready_i (cce_resp_ready_li)

  ,.stream_v_i      (mmio_v_li)
  ,.stream_data_i   (stream_data_i)
  ,.stream_ready_o  (mmio_ready_lo)
  
  ,.stream_v_o      (stream_v_o)
  ,.stream_data_o   (stream_data_o)
  ,.stream_yumi_i   (stream_v_o & stream_ready_i)
  );

endmodule


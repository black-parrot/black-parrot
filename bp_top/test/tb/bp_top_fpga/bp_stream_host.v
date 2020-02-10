
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

  ,input  [cce_mem_msg_width_lp-1:0]            io_cmd_i
  ,input                                        io_cmd_v_i
  ,output                                       io_cmd_yumi_o

  ,output [cce_mem_msg_width_lp-1:0]            io_resp_o
  ,output                                       io_resp_v_o
  ,input                                        io_resp_ready_i
  
  ,output [cce_mem_msg_width_lp-1:0]            io_cmd_o
  ,output                                       io_cmd_v_o
  ,input                                        io_cmd_yumi_i
  
  ,input  [cce_mem_msg_width_lp-1:0]            io_resp_i
  ,input                                        io_resp_v_i
  ,output                                       io_resp_ready_o
  
  ,input                                        stream_v_i
  ,input  [stream_addr_width_p-1:0]             stream_addr_i
  ,input  [stream_data_width_p-1:0]             stream_data_i
  ,output                                       stream_yumi_o
  
  ,output                                       stream_v_o
  ,output [stream_data_width_p-1:0]             stream_data_o
  ,input                                        stream_ready_i
  );
  
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  
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

  ,.io_cmd_o       (io_cmd_o)
  ,.io_cmd_v_o     (io_cmd_v_o)
  ,.io_cmd_yumi_i (io_cmd_yumi_i)

  ,.io_resp_i      (io_resp_i)
  ,.io_resp_v_i    (io_resp_v_i)
  ,.io_resp_ready_o (io_resp_ready_o)

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

  ,.io_cmd_i        (io_cmd_i)
  ,.io_cmd_v_i      (io_cmd_v_i)
  ,.io_cmd_yumi_o   (io_cmd_yumi_o)

  ,.io_resp_o       (io_resp_o)
  ,.io_resp_v_o     (io_resp_v_o)
  ,.io_resp_ready_i (io_resp_ready_i)

  ,.stream_v_i      (mmio_v_li)
  ,.stream_data_i   (stream_data_i)
  ,.stream_ready_o  (mmio_ready_lo)
  
  ,.stream_v_o      (stream_v_o)
  ,.stream_data_o   (stream_data_o)
  ,.stream_yumi_i   (stream_v_o & stream_ready_i)
  );

endmodule


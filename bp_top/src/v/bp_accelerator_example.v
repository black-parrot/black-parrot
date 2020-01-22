/**
 *  bp_accelerator_example.v
 *
 */

module bp_accelerator_example
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_be_dcache_pkg::*;  
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_io_if_widths(paddr_width_p, dword_width_p, lce_id_width_p) 
    )
   (
    input                                     clk_i
    , input                                   reset_i

    , output [lce_cce_req_width_lp-1:0]       lce_req_o
    , output                                  lce_req_v_o
    , input                                   lce_req_ready_i

    , output [lce_cce_resp_width_lp-1:0]      lce_resp_o
    , output                                  lce_resp_v_o
    , input                                   lce_resp_ready_i

    , input [lce_cmd_width_lp-1:0]            lce_cmd_i
    , input                                   lce_cmd_v_i
    , output                                  lce_cmd_yumi_o

    , output [lce_cmd_width_lp-1:0]           lce_cmd_o
    , output                                  lce_cmd_v_o
    , input                                   lce_cmd_ready_i

    // Master link
    , input  [cce_io_msg_width_lp-1:0]        io_cmd_i
    , input                                   io_cmd_v_i
    , output                                  io_cmd_ready_o

    , output [cce_io_msg_width_lp-1:0]        io_resp_o
    , output                                  io_resp_v_o
    , input                                   io_resp_yumi_i

    
    , input [io_noc_cord_width_p-1:0]         my_cord_i
//    , input [io_noc_cord_width_p-1:0]         dst_cord_i

    );

//dcache_pkt is the cached requests of the accelerator when miss happens
 `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dword_width_p);  
  bp_be_dcache_pkt_s        dcache_pkt;   
  logic                     dcache_ready, dcache_v;
  logic [dword_width_p-1:0] dcache_data;
  logic                     dcache_tlb_miss, dcache_poison;
  logic [ptag_width_p-1:0]  dcache_ptag;
  logic                     dcache_uncached;
  logic                     dcache_miss_v;
  logic                    load_op_tl_lo, store_op_tl_lo;
   
 bp_be_dcache 
  #(.bp_params_p(bp_params_p))
  accel_dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cfg_bus_i()//cfg_bus_cast_i.dcache_id is used inside cache to set the lce_id (prog needs to send it)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(/*dcache_pkt_v*/ 1'b0)
    ,.ready_o(dcache_ready)

    ,.v_o(dcache_v)
    ,.data_o(dcache_data)

    ,.tlb_miss_i(dcache_tlb_miss)
    ,.ptag_i(dcache_ptag)
    ,.uncached_i(dcache_uncached)

    ,.load_op_tl_o(load_op_tl_lo)
    ,.store_op_tl_o(store_op_tl_lo)

    ,.cache_miss_o(dcache_miss_v)
    ,.poison_i(dcache_poison)

    // LCE-CCE interface
    ,.lce_req_o(lce_req_o)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_resp_o)
    ,.lce_resp_v_o(lce_resp_v_o)
    ,.lce_resp_ready_i(lce_resp_ready_i)

    // CCE-LCE interface
    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_yumi_o(lce_cmd_yumi_o)

    ,.lce_cmd_o(lce_cmd_o)
    ,.lce_cmd_v_o(lce_cmd_v_o)
    ,.lce_cmd_ready_i(lce_cmd_ready_i)

    ,.credits_full_o(/*credits_full_o*/)
    ,.credits_empty_o(/*credits_empty_o*/)
  
    );

  // CCE-IO interface packets used for uncached requests-read/write memory mapped CSR
  `declare_bp_io_if(paddr_width_p, dword_width_p, lce_id_width_p);
  
  bp_cce_io_msg_s io_cmd_cast_i, io_resp_cast_o;

  assign io_cmd_cast_i = io_cmd_i;
  assign io_resp_o = io_resp_cast_o;


endmodule


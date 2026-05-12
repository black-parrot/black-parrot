/**
 * wrapper.sv
 *
 * Thin wrapper around bp_be_dcache for bind target support.
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module wrapper
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter bp_cache_features_t features_p = dcache_features_p
   , parameter sets_p         = dcache_sets_p
   , parameter assoc_p        = dcache_assoc_p
   , parameter block_width_p  = dcache_block_width_p
   , parameter fill_width_p   = dcache_fill_width_p
   , parameter data_width_p   = dcache_data_width_p
   , parameter tag_width_p    = dcache_tag_width_p
   , parameter id_width_p     = dcache_req_id_width_p

   `declare_bp_be_dcache_engine_if_widths(paddr_width_p, tag_width_p, sets_p, assoc_p, data_width_p, block_width_p, fill_width_p, id_width_p)

   , localparam dcache_pkt_width_lp = `bp_be_dcache_pkt_width(vaddr_width_p)
   )
  (input                                             clk_i
   , input                                           reset_i

   , output logic                                    busy_o
   , output logic                                    ordered_o

   // Cycle 0: Request
   , input [dcache_pkt_width_lp-1:0]                 dcache_pkt_i
   , input                                           v_i

   // Cycle 1: Tag Lookup
   , input [ptag_width_p-1:0]                        ptag_i
   , input                                           ptag_v_i
   , input                                           ptag_uncached_i
   , input                                           ptag_dram_i
   , input [data_width_p-1:0]                        st_data_i
   , input                                           flush_i

   // Cycle 2: Tag Verify
   , output logic                                    v_o
   , output logic [data_width_p-1:0]                 data_o
   , output logic [reg_addr_width_gp-1:0]            rd_addr_o
   , output logic [$bits(bp_be_int_tag_e)-1:0]       tag_o
   , output logic                                    unsigned_o
   , output logic                                    int_o
   , output logic                                    float_o
   , output logic                                    ptw_o
   , output logic                                    ret_o
   , output logic                                    late_o

   // Cache Engine Interface
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_lock_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input [id_width_p-1:0]                          cache_req_id_i
   , input                                           cache_req_critical_i
   , input                                           cache_req_last_i
   , input                                           cache_req_credits_full_i
   , input                                           cache_req_credits_empty_i

   // Data mem
   , input                                           data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0]        data_mem_pkt_i
   , output logic                                    data_mem_pkt_yumi_o
   , output logic [block_width_p-1:0]                data_mem_o

   // Tag mem
   , input                                           tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0]         tag_mem_pkt_i
   , output logic                                    tag_mem_pkt_yumi_o
   , output logic [dcache_tag_info_width_lp-1:0]     tag_mem_o

   // Stat mem
   , input                                           stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0]        stat_mem_pkt_i
   , output logic                                    stat_mem_pkt_yumi_o
   , output logic [dcache_stat_info_width_lp-1:0]    stat_mem_o
   );

  bp_be_dcache
   #(.bp_params_p(bp_params_p)
     ,.features_p(features_p)
     ,.sets_p(sets_p)
     ,.assoc_p(assoc_p)
     ,.block_width_p(block_width_p)
     ,.fill_width_p(fill_width_p)
     ,.data_width_p(data_width_p)
     ,.tag_width_p(tag_width_p)
     ,.id_width_p(id_width_p)
     )
   dut
    (.*);

endmodule

/**
 *
 * Name:
 *   bp_be_pipe_mem.v
 *
 * Description:
 *   Pipeline for RISC-V memory instructions. This includes both int + float loads + stores.
 *
 * Notes:
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_pipe_mem
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache)
   // Generated parameters
   , localparam cfg_bus_width_lp       = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   , localparam dispatch_pkt_width_lp  = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp  = `bp_be_ptw_fill_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam trans_info_width_lp    = `bp_be_trans_info_width(ptag_width_p)
   , localparam commit_pkt_width_lp    = `bp_be_commit_pkt_width(vaddr_width_p, paddr_width_p)
   , localparam wb_pkt_width_lp        = `bp_be_wb_pkt_width(vaddr_width_p)
   )
  (input                                  clk_i
   , input                                reset_i

   , input [cfg_bus_width_lp-1:0]         cfg_bus_i
   , input                                flush_i
   , input                                sfence_i

   , output logic                         ready_o

   , input [dispatch_pkt_width_lp-1:0]    reservation_i

   , input [commit_pkt_width_lp-1:0]      commit_pkt_i
   , output [ptw_fill_pkt_width_lp-1:0]   ptw_fill_pkt_o
   , output logic                         ptw_busy_o

   , output logic                         tlb_load_miss_v_o
   , output logic                         tlb_store_miss_v_o
   , output logic                         cache_miss_v_o
   , output logic                         cache_fail_v_o
   , output logic                         fencei_clean_v_o
   , output logic                         fencei_dirty_v_o
   , output logic                         load_misaligned_v_o
   , output logic                         load_access_fault_v_o
   , output logic                         load_page_fault_v_o
   , output logic                         store_misaligned_v_o
   , output logic                         store_access_fault_v_o
   , output logic                         store_page_fault_v_o

   , output logic [dpath_width_gp-1:0]    early_data_o
   , output rv64_fflags_s                 early_fflags_o
   , output logic                         early_v_o
   , output logic [dpath_width_gp-1:0]    final_data_o
   , output logic                         final_v_o

   , output logic [wb_pkt_width_lp-1:0]   late_iwb_pkt_o
   , output logic                         late_iwb_pkt_v_o
   , input                                late_iwb_pkt_yumi_i
   , output logic [wb_pkt_width_lp-1:0]   late_fwb_pkt_o
   , output logic                         late_fwb_pkt_v_o
   , input                                late_fwb_pkt_yumi_i

   , input [trans_info_width_lp-1:0]      trans_info_i

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_busy_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input                                           cache_req_critical_tag_i
   , input                                           cache_req_critical_data_i
   , input                                           cache_req_complete_i
   , input                                           cache_req_credits_full_i
   , input                                           cache_req_credits_empty_i

   , input                                           data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0]        data_mem_pkt_i
   , output logic                                    data_mem_pkt_yumi_o
   , output logic [dcache_block_width_p-1:0]         data_mem_o

   , input                                           tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0]         tag_mem_pkt_i
   , output logic                                    tag_mem_pkt_yumi_o
   , output logic [dcache_tag_info_width_lp-1:0]     tag_mem_o

   , input                                           stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0]        stat_mem_pkt_i
   , output logic                                    stat_mem_pkt_yumi_o
   , output logic [dcache_stat_info_width_lp-1:0]    stat_mem_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache);
  `declare_bp_be_dcache_pkt_s(vaddr_width_p);

  // Cast input and output ports
  bp_be_dispatch_pkt_s   reservation;
  bp_be_decode_s         decode;
  rv64_instr_s           instr;
  bp_cfg_bus_s           cfg_bus;
  bp_be_commit_pkt_s     commit_pkt;
  bp_be_ptw_fill_pkt_s   ptw_fill_pkt;
  bp_be_trans_info_s     trans_info;
  bp_dcache_req_s        cache_req_cast_o;
  bp_be_wb_pkt_s         late_iwb_pkt;
  bp_be_wb_pkt_s         late_fwb_pkt;

  assign cfg_bus = cfg_bus_i;
  assign ptw_fill_pkt_o = ptw_fill_pkt;
  assign commit_pkt = commit_pkt_i;
  assign trans_info = trans_info_i;
  assign cache_req_o = cache_req_cast_o;
  assign late_iwb_pkt_o = late_iwb_pkt;
  assign late_fwb_pkt_o = late_fwb_pkt;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dpath_width_gp-1:0] rs1 = reservation.rs1[0+:dpath_width_gp];
  wire [dpath_width_gp-1:0] rs2 = reservation.rs2[0+:dpath_width_gp];
  wire [dpath_width_gp-1:0] imm = reservation.imm[0+:dpath_width_gp];

  /* Internal connections */
  /* TLB ports */
  logic                    dtlb_miss_v, dtlb_w_v, dtlb_r_v, dtlb_v_lo;
  logic [vtag_width_p-1:0] dtlb_w_vtag;
  bp_pte_leaf_s            dtlb_w_entry;

  /* PTW ports */
  logic [ptag_width_p-1:0]  ptw_dcache_ptag;
  logic                     ptw_dcache_ptag_v;
  logic                     ptw_dcache_v, ptw_busy;
  bp_be_dcache_pkt_s        ptw_dcache_pkt;

  /* D-Cache ports */
  bp_be_dcache_pkt_s        dcache_pkt;
  logic [dpath_width_gp-1:0] dcache_early_data, dcache_final_data, dcache_late_data;
  rv64_fflags_s             dcache_early_fflags;
  logic [reg_addr_width_gp-1:0] dcache_late_rd_addr;
  logic [ptag_width_p-1:0]  dcache_ptag;
  logic                     dcache_pkt_v;
  logic                     dcache_early_miss_v, dcache_early_fencei, dcache_early_hit_v, dcache_final_v;
  logic                     dcache_late_float, dcache_late_v, dcache_late_yumi;
  logic                     dcache_ptag_v;
  logic                     dcache_ptag_uncached;
  logic                     dcache_ptag_dram;
  logic                     dcache_ready_lo;

  logic load_access_fault_v, store_access_fault_v;
  logic load_page_fault_v, store_page_fault_v;
  logic load_misaligned_v, store_misaligned_v;

  /* Control signals */
  wire is_store  = (decode.pipe_mem_early_v | decode.pipe_mem_final_v) & decode.dcache_w_v;
  wire is_load   = (decode.pipe_mem_early_v | decode.pipe_mem_final_v) & decode.dcache_r_v;
  wire is_fencei = (decode.pipe_mem_early_v | decode.pipe_mem_final_v) & decode.fu_op inside {e_dcache_op_fencei};
  wire is_req    = reservation.v & (is_store | is_load | is_fencei);

  // Calculate cache access eaddr
  wire [rv64_eaddr_width_gp-1:0] eaddr = rs1 + imm;

  // D-TLB connections
  assign dtlb_r_v        = reservation.v & (is_store | is_load);
  assign dtlb_w_v        = commit_pkt.dtlb_fill_v;
  assign dtlb_w_vtag     = commit_pkt.vaddr[vaddr_width_p-1-:vtag_width_p];
  assign dtlb_w_entry    = commit_pkt.pte_leaf;

  // Some duplicated decode logic from dcache_decoder. Can send this information
  //   as part of dcache_pkt to reduce overhead
  logic [1:0] size;
  always_comb
    unique case (decode.fu_op)
      e_dcache_op_lb, e_dcache_op_lbu, e_dcache_op_sb: size = 2'b00;
      e_dcache_op_lh, e_dcache_op_lhu, e_dcache_op_sh: size = 2'b01;
      e_dcache_op_amoswapw, e_dcache_op_amoaddw, e_dcache_op_amoxorw
      ,e_dcache_op_amoandw, e_dcache_op_amoorw, e_dcache_op_amominw
      ,e_dcache_op_amomaxw, e_dcache_op_amominuw, e_dcache_op_amomaxuw
      ,e_dcache_op_lw, e_dcache_op_lwu, e_dcache_op_sw
      ,e_dcache_op_flw, e_dcache_op_fsw
      ,e_dcache_op_lrw, e_dcache_op_scw:               size = 2'b10;
      default: size = 2'b11;
    endcase

  logic [ptag_width_p-1:0] dtlb_ptag_lo;
  bp_mmu
   #(.bp_params_p(bp_params_p)
     ,.tlb_els_4k_p(dtlb_els_4k_p)
     ,.tlb_els_1g_p(dtlb_els_1g_p)
     )
   dmmu
    (.clk_i(~clk_i)
     ,.reset_i(reset_i)

     ,.flush_i(sfence_i)
     ,.priv_mode_i(trans_info.priv_mode)
     ,.sum_i(trans_info.mstatus_sum)
     ,.mxr_i(trans_info.mstatus_mxr)
     ,.trans_en_i(trans_info.translation_en)
     ,.uncached_mode_i((cfg_bus.dcache_mode == e_lce_mode_uncached))
     ,.nonspec_mode_i((cfg_bus.dcache_mode == e_lce_mode_nonspec))
     ,.hio_mask_i(cfg_bus.hio_mask)

     ,.w_v_i(dtlb_w_v)
     ,.w_vtag_i(dtlb_w_vtag)
     ,.w_entry_i(dtlb_w_entry)

     ,.r_v_i(dtlb_r_v)
     ,.r_instr_i('0)
     ,.r_load_i(is_load)
     ,.r_store_i(is_store)
     ,.r_eaddr_i(eaddr)
     ,.r_size_i(size)

     ,.r_v_o(dtlb_v_lo)
     ,.r_ptag_o(dtlb_ptag_lo)
     ,.r_instr_miss_o()
     ,.r_load_miss_o(tlb_load_miss_v_o)
     ,.r_store_miss_o(tlb_store_miss_v_o)
     ,.r_uncached_o(dcache_ptag_uncached)
     ,.r_nonidem_o(/* All D$ misses are non-speculative */)
     ,.r_dram_o(dcache_ptag_dram)
     ,.r_instr_access_fault_o()
     ,.r_load_access_fault_o(load_access_fault_v)
     ,.r_store_access_fault_o(store_access_fault_v)
     ,.r_instr_misaligned_o()
     ,.r_load_misaligned_o(load_misaligned_v)
     ,.r_store_misaligned_o(store_misaligned_v)
     ,.r_instr_page_fault_o()
     ,.r_load_page_fault_o(load_page_fault_v)
     ,.r_store_page_fault_o(store_page_fault_v)
     );

  bp_be_ptw_miss_pkt_s ptw_miss_pkt;
  assign ptw_miss_pkt =
    '{instr_miss_v  : commit_pkt.itlb_miss
      ,store_miss_v : commit_pkt.dtlb_store_miss
      ,load_miss_v  : commit_pkt.dtlb_load_miss
      ,vaddr        : commit_pkt.vaddr
      ,mstatus_mxr  : trans_info.mstatus_mxr
      ,mstatus_sum  : trans_info.mstatus_sum
      ,base_ppn     : trans_info.base_ppn
      ,priv_mode    : trans_info.priv_mode
      };

  bp_be_ptw
   #(.bp_params_p(bp_params_p)
     ,.pte_width_p(sv39_pte_width_gp)
     ,.page_table_depth_p(sv39_levels_gp)
     ,.pte_size_in_bytes_p(sv39_pte_size_in_bytes_gp)
     ,.page_idx_width_p(sv39_page_idx_width_gp)
     )
   ptw
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.busy_o(ptw_busy)
     ,.ptw_miss_pkt_i(ptw_miss_pkt)
     ,.ptw_fill_pkt_o(ptw_fill_pkt)

     ,.dcache_v_o(ptw_dcache_v)
     ,.dcache_pkt_o(ptw_dcache_pkt)
     ,.dcache_ptag_o(ptw_dcache_ptag)
     ,.dcache_ptag_v_o(ptw_dcache_ptag_v)
     ,.dcache_ready_i(dcache_ready_lo)

     ,.dcache_early_hit_v_i(dcache_early_hit_v)
     ,.dcache_early_data_i(dcache_early_data)
     );

  bp_be_dcache
    #(.bp_params_p(bp_params_p))
    dcache
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)

      ,.dcache_pkt_i(dcache_pkt)
      ,.v_i(dcache_pkt_v)
      ,.ready_o(dcache_ready_lo)
      ,.poison_req_i(flush_i)

      ,.ptag_i(dcache_ptag)
      ,.ptag_v_i(dcache_ptag_v)
      ,.ptag_uncached_i(dcache_ptag_uncached)
      ,.ptag_dram_i(dcache_ptag_dram)
      ,.poison_tl_i(flush_i)

      ,.early_hit_v_o(dcache_early_hit_v)
      ,.early_miss_v_o(dcache_early_miss_v)
      ,.early_fencei_o(dcache_early_fencei)
      ,.early_data_o(dcache_early_data)
      ,.early_fflags_o(dcache_early_fflags)
      ,.final_data_o(dcache_final_data)
      ,.final_v_o(dcache_final_v)

      ,.late_rd_addr_o(dcache_late_rd_addr)
      ,.late_float_o(dcache_late_float)
      ,.late_data_o(dcache_late_data)
      ,.late_v_o(dcache_late_v)
      ,.late_yumi_i(dcache_late_yumi)

      // D$-LCE Interface
      ,.cache_req_o(cache_req_cast_o)
      ,.cache_req_v_o(cache_req_v_o)
      ,.cache_req_yumi_i(cache_req_yumi_i)
      ,.cache_req_busy_i(cache_req_busy_i)
      ,.cache_req_metadata_o(cache_req_metadata_o)
      ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
      ,.cache_req_critical_tag_i(cache_req_critical_tag_i)
      ,.cache_req_critical_data_i(cache_req_critical_data_i)
      ,.cache_req_complete_i(cache_req_complete_i)
      ,.cache_req_credits_full_i(cache_req_credits_full_i)
      ,.cache_req_credits_empty_i(cache_req_credits_empty_i)

      ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
      ,.data_mem_pkt_i(data_mem_pkt_i)
      ,.data_mem_o(data_mem_o)
      ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)
      ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
      ,.tag_mem_pkt_i(tag_mem_pkt_i)
      ,.tag_mem_o(tag_mem_o)
      ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)
      ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
      ,.stat_mem_pkt_i(stat_mem_pkt_i)
      ,.stat_mem_o(stat_mem_o)
      ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
      );

  // D-Cache connections
  always_comb
    if (ptw_busy)
      begin
        dcache_pkt_v    = ptw_dcache_v;
        dcache_pkt      = ptw_dcache_pkt;
        dcache_ptag     = ptw_dcache_ptag;
        dcache_ptag_v   = ptw_dcache_ptag_v;
      end
    else
      begin
        dcache_pkt_v           = reservation.v & (decode.pipe_mem_early_v | decode.pipe_mem_final_v);
        dcache_pkt.rd_addr     = instr.t.rtype.rd_addr;
        dcache_pkt.opcode      = bp_be_dcache_fu_op_e'(decode.fu_op);
        dcache_pkt.vaddr       = eaddr[0+:vaddr_width_p];
        dcache_pkt.data        = rs2;
        dcache_ptag            = dtlb_ptag_lo;
        // D$ can't handle misaligned accesses
        dcache_ptag_v          = dtlb_v_lo & ~load_misaligned_v & ~store_misaligned_v;
      end

  logic early_v_r;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(2))
   req_chain
    (.clk_i(~clk_i)
     ,.data_i(is_req)
     ,.data_o(early_v_r)
     );

  assign cache_fail_v_o         = early_v_r & ~dcache_early_hit_v  & ~dcache_early_miss_v;
  assign cache_miss_v_o         = early_v_r & ~dcache_early_fencei &  dcache_early_miss_v;
  assign fencei_clean_v_o       = early_v_r &  dcache_early_fencei &  dcache_early_hit_v;
  assign fencei_dirty_v_o       = early_v_r &  dcache_early_fencei & ~dcache_early_hit_v;

  assign store_page_fault_v_o   = store_page_fault_v;
  assign load_page_fault_v_o    = load_page_fault_v;
  assign store_access_fault_v_o = store_access_fault_v;
  assign load_access_fault_v_o  = load_access_fault_v;
  assign store_misaligned_v_o   = store_misaligned_v;
  assign load_misaligned_v_o    = load_misaligned_v;

  assign ready_o                = dcache_ready_lo;
  assign ptw_busy_o             = ptw_busy;
  assign early_data_o           = dcache_early_data;
  assign early_fflags_o         = dcache_early_fflags;
  assign final_data_o           = dcache_final_data;

  assign late_iwb_pkt = '{ird_w_v    : 1'b1
                          ,late      : 1'b1
                          ,rd_addr   : dcache_late_rd_addr
                          ,rd_data   : dcache_late_data
                          ,default: '0
                          };
  assign late_fwb_pkt = '{frd_w_v    : 1'b1
                          ,late      : 1'b1
                          ,rd_addr   : dcache_late_rd_addr
                          ,rd_data   : dcache_late_data
                          ,default: '0
                          };
  assign late_iwb_pkt_v_o = dcache_late_v & ~dcache_late_float;
  assign late_fwb_pkt_v_o = dcache_late_v &  dcache_late_float;
  assign dcache_late_yumi = late_fwb_pkt_yumi_i | late_iwb_pkt_yumi_i;

  wire early_v_li = reservation.v & reservation.decode.pipe_mem_early_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(1))
   early_chain
    (.clk_i(clk_i)

     ,.data_i(early_v_li)
     ,.data_o(early_v_o)
     );

  wire final_v_li = reservation.v & reservation.decode.pipe_mem_final_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(2))
   final_chain
    (.clk_i(clk_i)

     ,.data_i(final_v_li)
     ,.data_o(final_v_o)
     );

endmodule


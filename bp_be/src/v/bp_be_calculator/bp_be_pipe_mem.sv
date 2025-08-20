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
   `declare_bp_be_dcache_engine_if_widths(paddr_width_p, dcache_tag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache_req_id_width_p)
   `declare_bp_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p)
   // Generated parameters
   , localparam cfg_bus_width_lp      = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                  clk_i
   , input                                reset_i

   , input [cfg_bus_width_lp-1:0]         cfg_bus_i
   , input                                flush_i
   , input                                sfence_i

   , output logic                         busy_o
   , output logic                         ordered_o

   , input [reservation_width_lp-1:0]     reservation_i
   , input [dword_width_gp-1:0]           rs2_val_i

   , input [commit_pkt_width_lp-1:0]      commit_pkt_i

   , output logic                         tlb_load_miss_v_o
   , output logic                         tlb_store_miss_v_o
   , output logic                         cache_miss_v_o
   , output logic                         cache_replay_v_o
   , output logic                         load_misaligned_v_o
   , output logic                         load_access_fault_v_o
   , output logic                         load_page_fault_v_o
   , output logic                         store_misaligned_v_o
   , output logic                         store_access_fault_v_o
   , output logic                         store_page_fault_v_o

   , output logic [dpath_width_gp-1:0]    early_data_o
   , output logic                         early_v_o
   , output logic [dpath_width_gp-1:0]    final_data_o
   , output logic                         final_v_o

   , output logic [wb_pkt_width_lp-1:0]   late_wb_pkt_o
   , output logic                         late_wb_v_o

   , input [trans_info_width_lp-1:0]          trans_info_i

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_yumi_i
   , input                                           cache_req_lock_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input [dcache_req_id_width_p-1:0]               cache_req_id_i
   , input                                           cache_req_critical_i
   , input                                           cache_req_last_i
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
  `declare_bp_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p, fetch_ptr_p, issue_ptr_p);
  `declare_bp_be_dcache_pkt_s(vaddr_width_p);

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_be_dcache_engine_if(paddr_width_p, dcache_tag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_gp, dcache_block_width_p, dcache_fill_width_p, dcache_req_id_width_p);
  `bp_cast_o(bp_be_dcache_req_s, cache_req);
  `bp_cast_o(bp_be_wb_pkt_s, late_wb_pkt);
  `bp_cast_i(bp_be_trans_info_s, trans_info);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);
  `bp_cast_i(bp_be_commit_pkt_s, commit_pkt);

  wire negedge_clk = ~clk_i;
  wire posedge_clk =  clk_i;

  // Cast input and output ports
  bp_be_reservation_s reservation;
  bp_be_decode_s      decode;
  rv64_instr_s        instr;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [vaddr_width_p-1:0] pc   = reservation.pc;
  wire [dword_width_gp-1:0] rs1 = reservation.isrc1;
  wire [dword_width_gp-1:0] rs2 = reservation.isrc2;
  wire [dword_width_gp-1:0] imm = reservation.isrc3;

  wire is_req = reservation.v & (decode.pipe_mem_early_v | decode.pipe_mem_final_v);
  wire [rv64_eaddr_width_gp-1:0] eaddr = rs1 + imm;

  logic early_v_r;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(2))
   req_chain
    (.clk_i(negedge_clk)
     ,.data_i(is_req)
     ,.data_o(early_v_r)
     );

  // D-TLB connections
  wire dtlb_r_store  = is_req & (decode.dcache_w_v | decode.dcache_cbo_v);
  wire dtlb_r_load   = is_req & decode.dcache_r_v;
  wire dtlb_r_cbo    = is_req & decode.dcache_cbo_v;
  wire dtlb_r_ptw    = is_req & decode.dcache_mmu_v;
  wire dtlb_r_v      = dtlb_r_store | dtlb_r_load | dtlb_r_cbo | dtlb_r_ptw;

  logic [vtag_width_p-1:0] dtlb_w_vtag;
  bp_pte_leaf_s dtlb_w_entry;
  wire dtlb_w_v       = commit_pkt_cast_i.dtlb_fill_v;
  assign dtlb_w_vtag  = commit_pkt_cast_i.vaddr[page_offset_width_gp+:vtag_width_p];
  assign dtlb_w_entry = commit_pkt_cast_i.pte_leaf;

  // Some duplicated decode logic from dcache_decoder. Can send this information
  //   as part of dcache_pkt to reduce overhead
  logic [1:0] dtlb_r_size;
  always_comb
    unique case (decode.fu_op)
      e_dcache_op_lb, e_dcache_op_lbu, e_dcache_op_sb: dtlb_r_size = 2'b00;
      e_dcache_op_lh, e_dcache_op_lhu, e_dcache_op_sh: dtlb_r_size = 2'b01;
      e_dcache_op_amoswapw, e_dcache_op_amoaddw, e_dcache_op_amoxorw
      ,e_dcache_op_amoandw, e_dcache_op_amoorw, e_dcache_op_amominw
      ,e_dcache_op_amomaxw, e_dcache_op_amominuw, e_dcache_op_amomaxuw
      ,e_dcache_op_lw, e_dcache_op_lwu, e_dcache_op_sw
      ,e_dcache_op_flw, e_dcache_op_fsw
      ,e_dcache_op_lrw, e_dcache_op_scw:               dtlb_r_size = 2'b10;
      default: dtlb_r_size = 2'b11;
    endcase

  logic dtlb_v_lo;
  logic [ptag_width_p-1:0] dtlb_ptag_lo;
  logic dtlb_ptag_uncached_lo, dtlb_ptag_dram_lo;
  wire uncached_mode_li = cfg_bus_cast_i.dcache_mode == e_lce_mode_uncached;
  wire nonspec_mode_li = cfg_bus_cast_i.dcache_mode == e_lce_mode_nonspec;
  bp_mmu
   #(.bp_params_p(bp_params_p)
     ,.tlb_els_4k_p(dtlb_els_4k_p)
     ,.tlb_els_2m_p(dtlb_els_2m_p)
     ,.tlb_els_1g_p(dtlb_els_1g_p)
     ,.latch_last_read_p(0)
     )
   dmmu
    (.clk_i(negedge_clk)
     ,.reset_i(reset_i)
     ,.cfg_bus_i(cfg_bus_i)

     ,.flush_i(flush_i)
     ,.fence_i(sfence_i)
     ,.priv_mode_i(trans_info_cast_i.priv_mode)
     ,.sum_i(trans_info_cast_i.mstatus_sum)
     ,.mxr_i(trans_info_cast_i.mstatus_mxr)
     ,.trans_en_i(trans_info_cast_i.translation_en)
     ,.uncached_mode_i(uncached_mode_li)
     ,.nonspec_mode_i(nonspec_mode_li)
     ,.hio_mask_i(cfg_bus_cast_i.hio_mask)

     ,.w_v_i(dtlb_w_v)
     ,.w_vtag_i(dtlb_w_vtag)
     ,.w_entry_i(dtlb_w_entry)

     ,.r_v_i(dtlb_r_v)
     ,.r_instr_i('0)
     ,.r_load_i(dtlb_r_load)
     ,.r_store_i(dtlb_r_store)
     ,.r_cbo_i(dtlb_r_cbo)
     ,.r_ptw_i(dtlb_r_ptw)
     ,.r_eaddr_i(eaddr)
     ,.r_size_i(dtlb_r_size)

     ,.r_v_o(dtlb_v_lo)
     ,.r_ptag_o(dtlb_ptag_lo)
     ,.r_instr_miss_o()
     ,.r_load_miss_o(tlb_load_miss_v_o)
     ,.r_store_miss_o(tlb_store_miss_v_o)
     ,.r_uncached_o(dtlb_ptag_uncached_lo)
     ,.r_nonidem_o(/* All D$ misses are non-speculative */)
     ,.r_dram_o(dtlb_ptag_dram_lo)
     ,.r_instr_access_fault_o()
     ,.r_load_access_fault_o(load_access_fault_v_o)
     ,.r_store_access_fault_o(store_access_fault_v_o)
     ,.r_instr_misaligned_o()
     ,.r_load_misaligned_o(load_misaligned_v_o)
     ,.r_store_misaligned_o(store_misaligned_v_o)
     ,.r_instr_page_fault_o()
     ,.r_load_page_fault_o(load_page_fault_v_o)
     ,.r_store_page_fault_o(store_page_fault_v_o)
     );

  bp_be_dcache_pkt_s dcache_pkt;
  wire dcache_pkt_v = is_req;
  assign dcache_pkt = '{rd_addr : instr.t.rtype.rd_addr
                        ,opcode : decode.fu_op.t.dcache_fu_op
                        ,vaddr  : eaddr
                        };
  logic frs2_r_v_r;
  bsg_dff
   #(.width_p(1))
   freg
    (.clk_i(posedge_clk)
     ,.data_i(decode.frs2_r_v)
     ,.data_o(frs2_r_v_r)
     );

  // D$ can't handle misaligned accesses
  wire dcache_ptag_v = dtlb_v_lo & ~load_misaligned_v_o & ~store_misaligned_v_o;

  logic dcache_v;
  logic [dword_width_gp-1:0] dcache_data;
  logic [$bits(bp_be_int_tag_e)-1:0] dcache_tag;
  logic [reg_addr_width_gp-1:0] dcache_rd_addr;
  logic dcache_unsigned, dcache_int, dcache_float, dcache_ptw, dcache_ret, dcache_late;
  logic dcache_busy_lo, dcache_ordered_lo;
  wire [dword_width_gp-1:0] dcache_st_data = rs2_val_i;
  bp_be_dcache
   #(.bp_params_p(bp_params_p))
   dcache
    (.clk_i(negedge_clk)
     ,.reset_i(reset_i)

     ,.busy_o(dcache_busy_lo)
     ,.ordered_o(dcache_ordered_lo)

     ,.v_i(dcache_pkt_v)
     ,.dcache_pkt_i(dcache_pkt)

     ,.ptag_v_i(dcache_ptag_v)
     ,.ptag_i(dtlb_ptag_lo)
     ,.ptag_uncached_i(dtlb_ptag_uncached_lo)
     ,.ptag_dram_i(dtlb_ptag_dram_lo)

     ,.st_data_i(dcache_st_data)
     ,.flush_i(flush_i)

     ,.v_o(dcache_v)
     ,.data_o(dcache_data)
     ,.rd_addr_o(dcache_rd_addr)
     ,.unsigned_o(dcache_unsigned)
     ,.tag_o(dcache_tag)
     ,.int_o(dcache_int)
     ,.float_o(dcache_float)
     ,.ptw_o(dcache_ptw)
     ,.ret_o(dcache_ret)
     ,.late_o(dcache_late)

     // D$-LCE Interface
     ,.cache_req_o(cache_req_cast_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_lock_i(cache_req_lock_i)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_id_i(cache_req_id_i)
     ,.cache_req_critical_i(cache_req_critical_i)
     ,.cache_req_last_i(cache_req_last_i)
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

  wire early_v_li = reservation.v & reservation.decode.pipe_mem_early_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(1))
   early_chain
    (.clk_i(posedge_clk)

     ,.data_i(early_v_li)
     ,.data_o(early_v_o)
     );

  assign cache_miss_v_o   = early_v_r & ~(dcache_v |  dcache_late) &  cache_req_yumi_i;
  assign cache_replay_v_o = early_v_r & ~(dcache_v & ~dcache_late) & ~cache_req_yumi_i;

  bp_be_int_reg_s dcache_idata;
  bp_be_int_box
   #(.bp_params_p(bp_params_p))
   int_box
    (.raw_i(dcache_data)
     ,.tag_i(dcache_tag)
     ,.unsigned_i(dcache_unsigned)
     ,.reg_o(dcache_idata)
     );
  assign early_data_o = dcache_idata;

  bp_be_fp_reg_s dcache_fdata;
  bp_be_fp_box
   #(.bp_params_p(bp_params_p))
   fp_box
    (.ieee_i(dcache_data)
     ,.tag_i(dcache_tag[0])
     ,.reg_o(dcache_fdata)
     );

  logic [dpath_width_gp-1:0] dcache_data_r;
  logic [reg_addr_width_gp-1:0] dcache_rd_addr_r;
  wire [dpath_width_gp-1:0] dcache_data_n = dcache_float ? dcache_fdata : dcache_idata;
  bsg_dff
  #(.width_p(dpath_width_gp+reg_addr_width_gp))
  data_reg
   (.clk_i(negedge_clk)
    ,.data_i({dcache_data_n, dcache_rd_addr})
    ,.data_o({dcache_data_r, dcache_rd_addr_r})
    );

  logic dcache_v_r, dcache_int_r, dcache_float_r, dcache_ptw_r, dcache_late_r, dcache_ret_r;
  bsg_dff
   #(.width_p(6))
   final_reg
    (.clk_i(posedge_clk)
     ,.data_i({dcache_v, dcache_int, dcache_float, dcache_ptw, dcache_late, dcache_ret})
     ,.data_o({dcache_v_r, dcache_int_r, dcache_float_r, dcache_ptw_r, dcache_late_r, dcache_ret_r})
     );

  wire final_v_li = reservation.v & reservation.decode.pipe_mem_final_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(2))
   final_chain
    (.clk_i(posedge_clk)

     ,.data_i(final_v_li)
     ,.data_o(final_v_o)
     );
  assign final_data_o = dcache_data_r;

  // Pipeline these slow signals
  bsg_dff
   #(.width_p(2))
   sync_reg
    (.clk_i(posedge_clk)
     ,.data_i({dcache_ordered_lo, dcache_busy_lo})
     ,.data_o({ordered_o, busy_o})
     );

  assign late_wb_v_o = dcache_v_r & dcache_ret_r & (dcache_late_r | dcache_ptw_r);
  assign late_wb_pkt_cast_o = '{ird_w_v  : dcache_int_r
                                ,frd_w_v : dcache_float_r
                                ,ptw_w_v : dcache_ptw_r
                                ,rd_addr : dcache_rd_addr_r
                                ,rd_data : dcache_data_r
                                ,default : '0
                                };

endmodule


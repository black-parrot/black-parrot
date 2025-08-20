/*
 * bp_mmu.v
 */

`include "bp_common_defines.svh"

module bp_mmu
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter `BSG_INV_PARAM(tlb_els_4k_p)
   , parameter `BSG_INV_PARAM(tlb_els_2m_p)
   , parameter `BSG_INV_PARAM(tlb_els_1g_p)
   , parameter latch_last_read_p = 0

   `declare_bp_common_if_widths(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   , localparam entry_width_lp = `bp_pte_leaf_width(paddr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input [cfg_bus_width_lp-1:0]                     cfg_bus_i

   , input                                            flush_i
   , input                                            fence_i
   , input [1:0]                                      priv_mode_i
   , input                                            trans_en_i
   , input                                            sum_i
   , input                                            mxr_i
   , input                                            uncached_mode_i
   , input                                            nonspec_mode_i
   , input [hio_width_p-1:0]                          hio_mask_i

   , input                                            w_v_i
   , input [vtag_width_p-1:0]                         w_vtag_i
   , input [entry_width_lp-1:0]                       w_entry_i

   , input                                            r_v_i
   , input                                            r_instr_i
   , input                                            r_load_i
   , input                                            r_store_i
   , input [dword_width_gp-1:0]                       r_eaddr_i
   , input [1:0]                                      r_size_i
   , input                                            r_cbo_i
   , input                                            r_ptw_i

   , output logic                                     r_v_o
   , output logic [ptag_width_p-1:0]                  r_ptag_o
   , output logic                                     r_instr_miss_o
   , output logic                                     r_load_miss_o
   , output logic                                     r_store_miss_o
   , output logic                                     r_uncached_o
   , output logic                                     r_nonidem_o
   , output logic                                     r_dram_o
   , output logic                                     r_instr_access_fault_o
   , output logic                                     r_load_access_fault_o
   , output logic                                     r_store_access_fault_o
   , output logic                                     r_instr_misaligned_o
   , output logic                                     r_load_misaligned_o
   , output logic                                     r_store_misaligned_o
   , output logic                                     r_instr_page_fault_o
   , output logic                                     r_load_page_fault_o
   , output logic                                     r_store_page_fault_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  // This logic only works for 8-byte words max.
  logic r_misaligned;
  always_comb
    case ({r_ptw_i, r_cbo_i, r_size_i})
      {2'b00, 2'b01}: r_misaligned = |r_eaddr_i[0+:1];
      {2'b00, 2'b10}: r_misaligned = |r_eaddr_i[0+:2];
      {2'b00, 2'b11}: r_misaligned = |r_eaddr_i[0+:3];
      default: r_misaligned = '0;
    endcase

  logic r_instr_r, r_load_r, r_store_r, r_cbo_r, r_ptw_r, r_misaligned_r, trans_r;
  logic [etag_width_p-1:0] r_etag_r;
  wire [etag_width_p-1:0] r_etag_li = r_eaddr_i[dword_width_gp-1-:etag_width_p];
  wire trans_li = trans_en_i & ~r_ptw_i;
  bsg_dff_reset_en
   #(.width_p(7+etag_width_p))
   read_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(r_v_i)

     ,.data_i({trans_li, r_misaligned, r_instr_i, r_load_i, r_store_i, r_cbo_i, r_ptw_i, r_etag_li})
     ,.data_o({trans_r, r_misaligned_r, r_instr_r, r_load_r, r_store_r, r_cbo_r, r_ptw_r, r_etag_r})
     );

  logic r_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   r_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(r_v_i)
     ,.clear_i(flush_i || !latch_last_read_p)
     ,.data_o(r_v_r)
     );

  logic tlb_r_v_lo;
  bp_pte_leaf_s tlb_r_entry_lo;
  wire tlb_r_v_li = r_v_i | flush_i;
  wire tlb_w_v_li = w_v_i;
  wire tlb_v_li = tlb_r_v_li | tlb_w_v_li;
  wire [vtag_width_p-1:0] tlb_vtag_li = w_v_i ? w_vtag_i : vtag_width_p'(r_etag_li);
  bp_tlb
   #(.bp_params_p(bp_params_p), .els_4k_p(tlb_els_4k_p), .els_2m_p(tlb_els_2m_p), .els_1g_p(tlb_els_1g_p))
   tlb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.fence_i(fence_i)

     ,.v_i(tlb_v_li)
     ,.w_i(tlb_w_v_li)
     ,.vtag_i(tlb_vtag_li)
     ,.entry_i(w_entry_i)

     ,.v_o(tlb_r_v_lo)
     ,.entry_o(tlb_r_entry_lo)
     );

  bp_pte_leaf_s tlb_r_entry_r;
  logic tlb_r_v_r;
  bsg_dff_sync_read
   #(.width_p(1+$bits(bp_pte_leaf_s)), .bypass_p(1))
   entry_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_n_i(tlb_r_v_li)
     ,.data_i({tlb_r_v_lo, tlb_r_entry_lo})
     ,.data_o({tlb_r_v_r, tlb_r_entry_r})
     );

  bp_pte_leaf_s passthrough_entry, tlb_entry_lo;
  assign passthrough_entry = '{ptag: r_etag_r, default: '0};
  assign tlb_entry_lo      = trans_r ? tlb_r_entry_r : passthrough_entry;
  wire tlb_v_lo            = trans_r ? tlb_r_v_r : r_v_r;

  wire ptag_v_lo                  = tlb_v_lo;
  wire [ptag_width_p-1:0] ptag_lo = tlb_entry_lo.ptag;
  logic ptag_uncached_lo, ptag_nonidem_lo, ptag_dram_lo;
  bp_pma
   #(.bp_params_p(bp_params_p))
   pma
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.ptag_i(ptag_lo)
     ,.uncached_mode_i(uncached_mode_i)
     ,.nonspec_mode_i(nonspec_mode_i)

     ,.uncached_o(ptag_uncached_lo)
     ,.nonidem_o(ptag_nonidem_lo)
     ,.dram_o(ptag_dram_lo)
     );

  // Fault if higher bits of eaddr do not match vaddr MSB
  wire eaddr_fault_v = ~&r_etag_r[etag_width_p-1:vtag_width_p-1] & |r_etag_r[etag_width_p-1:vtag_width_p-1];
  wire cached_fault_v = r_cbo_r & ptag_v_lo & ptag_uncached_lo;
  // Fault if hio bit is not enabled and we're accessing that hio
  wire hio_fault_v = (r_instr_r & ptag_v_lo & ptag_lo[ptag_width_p-1-:hio_width_p] != '0)
    || (ptag_v_lo & ptag_lo[ptag_width_p-1-:hio_width_p] & ~hio_mask_i);

  // Access faults
  wire instr_access_fault_v = r_instr_r & hio_fault_v;
  wire load_access_fault_v  = r_load_r  & cached_fault_v;
  wire store_access_fault_v = r_store_r & cached_fault_v;
  wire any_access_fault_v   = |{instr_access_fault_v, load_access_fault_v, store_access_fault_v};

  // Page faults
  wire instr_exe_page_fault_v  = tlb_v_lo & ~tlb_entry_lo.x;
  wire instr_priv_page_fault_v = tlb_v_lo & (((priv_mode_i == `PRIV_MODE_S) & tlb_entry_lo.u)
                                             | ((priv_mode_i == `PRIV_MODE_U) & ~tlb_entry_lo.u)
                                             );
  wire data_priv_page_fault = tlb_v_lo & (((priv_mode_i == `PRIV_MODE_S) & ~sum_i & tlb_entry_lo.u)
                                           | ((priv_mode_i == `PRIV_MODE_U) & ~tlb_entry_lo.u)
                                          );
  wire data_read_page_fault  = tlb_v_lo & ~(tlb_entry_lo.r | (tlb_entry_lo.x & mxr_i));
  wire data_write_page_fault = tlb_v_lo & ~(tlb_entry_lo.w & tlb_entry_lo.d);
  wire instr_page_fault_v = trans_r & r_instr_r & (instr_priv_page_fault_v | instr_exe_page_fault_v | eaddr_fault_v);
  wire load_page_fault_v  = trans_r & r_load_r & (data_priv_page_fault | data_read_page_fault  | eaddr_fault_v);
  wire store_page_fault_v = trans_r & r_store_r & (data_priv_page_fault | data_write_page_fault | eaddr_fault_v);
  wire any_page_fault_v   = |{instr_page_fault_v, load_page_fault_v, store_page_fault_v};

  wire any_fault_v        = any_access_fault_v | any_page_fault_v;

  assign r_v_o                   = r_v_r &  tlb_v_lo & ~any_fault_v;
  assign r_instr_miss_o          = r_v_r & ~tlb_v_lo & ~any_fault_v & r_instr_r;
  assign r_load_miss_o           = r_v_r & ~tlb_v_lo & ~any_fault_v & r_load_r;
  assign r_store_miss_o          = r_v_r & ~tlb_v_lo & ~any_fault_v & r_store_r;
  assign r_instr_misaligned_o    = r_v_r & r_misaligned_r & r_instr_r;
  assign r_load_misaligned_o     = r_v_r & r_misaligned_r & r_load_r;
  assign r_store_misaligned_o    = r_v_r & r_misaligned_r & r_store_r;
  assign r_instr_access_fault_o  = r_v_r & instr_access_fault_v;
  assign r_load_access_fault_o   = r_v_r & load_access_fault_v;
  assign r_store_access_fault_o  = r_v_r & store_access_fault_v;
  assign r_instr_page_fault_o    = r_v_r & instr_page_fault_v;
  assign r_load_page_fault_o     = r_v_r & load_page_fault_v;
  assign r_store_page_fault_o    = r_v_r & store_page_fault_v;
  assign r_ptag_o                = ptag_lo;
  assign r_uncached_o            = ptag_uncached_lo;
  assign r_nonidem_o             = ptag_nonidem_lo;
  assign r_dram_o                = ptag_dram_lo;

endmodule

`BSG_ABSTRACT_MODULE(bp_mmu)


/*
 * bp_mmu.v
 */

module bp_mmu
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter tlb_els_p = "inv"

   , localparam entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                                              clk_i
   , input                                            reset_i

   , input                                            flush_i
   , input [1:0]                                      priv_mode_i
   , input                                            trans_en_i
   , input                                            sum_i
   , input                                            uncached_mode_i
   , input                                            sac_i
   , input [7:0]                                      domain_mask_i

   , input                                            w_v_i
   , input [vtag_width_p-1:0]                         w_vtag_i
   , input [entry_width_lp-1:0]                       w_entry_i

   , input                                            r_v_i
   , input                                            r_instr_i
   , input                                            r_load_i
   , input                                            r_store_i
   , input [dword_width_p-1:0]                        r_eaddr_i

   , output logic                                     r_v_o
   , output logic [ptag_width_p-1:0]                  r_ptag_o
   , output logic                                     r_miss_o
   , output logic                                     r_uncached_o
   , output logic                                     r_instr_access_fault_o
   , output logic                                     r_load_access_fault_o
   , output logic                                     r_store_access_fault_o
   , output logic                                     r_instr_page_fault_o
   , output logic                                     r_load_page_fault_o
   , output logic                                     r_store_page_fault_o
   );

  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  logic tlb_r_v_lo, tlb_r_miss_lo;
  bp_pte_entry_leaf_s tlb_r_entry_lo;
  wire [vtag_width_p-1:0] w_vtag_li = w_v_i ? w_vtag_i : r_eaddr_i[vaddr_width_p-1-:vtag_width_p];
  bp_tlb
   #(.bp_params_p(bp_params_p), .els_p(tlb_els_p))
   tlb
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.flush_i(flush_i)

     ,.v_i((r_v_i | w_v_i) & trans_en_i)
     ,.w_i(w_v_i)
     ,.vtag_i(w_vtag_li)
     ,.entry_i(w_entry_i)

     ,.v_o(tlb_r_v_lo)
     ,.miss_v_o(tlb_r_miss_lo)
     ,.entry_o(tlb_r_entry_lo)
     );

  logic [vtag_width_p-1:0] r_vtag_r;
  wire [vtag_width_p-1:0] r_vtag_li = r_eaddr_i[vaddr_width_p-1-:vtag_width_p];
  bsg_dff_reset_en
   #(.width_p(vtag_width_p))
   vtag_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(r_v_i)

     ,.data_i(r_vtag_li)
     ,.data_o(r_vtag_r)
    );

  logic r_v_r, r_instr_r, r_load_r, r_store_r;
  bsg_dff_reset
   #(.width_p(4))
   r_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.data_i({r_v_i, r_instr_i, r_load_i, r_store_i})
     ,.data_o({r_v_r, r_instr_r, r_load_r, r_store_r})
     );

  bp_pte_entry_leaf_s passthrough_entry, tlb_entry_lo;
  assign passthrough_entry = '{ptag: r_vtag_r, default: '0};
  assign tlb_entry_lo      = trans_en_i ? tlb_r_entry_lo : passthrough_entry;
  wire tlb_v_lo            = trans_en_i ? tlb_r_v_lo : r_v_r;

  wire ptag_v_lo                  = tlb_v_lo;
  wire [ptag_width_p-1:0] ptag_lo = tlb_entry_lo.ptag;
  logic ptag_uncached_lo;
  bp_pma
   #(.bp_params_p(bp_params_p))
   pma
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.ptag_v_i(ptag_v_lo)
     ,.ptag_i(ptag_lo)

     ,.uncached_o(ptag_uncached_lo)
     );

  // Fault if higher bits of eaddr do not match vaddr MSB
  logic eaddr_fault_v;
  localparam eaddr_pad_lp = dword_width_p - vaddr_width_p;
  wire eaddr_fault = (r_eaddr_i[dword_width_p-1:vaddr_width_p] != {eaddr_pad_lp{r_eaddr_i[vaddr_width_p-1]}});
  always_ff @(posedge clk_i) eaddr_fault_v <= eaddr_fault;
  // Fault if in uncached mode but access is not for an uncached address
  wire mode_fault_v  = (uncached_mode_i & ~r_uncached_o);
  // Fault if domain is not zero (top <io_noc_did_width_p> bits) and SAC bit is not zero (next bit)
  wire did_fault_v = (r_instr_r & ptag_lo[ptag_width_p-1-:io_noc_did_width_p] != '0)
    || (~domain_mask_i[ptag_lo[ptag_width_p-1-:io_noc_did_width_p]]);
  // Fault if sac activation bit is not set
  wire sac_fault_v = (r_instr_r & ptag_lo[ptag_width_p-1-io_noc_did_width_p-1])
    || (ptag_lo[ptag_width_p-1-io_noc_did_width_p-1] & ~sac_i);

  // Access faults
  wire instr_access_fault_v = r_instr_r & (mode_fault_v | did_fault_v | sac_fault_v);
  wire load_access_fault_v  = r_load_r  & (mode_fault_v | did_fault_v | sac_fault_v);
  wire store_access_fault_v = r_store_r & (mode_fault_v | did_fault_v | sac_fault_v);
  wire any_access_fault_v   = |{instr_access_fault_v, load_access_fault_v, store_access_fault_v};

  // Page faults
  wire instr_exe_page_fault_v  = ~tlb_entry_lo.x;
  wire instr_priv_page_fault_v = ((priv_mode_i == `PRIV_MODE_S) & tlb_entry_lo.u)
                                 | ((priv_mode_i == `PRIV_MODE_U) & ~tlb_entry_lo.u);
  wire data_priv_page_fault = ((priv_mode_i == `PRIV_MODE_S) & ~sum_i & tlb_entry_lo.u)
                                | ((priv_mode_i == `PRIV_MODE_U) & ~tlb_entry_lo.u);
  wire data_write_page_fault = r_store_r & (~tlb_entry_lo.w | ~tlb_entry_lo.d);
  wire instr_page_fault_v = trans_en_i & r_instr_r & (instr_priv_page_fault_v | instr_exe_page_fault_v);
  wire load_page_fault_v  = trans_en_i & r_load_r & (data_priv_page_fault | eaddr_fault_v);
  wire store_page_fault_v = trans_en_i & r_store_r & (data_priv_page_fault | data_write_page_fault | eaddr_fault_v);
  wire any_page_fault_v   = |{instr_page_fault_v, load_page_fault_v, store_page_fault_v};

  assign r_v_o                   = r_v_r &  tlb_v_lo & ~any_access_fault_v & ~any_page_fault_v;
  assign r_ptag_o                = ptag_lo;
  assign r_miss_o                = r_v_r & ~tlb_v_lo;
  assign r_uncached_o            = r_v_r & tlb_v_lo & ptag_uncached_lo;
  assign r_instr_access_fault_o  = r_v_r & tlb_v_lo & instr_access_fault_v;
  assign r_load_access_fault_o   = r_v_r & tlb_v_lo & load_access_fault_v;
  assign r_store_access_fault_o  = r_v_r & tlb_v_lo & store_access_fault_v;
  assign r_instr_page_fault_o    = r_v_r & tlb_r_v_lo & instr_page_fault_v;
  assign r_load_page_fault_o     = r_v_r & tlb_r_v_lo & load_page_fault_v;
  assign r_store_page_fault_o    = r_v_r & tlb_r_v_lo & store_page_fault_v;

endmodule


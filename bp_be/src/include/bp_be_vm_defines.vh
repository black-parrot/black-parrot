
`ifndef BP_BE_VM_DEFINES_VH
`define BP_BE_VM_DEFINES_VH

`define declare_bp_sv39_pte_s(pte_width_mp, ppn_width_mp, pte_offset_width_mp)                             \
  typedef struct packed {                                                                              \
    logic v;                                                                                           \
	logic r;                                                                                           \
	logic w;                                                                                           \
	logic x;                                                                                           \
	logic u;                                                                                           \
	logic g;                                                                                           \
	logic a;                                                                                           \
	logic d;                                                                                           \
	logic [1:0] rsw;                                                                                   \
	logic [pte_offset_width_mp-1:0] ppn0;                                                                    \
	logic [pte_offset_width_mp-1:0] ppn1;                                                                    \
	logic [ppn_width_mp-2*pte_offset_width_mp-1:0] ppn2;                                                                    \
	logic [pte_width_mp - 10 - ppn_width_mp - 1:0] reserved;  \
  } bp_sv39_pte_s                                                                                      \

  
`define declare_bp_be_tlb_entry_s(ptag_width_mp)                                                      \
  typedef struct packed {                                                                              \
    logic [ptag_width_mp-1:0]  ptag;                                                                  \
    logic                      extent;                                                                 \
	logic                      u;                                                                      \
    logic                      g;                                                                      \
    logic                      l;                                                                      \
    logic                      x;                                                                      \
  } bp_be_tlb_entry_s                                                                                  \
  
`define bp_be_tlb_entry_width(ptag_width_mp)                                                 \
  (ptag_width_mp + 5)                                                                                 \
  
`endif
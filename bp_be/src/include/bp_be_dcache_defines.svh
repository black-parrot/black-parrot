
`ifndef BP_BE_DCACHE_DEFINES_SVH
`define BP_BE_DCACHE_DEFINES_SVH

  `define declare_bp_be_dcache_pkt_s(vaddr_width_mp) \
    typedef struct packed                           \
    {                                               \
      logic [reg_addr_width_gp-1:0]    rd_addr;     \
      bp_be_dcache_fu_op_e             opcode;      \
      logic [vaddr_width_mp-1:0]       vaddr;       \
    }  bp_be_dcache_pkt_s;                          \

  `define declare_bp_be_dcache_wbuf_entry_s(caddr_width_mp, ways_mp) \
    typedef struct packed                            \
    {                                                \
      logic                                snoop;    \
      logic [(1<<ways_mp)-1:0]             bank_sel; \
      logic [(dword_width_gp>>3)-1:0]      mask;     \
      logic [dword_width_gp-1:0]           data;     \
      logic [caddr_width_mp-1:0]           caddr;    \
    } bp_be_dcache_wbuf_entry_s

  `define bp_be_dcache_pkt_width(vaddr_width_mp) \
    (vaddr_width_mp+$bits(bp_be_dcache_fu_op_e)+reg_addr_width_gp)

  `define bp_be_dcache_wbuf_entry_width(caddr_width_mp, ways_mp) \
    (1+(1<<ways_mp)+(dword_width_gp>>3)+dword_width_gp+caddr_width_mp)

`endif


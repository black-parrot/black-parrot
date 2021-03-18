
`ifndef BP_BE_DCACHE_PKGDEF_SVH
`define BP_BE_DCACHE_PKGDEF_SVH

  typedef enum logic [3:0]
  {
    e_dcache_subop_none
    ,e_dcache_subop_lr
    ,e_dcache_subop_sc
    ,e_dcache_subop_amoswap
    ,e_dcache_subop_amoadd
    ,e_dcache_subop_amoxor
    ,e_dcache_subop_amoand
    ,e_dcache_subop_amoor
    ,e_dcache_subop_amomin
    ,e_dcache_subop_amomax
    ,e_dcache_subop_amominu
    ,e_dcache_subop_amomaxu
  } bp_be_amo_subop_e;

  typedef struct packed
  {
    logic                         load_op;
    logic                         store_op;
    logic                         signed_op;
    logic                         float_op;
    logic                         double_op;
    logic                         word_op;
    logic                         half_op;
    logic                         byte_op;
    logic                         fencei_op;
    logic                         l2_op;
    logic                         lr_op;
    logic                         sc_op;
    logic                         amo_op;
    bp_be_amo_subop_e             amo_subop;
    logic [reg_addr_width_gp-1:0] rd_addr;
  }  bp_be_dcache_decode_s;

  typedef struct packed
  {
    logic [reg_addr_width_gp-1:0]    rd_addr;
    bp_be_dcache_fu_op_e             opcode;
    logic [page_offset_width_gp-1:0] page_offset;
    logic [dpath_width_gp-1:0]       data;
  }  bp_be_dcache_pkt_s;

`endif


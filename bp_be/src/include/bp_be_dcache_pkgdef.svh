
`ifndef BP_BE_DCACHE_PKGDEF_SVH
`define BP_BE_DCACHE_PKGDEF_SVH

  typedef struct packed
  {
    logic load_op;
    logic store_op;
    logic signed_op;
    logic float_op;
    logic lr_op;
    logic sc_op;
    logic amoswap_op;
    logic amoadd_op;
    logic amoxor_op;
    logic amoand_op;
    logic amoor_op;
    logic amomin_op;
    logic amomax_op;
    logic amominu_op;
    logic amomaxu_op;
    logic double_op;
    logic word_op;
    logic half_op;
    logic byte_op;
    logic fencei_op;
    logic l2_op;
  }  bp_be_dcache_pipeline_s;

  typedef struct packed
  {
    bp_be_dcache_fu_op_e opcode;
    logic [page_offset_width_gp-1:0] page_offset;
    logic [dword_width_gp-1:0] data;
  }  bp_be_dcache_pkt_s;

`endif

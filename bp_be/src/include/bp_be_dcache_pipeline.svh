/**
 *  Name:
 *    bp_be_dcache_pipeline.svh
 *
 *  Description:
 *    Structs used for dcache pipeline
 */

`ifndef BP_BE_DCACHE_PIPELINE_VH
`define BP_BE_DCACHE_PIPELINE_VH

`define declare_bp_be_dcache_pipeline_s                                            \
  typedef struct packed {                                                          \
    logic load_op;                                                                 \
    logic store_op;                                                                \
    logic signed_op;                                                               \
    logic float_op;                                                                \
    logic lr_op;                                                                   \
    logic sc_op;                                                                   \
    logic amoswap_op;                                                              \
    logic amoadd_op;                                                               \
    logic amoxor_op;                                                               \
    logic amoand_op;                                                               \
    logic amoor_op;                                                                \
    logic amomin_op;                                                               \
    logic amomax_op;                                                               \
    logic amominu_op;                                                              \
    logic amomaxu_op;                                                              \
    logic double_op;                                                               \
    logic word_op;                                                                 \
    logic half_op;                                                                 \
    logic byte_op;                                                                 \
    logic fencei_op;                                                               \
    logic l2_op;                                                                   \
  } bp_be_dcache_pipeline_s;

`define bp_be_dcache_pipeline_struct_width                                         \
  (2 + 1 + 1 + 11 + 4 + 1 + 1)

`endif

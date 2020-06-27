/**
 *  Name: 
 *    bp_be_dcache_pipeline.vh
 *
 *  Description: 
 *    Structs used for dcache pipeline
 */

`ifndef BP_BE_DCACHE_PIPELINE_VH
`define BP_BE_DCACHE_PIPELINE_VH

`define declare_bp_be_dcache_size_op_s                                             \
  typedef struct packed {                                                          \
    logic double_op;                                                               \
    logic word_op;                                                                 \
    logic half_op;                                                                 \
    logic byte_op;                                                                 \
  } bp_be_dcache_size_op_s;

`define bp_be_dcache_size_op_width                                                 \
  (1 + 1 + 1 + 1)

`define declare_bp_be_dcache_pipeline_s                                            \
  typedef struct packed {                                                          \
    logic load_op;                                                                 \
    logic store_op;                                                                \
    logic signed_op;                                                               \
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
    bp_be_dcache_size_op_s size;                                                   \
    logic fencei_op;                                                               \
  } bp_be_dcache_pipeline_s; 

`define declare_bp_be_dcache_pipeline_structs                                      \
  `declare_bp_be_dcache_size_op_s                                                  \
  `declare_bp_be_dcache_pipeline_s

`define bp_be_dcache_pipeline_struct_width                                         \
  (2 + 1 + 11 + `bp_be_dcache_size_op_width + 1)

`endif

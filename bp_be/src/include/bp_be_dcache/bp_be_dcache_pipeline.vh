/**
 *  Name: 
 *    bp_be_dcache_pipeline.vh
 *
 *  Description: 
 *    Structs used for dcache pipeline
 */

`ifndef BP_BE_DCACHE_PIPELINE_VH
`define BP_BE_DCACHE_PIPELINE_VH

`define declare_bp_amo_fetch_arithmetic_op_s                                            \
  typedef struct packed {                                                          \
    logic add_op;                                                               \
    logic min_op;                                                               \
    logic max_op;                                                               \
    logic minu_op;                                                              \
    logic maxu_op;                                                              \
  } bp_amo_fetch_arithmetic_op_s;

`define bp_amo_fetch_arithmetic_op_width \
  (1 + 1 + 1 + 1 + 1)

`define declare_bp_amo_fetch_logic_op_s                                       \
  typedef struct packed {                                                          \
    logic xor_op;                                                               \
    logic and_op;                                                               \
    logic or_op;                                                                \
  } bp_amo_fetch_logic_op_s;

`define bp_amo_fetch_logic_op_width \
  (1 + 1 + 1)

`define declare_bp_be_dcache_size_op_s                                             \
  typedef struct packed {                                                          \
    logic double_op;                                                               \
    logic word_op;                                                                 \
    logic half_op;                                                                 \
    logic byte_op;                                                                 \
  } bp_be_dcache_size_op_s;

`define bp_be_dcache_size_op_width \
  (1 + 1 + 1 + 1)

`define declare_bp_be_dcache_pipeline_struct_s                                     \
  typedef struct packed {                                                          \
    logic load_op;                                                                 \
    logic store_op;                                                                \
    logic signed_op;                                                               \
    logic lr_op;                                                                   \
    logic sc_op;                                                                   \
    logic swap_op;                                                              \
    bp_amo_fetch_logic_op_s amo_fetch_logic;                                       \
    bp_amo_fetch_arithmetic_op_s amo_fetch_arithmetic;                             \
    bp_be_dcache_size_op_s size;                                                   \
    logic fencei_op;                                                               \
  } bp_be_dcache_pipeline_struct_s; 

`define declare_bp_be_dcache_pipeline_structs \
  `declare_bp_amo_fetch_logic_op_s                                                 \
  `declare_bp_amo_fetch_arithmetic_op_s                                            \
  `declare_bp_be_dcache_size_op_s                                                  \
  `declare_bp_be_dcache_pipeline_struct_s

`define bp_be_dcache_pipeline_struct_width \
  (2 + 1 + 3 + `bp_amo_fetch_logic_op_width + `bp_amo_fetch_arithmetic_op_width \
   + `bp_be_dcache_size_op_width + 1)

`endif

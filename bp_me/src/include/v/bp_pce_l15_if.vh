// L1.5 - PCE interface signals

`ifndef BP_PCE_L15_IF_VH
`define BP_PCE_L15_IF_VH

// You can find these bit patterns in the piton/design/include/l15.h.pyv
typedef enum logic [4:0]
{
  e_load_req     = 5'b00000 // LOAD_RQ
  , e_store_req  = 5'b00001 // STORE_RQ
  , e_atomic_req = 5'b00110 // AMO_RQ
  , e_int_req    = 5'b01001 // INT_RQ
  , e_imiss_req  = 5'b10000 // IMISS_RQ
} bp_pce_l15_req_type_e;

typedef enum logic [3:0]
{
  e_load_ret     = 4'b0000 // LOAD_RET
  , e_ifill_ret  = 4'b0001 // IFILL_RET
  , e_evict_req  = 4'b0011 // EVICT_REQ
  , e_st_ack     = 4'b0100 // ST_ACK
  , e_int_ret    = 4'b0111 // INT_RET
  , e_atomic_ret = 4'b1110 // CPX_RESTYPE_ATOMIC_RES (custom type)
} bp_l15_pce_ret_type_e;

typedef enum logic [3:0]
{
  e_amo_op_none   = 4'b0000 // L15_AMO_OP_NONE
  , e_amo_op_lr   = 4'b0001 // L15_AMO_OP_LR
  , e_amo_op_sc   = 4'b0010 // L15_AMO_OP_SC
  , e_amo_op_swap = 4'b0011 // L15_AMO_OP_SWAP
  , e_amo_op_add  = 4'b0100 // L15_AMO_OP_ADD
  , e_amo_op_and  = 4'b0101 // L15_AMO_OP_AND
  , e_amo_op_or   = 4'b0110 // L15_AMO_OP_OR
  , e_amo_op_xor  = 4'b0111 // L15_AMO_OP_XOR 
  , e_amo_op_max  = 4'b1000 // L15_AMO_OP_MAX
  , e_amo_op_maxu = 4'b1001 // L15_AMO_OP_MAXU
  , e_amo_op_min  = 4'b1010 // L15_AMO_OP_MIN
  , e_amo_op_minu = 4'b1011 // L15_AMO_OP_MINU
  , e_amo_op_cas1 = 4'b1100 // L15_AMO_OP_CAS1
  , e_amo_op_cas2 = 4'b1101 // L15_AMO_OP_CAS2  
} bp_pce_l15_amo_type_e;

// You can find these bit patterns in piton/design/include/define.h.pyv
typedef enum logic [2:0]
{
  e_l15_size_0B    = 3'b000 // MSG_DATA_SIZE_0B
  , e_l15_size_1B  = 3'b001 // MSG_DATA_SIZE_1B
  , e_l15_size_2B  = 3'b010 // MSG_DATA_SIZE_2B
  , e_l15_size_4B  = 3'b011 // MSG_DATA_SIZE_4B
  , e_l15_size_8B  = 3'b100 // MSG_DATA_SIZE_8B
  , e_l15_size_16B = 3'b101 // MSG_DATA_SIZE_16B
  , e_l15_size_32B = 3'b110 // MSG_DATA_SIZE_32B
  , e_l15_size_64B = 3'b111 // MSG_DATA_SIZE_64B
} bp_pce_l15_req_size_e;

`define declare_bp_pce_l15_req_s(paddr_width_mp, data_width_mp)  \
typedef struct packed                                            \
{                                                                \
  bp_pce_l15_req_type_e      rqtype;                             \
  logic                      nc;                                 \
  bp_pce_l15_req_size_e      size;                               \
  logic [paddr_width_mp-1:0] address;                            \
  logic [data_width_mp-1:0]  data;                               \
  logic [1:0]                l1rplway;                           \
  bp_pce_l15_amo_type_e      amo_op                              \
} bp_pce_l15_req_s

`define declare_bp_l15_pce_ret_s(data_width_mp)                  \
typedef struct packed                                            \
{                                                                \
  bp_l15_pce_ret_type_e     rtntype;                             \
  logic                     noncacheable;                        \
  logic                     atomic                               \
  logic [data_width_mp-1:0] data_0;                              \
  logic [data_width_mp-1:0] data_1;                              \
  logic [data_width_mp-1:0] data_2;                              \
  logic [data_width_mp-1:0] data_3;                              \
  logic                     threadid;                            \
  logic [11:0]              inval_address_15_4;                  \
  logic                     inval_icache_inval;                  \
  logic                     inval_dcache_inval;                  \
  logic                     inval_icache_all_way;                \
  logic                     inval_dcache_all_way;                \
  logic [1:0]               inval_way;                           \
} bp_l15_pce_ret_s

`define bp_pce_l15_req_width(paddr_width_mp, data_width_mp) \
  ($bits(bp_pce_l15_req_type_e) + $bits(bp_pce_l15_req_size_e) \
   + $bits(bp_pce_l15_amo_type_e) + paddr_width_mp + data_width_mp + 2 + 1)

`define bp_l15_pce_ret_width(data_width_mp) \
  ($bits(bp_l15_pce_ret_type_e) + 1 + 1 + 4*data_width_mp + 1 + 12 + 4 + 2)

`define declare_bp_pce_l15_if(paddr_width_mp, data_width_mp) \
  `declare_bp_pce_l15_req_s(paddr_width_mp, data_width_mp); \
  `declare_bp_l15_pce_ret_s(data_width_mp)

`define declare_bp_pce_l15_if_widths(paddr_width_mp, data_width_mp) \
  , localparam bp_pce_l15_req_width_lp = `bp_pce_l15_req_width(paddr_width_mp, data_width_mp) \
  , localparam bp_l15_pce_ret_width_lp = `bp_l15_pce_ret_width(data_width_mp)

`endif

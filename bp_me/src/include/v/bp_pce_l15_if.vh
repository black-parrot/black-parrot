// L1.5 - PCE interface signals

`ifndef BP_PCE_L15_IF_VH
`define BP_PCE_L15_IF_VH

typedef enum logic [4:0]
{
  e_load_req     = 5'b00000 // LOAD_RQ
  , e_store_req  = 5'b00001 // STORE_RQ
  , e_atomic_req = 5'b00110 // SWAP_RQ (We could probably use this for BP atomics)
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
} bp_l15_pce_ret_type_e;

typedef enum logic [2:0]
{
  e_size_1B    = 3'b000 // PCX_SZ_1B
  , e_size_2B  = 3'b001 // PCX_SZ_2B
  , e_size_4B  = 3'b010 // PCX_SZ_4B
  , e_size_8B  = 3'b011 // PCX_SZ_8B
  , e_size_16B = 3'b111 // PCX_SZ_16B
} bp_pce_l15_req_size_e;

`define declare_bp_pce_l15_req_s(paddr_width_mp, data_width_mp)  \
typedef struct packed                                            \
{                                                                \
  bp_pce_l15_req_type_e      transducer_l15_rqtype;              \
  logic                      transducer_l15_nc;                  \
  bp_pce_l15_req_size_e      transducer_l15_size;                \
  logic [paddr_width_mp-1:0] transducer_l15_address;             \
  logic [data_width_mp-1:0]  transducer_l15_data;                \
  logic [1:0]                transducer_l15_rplway;              \
} bp_pce_l15_req_s

`define declare_bp_l15_pce_ret_s(data_width_mp)                  \
{                                                                \
  bp_l15_pce_ret_type_e     l15_transducer_returntype            \
  logic                     l15_transducer_noncacheable;         \
  logic [data_width_mp-1:0] l15_transducer_data_0;               \
  logic [data_width_mp-1:0] l15_transducer_data_1;               \
  logic [data_width_mp-1:0] l15_transducer_data_2;               \
  logic [data_width_mp-1:0] l15_transducer_data_3;               \
  logic [2:0]               l15_transducer_threadid;             \
  logic [11:0]              l15_tranducer_inval_address_15_4;    \
  logic                     l15_transducer_inval_icache_inval;   \
  logic                     l15_transducer_inval_dcache_inval;   \
  logic                     l15_transducer_inval_icache_all_way; \
  logic                     l15_transducer_inval_dcache_all_way; \
  logic [1:0]               l15_transducer_inval_way;            \
} bp_l15_pce_ret_s

`define bp_pce_l15_req_width(paddr_width_mp, data_width_mp) \
  ($bits(bp_pce_l15_req_type_e) + $bits(bp_pce_l15_req_size_e) \
   + paddr_width_mp + data_width_mp + 2 + 1)

`define bp_l15_pce_ret_width(data_width_mp) \
  ($bits(bp_l15_pce_ret_type_e) + 3 + 12 + 2 + 4*data_width_mp + 5)

`define declare_bp_pce_l15_if(paddr_width_mp, data_width_mp) \
  `declare_bp_pce_l15_req_s(paddr_width_mp, data_width_mp) \
  `declare_bp_l15_pce_ret_s(data_width_mp)

`define declare_bp_pce_l15_if_widths(paddr_width_mp, data_width_mp) \
  , localparam bp_pce_l15_req_width_lp = `bp_pce_l15_req_width(paddr_width_mp, data_width_mp) \
  , localparam bp_l15_pce_ret_width_lp = `bp_l15_pce_ret_width(data_width_mp)

`endif

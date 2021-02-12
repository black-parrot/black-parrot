
`ifndef BP_COMMON_CACHE_ENGINE_PKGDEF_SVH
`define BP_COMMON_CACHE_ENGINE_PKGDEF_SVH

  typedef enum logic [4:0]
  {
    e_miss_load         = 5'b00000
    ,e_miss_store       = 5'b00001
    ,e_uc_load          = 5'b00010
    ,e_uc_store         = 5'b00011
    ,e_wt_store         = 5'b00100
    ,e_cache_flush      = 5'b00101
    ,e_cache_clear      = 5'b00110
    ,e_amo_lr           = 5'b00111
    ,e_amo_sc           = 5'b01000
    ,e_amo_swap         = 5'b01001
    ,e_amo_add          = 5'b01010
    ,e_amo_xor          = 5'b01011
    ,e_amo_and          = 5'b01100
    ,e_amo_or           = 5'b01101
    ,e_amo_min          = 5'b01110
    ,e_amo_max          = 5'b01111
    ,e_amo_minu         = 5'b10000
    ,e_amo_maxu         = 5'b10001
  } bp_cache_req_msg_type_e;

  typedef enum logic [2:0]
  {
    e_size_1B    = 3'b000
    ,e_size_2B   = 3'b001
    ,e_size_4B   = 3'b010
    ,e_size_8B   = 3'b011
    ,e_size_16B  = 3'b100
    ,e_size_32B  = 3'b101
    ,e_size_64B  = 3'b110
  } bp_cache_req_size_e;

`endif


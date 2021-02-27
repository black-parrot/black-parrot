
`ifndef BP_COMMON_CACHE_ENGINE_PKGDEF_SVH
`define BP_COMMON_CACHE_ENGINE_PKGDEF_SVH

  typedef enum logic [3:0]
  {
    e_miss_load         = 4'b0000
    ,e_miss_store       = 4'b0001
    ,e_wt_store         = 4'b0010
    ,e_uc_load          = 4'b0011
    ,e_uc_store         = 4'b0100
    ,e_uc_amo           = 4'b0101
    ,e_cache_flush      = 4'b0110
    ,e_cache_clear      = 4'b0111
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

  // Relevant for uc_store and uc_amo
  typedef enum logic [3:0]
  {
    // Return value of e_req_store is undefined, clients should not
    //   depend on it being zero
    e_req_store    = 4'b0000
    ,e_req_amolr   = 4'b0001
    ,e_req_amosc   = 4'b0010
    ,e_req_amoswap = 4'b0011
    ,e_req_amoadd  = 4'b0100
    ,e_req_amoxor  = 4'b0101
    ,e_req_amoand  = 4'b0110
    ,e_req_amoor   = 4'b0111
    ,e_req_amomin  = 4'b1000
    ,e_req_amomax  = 4'b1001
    ,e_req_amominu = 4'b1010
    ,e_req_amomaxu = 4'b1011
  } bp_cache_req_wr_subop_e;

`endif


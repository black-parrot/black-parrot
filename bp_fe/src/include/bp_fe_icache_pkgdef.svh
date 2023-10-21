`ifndef BP_FE_ICACHE_PKGDEF_SVH
`define BP_FE_ICACHE_PKGDEF_SVH

  typedef enum
  {
    e_icache_fetch
    ,e_icache_inval
  } bp_fe_icache_op_e;

  typedef struct packed
  {
    logic fetch_op;
    logic inval_op;
  }  bp_fe_icache_decode_s;

  typedef struct packed
  {
    bp_fe_icache_decode_s decode;
    logic uncached;
    logic spec;
  }  bp_fe_icache_req_payload_s;

`endif


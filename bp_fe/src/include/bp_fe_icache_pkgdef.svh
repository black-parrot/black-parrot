`ifndef BP_FE_ICACHE_PKGDEF_SVH
`define BP_FE_ICACHE_PKGDEF_SVH

  typedef enum
  {
    e_icache_fetch
    ,e_icache_inval
  } bp_fe_icache_op_e;

  typedef struct packed
  {
    logic unused;
  }  bp_fe_icache_req_payload_s;

`endif



`ifndef BP_FE_PC_GEN_PKGDEF_SVH
`define BP_FE_PC_GEN_PKGDEF_SVH

  import bp_common_pkg::*;

  typedef struct packed
  {
    logic br;
    logic jal;
    logic jalr;
    logic call;
    logic _return;
    logic full1;
    logic full2;
    logic comp;
    logic [38:0] imm;
  }  bp_fe_decode_s;

  typedef struct packed
  {
    logic startup;
    logic catchup;
    logic rebase;
    logic br;
    logic jal;
    logic jalr;
    logic call;
    logic _return;
    logic [38:0] linear_imm;
    logic [38:0] ntaken_imm;
    logic [38:0] taken_imm;
  }  bp_fe_scan_s;

`endif


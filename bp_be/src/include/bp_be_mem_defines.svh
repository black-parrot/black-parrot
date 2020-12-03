`ifndef BP_BE_MEM_DEFINES_VH
`define BP_BE_MEM_DEFINES_VH

  typedef struct packed
  {
    bp_be_fu_op_s                      csr_op;
    logic [rv64_csr_addr_width_gp-1:0] csr_addr;
    logic [rv64_reg_data_width_gp-1:0] data;
  }  bp_be_csr_cmd_s;

  typedef struct packed
  {
    logic [bp_sv39_pte_width_gp-10-bp_sv39_ppn_width_gp-1:0] reserved;
    logic [bp_sv39_ppn_width_gp-1:0] ppn;
    logic [1:0] rsw;
    logic d;
    logic a;
    logic g;
    logic u;
    logic x;
    logic w;
    logic r;
    logic v;
  }  bp_sv39_pte_s;

`define bp_be_csr_cmd_width \
  (`bp_be_fu_op_width + rv64_csr_addr_width_gp + rv64_reg_data_width_gp)

`endif


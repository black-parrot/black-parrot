module bp_be_csr
  import bp_be_rv64_pkg::*;
  import bp_be_pkg::*;
  #(parameter num_core_p = "inv"
    , parameter vaddr_width_p = "inv"
    , parameter lce_sets_p = "inv"
    , parameter cce_block_size_in_bytes_p = "inv"

    // Default parameters
    // TODO: Should be set from bp_cfg when implemented
    , parameter vendorid_p = 16'h1234
    , parameter archid_p   = 16'h5678
    , parameter impid_p    = 32'hdeadbeef

    , localparam fu_op_width_lp = `bp_be_fu_op_width
    , localparam csr_cmd_width_lp = `bp_be_csr_cmd_width

    , localparam hartid_width_lp = `BSG_SAFE_CLOG2(num_core_p)
    , localparam reg_data_width_lp = rv64_reg_data_width_gp
    , localparam instr_width_lp = rv64_instr_width_gp
    , localparam csr_addr_width_lp = 12
    )
   (input                            clk_i
    , input                          reset_i

    // CSR instruction interface
    , input [csr_cmd_width_lp-1:0]   csr_cmd_i
    , input                          csr_cmd_v_i
    , output                         csr_cmd_ready_o

    , output [reg_data_width_lp-1:0] data_o
    , output                         v_o
    , output logic                   illegal_csr_o

    // Misc interface
    , input [hartid_width_lp-1:0]    hartid_i
    , input                          instret_i
    , input [vaddr_width_p-1:0]      exception_pc_i
    , input [instr_width_lp-1:0]     exception_instr_i
    , input                          exception_v_i
    , input                          mret_v_i

    , output [reg_data_width_lp-1:0] mepc_o
    , output [reg_data_width_lp-1:0] mtvec_o
    , output                         translation_en_o
    );

// Declare parameterizable structs
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)

// Casting input and output ports
bp_be_csr_cmd_s csr_cmd;

assign csr_cmd = csr_cmd_i;

// The muxed and demuxed CSR outputs
logic [reg_data_width_lp-1:0] csr_data_li, csr_data_lo;

`define declare_rw_csr(csr_name_mp, width_mp, addr_mp) \
  logic [width_mp-1:0] ``csr_name_mp``_li, ``csr_name_mp``_lo;                      \
  logic [0:0] ``csr_name_mp``_w_v_li;                                               \
  wire [0:0] ``csr_name_mp``_match_v = csr_cmd_v_i & (csr_cmd.csr_addr == addr_mp); \
      bsg_dff_reset_en                                                              \
       #(.width_p(width_mp))                                                        \
       ``csr_name_mp``                                                              \
        (.clk_i(clk_i)                                                              \
         ,.reset_i(reset_i)                                                         \
         ,.en_i(``csr_name_mp``_w_v_li)                                             \
                                                                                    \
         ,.data_i(``csr_name_mp``_li)                                               \
         ,.data_o(``csr_name_mp``_lo)                                               \
         );

`define declare_ro_csr(csr_name_mp, width_mp, addr_mp) \
  logic [width_mp-1:0] ``csr_name_mp``_li;                                          \
  logic [0:0] ``csr_name_mp``_w_v_li;                                               \
  wire [0:0] ``csr_name_mp``_match_v = csr_cmd_v_i & (csr_cmd.csr_addr == addr_mp); \
  wire [width_mp-1:0] ``csr_name_mp``_lo = ``csr_name_mp``_li;
  
`declare_ro_csr(mvendorid, reg_data_width_lp, `RV64_MVENDORID_CSR_ADDR)
`declare_ro_csr(marchid  , reg_data_width_lp, `RV64_MARCHID_CSR_ADDR)
`declare_ro_csr(mimpid   , reg_data_width_lp, `RV64_MIMPID_CSR_ADDR)
`declare_ro_csr(mhartid  , reg_data_width_lp, `RV64_MHARTID_CSR_ADDR)

`declare_rw_csr(mcycle  , reg_data_width_lp, `RV64_MCYCLE_CSR_ADDR)
`declare_rw_csr(minstret, reg_data_width_lp, `RV64_MINSTRET_CSR_ADDR)

`declare_rw_csr(mtvec, reg_data_width_lp, `RV64_MTVEC_CSR_ADDR)

`declare_rw_csr(mscratch, reg_data_width_lp, `RV64_MSCRATCH_CSR_ADDR)
`declare_rw_csr(mepc    , reg_data_width_lp, `RV64_MEPC_CSR_ADDR)
`declare_rw_csr(mcause  , reg_data_width_lp, `RV64_MCAUSE_CSR_ADDR)
`declare_rw_csr(mtval   , reg_data_width_lp, `RV64_MTVAL_CSR_ADDR)

logic [1:0] priv_mode_n, priv_mode_r;
logic priv_mode_w_v_li;
assign priv_mode_n = exception_v_i
                     ? `RV64_PRIV_M_MODE
                     : mret_v_i
                       ? `RV64_PRIV_S_MODE
                       : priv_mode_r;
assign priv_mode_w_v_li = exception_v_i | mret_v_i;
assign translation_en_o = (priv_mode_r == `RV64_PRIV_S_MODE);

bsg_dff_reset_en
 #(.width_p(2)
   ,.reset_val_p(`RV64_PRIV_M_MODE)
   )
  priv_mode_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(priv_mode_w_v_li)

   ,.data_i(priv_mode_n)
   ,.data_o(priv_mode_r)
   );

// CSR write enable
always_comb 
  begin
    mvendorid_w_v_li = '0; // Read-only
    marchid_w_v_li   = '0; // Read-only
    mimpid_w_v_li    = '0; // Read-only
    mhartid_w_v_li   = '0; // Read-only
    
    mcycle_w_v_li    = mcycle_match_v   | 1'b1; // Always increment cycle counter
    minstret_w_v_li  = minstret_match_v | instret_i;
    
    mtvec_w_v_li     = mtvec_match_v;
    
    mscratch_w_v_li  = mscratch_match_v;
    mepc_w_v_li      = mepc_match_v   | exception_v_i;
    mcause_w_v_li    = mcause_match_v | exception_v_i;
    mtval_w_v_li     = mtval_match_v  | exception_v_i;
  end

// CSR data
always_comb
  begin
    mvendorid_li = reg_data_width_lp'(vendorid_p);
    marchid_li   = reg_data_width_lp'(archid_p);
    mimpid_li    = reg_data_width_lp'(impid_p);
    mhartid_li   = reg_data_width_lp'(hartid_i);

    mcycle_li    = mcycle_match_v ? csr_data_li : csr_data_lo + reg_data_width_lp'(1);
    minstret_li  = minstret_match_v ? csr_data_li : csr_data_lo + reg_data_width_lp'(instret_i);

    mtvec_li    = csr_data_li;

    mscratch_li = csr_data_li;
    mepc_li     = exception_v_i ? exception_pc_i : csr_data_li;
    mcause_li   = '0; // TODO: Unimplemented
    mtval_li    = exception_v_i ? exception_instr_i : csr_data_li;
  end

// Compute input CSR data
always_comb 
  begin
    unique casez (csr_cmd.csr_op)
      e_csrrw  : csr_data_li =  csr_cmd.data;
      e_csrrs  : csr_data_li =  csr_cmd.data | csr_data_lo;
      e_csrrc  : csr_data_li = ~csr_cmd.data & csr_data_lo;

      e_csrrwi : csr_data_li =  csr_cmd.data[4:0];
      e_csrrsi : csr_data_li =  csr_cmd.data[4:0] | csr_data_lo;
      e_csrrci : csr_data_li = ~csr_cmd.data[4:0] & csr_data_lo;
      default  : csr_data_li = '0;
    endcase
  end

// Mux output data
always_comb 
  begin
    csr_data_lo   = '0;
    illegal_csr_o = '0;
    unique if (mvendorid_match_v) csr_data_lo = mvendorid_lo;
      else if (marchid_match_v)   csr_data_lo = marchid_lo;
      else if (mimpid_match_v)    csr_data_lo = mimpid_lo;
      else if (mhartid_match_v)   csr_data_lo = mhartid_lo;

      else if (mcycle_match_v)    csr_data_lo = mcycle_lo;
      else if (minstret_match_v)  csr_data_lo = minstret_lo;

      else if (mtvec_match_v)     csr_data_lo = mtvec_lo;

      else if (mscratch_match_v)  csr_data_lo = mscratch_lo;
      else if (mepc_match_v)      csr_data_lo = mepc_lo;
      else if (mcause_match_v)    csr_data_lo = mcause_lo;
      else if (mtval_match_v)     csr_data_lo = mtval_lo;
      else 
        begin
          illegal_csr_o = csr_cmd_v_i;
        end
  end

// CSR slow paths
assign mepc_o  = mepc_lo;
assign mtvec_o = mtvec_lo;

assign csr_cmd_ready_o = 1'b1;
assign data_o = reg_data_width_lp'(csr_data_lo);
assign v_o = ~illegal_csr_o;

endmodule : bp_be_csr


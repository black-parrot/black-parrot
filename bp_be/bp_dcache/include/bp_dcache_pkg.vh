/**
 *  bp_dcache_pkg.vh
 *
 *  @author tommy
 */

`ifndef BP_DCACHE_PKG_VH
`define BP_DCACHE_PKG_VH

package bp_dcache_pkg;

  typedef enum logic [3:0] {

    e_dcache_opcode_lbu  = 4'b0100
    ,e_dcache_opcode_lhu = 4'b0101
    ,e_dcache_opcode_lwu = 4'b0110

    ,e_dcache_opcode_lb  = 4'b0000
    ,e_dcache_opcode_lh  = 4'b0001
    ,e_dcache_opcode_lw  = 4'b0010
    ,e_dcache_opcode_ld  = 4'b0011

    ,e_dcache_opcode_sb  = 4'b1000
    ,e_dcache_opcode_sh  = 4'b1001
    ,e_dcache_opcode_sw  = 4'b1010
    ,e_dcache_opcode_sd  = 4'b1011

  } bp_dcache_opcode_e;

endpackage

`endif


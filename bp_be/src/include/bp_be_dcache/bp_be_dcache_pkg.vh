/**
 *  Name:
 *    bp_be_dcache_pkg.vh
 *  
 *  Description:
 *    opcodes for dcache packet from mmu.
 */

package bp_be_dcache_pkg;

  typedef enum logic [3:0] {

    e_dcache_opcode_lbu  = 4'b0100  // load byte unsigned
    ,e_dcache_opcode_lhu = 4'b0101  // load half unsigned
    ,e_dcache_opcode_lwu = 4'b0110  // load word unsigned

    ,e_dcache_opcode_lb  = 4'b0000  // load byte
    ,e_dcache_opcode_lh  = 4'b0001  // load half
    ,e_dcache_opcode_lw  = 4'b0010  // load word
    ,e_dcache_opcode_ld  = 4'b0011  // load double

    ,e_dcache_opcode_sb  = 4'b1000  // store byte
    ,e_dcache_opcode_sh  = 4'b1001  // store half
    ,e_dcache_opcode_sw  = 4'b1010  // store word
    ,e_dcache_opcode_sd  = 4'b1011  // store double

  } bp_be_dcache_opcode_e;

endpackage

/**
 *  Name:
 *    bp_be_dcache_pkg.vh
 *  
 *  Description:
 *    opcodes for dcache packet from mmu.
 */

package bp_be_dcache_pkg;
    
  `include "bp_be_dcache_pkt.vh"
  `include "bp_be_dcache_tag_info.vh"
  `include "bp_be_dcache_wbuf_entry.vh"

  typedef enum logic [5:0] {

    e_dcache_opcode_lbu  = 6'b000100  // load byte unsigned
    ,e_dcache_opcode_lhu = 6'b000101  // load half unsigned
    ,e_dcache_opcode_lwu = 6'b000110  // load word unsigned

    ,e_dcache_opcode_lb  = 6'b000000  // load byte
    ,e_dcache_opcode_lh  = 6'b000001  // load half
    ,e_dcache_opcode_lw  = 6'b000010  // load word
    ,e_dcache_opcode_ld  = 6'b000011  // load double

    ,e_dcache_opcode_sb  = 6'b001000  // store byte
    ,e_dcache_opcode_sh  = 6'b001001  // store half
    ,e_dcache_opcode_sw  = 6'b001010  // store word
    ,e_dcache_opcode_sd  = 6'b001011  // store double

    ,e_dcache_opcode_lrw = 6'b000111  // load reserved word
    ,e_dcache_opcode_scw = 6'b001100  // store conditional word

    ,e_dcache_opcode_lrd = 6'b001101  // load reserved double
    ,e_dcache_opcode_scd = 6'b001110  // store conditional double
    ,e_dcache_opcode_fencei = 6'b001111 // Writeback all data in data cache

    ,e_dcache_opcode_amoswapw = 6'b010000 // Atomic swap word
    ,e_dcache_opcode_amoaddw  = 6'b010001 // Atomic add word
    ,e_dcache_opcode_amoxorw  = 6'b010010 // Atomic xor word
    ,e_dcache_opcode_amoandw  = 6'b010011 // Atomic and word
    ,e_dcache_opcode_amoorw   = 6'b010100 // Atomic or word
    ,e_dcache_opcode_amominw  = 6'b010101 // Atomic min word
    ,e_dcache_opcode_amomaxw  = 6'b010110 // Atomic max word
    ,e_dcache_opcode_amominuw = 6'b010111 // Atomic min unsigned word
    ,e_dcache_opcode_amomaxuw = 6'b011000 // Atomic max unsigned word

    ,e_dcache_opcode_amoswapd = 6'b011001 // Atomic swap double
    ,e_dcache_opcode_amoaddd  = 6'b011010 // Atomic add double
    ,e_dcache_opcode_amoxord  = 6'b011011 // Atomic xor double
    ,e_dcache_opcode_amoandd  = 6'b011100 // Atomic and double
    ,e_dcache_opcode_amoord   = 6'b011101 // Atomic or double
    ,e_dcache_opcode_amomind  = 6'b011110 // Atomic min double
    ,e_dcache_opcode_amomaxd  = 6'b011111 // Atomic max double
    ,e_dcache_opcode_amominud = 6'b100000 // Atomic min unsigned double
    ,e_dcache_opcode_amomaxud = 6'b100001 // Atomic max unsigned double
  } bp_be_dcache_opcode_e;

endpackage

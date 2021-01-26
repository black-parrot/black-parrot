/**
 *  Name:
 *
 *    bp_me_nonsynth_pkg.svh
 *
 *  Description:
 */

package bp_me_nonsynth_pkg;

  // bits: 3 = store/load
  //       2 = unsigned/signed
  //     1:0 = size (1, 2, 4, 8 bytes)
  typedef enum logic [3:0] {

    e_lce_opcode_lbu  = 4'b0100  // load byte unsigned
    ,e_lce_opcode_lhu = 4'b0101  // load half unsigned
    ,e_lce_opcode_lwu = 4'b0110  // load word unsigned

    ,e_lce_opcode_lb  = 4'b0000  // load byte
    ,e_lce_opcode_lh  = 4'b0001  // load half
    ,e_lce_opcode_lw  = 4'b0010  // load word
    ,e_lce_opcode_ld  = 4'b0011  // load double

    ,e_lce_opcode_sb  = 4'b1000  // store byte
    ,e_lce_opcode_sh  = 4'b1001  // store half
    ,e_lce_opcode_sw  = 4'b1010  // store word
    ,e_lce_opcode_sd  = 4'b1011  // store double

    // TODO: LR/SC not yet supported in nonsynth mock LCE
    //,e_lce_opcode_lrw = 4'b0111  // load reserved word
    //,e_lce_opcode_scw = 4'b1100  // store conditional word

    //,e_lce_opcode_lrd = 4'b1101  // load reserved double
    //,e_lce_opcode_scd = 4'b1110  // store conditional double

  } bp_me_nonsynth_lce_opcode_e;

  `define declare_bp_me_nonsynth_lce_tr_pkt_s(addr_width_mp, data_width_mp) \
  typedef struct packed {                                                   \
    bp_me_nonsynth_lce_opcode_e   cmd;                                      \
    logic [addr_width_mp-1:0]     paddr;                                    \
    logic                         uncached;                                 \
    logic [data_width_mp-1:0]     data;                                     \
  } bp_me_nonsynth_lce_tr_pkt_s;

  `define bp_me_nonsynth_lce_tr_pkt_width(addr_width_mp, data_width_mp) \
    ($bits(bp_me_nonsynth_lce_opcode_e)+addr_width_mp+1+data_width_mp)

endpackage

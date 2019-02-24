
package bp_be_bserial_pkg;

  typedef enum bit[3:0]
  {
    e_bserial_op_add     = 4'b0000
    , e_bserial_op_sub   = 4'b1000
    , e_bserial_op_sll   = 4'b0001
    , e_bserial_op_slt   = 4'b0010
    , e_bserial_op_xor   = 4'b0100
    , e_bserial_op_and   = 4'b0111
    , e_bserial_op_or    = 4'b0110
    , e_bserial_op_sext  = 4'b1001
    , e_bserial_op_eq    = 4'b1100
    , e_bserial_op_ne    = 4'b1110
    , e_bserial_op_passb = 4'b1111
  } bp_be_bserial_opcode_e;

  `define bp_be_bserial_opcode_width \
    ($bits(bp_be_bserial_opcode_e))

endpackage : bp_be_bserial_pkg
 

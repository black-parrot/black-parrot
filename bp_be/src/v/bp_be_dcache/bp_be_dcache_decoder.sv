
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_dcache_decoder
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter amo_support_p = 0

   , localparam dcache_pkt_width_lp = $bits(bp_be_dcache_pkt_s)
   , localparam dcache_decode_width_lp = $bits(bp_be_dcache_decode_s)
   )
  (input [dcache_pkt_width_lp-1:0]             pkt_i
   , output logic [dcache_decode_width_lp-1:0] decode_o
   );

  `bp_cast_i(bp_be_dcache_pkt_s, pkt);
  `bp_cast_o(bp_be_dcache_decode_s, decode);

  always_comb begin
    decode_cast_o = '0;

    // Atomic op decoding
    decode_cast_o.lr_op = pkt_cast_i.opcode inside {e_dcache_op_lrw, e_dcache_op_lrd};
    decode_cast_o.sc_op = pkt_cast_i.opcode inside {e_dcache_op_scw, e_dcache_op_scd};

    // Atomic subop decoding
    unique casez (pkt_cast_i.opcode)
      e_dcache_op_lrw, e_dcache_op_lrd          : decode_cast_o.amo_subop = e_dcache_subop_lr;
      e_dcache_op_scw, e_dcache_op_scd          : decode_cast_o.amo_subop = e_dcache_subop_sc;
      e_dcache_op_amoswapw, e_dcache_op_amoswapd: decode_cast_o.amo_subop = e_dcache_subop_amoswap;
      e_dcache_op_amoaddw, e_dcache_op_amoaddd  : decode_cast_o.amo_subop = e_dcache_subop_amoadd;
      e_dcache_op_amoxorw, e_dcache_op_amoxord  : decode_cast_o.amo_subop = e_dcache_subop_amoxor;
      e_dcache_op_amoandw, e_dcache_op_amoandd  : decode_cast_o.amo_subop = e_dcache_subop_amoand;
      e_dcache_op_amoorw, e_dcache_op_amoord    : decode_cast_o.amo_subop = e_dcache_subop_amoor;
      e_dcache_op_amominw, e_dcache_op_amomind  : decode_cast_o.amo_subop = e_dcache_subop_amomin;
      e_dcache_op_amomaxw, e_dcache_op_amomaxd  : decode_cast_o.amo_subop = e_dcache_subop_amomax;
      e_dcache_op_amominuw, e_dcache_op_amominud: decode_cast_o.amo_subop = e_dcache_subop_amominu;
      e_dcache_op_amomaxuw, e_dcache_op_amomaxud: decode_cast_o.amo_subop = e_dcache_subop_amomaxu;
      default                                   : decode_cast_o.amo_subop = e_dcache_subop_none;
    endcase

    decode_cast_o.amo_op = (decode_cast_o.amo_subop != e_dcache_subop_none);
    decode_cast_o.binval_op = pkt_cast_i.opcode inside {e_dcache_op_binval, e_dcache_op_bflush};
    decode_cast_o.bclean_op = pkt_cast_i.opcode inside {e_dcache_op_bclean, e_dcache_op_bflush};
    decode_cast_o.bzero_op = pkt_cast_i.opcode inside {e_dcache_op_bzero};

    decode_cast_o.inval_op = pkt_cast_i.opcode inside {e_dcache_op_inval, e_dcache_op_flush};
    decode_cast_o.clean_op = pkt_cast_i.opcode inside {e_dcache_op_clean, e_dcache_op_flush};

    decode_cast_o.uncached_op =
      ((!amo_support_p[e_dcache_subop_lr]) && (decode_cast_o.lr_op))
       || ((!amo_support_p[e_dcache_subop_sc]) && (decode_cast_o.sc_op))
       || ((!amo_support_p[e_dcache_subop_amoswap]) && decode_cast_o.amo_subop == e_dcache_subop_amoswap)
       || ((!amo_support_p[e_dcache_subop_amoadd]) && decode_cast_o.amo_subop == e_dcache_subop_amoadd)
       || ((!amo_support_p[e_dcache_subop_amomin]) && decode_cast_o.amo_subop == e_dcache_subop_amomin)
       || ((!amo_support_p[e_dcache_subop_amomax]) && decode_cast_o.amo_subop == e_dcache_subop_amomax)
       || ((!amo_support_p[e_dcache_subop_amominu]) && decode_cast_o.amo_subop == e_dcache_subop_amominu)
       || ((!amo_support_p[e_dcache_subop_amomaxu]) && decode_cast_o.amo_subop == e_dcache_subop_amomaxu)
       || ((!amo_support_p[e_dcache_subop_amoxor]) && decode_cast_o.amo_subop == e_dcache_subop_amoxor)
       || ((!amo_support_p[e_dcache_subop_amoand]) && decode_cast_o.amo_subop == e_dcache_subop_amoand)
       || ((!amo_support_p[e_dcache_subop_amoor]) && decode_cast_o.amo_subop == e_dcache_subop_amoor);

    decode_cast_o.load_op = (decode_cast_o.amo_op | decode_cast_o.lr_op) || pkt_cast_i.opcode inside
      {e_dcache_op_flw, e_dcache_op_fld
       ,e_dcache_op_ld, e_dcache_op_lw, e_dcache_op_lh, e_dcache_op_lb
       ,e_dcache_op_lwu, e_dcache_op_lhu, e_dcache_op_lbu
       ,e_dcache_op_ptw
       };

    decode_cast_o.store_op = (decode_cast_o.amo_op & ~decode_cast_o.lr_op) || pkt_cast_i.opcode inside
      {e_dcache_op_sd, e_dcache_op_sw, e_dcache_op_sh, e_dcache_op_sb
       ,e_dcache_op_fsw, e_dcache_op_fsd
       ,e_dcache_op_bzero
       };

    // Type decoding
    decode_cast_o.int_op = pkt_cast_i.opcode inside
      {e_dcache_op_lb, e_dcache_op_lh, e_dcache_op_lw, e_dcache_op_ld
       ,e_dcache_op_lbu, e_dcache_op_lhu, e_dcache_op_lwu
       ,e_dcache_op_sb, e_dcache_op_sh, e_dcache_op_sw, e_dcache_op_sd
       ,e_dcache_op_lrw, e_dcache_op_scw, e_dcache_op_lrd, e_dcache_op_scd
       ,e_dcache_op_amoswapw, e_dcache_op_amoaddw, e_dcache_op_amoxorw
       ,e_dcache_op_amoandw, e_dcache_op_amoorw, e_dcache_op_amominw
       ,e_dcache_op_amomaxw, e_dcache_op_amominuw, e_dcache_op_amomaxuw
       ,e_dcache_op_amoswapd, e_dcache_op_amoaddd, e_dcache_op_amoxord
       ,e_dcache_op_amoandd, e_dcache_op_amoord, e_dcache_op_amomind
       ,e_dcache_op_amomaxd, e_dcache_op_amominud, e_dcache_op_amomaxud
       };
    decode_cast_o.float_op = pkt_cast_i.opcode inside
      {e_dcache_op_flw, e_dcache_op_fld, e_dcache_op_fsw, e_dcache_op_fsd};
    decode_cast_o.ptw_op = pkt_cast_i.opcode inside {e_dcache_op_ptw};

    // Size decoding
    unique case (pkt_cast_i.opcode)
      e_dcache_op_inval, e_dcache_op_clean, e_dcache_op_flush:
                                                       decode_cast_o.cache_op  = 1'b1;
      e_dcache_op_bzero, e_dcache_op_binval, e_dcache_op_bclean, e_dcache_op_bflush:
                                                       decode_cast_o.block_op  = 1'b1;
      e_dcache_op_lb, e_dcache_op_lbu, e_dcache_op_sb: decode_cast_o.byte_op   = 1'b1;
      e_dcache_op_lh, e_dcache_op_lhu, e_dcache_op_sh: decode_cast_o.half_op   = 1'b1;
      e_dcache_op_amoswapw, e_dcache_op_amoaddw, e_dcache_op_amoxorw
      ,e_dcache_op_amoandw, e_dcache_op_amoorw, e_dcache_op_amominw
      ,e_dcache_op_amomaxw, e_dcache_op_amominuw, e_dcache_op_amomaxuw
      ,e_dcache_op_lw, e_dcache_op_lwu, e_dcache_op_sw
      ,e_dcache_op_flw, e_dcache_op_fsw
      ,e_dcache_op_lrw, e_dcache_op_scw:               decode_cast_o.word_op   = 1'b1;
      default: decode_cast_o.double_op = 1'b1;
    endcase

    // Signed op decoding
    decode_cast_o.signed_op = (decode_cast_o.byte_op | decode_cast_o.half_op | decode_cast_o.word_op)
      && !(pkt_cast_i.opcode inside {e_dcache_op_lwu, e_dcache_op_lhu, e_dcache_op_lbu});

    // The destination register of the cache request
    decode_cast_o.rd_addr = pkt_cast_i.rd_addr;

    if (decode_cast_o.int_op & decode_cast_o.byte_op)
      decode_cast_o.tag = e_int_byte;
    else if (decode_cast_o.int_op & decode_cast_o.half_op)
      decode_cast_o.tag = e_int_hword;
    else if (decode_cast_o.int_op & decode_cast_o.word_op)
      decode_cast_o.tag = e_int_word;
    else if (decode_cast_o.float_op & decode_cast_o.word_op)
      decode_cast_o.tag = e_fp_sp;

    // Return
    decode_cast_o.ret_op = decode_cast_o.load_op
      & (decode_cast_o.ptw_op
         | decode_cast_o.float_op
         | (decode_cast_o.int_op && (decode_cast_o.rd_addr != '0))
         );
  end

endmodule

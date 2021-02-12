
`include "bp_be_defines.svh"

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_dcache_decoder
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dcache_pkt_width_lp = $bits(bp_be_dcache_pkt_s)
   , localparam dcache_pipeline_struct_width_lp = $bits(bp_be_dcache_decode_s)
   )
  (input [dcache_pkt_width_lp-1:0]                      pkt_i
   , output logic [dcache_pipeline_struct_width_lp-1:0] decode_o
   );

  bp_be_dcache_pkt_s dcache_pkt;
  assign dcache_pkt = pkt_i;

  bp_be_dcache_decode_s decode_cast_o;
  assign decode_o = decode_cast_o;

  always_comb begin
    decode_cast_o = '0;

    // Signed op decoding
    decode_cast_o.signed_op = !(dcache_pkt.opcode inside
      {e_dcache_op_lwu, e_dcache_op_lhu, e_dcache_op_lbu});

    // Float decoding
    decode_cast_o.float_op = dcache_pkt.opcode inside
      {e_dcache_op_flw, e_dcache_op_fld, e_dcache_op_fsw, e_dcache_op_fsd};

    // Atomic op decoding
    decode_cast_o.lr_op = dcache_pkt.opcode inside {e_dcache_op_lrw, e_dcache_op_lrd};
    decode_cast_o.sc_op = dcache_pkt.opcode inside {e_dcache_op_scw, e_dcache_op_scd};
    decode_cast_o.fencei_op = dcache_pkt.opcode inside {e_dcache_op_fencei};

    // Atomic subop decoding
    unique casez (dcache_pkt.opcode)
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

    decode_cast_o.l2_op =
      ((lr_sc_p == e_l2) && (decode_cast_o.lr_op || decode_cast_o.sc_op))
      || ((amo_swap_p == e_l2) && decode_cast_o.amo_subop inside {e_dcache_subop_amoswap})
      || ((amo_fetch_arithmetic_p == e_l2) && decode_cast_o.amo_subop inside
            {e_dcache_subop_amoadd
             ,e_dcache_subop_amomin, e_dcache_subop_amomax
             ,e_dcache_subop_amominu, e_dcache_subop_amomaxu
             })
      || ((amo_fetch_logic_p == e_l2) && decode_cast_o.amo_subop inside
            {e_dcache_subop_amoxor, e_dcache_subop_amoand, e_dcache_subop_amoor});

    decode_cast_o.load_op = (decode_cast_o.amo_op | decode_cast_o.lr_op) || dcache_pkt.opcode inside
      {e_dcache_op_flw, e_dcache_op_fld
       ,e_dcache_op_ld, e_dcache_op_lw, e_dcache_op_lh, e_dcache_op_lb
       ,e_dcache_op_lwu, e_dcache_op_lhu, e_dcache_op_lbu
       };

    decode_cast_o.store_op = (decode_cast_o.amo_op & ~decode_cast_o.lr_op) || dcache_pkt.opcode inside
      {e_dcache_op_sd, e_dcache_op_sw, e_dcache_op_sh, e_dcache_op_sb, e_dcache_op_fsw, e_dcache_op_fsd};

    // Size decoding
    unique case (dcache_pkt.opcode)
      e_dcache_op_amoswapw, e_dcache_op_amoaddw, e_dcache_op_amoxorw
      ,e_dcache_op_amoandw, e_dcache_op_amoorw, e_dcache_op_amominw
      ,e_dcache_op_amomaxw, e_dcache_op_amominuw, e_dcache_op_amomaxuw
      ,e_dcache_op_lw, e_dcache_op_lwu, e_dcache_op_sw
      ,e_dcache_op_flw, e_dcache_op_fsw
      ,e_dcache_op_lrw, e_dcache_op_scw:               decode_cast_o.word_op   = 1'b1;
      e_dcache_op_lh, e_dcache_op_lhu, e_dcache_op_sh: decode_cast_o.half_op   = 1'b1;
      e_dcache_op_lb, e_dcache_op_lbu, e_dcache_op_sb: decode_cast_o.byte_op   = 1'b1;
      default:                                         decode_cast_o.double_op = 1'b1;
    endcase

    // The destination register of the cache request
    decode_cast_o.rd_addr = dcache_pkt.rd_addr;
  end

endmodule

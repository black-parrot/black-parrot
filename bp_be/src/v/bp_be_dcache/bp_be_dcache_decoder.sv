module bp_be_dcache_decoder
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dcache_pkt_width_lp = `bp_be_dcache_pkt_width(bp_page_offset_width_gp, dpath_width_p)
   , localparam dcache_pipeline_struct_width_lp = `bp_be_dcache_pipeline_struct_width

  )
  (
    input [dcache_pkt_width_lp-1:0]                      pkt_i
    , output logic [dcache_pipeline_struct_width_lp-1:0] decoded_o
  );

  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dpath_width_p);
  bp_be_dcache_pkt_s dcache_pkt;
  assign dcache_pkt = pkt_i;

  `declare_bp_be_dcache_pipeline_s
  bp_be_dcache_pipeline_s decoded_cast_o;
  assign decoded_o = decoded_cast_o;

  always_comb begin
    decoded_cast_o = '0;

    // Op type decoding
    unique case (dcache_pkt.opcode)
      e_dcache_op_lrw, e_dcache_op_lrd:
       begin
        // An LR is a load operation of either double word or word size,
        // inherently signed
        decoded_cast_o.lr_op                         = 1'b1;
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (lr_sc_p == e_l2);
       end
      e_dcache_op_scw, e_dcache_op_scd:
       begin
        // An SC is a store operation of either double word or word size,
        // inherently signed
        decoded_cast_o.sc_op                         = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (lr_sc_p == e_l2);
       end
      e_dcache_op_amoswapw, e_dcache_op_amoswapd:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amoswap_op                    = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_swap_p == e_l2);
       end
      e_dcache_op_amoaddw, e_dcache_op_amoaddd:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amoadd_op                     = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_arithmetic_p == e_l2);
       end
      e_dcache_op_amoxorw, e_dcache_op_amoxord:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amoxor_op                     = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_logic_p == e_l2);
       end
      e_dcache_op_amoandw, e_dcache_op_amoandd:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amoand_op                     = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_logic_p == e_l2);
       end
      e_dcache_op_amoorw, e_dcache_op_amoord:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amoor_op                      = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_logic_p == e_l2);
       end
      e_dcache_op_amominw, e_dcache_op_amomind:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amomin_op                     = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_arithmetic_p == e_l2);
       end
      e_dcache_op_amomaxw, e_dcache_op_amomaxd:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amomax_op                     = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_arithmetic_p == e_l2);
       end
      e_dcache_op_amominuw, e_dcache_op_amominud:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amominu_op                    = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_arithmetic_p == e_l2);
       end
      e_dcache_op_amomaxuw, e_dcache_op_amomaxud:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.amomaxu_op                    = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
        decoded_cast_o.l2_op                         = (amo_fetch_arithmetic_p == e_l2);
       end
      e_dcache_op_ld, e_dcache_op_lw, e_dcache_op_lh, e_dcache_op_lb:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
       end
      e_dcache_op_lwu, e_dcache_op_lhu, e_dcache_op_lbu:
       begin
        decoded_cast_o.load_op                       = 1'b1;
        decoded_cast_o.signed_op                     = 1'b0;
       end
      e_dcache_op_sd, e_dcache_op_sw, e_dcache_op_sh, e_dcache_op_sb:
       begin
        decoded_cast_o.store_op                      = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
       end
      e_dcache_op_flw, e_dcache_op_fld:
        begin
          decoded_cast_o.load_op                     = 1'b1;
          decoded_cast_o.float_op                    = 1'b1;
        end
      e_dcache_op_fsw, e_dcache_op_fsd:
        begin
          decoded_cast_o.store_op                    = 1'b1;
          decoded_cast_o.float_op                    = 1'b1;
        end
      e_dcache_op_fencei:
       begin
        decoded_cast_o.fencei_op                     = 1'b1;
        decoded_cast_o.signed_op                     = 1'b1;
       end
      default: begin end
    endcase

    // Size decoding
    unique case (dcache_pkt.opcode)
      e_dcache_op_ld, e_dcache_op_lrd, e_dcache_op_sd, e_dcache_op_scd
      ,e_dcache_op_fld, e_dcache_op_fsd:
       begin
        decoded_cast_o.double_op                = 1'b1;
       end
      e_dcache_op_lw, e_dcache_op_lwu, e_dcache_op_lrw, e_dcache_op_sw, e_dcache_op_scw
      ,e_dcache_op_flw, e_dcache_op_fsw:
       begin
        decoded_cast_o.word_op                  = 1'b1;
       end
      e_dcache_op_lh, e_dcache_op_lhu, e_dcache_op_sh:
       begin
        decoded_cast_o.half_op                  = 1'b1;
       end
      e_dcache_op_lb, e_dcache_op_lbu, e_dcache_op_sb:
       begin
        decoded_cast_o.byte_op                  = 1'b1;
       end
      e_dcache_op_amoswapw, e_dcache_op_amoaddw, e_dcache_op_amoxorw
      , e_dcache_op_amoandw, e_dcache_op_amoorw, e_dcache_op_amominw
      , e_dcache_op_amomaxw, e_dcache_op_amominuw, e_dcache_op_amomaxuw:
       begin
        decoded_cast_o.word_op                  = 1'b1;
       end
      e_dcache_op_amoswapd, e_dcache_op_amoaddd, e_dcache_op_amoxord
      , e_dcache_op_amoandd, e_dcache_op_amoord, e_dcache_op_amomind
      , e_dcache_op_amomaxd, e_dcache_op_amominud, e_dcache_op_amomaxud:
       begin
        decoded_cast_o.double_op                = 1'b1;
       end
      default: begin end
    endcase
  end

endmodule

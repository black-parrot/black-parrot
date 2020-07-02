module bp_be_dcache_decoder
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam dcache_pkt_width_lp = `bp_be_dcache_pkt_width(bp_page_offset_width_gp, dword_width_p)
   , localparam dcache_pipeline_struct_width_lp = `bp_be_dcache_pipeline_struct_width
   
  )
  (
    input [dcache_pkt_width_lp-1:0]                     dcache_pkt_i
    , output logic [dcache_pipeline_struct_width_lp-1:0] dcache_decoded_o
  );

  `declare_bp_be_dcache_pkt_s(bp_page_offset_width_gp, dword_width_p);
  bp_be_dcache_pkt_s dcache_pkt;
  assign dcache_pkt = dcache_pkt_i;

  `declare_bp_be_dcache_pipeline_s
  bp_be_dcache_pipeline_s dcache_decoded_cast_o;
  assign dcache_decoded_o = dcache_decoded_cast_o;

  always_comb begin
    dcache_decoded_cast_o = '0;

    // Op type decoding
    unique case (dcache_pkt.opcode)
      e_dcache_opcode_lrw, e_dcache_opcode_lrd: begin
        // An LR is a load operation of either double word or word size,
        // inherently signed
        dcache_decoded_cast_o.lr_op                         = 1'b1;
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_scw, e_dcache_opcode_scd: begin
      // An SC is a store operation of either double word or word size, 
      // inherently signed
        dcache_decoded_cast_o.sc_op                         = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amoswapw, e_dcache_opcode_amoswapd: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amoswap_op                    = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amoaddw, e_dcache_opcode_amoaddd: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amoadd_op                     = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amoxorw, e_dcache_opcode_amoxord: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amoxor_op                     = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amoandw, e_dcache_opcode_amoandd: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amoand_op                     = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amoorw, e_dcache_opcode_amoord: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amoor_op                      = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amominw, e_dcache_opcode_amomind: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amomin_op                     = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amomaxw, e_dcache_opcode_amomaxd: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amomax_op                     = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amominuw, e_dcache_opcode_amominud: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amominu_op                    = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_amomaxuw, e_dcache_opcode_amomaxud: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.amomaxu_op                    = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_ld, e_dcache_opcode_lw, e_dcache_opcode_lh, e_dcache_opcode_lb: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_lwu, e_dcache_opcode_lhu, e_dcache_opcode_lbu: begin
        dcache_decoded_cast_o.load_op                       = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b0;
      end
      e_dcache_opcode_sd, e_dcache_opcode_sw, e_dcache_opcode_sh, e_dcache_opcode_sb: begin
        dcache_decoded_cast_o.store_op                      = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      e_dcache_opcode_fencei: begin
        dcache_decoded_cast_o.fencei_op                     = 1'b1;
        dcache_decoded_cast_o.signed_op                     = 1'b1;
      end
      default: begin end
    endcase

    // Size decoding
    unique case (dcache_pkt.opcode)
      e_dcache_opcode_ld, e_dcache_opcode_lrd, e_dcache_opcode_sd, e_dcache_opcode_scd: begin
        dcache_decoded_cast_o.double_op                = 1'b1;
      end
      e_dcache_opcode_lw, e_dcache_opcode_lwu, e_dcache_opcode_lrw, e_dcache_opcode_sw, e_dcache_opcode_scw: begin
        dcache_decoded_cast_o.word_op                  = 1'b1;
      end
      e_dcache_opcode_lh, e_dcache_opcode_lhu, e_dcache_opcode_sh: begin
        dcache_decoded_cast_o.half_op                  = 1'b1;
      end
      e_dcache_opcode_lb, e_dcache_opcode_lbu, e_dcache_opcode_sb: begin
        dcache_decoded_cast_o.byte_op                  = 1'b1;
      end
      e_dcache_opcode_amoswapw, e_dcache_opcode_amoaddw, e_dcache_opcode_amoxorw
      , e_dcache_opcode_amoandw, e_dcache_opcode_amoorw, e_dcache_opcode_amominw
      , e_dcache_opcode_amomaxw, e_dcache_opcode_amominuw, e_dcache_opcode_amomaxuw: begin
        dcache_decoded_cast_o.word_op                  = 1'b1;
      end
      e_dcache_opcode_amoswapd, e_dcache_opcode_amoaddd, e_dcache_opcode_amoxord
      , e_dcache_opcode_amoandd, e_dcache_opcode_amoord, e_dcache_opcode_amomind
      , e_dcache_opcode_amomaxd, e_dcache_opcode_amominud, e_dcache_opcode_amomaxud: begin
        dcache_decoded_cast_o.double_op                = 1'b1;
      end
      default: begin end
    endcase
  end

endmodule

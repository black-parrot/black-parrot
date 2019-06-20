/**
 *
 * Name:
 *   bp_cce_reg.v
 *
 * Description:
 *
 */

module bp_cce_reg
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_lce_p                     = "inv"
    , parameter num_cce_p                   = "inv"
    , parameter paddr_width_p                = "inv"
    , parameter lce_assoc_p                 = "inv"
    , parameter lce_sets_p                  = "inv"
    , parameter block_size_in_bytes_p       = "inv"
    , parameter lce_req_data_width_p        = "inv"

    // Derived parameters
    , localparam lg_num_lce_lp              = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp              = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam block_size_in_bits_lp      = (block_size_in_bytes_p*8)
    , localparam lg_block_size_in_bytes_lp  = `BSG_SAFE_CLOG2(block_size_in_bytes_p)
    , localparam lg_lce_assoc_lp            = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp             = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp               =
      (paddr_width_p-lg_lce_sets_lp-lg_block_size_in_bytes_lp)
    , localparam entry_width_lp             = (tag_width_lp+`bp_cce_coh_bits)
    , localparam tag_set_width_lp           = (entry_width_lp*lce_assoc_p)

    , localparam mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)

    , localparam bp_lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p)
    , localparam bp_lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam bp_lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp)
    , localparam bp_mem_cce_resp_width_lp=
      `bp_mem_cce_resp_width(paddr_width_p, mshr_width_lp)
    , localparam bp_mem_cce_data_resp_width_lp=
      `bp_mem_cce_data_resp_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
  )
  (input                                                                   clk_i
   , input                                                                 reset_i

   , input bp_cce_inst_decoded_s                                           decoded_inst_i

   , input [bp_lce_cce_req_width_lp-1:0]                                   lce_req_i
   , input bp_lce_cce_resp_msg_type_e                                      null_wb_flag_i
   , input bp_lce_cce_ack_type_e                                           resp_ack_type_i

   , input [mshr_width_lp-1:0]                                             mem_resp_payload_i

   , input [`bp_cce_inst_gpr_width-1:0]                                    alu_res_i
   , input [`bp_cce_inst_gpr_width-1:0]                                    mov_src_i

   , input                                                                 pending_o_i
   , input                                                                 pending_v_o_i

   , input                                                                 dir_lru_v_i
   , input                                                                 dir_lru_cached_excl_i
   , input [tag_width_lp-1:0]                                              dir_lru_tag_i

   , input [lg_lce_assoc_lp-1:0]                                           gad_req_addr_way_i
   , input [lg_num_lce_lp-1:0]                                             gad_transfer_lce_i
   , input [lg_lce_assoc_lp-1:0]                                           gad_transfer_lce_way_i
   , input                                                                 gad_transfer_flag_i
   , input                                                                 gad_replacement_flag_i
   , input                                                                 gad_upgrade_flag_i
   , input                                                                 gad_invalidate_flag_i
   , input                                                                 gad_exclusive_flag_i
   , input                                                                 gad_cached_flag_i

   // Register value outputs
   , output logic [mshr_width_lp-1:0]                                      mshr_o

   , output logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0]   gpr_o

   , output logic [`bp_lce_cce_ack_type_width-1:0]                         ack_type_o

   , output logic [lce_req_data_width_p-1:0]                               nc_data_o
  );

  wire unused = pending_v_o_i;

  // Define structure variables for input queues
  `declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, lce_req_data_width_p);
  `declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, block_size_in_bits_lp);

  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p, mshr_width_lp);

  bp_lce_cce_req_s lce_req;

  // assign input and output queues to/from structure variables
  always_comb
  begin
    lce_req = lce_req_i;
  end

  // Registers
  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr_r, mshr_n;

  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r, gpr_n;
  logic [`bp_lce_cce_ack_type_width-1:0] ack_type_r, ack_type_n;
  logic [lce_req_data_width_p-1:0] nc_data_r, nc_data_n;
  
  // Output register values
  assign mshr_o = mshr_r;
  assign gpr_o = gpr_r;
  assign ack_type_o = ack_type_r;
  assign nc_data_o = nc_data_r;

  // Memory Response Message Payload (e.g., MSHR values to restore to MSHR register)
  bp_cce_mshr_s mem_resp_payload;
  assign mem_resp_payload = mem_resp_payload_i;

  always_comb
  begin

    // ACK Type
    ack_type_n = resp_ack_type_i;

    // GPR
    for (int i = 0; i < `bp_cce_inst_num_gpr; i=i+1) begin
      if (decoded_inst_i.alu_dst_w_v & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = alu_res_i;
      end else if (decoded_inst_i.mov_dst_w_v & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = mov_src_i;
      end else begin
        gpr_n[i] = '0;
      end
    end

    // Uncached data register is always sourced from LCE Request
    // Uncached data that is being returned to an LCE from a Mem Data Resp does not need
    // to be registered, and is handled by bp_cce_msg module.
    nc_data_n = lce_req.data;

    // MSHR

    // by default, hold mshr value
    mshr_n = mshr_r;

    // Next value for MSHR depends on whether the full MSHR is being restored (by MemResp msg),
    // cleared (by clm instruction), or being updated in pieces (lots of other instructions during
    // normal request processing).
    if (decoded_inst_i.mshr_restore) begin
      mshr_n = mem_resp_payload;
    end else if (decoded_inst_i.mshr_clear) begin
      mshr_n = '0;
    end else begin
      // Request LCE, address, tag
      case (decoded_inst_i.req_sel)
        e_req_sel_lce_req: begin
          mshr_n.lce_id = lce_req.src_id;
          mshr_n.paddr = lce_req.addr;
        end
        e_req_sel_pending: begin // TODO: v2
          mshr_n.lce_id = '0;
          mshr_n.paddr = '0;
        end
        default: begin
          mshr_n.lce_id = '0;
          mshr_n.paddr = '0;
        end
      endcase

      // Request Address Way
      case (decoded_inst_i.req_addr_way_sel)
        e_req_addr_way_sel_logic: begin
          mshr_n.way_id = gad_req_addr_way_i;
        end
        default: begin
          mshr_n.way_id = '0;
        end
      endcase

      // LRU Way
      case (decoded_inst_i.lru_way_sel)
        e_lru_way_sel_lce_req: begin
          mshr_n.lru_way_id = lce_req.lru_way_id;
        end
        e_lru_way_sel_pending: begin
          mshr_n.lru_way_id = '0; // TODO: v2
        end
        default: begin
            mshr_n.lru_way_id = '0;
        end
      endcase

      // Transfer LCE and Transfer LCE Way
      case (decoded_inst_i.transfer_lce_sel)
        e_tr_lce_sel_logic: begin
          mshr_n.tr_lce_id = gad_transfer_lce_i;
          mshr_n.tr_way_id = gad_transfer_lce_way_i;
        end
        default: begin
          mshr_n.tr_lce_id = '0;
          mshr_n.tr_way_id = '0;
        end
      endcase

      // Flags
      mshr_n.flags[e_flag_sel_pcf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];

      case (decoded_inst_i.rqf_sel)
        e_rqf_lce_req: begin
          mshr_n.flags[e_flag_sel_rqf] = lce_req.msg_type;
          mshr_n.flags[e_flag_sel_ucf] = lce_req.non_cacheable;
          mshr_n.nc_req_size           = lce_req.nc_size;
        end
        e_rqf_pending: begin
          mshr_n.flags[e_flag_sel_rqf] = '0; // TODO: v2
          mshr_n.flags[e_flag_sel_ucf] = '0;
          mshr_n.nc_req_size           = '0;
        end
        e_rqf_imm0: begin
          mshr_n.flags[e_flag_sel_rqf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.flags[e_flag_sel_ucf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.nc_req_size           = '0;
        end
        default: begin
          mshr_n.flags[e_flag_sel_rqf] = '0;
          mshr_n.flags[e_flag_sel_ucf] = '0;
          mshr_n.nc_req_size           = '0;
        end
      endcase

      case (decoded_inst_i.nerldf_sel)
        e_nerldf_lce_req: begin
          mshr_n.flags[e_flag_sel_nerf] = lce_req.non_exclusive;
          mshr_n.flags[e_flag_sel_ldf] = lce_req.lru_dirty;
        end
        e_nerldf_pending: begin
          mshr_n.flags[e_flag_sel_nerf] = '0; // TODO: v2
          mshr_n.flags[e_flag_sel_ldf] = '0; // TODO: v2
        end
        e_nerldf_imm0: begin
          mshr_n.flags[e_flag_sel_nerf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.flags[e_flag_sel_ldf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        end
        default: begin
          mshr_n.flags[e_flag_sel_nerf] = '0;
          mshr_n.flags[e_flag_sel_ldf] = '0;
        end
      endcase

      case (decoded_inst_i.nwbf_sel)
        e_nwbf_lce_data_resp: begin
          if (null_wb_flag_i == e_lce_resp_null_wb) begin
            mshr_n.flags[e_flag_sel_nwbf] = 1'b1;
          end else begin
            mshr_n.flags[e_flag_sel_nwbf] = '0;
          end
        end
        e_nwbf_imm0: begin
          mshr_n.flags[e_flag_sel_nwbf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        end
        default: begin
          mshr_n.flags[e_flag_sel_nwbf] = '0;
        end
      endcase

      case (decoded_inst_i.tf_sel)
        e_tf_logic: mshr_n.flags[e_flag_sel_tf] = gad_transfer_flag_i;
        e_tf_imm0: mshr_n.flags[e_flag_sel_tf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        default: mshr_n.flags[e_flag_sel_tf] = '0;
      endcase

      case (decoded_inst_i.pruief_sel)
        e_pruief_logic: begin
          mshr_n.flags[e_flag_sel_pf] = pending_o_i; // RDP instruction
          mshr_n.flags[e_flag_sel_rf] = gad_replacement_flag_i;
          mshr_n.flags[e_flag_sel_uf] = gad_upgrade_flag_i;
          mshr_n.flags[e_flag_sel_if] = gad_invalidate_flag_i;
          mshr_n.flags[e_flag_sel_ef] = gad_exclusive_flag_i;
          mshr_n.flags[e_flag_sel_cf] = gad_cached_flag_i;
        end
        e_pruief_imm0: begin
          mshr_n.flags[e_flag_sel_pf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.flags[e_flag_sel_rf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.flags[e_flag_sel_uf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.flags[e_flag_sel_if] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.flags[e_flag_sel_ef] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
          mshr_n.flags[e_flag_sel_cf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        end
        default: begin
          mshr_n.flags[e_flag_sel_pf] = '0;
          mshr_n.flags[e_flag_sel_rf] = '0;
          mshr_n.flags[e_flag_sel_uf] = '0;
          mshr_n.flags[e_flag_sel_if] = '0;
          mshr_n.flags[e_flag_sel_ef] = '0;
          mshr_n.flags[e_flag_sel_cf] = '0;
        end
      endcase

      case (decoded_inst_i.rwbf_sel)
        e_rwbf_imm0: mshr_n.flags[e_flag_sel_rwbf] = decoded_inst_i.imm[`bp_cce_inst_flag_imm_bit];
        default: mshr_n.flags[e_flag_sel_rwbf] = '0;
      endcase

      // Next Coh State
      //next_coh_state_n = decoded_inst_i.imm[`bp_cce_coh_bits-1:0];
      mshr_n.next_coh_state = decoded_inst_i.imm[`bp_cce_coh_bits-1:0];

      mshr_n.flags[e_flag_sel_lef] = dir_lru_cached_excl_i;

      // LRU Addr
      mshr_n.lru_paddr = {dir_lru_tag_i, mshr_r.paddr[lg_block_size_in_bytes_lp +: lg_lce_sets_lp],
                          {lg_block_size_in_bytes_lp{1'b0}}};

    end
  end // always_comb

  always_ff @(posedge clk_i)
  begin
    if (reset_i) begin
      mshr_r <= '0;
      gpr_r <= '0;
      ack_type_r <= '0;
      nc_data_r <= '0;
    end else begin
      // MSHR writes
      if (decoded_inst_i.mshr_restore) begin
        mshr_r <= mshr_n;
      end else if (decoded_inst_i.mshr_clear) begin
        mshr_r <= mshr_n;
      end else begin
        if (decoded_inst_i.req_w_v) begin
          mshr_r.lce_id <= mshr_n.lce_id;
          mshr_r.paddr <= mshr_n.paddr;
        end
        if (decoded_inst_i.req_addr_way_w_v) begin
          mshr_r.way_id <= mshr_n.way_id;
        end
        if (decoded_inst_i.lru_way_w_v) begin
          mshr_r.lru_way_id <= mshr_n.lru_way_id;
        end
        if (decoded_inst_i.transfer_lce_w_v) begin
          mshr_r.tr_lce_id <= mshr_n.tr_lce_id;
          mshr_r.tr_way_id <= mshr_n.tr_way_id;
        end
        // Flags
        for (int i = 0; i < `bp_cce_inst_num_flags; i=i+1) begin
          if (decoded_inst_i.flag_mask_w_v[i]) begin
            mshr_r.flags[i] <= mshr_n.flags[i];
          end
        end
        if (dir_lru_v_i) begin
          mshr_r.flags[e_flag_sel_lef] <= mshr_n.flags[e_flag_sel_lef];
          mshr_r.lru_paddr <= mshr_n.lru_paddr;
        end
        // Next Coh State
        if (decoded_inst_i.mov_dst_w_v & (decoded_inst_i.dst == e_dst_next_coh_state)) begin
          mshr_r.next_coh_state <= mshr_n.next_coh_state;
        end

        if (decoded_inst_i.nc_req_size_w_v) begin
          mshr_r.nc_req_size <= mshr_n.nc_req_size;
        end
      end

      // Ack Type
      if (decoded_inst_i.ack_type_w_v) begin
        ack_type_r <= ack_type_n;
      end

      // GPR
      for (int i = 0; i < `bp_cce_inst_num_gpr; i=i+1) begin
        if (decoded_inst_i.gpr_w_mask[i]) begin
          gpr_r[i] <= gpr_n[i];
        end
      end

      // Uncached data and request size
      if (decoded_inst_i.nc_data_w_v) begin
        nc_data_r <= nc_data_n;
      end
    end // else
  end // always_ff

endmodule

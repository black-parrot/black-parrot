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
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  import bp_common_cfg_link_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    // Derived parameters
    , localparam lg_num_lce_lp              = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_num_cce_lp              = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam lg_block_size_in_bytes_lp  = `BSG_SAFE_CLOG2(cce_block_width_p/8)
    , localparam lg_lce_assoc_lp            = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_lce_sets_lp             = `BSG_SAFE_CLOG2(lce_sets_p)
    , localparam tag_width_lp               =
      (paddr_width_p-lg_lce_sets_lp-lg_block_size_in_bytes_lp)
    , localparam entry_width_lp             = (tag_width_lp+`bp_coh_bits)
    , localparam tag_set_width_lp           = (entry_width_lp*lce_assoc_p)
    , localparam cfg_bus_width_lp         = `bp_cfg_bus_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)

    , localparam mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)

    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  )
  (input                                                                   clk_i
   , input                                                                 reset_i

   , input bp_cce_inst_decoded_s                                           decoded_inst_i

   , input [lce_cce_req_width_lp-1:0]                                      lce_req_i
   , input                                                                 null_wb_flag_i
   , input bp_lce_cce_resp_type_e                                          lce_resp_type_i
   , input bp_cce_mem_cmd_type_e                                           mem_resp_type_i
   , input [cce_mem_msg_width_lp-1:0]                                      mem_cmd_i

   , input [`bp_cce_inst_gpr_width-1:0]                                    alu_res_i
   , input [`bp_cce_inst_gpr_width-1:0]                                    mov_src_i

   , input                                                                 pending_o_i
   , input                                                                 pending_v_o_i

   , input                                                                 dir_lru_v_i
   , input                                                                 dir_lru_cached_excl_i
   , input [tag_width_lp-1:0]                                              dir_lru_tag_i
   , input [tag_width_lp-1:0]                                              dir_tag_i

   , input [lg_lce_assoc_lp-1:0]                                           gad_req_addr_way_i
   , input [lg_num_lce_lp-1:0]                                             gad_transfer_lce_i
   , input [lg_lce_assoc_lp-1:0]                                           gad_transfer_lce_way_i
   , input                                                                 gad_transfer_flag_i
   , input                                                                 gad_replacement_flag_i
   , input                                                                 gad_upgrade_flag_i
   , input                                                                 gad_invalidate_flag_i
   , input                                                                 gad_cached_flag_i
   , input                                                                 gad_cached_exclusive_flag_i
   , input                                                                 gad_cached_owned_flag_i
   , input                                                                 gad_cached_dirty_flag_i

   , input [cfg_bus_width_lp-1:0]                                         cfg_bus_i

   // Register value outputs
   , output logic [mshr_width_lp-1:0]                                      mshr_o

   , output logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0]   gpr_o

   , output logic [`bp_coh_bits-1:0]                                       coh_state_o

   , output logic [dword_width_p-1:0]                                      nc_data_o
  );

  wire unused = pending_v_o_i;

  // Define structure variables for input queues

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  `declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s lce_req;

  // assign input and output queues to/from structure variables
  assign lce_req = lce_req_i;

  logic uc_req;
  assign uc_req = (lce_req.msg_type == e_lce_req_type_uc_rd) | (lce_req.msg_type == e_lce_req_type_uc_wr);

  bp_cce_mem_msg_s mem_cmd;
  assign mem_cmd = mem_cmd_i;

  // Registers
  `declare_bp_cce_mshr_s(num_lce_p, lce_assoc_p, paddr_width_p);
  bp_cce_mshr_s mshr_r, mshr_n;

  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r, gpr_n;
  logic [dword_width_p-1:0] nc_data_r, nc_data_n;
  bp_coh_states_e coh_state_r, coh_state_n;

  // Output register values
  assign mshr_o = mshr_r;
  assign gpr_o = gpr_r;
  assign nc_data_o = nc_data_r;
  assign coh_state_o = coh_state_r;

  always_comb
  begin

    // GPR
    for (int i = 0; i < `bp_cce_inst_num_gpr; i=i+1) begin
      if (decoded_inst_i.alu_dst_w_v & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = alu_res_i;
      end else if (decoded_inst_i.mov_dst_w_v & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = mov_src_i;
      end else if (decoded_inst_i.resp_type_w_v & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = {'0, lce_resp_type_i};
      end else if (decoded_inst_i.mem_resp_type_w_v & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = {'0, mem_resp_type_i};
      end else if (decoded_inst_i.mem_cmd_type_w_v & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = {'0, mem_cmd.msg_type};
      end else if (decoded_inst_i.dir_r_v
                   & (decoded_inst_i.minor_op_u.dir_minor_op == e_rde_op)
                   & decoded_inst_i.gpr_w_mask[i]) begin
        gpr_n[i] = {'0, dir_tag_i} << (paddr_width_p - tag_width_lp);
      end else begin
        gpr_n[i] = '0;
      end
    end

    // Uncached data register is always sourced from LCE Request
    // Uncached data that is being returned to an LCE from a Mem Data Resp does not need
    // to be registered, and is handled by bp_cce_msg module.
    nc_data_n = lce_req.msg.uc_req.data;

    // Default coherence state
    coh_state_n = bp_coh_states_e'(mov_src_i[0+:`bp_coh_bits]);

    // MSHR

    // by default, hold mshr value
    mshr_n = mshr_r;

    // Next value for MSHR depends on whether the full MSHR is being restored (by MemResp msg),
    // cleared (by clm instruction), or being updated in pieces (lots of other instructions during
    // normal request processing).
    if (decoded_inst_i.mshr_clear) begin
      mshr_n = '0;
      mshr_n.next_coh_state = bp_coh_states_e'(coh_state_r);
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
        e_req_sel_mem_cmd: begin
          mshr_n.lce_id = mem_cmd.payload.lce_id;
          mshr_n.paddr = mem_cmd.addr;
        end
        default: begin
          mshr_n.lce_id = '0;
          mshr_n.paddr = '0;
        end
      endcase

      // Request Address Way
      mshr_n.way_id = gad_req_addr_way_i;

      // LRU Way
      case (decoded_inst_i.lru_way_sel)
        e_lru_way_sel_lce_req: begin
          mshr_n.lru_way_id = lce_req.msg.req.lru_way_id;
        end
        e_lru_way_sel_pending: begin
          mshr_n.lru_way_id = '0; // TODO: v2
        end
        default: begin
            mshr_n.lru_way_id = '0;
        end
      endcase

      // Transfer LCE and Transfer LCE Way
      mshr_n.tr_lce_id = gad_transfer_lce_i;
      mshr_n.tr_way_id = gad_transfer_lce_way_i;

      // Flags

      case (decoded_inst_i.rqf_sel)
        e_rqf_lce_req: begin
          mshr_n.flags[e_flag_sel_rqf] = lce_req.msg_type;
        end
        e_rqf_pending: begin
          mshr_n.flags[e_flag_sel_rqf] = '0; // TODO: v2
        end
        e_rqf_imm0: begin
          mshr_n.flags[e_flag_sel_rqf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_rqf] = '0;
        end
      endcase

      case (decoded_inst_i.ucf_sel)
        e_ucf_lce_req: begin
          mshr_n.flags[e_flag_sel_ucf] = uc_req;
          mshr_n.uc_req_size           = bp_lce_cce_uc_req_size_e'(lce_req.msg.uc_req.uc_size);
        end
        e_ucf_pending: begin
          mshr_n.flags[e_flag_sel_ucf] = '0;
          mshr_n.uc_req_size           = bp_lce_cce_uc_req_size_e'('0);
        end
        e_ucf_imm0: begin
          mshr_n.flags[e_flag_sel_ucf] = decoded_inst_i.imm[0];
          mshr_n.uc_req_size           = bp_lce_cce_uc_req_size_e'('0);
        end
        default: begin
          mshr_n.flags[e_flag_sel_ucf] = '0;
          mshr_n.uc_req_size           = bp_lce_cce_uc_req_size_e'('0);
        end
      endcase

      case (decoded_inst_i.nerf_sel)
        e_nerf_lce_req: begin
          mshr_n.flags[e_flag_sel_nerf] = lce_req.msg.req.non_exclusive;
        end
        e_nerf_pending: begin
          mshr_n.flags[e_flag_sel_nerf] = '0; // TODO: v2
        end
        e_nerf_imm0: begin
          mshr_n.flags[e_flag_sel_nerf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_nerf] = '0;
        end
      endcase

      case (decoded_inst_i.ldf_sel)
        e_ldf_lce_req: begin
          mshr_n.flags[e_flag_sel_ldf] = lce_req.msg.req.lru_dirty;
        end
        e_ldf_pending: begin
          mshr_n.flags[e_flag_sel_ldf] = '0; // TODO: v2
        end
        e_ldf_imm0: begin
          mshr_n.flags[e_flag_sel_ldf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_ldf] = '0;
        end
      endcase

      case (decoded_inst_i.nwbf_sel)
        e_nwbf_lce_resp: begin
          mshr_n.flags[e_flag_sel_nwbf] = null_wb_flag_i;
        end
        e_nwbf_imm0: begin
          mshr_n.flags[e_flag_sel_nwbf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_nwbf] = '0;
        end
      endcase

      case (decoded_inst_i.tf_sel)
        e_tf_logic: begin
          mshr_n.flags[e_flag_sel_tf] = gad_transfer_flag_i;
        end
        e_tf_imm0: begin
          mshr_n.flags[e_flag_sel_tf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_tf] = '0;
        end
      endcase

      case (decoded_inst_i.pf_sel)
        e_pf_logic: begin
          mshr_n.flags[e_flag_sel_pf] = pending_o_i; // RDP instruction
        end
        e_pf_imm0: begin
          mshr_n.flags[e_flag_sel_pf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_pf] = '0;
        end
      endcase
      case (decoded_inst_i.rf_sel)
        e_rf_logic: begin
          mshr_n.flags[e_flag_sel_rf] = gad_replacement_flag_i;
        end
        e_rf_imm0: begin
          mshr_n.flags[e_flag_sel_rf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_rf] = '0;
        end
      endcase
      case (decoded_inst_i.uf_sel)
        e_uf_logic: begin
          mshr_n.flags[e_flag_sel_uf] = gad_upgrade_flag_i;
        end
        e_uf_imm0: begin
          mshr_n.flags[e_flag_sel_uf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_uf] = '0;
        end
      endcase
      case (decoded_inst_i.if_sel)
        e_if_logic: begin
          mshr_n.flags[e_flag_sel_if] = gad_invalidate_flag_i;
        end
        e_if_imm0: begin
          mshr_n.flags[e_flag_sel_if] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_if] = '0;
        end
      endcase
      case (decoded_inst_i.cf_sel)
        e_cf_logic: begin
          mshr_n.flags[e_flag_sel_cf] = gad_cached_flag_i;
        end
        e_cf_imm0: begin
          mshr_n.flags[e_flag_sel_cf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_cf] = '0;
        end
      endcase
      case (decoded_inst_i.cef_sel)
        e_cef_logic: begin
          mshr_n.flags[e_flag_sel_cef] = gad_cached_exclusive_flag_i;
        end
        e_cef_imm0: begin
          mshr_n.flags[e_flag_sel_cef] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_cef] = '0;
        end
      endcase
      case (decoded_inst_i.cof_sel)
        e_cof_logic: begin
          mshr_n.flags[e_flag_sel_cof] = gad_cached_owned_flag_i;
        end
        e_cof_imm0: begin
          mshr_n.flags[e_flag_sel_cof] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_cof] = '0;
        end
      endcase
      case (decoded_inst_i.cdf_sel)
        e_cdf_logic: begin
          mshr_n.flags[e_flag_sel_cdf] = gad_cached_dirty_flag_i;
        end
        e_cdf_imm0: begin
          mshr_n.flags[e_flag_sel_cdf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_cdf] = '0;
        end
      endcase
      case (decoded_inst_i.lef_sel)
        e_lef_logic: begin
          mshr_n.flags[e_flag_sel_lef] = dir_lru_cached_excl_i;
        end
        e_lef_imm0: begin
          mshr_n.flags[e_flag_sel_lef] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_lef] = '0;
        end
      endcase
      case (decoded_inst_i.sf_sel)
        e_sf_logic: begin
          // logic select sources from speculative bit in outbound mem_cmd message
          mshr_n.flags[e_flag_sel_sf] = decoded_inst_i.spec_bits.spec;
        end
        e_sf_imm0: begin
          mshr_n.flags[e_flag_sel_sf] = decoded_inst_i.imm[0];
        end
        default: begin
          mshr_n.flags[e_flag_sel_sf] = '0;
        end
      endcase

      // Next Coh State
      mshr_n.next_coh_state = bp_coh_states_e'(decoded_inst_i.imm[`bp_coh_bits-1:0]);

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
      nc_data_r <= '0;
      coh_state_r <= bp_coh_states_e'('0);
    end else begin
      // MSHR writes
      if (decoded_inst_i.mshr_clear) begin
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
        if (decoded_inst_i.mov_dst_w_v & (decoded_inst_i.dst_sel == e_dst_sel_special)
            & (decoded_inst_i.dst.special == e_dst_next_coh_state)) begin
          mshr_r.next_coh_state <= mshr_n.next_coh_state;
        end

        if (decoded_inst_i.nc_req_size_w_v) begin
          mshr_r.uc_req_size <= mshr_n.uc_req_size;
        end
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

      if (decoded_inst_i.mov_dst_w_v & (decoded_inst_i.dst_sel == e_dst_sel_special)
          & (decoded_inst_i.dst.special == e_dst_coh_state)) begin
        coh_state_r <= coh_state_n;
      end

    end // else
  end // always_ff

endmodule

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
    , localparam block_size_in_bytes_lp    = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    , localparam mshr_width_lp = `bp_cce_mshr_width(lce_id_width_p, lce_assoc_p, paddr_width_p)

    // Interface Widths
    `declare_bp_lce_cce_if_header_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p)
    `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  )
  (input                                                                   clk_i
   , input                                                                 reset_i

   // Control signals
   , input bp_cce_inst_decoded_s                                           decoded_inst_i
   , input                                                                 dir_lru_v_i
   , input                                                                 dir_addr_v_i

   , input                                                                 stall_i

   // Data source inputs
   , input [`bp_cce_inst_gpr_width-1:0]                                    src_a_i
   , input [`bp_cce_inst_gpr_width-1:0]                                    alu_res_i

   , input [lce_cce_req_width_lp-1:0]                                      lce_req_i
   , input [lce_cce_resp_width_lp-1:0]                                     lce_resp_i
   , input [cce_mem_msg_width_lp-1:0]                                      mem_resp_i

   // For RDP, output state of pending bits from read operation
   , input                                                                 pending_i

   // From Directory - RDW operation generates LRU Cached Exclusive flag and LRU entry address
   , input bp_coh_states_e                                                 dir_lru_coh_state_i
   , input [paddr_width_p-1:0]                                             dir_lru_addr_i
   // From Directory - RDE operation writes address to GPR
   , input [paddr_width_p-1:0]                                             dir_addr_i
   , input bp_cce_inst_opd_gpr_e                                           dir_addr_dst_gpr_i

   // From GAD unit - written on GAD ucode operation
   , input [lce_assoc_width_p-1:0]                                         gad_req_addr_way_i
   , input [lce_id_width_p-1:0]                                            gad_owner_lce_i
   , input [lce_assoc_width_p-1:0]                                         gad_owner_way_i
   , input                                                                 gad_replacement_flag_i
   , input                                                                 gad_upgrade_flag_i
   , input                                                                 gad_cached_shared_flag_i
   , input                                                                 gad_cached_exclusive_flag_i
   , input                                                                 gad_cached_modified_flag_i
   , input                                                                 gad_cached_owned_flag_i
   , input                                                                 gad_cached_forward_flag_i

   , input                                                                 spec_sf_i

   // Register outputs
   , output logic [mshr_width_lp-1:0]                                      mshr_o
   , output logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0]   gpr_o
   , output bp_coh_states_e                                                coh_state_o
   , output logic                                                          auto_fwd_msg_o

  );


  // Interface Structs
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  bp_lce_cce_req_s  lce_req;
  bp_lce_cce_resp_s lce_resp;
  bp_cce_mem_msg_s  mem_resp;

  assign lce_req  = lce_req_i;
  assign lce_resp = lce_resp_i;
  assign mem_resp = mem_resp_i;

  // Registers
  `declare_bp_cce_mshr_s(lce_id_width_p, lce_assoc_p, paddr_width_p);

  bp_cce_mshr_s                                                mshr_r, mshr_n;
  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r;
  logic [`bp_cce_inst_gpr_width-1:0]                           gpr_next;
  bp_coh_states_e                                              coh_state_r, coh_state_n;
  logic                                                        auto_fwd_msg_r, auto_fwd_msg_n;

  assign mshr_o         = mshr_r;
  assign gpr_o          = gpr_r;
  assign coh_state_o    = coh_state_r;
  assign auto_fwd_msg_o = auto_fwd_msg_r;

  // Write mask for GPRs
  // This is by default the write mask from the decoded instruction, but it is also modified
  // by the Directory on RDE operation to indicate which GPR the address from RDE is written to.
  // On a stall, the mask is set to '0 by default.
  logic [`bp_cce_inst_num_gpr-1:0]                             gpr_w_mask;

  // Move operation
  wire mov_op        = (decoded_inst_i.op == e_op_reg_data);
  // Queue operation
  wire queue_op      = (decoded_inst_i.op == e_op_queue);

  // Flag next values
  wire lce_req_rqf   = (lce_req.header.msg_type == e_lce_req_type_wr)
                       | (lce_req.header.msg_type == e_lce_req_type_uc_wr);
  wire lce_req_ucf   = (lce_req.header.msg_type == e_lce_req_type_uc_rd)
                       | (lce_req.header.msg_type == e_lce_req_type_uc_wr);
  wire lce_resp_nwbf = (lce_resp.header.msg_type == e_lce_cce_resp_null_wb);
  wire lce_req_nerf  = (lce_req.header.non_exclusive == e_lce_req_non_excl);

  // operation writes all flags in bulk
  wire write_all_flags = ((decoded_inst_i.dst_sel == e_dst_sel_special)
                          & (decoded_inst_i.dst.special == e_opd_flags));

  // Combinational Logic - next values for registers and write masks
  always_comb begin
    // Default next values
    // Note: whether the next value is written to the register depends on the
    // write enable decisions in the sequential logic
    mshr_n = mshr_r;
    gpr_next = '0;

    // Auto Forward BP Coherence Messages
    auto_fwd_msg_n = src_a_i[0];

    // Default Coherence State Register
    coh_state_n = bp_coh_states_e'(src_a_i[0+:$bits(bp_coh_states_e)]);

    // GPR Write Mask
    gpr_w_mask = stall_i ? '0 : decoded_inst_i.gpr_w_v;
    // RDE operation sets write mask bit for proper GPR destination
    // this write only happens when ucode is stalling
    if (dir_addr_v_i) begin
      gpr_w_mask[dir_addr_dst_gpr_i[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;
    end

    // GPRs
    // By default, use the result from the ALU (ALU ops, Flag ALU ops)
    gpr_next = alu_res_i;
    // Directory read operation (while stalling) takes priority over the stalling instruction's
    // decoding for gpr_next. If the stalling instruction is a move, but a directory read is
    // happening, we want the directory read to determine the source, not the stalling move.
    if (dir_addr_v_i) begin
      gpr_next = {'0, dir_addr_i};
    // Move (including set flag) and queue ops use source A
    end else if (mov_op | queue_op) begin
      gpr_next = src_a_i;
    end

    // MSHR
    if (decoded_inst_i.mshr_clear) begin
      mshr_n = '0;
      mshr_n.next_coh_state = coh_state_r;
    end else begin
      // default to catch any unset fields
      mshr_n = mshr_r;

      // LCE ID - from lce_req, lce_resp, mem_resp.payload, or move
      // paddr - from lce_req, lce_resp, mem_resp, or move
      // LRU Way ID - from lce_req or move
      // Next Coh State - from move or mem_resp.payload
      // UC Req Size - from lce_req or move
      // Data Length - from lce_req, lce_resp, or move
      // Way ID - from move, GAD, or mem_resp
      // Owner LCE ID - from GAD or move
      // Owner Way ID - from GAD or move
      // LRU paddr - from Directory or move
      mshr_n.lce_id = src_a_i[0+:lce_id_width_p];
      mshr_n.paddr = src_a_i[0+:paddr_width_p];
      mshr_n.lru_way_id = src_a_i[0+:lce_assoc_width_p];
      mshr_n.next_coh_state = bp_coh_states_e'(src_a_i[0+:$bits(bp_coh_states_e)]);
      mshr_n.lru_coh_state = bp_coh_states_e'(src_a_i[0+:$bits(bp_coh_states_e)]);
      mshr_n.msg_size = bp_mem_msg_size_e'(src_a_i[0+:$bits(bp_mem_msg_size_e)]);
      mshr_n.way_id = src_a_i[0+:lce_id_width_p];
      mshr_n.owner_lce_id = src_a_i[0+:lce_id_width_p];
      mshr_n.owner_way_id = src_a_i[0+:lce_assoc_width_p];
      mshr_n.lru_paddr = src_a_i[0+:paddr_width_p];

      // Flags - by default, next value comes from src_a
      for (int i = 0; i < `bp_cce_inst_num_flags; i=i+1) begin
        mshr_n.flags[i] = src_a_i[0];
      end

      // Overrides from defaults - poph
      if (decoded_inst_i.poph) begin
        unique case (decoded_inst_i.popq_qsel)
          e_src_q_sel_lce_req: begin
            mshr_n.lce_id = lce_req.header.src_id;
            mshr_n.paddr = lce_req.header.addr;
            mshr_n.lru_way_id = lce_req.header.lru_way_id;
            mshr_n.msg_size = lce_req.header.size;
            mshr_n.flags[e_opd_rqf] = lce_req_rqf;
            mshr_n.flags[e_opd_ucf] = lce_req_ucf;
            mshr_n.flags[e_opd_nerf] = lce_req_nerf;
          end
          e_src_q_sel_lce_resp: begin
            //mshr_n.lce_id = lce_resp.header.src_id;
            //mshr_n.paddr = lce_resp.header.addr;
            //mshr_n.msg_size = lce_resp.header.size;
            mshr_n.flags[e_opd_nwbf] = lce_resp_nwbf;
          end
          e_src_q_sel_mem_resp: begin
            //mshr_n.lce_id = mem_resp.header.payload.lce_id;
            //mshr_n.way_id = mem_resp.header.payload.way_id;
            //mshr_n.paddr = mem_resp.header.addr;
            //mshr_n.next_coh_state = mem_resp.header.payload.state;
            //mshr_n.msg_size = mem_resp.header.size;
            mshr_n.flags[e_opd_sf] = mem_resp.header.payload.speculative;
          end
          default: begin
          end
        endcase
      end // poph

      // Overrides from defaults - GAD
      else if (decoded_inst_i.gad_v) begin
        mshr_n.way_id = gad_req_addr_way_i;
        mshr_n.owner_lce_id = gad_owner_lce_i;
        mshr_n.owner_way_id = gad_owner_way_i;
        mshr_n.flags[e_opd_rf] = gad_replacement_flag_i;
        mshr_n.flags[e_opd_uf] = gad_upgrade_flag_i;
        mshr_n.flags[e_opd_csf] = gad_cached_shared_flag_i;
        mshr_n.flags[e_opd_cef] = gad_cached_exclusive_flag_i;
        mshr_n.flags[e_opd_cmf] = gad_cached_modified_flag_i;
        mshr_n.flags[e_opd_cof] = gad_cached_owned_flag_i;
        mshr_n.flags[e_opd_cff] = gad_cached_forward_flag_i;
      end

      // Overrides from defaults - Directory
      if (dir_lru_v_i) begin
        mshr_n.lru_paddr = dir_lru_addr_i;
        mshr_n.lru_coh_state = dir_lru_coh_state_i;
      end

      // RDP instruction writes pending flag
      if (decoded_inst_i.pending_r_v) begin
        mshr_n.flags[e_opd_pf] = pending_i;
      end

      // Spec Bits Read
      if (decoded_inst_i.spec_r_v) begin
        mshr_n.flags[e_opd_sf] = spec_sf_i;
      end

      // Flag operation - ldflags, ldflagsi, or clf
      if (write_all_flags) begin
        mshr_n.flags = src_a_i[0+:`bp_cce_inst_num_flags];
      end

    end // MSHR

  end // always_comb

  // Sequential Logic - register state updates
  always_ff @(posedge clk_i)
  begin
    if (reset_i) begin
      mshr_r <= '0;
      gpr_r <= '0;
      coh_state_r <= e_COH_I;
      auto_fwd_msg_r <= 1'b1;
    end else begin

      // Auto Forward Message control - only from move, only when not stalling
      if (~stall_i & decoded_inst_i.auto_fwd_msg_w_v) begin
        auto_fwd_msg_r <= auto_fwd_msg_n;
      end

      // Default Coherence State for MSHR - only from move, only when not stalling
      if (~stall_i & decoded_inst_i.coh_state_w_v) begin
        coh_state_r <= coh_state_n;
      end

      // GPR
      for (int i = 0; i < `bp_cce_inst_num_gpr; i=i+1) begin
        if (gpr_w_mask[i]) begin
          gpr_r[i] <= gpr_next;
        end
      end

      // MSHR writes - these occur on a per MSHR item basis
      // By default, all fields can only be written while not stalling

      if (~stall_i & decoded_inst_i.mshr_clear) begin
        mshr_r <= mshr_n;
      end else begin
        if (~stall_i & decoded_inst_i.lce_w_v) begin
          mshr_r.lce_id <= mshr_n.lce_id;
        end
        if (~stall_i & decoded_inst_i.addr_w_v) begin
          mshr_r.paddr <= mshr_n.paddr;
        end
        if (~stall_i & decoded_inst_i.way_w_v) begin
          mshr_r.way_id <= mshr_n.way_id;
        end
        if (~stall_i & decoded_inst_i.lru_way_w_v) begin
          mshr_r.lru_way_id <= mshr_n.lru_way_id;
        end
        // LRU address can be written while stalling, from directory
        if ((~stall_i & decoded_inst_i.lru_addr_w_v) | dir_lru_v_i) begin
          mshr_r.lru_paddr <= mshr_n.lru_paddr;
        end
        if ((~stall_i & decoded_inst_i.lru_coh_state_w_v) | dir_lru_v_i) begin
          mshr_r.lru_coh_state <= mshr_n.lru_coh_state;
        end
        if (~stall_i & decoded_inst_i.owner_lce_w_v) begin
          mshr_r.owner_lce_id <= mshr_n.owner_lce_id;
        end
        if (~stall_i & decoded_inst_i.owner_way_w_v) begin
          mshr_r.owner_way_id <= mshr_n.owner_way_id;
        end
        if (~stall_i & decoded_inst_i.next_coh_state_w_v) begin
          mshr_r.next_coh_state <= mshr_n.next_coh_state;
        end
        for (int i = 0; i < `bp_cce_inst_num_flags; i=i+1) begin
          if (~stall_i & decoded_inst_i.flag_w_v[i]) begin
            mshr_r.flags[i] <= mshr_n.flags[i];
          end
        end
        if (~stall_i & decoded_inst_i.msg_size_w_v) begin
          mshr_r.msg_size <= mshr_n.msg_size;
        end
      end

    end // else
  end // always_ff

endmodule

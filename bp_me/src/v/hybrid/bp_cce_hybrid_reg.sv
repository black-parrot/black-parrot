/**
 *
 * Name:
 *   bp_cce_hybrid_reg.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_reg
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp    = (bedrock_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    , localparam mshr_width_lp = `bp_cce_mshr_width(paddr_width_p, lce_id_width_p, cce_width_p, did_width_p, lce_assoc_p)

    // Interface Widths
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

  )
  (input                                                                   clk_i
   , input                                                                 reset_i

   // Control signals
   , input bp_cce_inst_decoded_s                                           decoded_inst_i

   , input                                                                 stall_i

   // Data source inputs
   , input [`bp_cce_inst_gpr_width-1:0]                                    src_a_i
   , input [`bp_cce_inst_gpr_width-1:0]                                    alu_res_i

   , input [lce_req_header_width_lp-1:0]                                   lce_req_header_i
   , input                                                                 lce_req_v_i

   // Register outputs
   , output logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0]   gpr_o
  );


  // Interface Structs
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  bp_bedrock_lce_req_header_s  lce_req_hdr;
  assign lce_req_hdr  = lce_req_header_i;

  // Registers
  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_r;
  logic [`bp_cce_inst_gpr_width-1:0]                           gpr_next;

  assign gpr_o          = gpr_r;

  // Write mask for GPRs
  // This is by default the write mask from the decoded instruction, but it is also modified
  // by the Directory on RDE operation to indicate which GPR the address from RDE is written to.
  // On a stall, the mask is set to '0 by default.
  logic [`bp_cce_inst_num_gpr-1:0]                             gpr_w_mask;

  // Move operation
  wire mov_op        = (decoded_inst_i.op == e_op_reg_data);
  // Queue operation
  wire queue_op      = (decoded_inst_i.op == e_op_queue);

  // Combinational Logic - next values for registers and write masks
  always_comb begin
    // Default next values
    // Note: whether the next value is written to the register depends on the
    // write enable decisions in the sequential logic
    gpr_next = '0;

    // GPR Write Mask
    gpr_w_mask = stall_i ? '0 : decoded_inst_i.gpr_w_v;

    // GPRs
    // By default, use the result from the ALU (ALU ops, Flag ALU ops)
    gpr_next = alu_res_i;
    // Move (including set flag) and queue ops use source A
    if (mov_op | queue_op) begin
      gpr_next = src_a_i;
    end

  end // always_comb

  // Sequential Logic - register state updates
  always_ff @(posedge clk_i)
  begin
    if (reset_i) begin
      gpr_r <= '0;
    end else begin

      // GPR
      for (int i = 0; i < `bp_cce_inst_num_gpr; i=i+1) begin
        if (gpr_w_mask[i]) begin
          gpr_r[i] <= gpr_next;
        end
      end
    end // else
  end // always_ff

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_hybrid_reg)

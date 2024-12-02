/**
 *
 * Name:
 *   bp_cce_hybrid_prog_pipe.sv
 *
 * Description:
 *   Programmable pipeline that is hooked to coherent request pipeline
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_prog_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter header_fifo_els_p          = 2

    // interface width
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // Config channel
   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   // control
   , input bp_cce_mode_e                            cce_mode_i
   , input [cce_id_width_p-1:0]                     cce_id_i
   , output logic                                   empty_o

   // ucode programming interface, synchronous read, direct connection to RAM
   , input                                          ucode_v_i
   , input                                          ucode_w_i
   , input [cce_pc_width_p-1:0]                     ucode_addr_i
   , input [cce_instr_width_gp-1:0]                 ucode_data_i
   , output logic [cce_instr_width_gp-1:0]          ucode_data_o

   // LCE request header
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_v_i
   , output logic                                   lce_req_ready_and_o

   // response to coherent pipeline
   , output logic                                   prog_v_o
   , input                                          prog_yumi_i
   , output logic                                   prog_status_o // 1 = okay, 0 = squash
   );

  // Define structure variables for output queues
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);

  // Header Buffer
  logic lce_req_v_li, lce_req_yumi_lo;
  bp_bedrock_lce_req_header_s  lce_req_header_li;
  bsg_fifo_1r1w_small
    #(.width_p(lce_req_header_width_lp)
      ,.els_p(header_fifo_els_p)
      ,.ready_THEN_valid_p(0)
      )
    header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      ,.v_i(lce_req_v_i)
      ,.ready_param_o(lce_req_ready_and_o)
      ,.data_i(lce_req_header_cast_i)
      // output
      ,.v_o(lce_req_v_li)
      ,.yumi_i(lce_req_yumi_lo)
      ,.data_o(lce_req_header_li)
      );

  // From Fetch to Execute/Pre-Decode
  logic [cce_pc_width_p-1:0]           fetch_pc_lo;
  bp_cce_inst_s                        fetch_inst_lo;
  logic                                fetch_inst_v_lo;

  // From Predecode to Fetch
  logic [cce_pc_width_p-1:0]           predicted_fetch_pc_lo;

  // From Decoder to rest of Execute
  bp_cce_inst_decoded_s                decoded_inst_lo;
  logic [cce_pc_width_p-1:0]           ex_pc_lo;

  // From Execute to Fetch/Decode
  logic [cce_pc_width_p-1:0]           branch_resolution_pc_lo;
  logic                                stall_lo, mispredict_lo;

  // From ALU
  logic [`bp_cce_inst_gpr_width-1:0]   alu_res_lo;

  // From Source Selector to Execute
  logic [`bp_cce_inst_gpr_width-1:0]   src_a, src_b;

  // From Register File
  logic [`bp_cce_inst_num_gpr-1:0][`bp_cce_inst_gpr_width-1:0] gpr_lo;


  /*
   * Fetch Stage
   */

  // ucode RAM
  bp_cce_hybrid_inst_ram
    #(.bp_params_p(bp_params_p)
      )
    inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cfg_bus_i(cfg_bus_i)

      ,.ucode_v_i(ucode_v_i)
      ,.ucode_w_i(ucode_w_i)
      ,.ucode_addr_i(ucode_addr_i)
      ,.ucode_data_i(ucode_data_i)
      ,.ucode_data_o(ucode_data_o)

      ,.predicted_fetch_pc_i(predicted_fetch_pc_lo)
      ,.branch_resolution_pc_i(branch_resolution_pc_lo)
      ,.stall_i(stall_lo)
      ,.mispredict_i(mispredict_lo)
      ,.fetch_pc_o(fetch_pc_lo)
      ,.inst_o(fetch_inst_lo)
      ,.inst_v_o(fetch_inst_v_lo)
      );

  // instruction pre-decode
  bp_cce_hybrid_inst_predecode
    #(.width_p(cce_pc_width_p)
      )
    inst_predecode
     (.inst_i(fetch_inst_lo)
      ,.pc_i(fetch_pc_lo)
      ,.predicted_next_pc_o(predicted_fetch_pc_lo)
      );

  /*
   * Decode/Execute Stage
   */

  // Instruction Decode
  bp_cce_hybrid_inst_decode
   #(.cce_pc_width_p(cce_pc_width_p))
    inst_decode
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.inst_i(fetch_inst_lo)
      ,.pc_i(fetch_pc_lo)
      ,.inst_v_i(fetch_inst_v_lo)
      ,.stall_i(stall_lo)
      ,.mispredict_i(mispredict_lo)
      ,.decoded_inst_o(decoded_inst_lo)
      ,.pc_o(ex_pc_lo)
      );

  // ALU
  bp_cce_hybrid_alu
    #(.width_p(`bp_cce_inst_gpr_width)
      )
    alu
     (.opd_a_i(src_a)
      ,.opd_b_i(src_b)
      ,.alu_op_i(decoded_inst_lo.alu_op)
      ,.res_o(alu_res_lo)
      );

  // Branch Unit
  bp_cce_hybrid_branch
    #(.width_p(`bp_cce_inst_gpr_width)
      ,.cce_pc_width_p(cce_pc_width_p)
      )
    branch
     (.opd_a_i(src_a)
      ,.opd_b_i(src_b)
      ,.branch_i(decoded_inst_lo.branch)
      ,.predicted_taken_i(decoded_inst_lo.predict_taken)
      ,.branch_op_i(decoded_inst_lo.branch_op)
      ,.execute_pc_i(ex_pc_lo)
      ,.branch_target_i(decoded_inst_lo.branch_target[0+:cce_pc_width_p])
      ,.mispredict_o(mispredict_lo)
      ,.pc_o(branch_resolution_pc_lo)
      );

  // Source Select
  bp_cce_hybrid_src_sel
   #(.bp_params_p(bp_params_p))
    source_selector
     (.src_a_sel_i(decoded_inst_lo.src_a_sel)
      ,.src_a_i(decoded_inst_lo.src_a)
      ,.src_b_sel_i(decoded_inst_lo.src_b_sel)
      ,.src_b_i(decoded_inst_lo.src_b)
      ,.cfg_bus_i(cfg_bus_i)
      ,.gpr_i(gpr_lo)
      ,.imm_i(decoded_inst_lo.imm)
      ,.lce_req_v_i(lce_req_v_li)
      ,.lce_req_header_i(lce_req_header_li)
      ,.src_a_o(src_a)
      ,.src_b_o(src_b)
      );

  // Register File
  bp_cce_hybrid_reg
    #(.bp_params_p(bp_params_p)
      )
    registers
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.decoded_inst_i(decoded_inst_lo)
      ,.stall_i(stall_lo)
      ,.src_a_i(src_a)
      ,.alu_res_i(alu_res_lo)
      ,.lce_req_header_i(lce_req_header_li)
      ,.lce_req_v_i(lce_req_v_li)
      // register state outputs
      ,.gpr_o(gpr_lo)
      );


  // Instruction Stall
  bp_cce_hybrid_inst_stall
    #()
    inst_stall
     (.decoded_inst_i(decoded_inst_lo)
      ,.lce_req_v_i(lce_req_v_li)
      ,.stall_o(stall_lo)
      );

  typedef enum logic [4:0] {
    e_reset
    ,e_ready
    ,e_send_status
    ,e_error
  } state_e;

  state_e state_r, state_n;

  always_comb begin
    empty_o = 1'b1;

    state_n = state_r;

    // STUB
    lce_req_yumi_lo = lce_req_v_li;
    prog_v_o = gpr_lo[0][0];
    prog_status_o = gpr_lo[0][0];

    /*
    // LCE request
    lce_req_yumi_lo = '0;

    prog_v_o = 1'b0;
    prog_status_o = 1'b1;

    case (state_r)
      e_reset: begin
        state_n = e_ready;
      end // e_reset

      e_ready: begin
        lce_req_yumi_lo = lce_req_v_li;
        state_n = (lce_req_yumi_lo) ? e_send_status : state_r;
      end // e_ready

      e_send_status: begin
        prog_v_o = 1'b1;
        prog_status_o = 1'b1;
        state_n = (prog_yumi_i) ? e_ready : state_r;
      end // e_send_status

      e_error: begin
        state_n = e_error;
      end // e_error

      default: begin
        // use defaults above
      end

    endcase
    */
  end // always_comb

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
    end else begin
      state_r <= state_n;
    end
  end

endmodule

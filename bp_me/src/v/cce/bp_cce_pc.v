/**
 *
 * Name:
 *   bp_cce_pc.v
 *
 * Description:
 *   PC register, next PC logic, and instruction memory
 *
 */

`include "bp_common_me_if.vh"
`include "bp_cce_inst_pkg.v"

module bp_cce_pc
  import bp_cce_inst_pkg::*;
  #(parameter num_cce_inst_ram_els_p    = "inv"

    // Default parameters
    ,parameter harden_p                 = 0

    // Derived parameters
    ,localparam inst_width_lp           = `bp_cce_inst_width
    ,localparam inst_ram_addr_width_lp  = `BSG_SAFE_CLOG2(num_cce_inst_ram_els_p)
  )
  (input                                        clk_i
   ,input                                       reset_i

   // ALU branch result signal
   ,input                                       alu_branch_res_i

   // input queue valid signals
   ,input                                       lce_req_v_i
   ,input                                       lce_resp_v_i
   ,input                                       lce_data_resp_v_i
   ,input                                       mem_resp_v_i
   ,input                                       mem_data_resp_v_i
   ,input                                       pending_v_i

   // output queue ready_i signals
   ,input                                       lce_cmd_ready_i
   ,input                                       lce_data_cmd_ready_i
   ,input                                       mem_cmd_ready_i
   ,input                                       mem_data_cmd_ready_i

   // instruction output to decode
   ,output logic [inst_width_lp-1:0]            inst_o
   ,output logic                                inst_v_o
  );

  // Combination logic signals
  logic [`bp_cce_num_src_q-1:0] wfq_v_vec;
  logic [`bp_cce_num_src_q-1:0] wfq_mask;
  bp_cce_inst_dst_q_sel_e pushq_qsel;
  logic pushq_op;
  logic wfq_op;
  logic wfq_q_ready;
  logic stall_op;
  logic pc_stall;
  logic [inst_ram_addr_width_lp-1:0] branch_target;


  // PC Register
  logic [inst_ram_addr_width_lp-1:0] pc_r, pc_n;
  logic pc_v;

  // PC register update
  always_ff @(posedge clk_i)
  begin
    if (reset_i)
      pc_r <= 0;
    else if (!pc_stall)
      pc_r <= pc_n;
  end

  // TODO: make ROM a 1RW RAM
  bp_cce_inst_s inst;
  logic [inst_width_lp-1:0] inst_mem_data_o;
  bp_cce_inst_rom
    #(.width_p(inst_width_lp)
      ,.addr_width_p(inst_ram_addr_width_lp)
     )
  inst_rom
    (.addr_i(pc_r)
     ,.data_o(inst_mem_data_o)
    );

  // Next PC combinational logic
  always_comb
  begin
    pc_v = ~reset_i;

    if (reset_i) begin
      inst = '0;
      inst_o = '0;
    end else begin
      inst = inst_mem_data_o;
      inst_o = inst_mem_data_o;
    end
    inst_v_o = ~reset_i;

    pushq_op = (inst.op == e_op_queue) && (inst.minor_op == e_pushq_op);
    pushq_qsel =
      bp_cce_inst_dst_q_sel_e'(
        inst.imm[`bp_cce_lce_cmd_type_width +: `bp_cce_inst_dst_q_sel_width]
      );
    wfq_op = (inst.op == e_op_queue) && (inst.minor_op == e_wfq_op);
    stall_op = (inst.op == e_op_misc) && (inst.minor_op == e_stall_op);

    // vector of input queue valid signals
    wfq_v_vec = {lce_req_v_i, lce_resp_v_i, lce_data_resp_v_i, mem_resp_v_i, mem_data_resp_v_i,
                 pending_v_i};
    // WFQ mask from instruction immediate
    wfq_mask = inst.imm[`bp_cce_num_src_q-1:0];

    // wfq_q_ready is high if any of the selected queues in the mask are ready
    // wfq_q_ready is low if none of the selected queues in the mask are ready
    wfq_q_ready = |(wfq_mask & wfq_v_vec);

    // stall PC if WFQ instruction and none of the target queues are ready
    pc_stall = stall_op | (wfq_op & ~wfq_q_ready);

    // stall PC if PUSHQ instruction and target output queue is not ready for data
    if (pushq_op) begin
    case (pushq_qsel)
      e_dst_q_lce_cmd: pc_stall |= ~lce_cmd_ready_i;
      e_dst_q_lce_data_cmd: pc_stall |= ~lce_data_cmd_ready_i;
      e_dst_q_mem_cmd: pc_stall |= ~mem_cmd_ready_i;
      e_dst_q_mem_data_cmd: pc_stall |= ~mem_data_cmd_ready_i;
      default: pc_stall = pc_stall;
    endcase
    end

    // Next PC computation
    branch_target = inst.imm[inst_ram_addr_width_lp-1:0];
    pc_n = alu_branch_res_i ? branch_target : (pc_r + 1);

  end


endmodule

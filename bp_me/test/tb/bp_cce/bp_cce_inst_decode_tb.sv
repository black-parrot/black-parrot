`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_inst_decode_tb;
  import bp_common_pkg::*;
  import bp_me_pkg::*;

  localparam int cce_pc_width_lp = 6;

  logic clk, reset;
  bp_cce_inst_s inst_i;
  logic [cce_pc_width_lp-1:0] pc_i;
  logic inst_v_i;
  logic stall_i;
  logic mispredict_i;

  bp_cce_inst_decoded_s decoded_inst_o;
  logic [cce_pc_width_lp-1:0] pc_o;

  int unsigned failures;

  bp_cce_inst_decode
    #(.cce_pc_width_p(cce_pc_width_lp))
  dut
    (.clk_i(clk)
     ,.reset_i(reset)
     ,.inst_i(inst_i)
     ,.pc_i(pc_i)
     ,.inst_v_i(inst_v_i)
     ,.stall_i(stall_i)
     ,.mispredict_i(mispredict_i)
     ,.decoded_inst_o(decoded_inst_o)
     ,.pc_o(pc_o)
     );

  always #5 clk = ~clk;

  task automatic push_and_decode(input bp_cce_inst_s inst);
    begin
      inst_i = inst;
      inst_v_i = 1'b1;
      pc_i = pc_i + 1'b1;
      @(posedge clk);
      #1;
    end
  endtask

  task automatic check_expect(input logic cond, input string msg);
    begin
      if (!cond) begin
        failures = failures + 1;
        $error("[bp_cce_inst_decode_tb] %s", msg);
      end
    end
  endtask

  initial begin
    logic [`bp_cce_inst_num_gpr-1:0] r1_mask;
    bp_cce_inst_s inst;

    clk = 1'b0;
    reset = 1'b1;
    inst_i = '0;
    pc_i = '0;
    inst_v_i = 1'b0;
    stall_i = 1'b0;
    mispredict_i = 1'b0;
    failures = 0;

    repeat (2) @(posedge clk);
    reset = 1'b0;

    r1_mask = '0;
    r1_mask[e_opd_r1[0+:`bp_cce_inst_gpr_sel_width]] = 1'b1;

    // 1) popq pending must assert pending_yumi.
    inst = '0;
    inst.op = e_op_queue;
    inst.minor_op_u.queue_minor_op = e_popq_op;
    inst.type_u.popq.src_q = e_src_q_sel_pending;
    push_and_decode(inst);

    check_expect(decoded_inst_o.v, "decoded instruction should be valid for popq pending");
    check_expect(decoded_inst_o.popq, "popq should be asserted");
    check_expect(decoded_inst_o.pending_yumi, "pending_yumi must assert for popq pending");
    check_expect(decoded_inst_o.popq_qsel == e_src_q_sel_pending, "popq queue select should be pending");

    // 2) popd pending must not perform a data pop/GPR write.
    inst = '0;
    inst.op = e_op_queue;
    inst.minor_op_u.queue_minor_op = e_popd_op;
    inst.type_u.popq.src_q = e_src_q_sel_pending;
    inst.type_u.popq.dst = e_opd_r1;
    push_and_decode(inst);

    check_expect(decoded_inst_o.v, "decoded instruction should be valid for popd pending");
    check_expect(!decoded_inst_o.popd, "popd must remain deasserted for pending queue");
    check_expect(decoded_inst_o.gpr_w_v == '0, "no GPR write should occur for popd pending");

    // 3) positive control: popd lce_resp should pop and write selected GPR.
    inst = '0;
    inst.op = e_op_queue;
    inst.minor_op_u.queue_minor_op = e_popd_op;
    inst.type_u.popq.src_q = e_src_q_sel_lce_resp;
    inst.type_u.popq.dst = e_opd_r1;
    push_and_decode(inst);

    check_expect(decoded_inst_o.v, "decoded instruction should be valid for popd lce_resp");
    check_expect(decoded_inst_o.popd, "popd should assert for lce_resp");
    check_expect(decoded_inst_o.gpr_w_v == r1_mask, "popd lce_resp should only write destination GPR");
    check_expect(decoded_inst_o.src_a.q == e_opd_lce_resp_data, "popd lce_resp should select lce_resp data source");

    if (failures == 0) begin
      $display("[bp_cce_inst_decode_tb] PASS");
    end else begin
      $fatal(1, "[bp_cce_inst_decode_tb] FAIL (%0d checks failed)", failures);
    end

    $finish;
  end

endmodule

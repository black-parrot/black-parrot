
module bp_nonsynth_cosim
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_rv64_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    )
   (input                                     clk_i
    , input                                   reset_i
    , input                                   en_i

    , input [`BSG_SAFE_CLOG2(num_core_p)-1:0] mhartid_i
    , input [63:0]                            config_file_i

    , input                                   commit_v_i
    , input [vaddr_width_p-1:0]               commit_pc_i
    , input [instr_width_p-1:0]               commit_instr_i
    , input                                   rd_w_v_i
    , input [rv64_reg_addr_width_gp-1:0]      rd_addr_i
    , input [dword_width_p-1:0]               rd_data_i
    , input                                   interrupt_v_i
    , input [dword_width_p-1:0]               cause_i
    );

import "DPI-C" context function void init_dromajo(string cfg_f_name);
import "DPI-C" context function void dromajo_step(int      hart_id,
                                                  longint pc,
                                                  int insn,
                                                  longint wdata);
import "DPI-C" context function void dromajo_trap(int hart_id, longint cause);

always_ff @(negedge reset_i)
  if (en_i)
    begin
      $display("Running with Dromajo cosimulation");
      init_dromajo(config_file_i);
    end

  logic                     commit_v_r;
  logic [vaddr_width_p-1:0] commit_pc_r;
  logic [instr_width_p-1:0] commit_instr_r;
  bsg_dff_chain
   #(.width_p(1+vaddr_width_p+instr_width_p), .num_stages_p(2))
   commit__reg
    (.clk_i(clk_i)
     ,.data_i({commit_v_i, commit_pc_i, commit_instr_i})
     ,.data_o({commit_v_r, commit_pc_r, commit_instr_r})
     );
     
  logic                     interrupt_v_r;
  logic [dword_width_p-1:0] cause_r;
  bsg_dff_chain
   #(.width_p(1+dword_width_p), .num_stages_p(2))
   trap__reg
    (.clk_i(clk_i)
     ,.data_i({interrupt_v_i, cause_i})
     ,.data_o({interrupt_v_r, cause_r})
     );

  always_ff @(negedge clk_i) begin
    if(en_i) begin
      if(interrupt_v_r) begin
        dromajo_trap(mhartid_i, cause_r);
      end
      else if (commit_v_r & commit_pc_r != '0) begin
        dromajo_step(mhartid_i, 64'($signed(commit_pc_r)), commit_instr_r, rd_data_i);
      end
    end
  end

endmodule


/**
 *
 * Name:
 *   bp_cce_pc.v
 *
 * Description:
 *   PC register, next PC logic, and instruction memory
 *
 */

module bp_cce_pc
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter inst_ram_els_p     = "inv"

    // Default parameters
    , parameter harden_p                 = 0

    // Derived parameters
    , localparam inst_width_lp           = `bp_cce_inst_width
    , localparam inst_ram_addr_width_lp  = `BSG_SAFE_CLOG2(inst_ram_els_p)
  )
  (input                                         clk_i
   , input                                       reset_i

   // ALU branch result signal
   , input                                       alu_branch_res_i

   // control from decode
   , input                                       pc_stall_i
   , input [inst_ram_addr_width_lp-1:0]          pc_branch_target_i

   // instruction output to decode
   , output logic [inst_width_lp-1:0]            inst_o
   , output logic                                inst_v_o
  );

  // PC Register
  logic [inst_ram_addr_width_lp-1:0] pc_r, pc_n;
  logic pc_v;

  // PC register update
  always_ff @(posedge clk_i)
  begin
    if (reset_i)
      pc_r <= 0;
    else if (!pc_stall_i)
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

    pc_n = alu_branch_res_i ? pc_branch_target_i : (pc_r + 1);

  end


endmodule

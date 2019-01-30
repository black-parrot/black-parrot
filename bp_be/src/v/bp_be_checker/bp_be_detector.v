/**
 *
 * Name:
 *   bp_be_detector.v
 * 
 * Description:
 *   Schedules instruction issue from the FE queue to the Calculator.
 *
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''
 * 
 * Inputs:
 *   clk_i                       -
 *   reset_i                     -
 *   
 *   calc_status_i               - Instruction dependency information from the calculator
 *   expected_npc_i              - The expected next pc, considering branching information
 *   mmu_cmd_rdy_i               - MMU ready, used as structural hazard detection for mem instrs
 *
 * Outputs:
 *   chk_dispatch_v_o            - Dispatch signal to the calculator. Since the pipes are 
 *                                   non-blocking, this signal indicates that there will be no
 *                                   hazards from this point on
 *   chk_roll_o                  - Roll back all the instructions in the pipe
 *   chk_psn_isd_o               - Poison the instruction currently in ISD stage
 *   chk_psn_ex_o                - Poison all instructions currently in the pipe
 *   
 * Keywords:
 *   detector, hazard, dependencies, stall
 * 
 * Notes:
 *   We don't need the entirety of the calc_status structure here, but for simplicity 
 *     we pass it all. If the compiler doesn't flatten and optimize, we can do it ourselves.
 *
 */

module bp_be_detector 
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   // Generated parameters
   , localparam calc_status_width_lp = `bp_be_calc_status_width(branch_metadata_fwd_width_p)
   // From BE specifications
   , localparam pc_entry_point_lp = bp_pc_entry_point_gp
   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam eaddr_width_lp    = rv64_eaddr_width_gp
   )
  (input logic                               clk_i
   , input logic                             reset_i

   // Dependency information
   , input logic [calc_status_width_lp-1:0]  calc_status_i
   , input logic [reg_data_width_lp-1:0]     expected_npc_i
   , input logic                             mmu_cmd_rdy_i

   // Pipeline control signals from the checker to the calculator
   , output logic                            chk_dispatch_v_o
   , output logic                            chk_roll_o
   , output logic                            chk_psn_isd_o
   , output logic                            chk_psn_ex_o
  );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   ); 

// Casting 
bp_be_calc_status_s calc_status;

assign calc_status = calc_status_i;

// Suppress unused inputs
wire unused1 = clk_i;
wire unused2 = reset_i;

// Declare intermediate signals
logic[1:0] irs1_dhaz_v     , irs2_dhaz_v;
logic[2:0] frs1_dhaz_v     , frs2_dhaz_v;
logic[2:0] rs1_match_vector, rs2_match_vector;

logic dhaz_v, shaz_v, mispredict_v;

always_comb 
  begin : detection
    // Generate matches for rs1 and rs2
    for(integer i = 0; i < 3; i++) 
      begin : match_vector
        rs1_match_vector[i] = (calc_status.isd_rs1_addr != reg_addr_width_lp'(0))
                              & (calc_status.isd_rs1_addr == calc_status.dep_status[i].rd_addr);

        rs2_match_vector[i] = (calc_status.isd_rs2_addr != reg_addr_width_lp'(0))
                              & (calc_status.isd_rs2_addr == calc_status.dep_status[i].rd_addr);
      end

    // Detect data hazards for EX1
    irs1_dhaz_v[0] = (calc_status.isd_irs1_v & rs1_match_vector[0])
                     & (calc_status.dep_status[0].mul_iwb_v | calc_status.dep_status[0].mem_iwb_v);

    irs2_dhaz_v[0] = (calc_status.isd_irs2_v & rs2_match_vector[0])
                     & (calc_status.dep_status[0].mul_iwb_v | calc_status.dep_status[0].mem_iwb_v);

    frs1_dhaz_v[0] = (calc_status.isd_frs1_v & rs1_match_vector[0])
                     & (calc_status.dep_status[0].mem_fwb_v | calc_status.dep_status[0].fp_fwb_v);

    frs2_dhaz_v[0] = (calc_status.isd_frs2_v & rs2_match_vector[0])
                     & (calc_status.dep_status[0].mem_fwb_v | calc_status.dep_status[0].fp_fwb_v);

    // Detect data hazards for EX2
    irs1_dhaz_v[1] = (calc_status.isd_irs1_v & rs1_match_vector[1])
                     & (calc_status.dep_status[1].mem_iwb_v);

    irs2_dhaz_v[1] = (calc_status.isd_irs2_v & rs2_match_vector[1])
                     & (calc_status.dep_status[1].mem_iwb_v);

    frs1_dhaz_v[1] = (calc_status.isd_frs1_v & rs1_match_vector[1])
                     & (calc_status.dep_status[1].mem_fwb_v | calc_status.dep_status[1].fp_fwb_v);

    frs2_dhaz_v[1] = (calc_status.isd_frs2_v & rs2_match_vector[1])
                     & (calc_status.dep_status[1].mem_fwb_v | calc_status.dep_status[1].fp_fwb_v);

    // Detect data hazards for IWB
    frs1_dhaz_v[2] = (calc_status.isd_frs1_v & rs1_match_vector[2])
                     & (calc_status.dep_status[2].fp_fwb_v);

    frs2_dhaz_v[2] = (calc_status.isd_frs2_v & rs2_match_vector[2])
                      & (calc_status.dep_status[2].fp_fwb_v);

    // Combine all data hazard information
    dhaz_v = (|irs1_dhaz_v) | (|irs2_dhaz_v) | (|frs1_dhaz_v) | (|frs2_dhaz_v);

    // Combine all structural hazard information
    shaz_v = ~mmu_cmd_rdy_i;

    // Detect misprediction
    mispredict_v = (calc_status.isd_v & (calc_status.isd_pc != expected_npc_i));

    // Generate calculator control signals
    chk_dispatch_v_o = ~(dhaz_v | shaz_v);
    chk_roll_o       = calc_status.mem3_cache_miss_v;
    chk_psn_isd_o    = reset_i 
                       | mispredict_v
                       | calc_status.mem3_cache_miss_v 
                       | calc_status.mem3_exception_v 
                       | calc_status.mem3_ret_v;

    chk_psn_ex_o     = reset_i
                       | calc_status.mem3_cache_miss_v 
                       | calc_status.mem3_exception_v 
                       | calc_status.mem3_ret_v;
  end

endmodule : bp_be_detector

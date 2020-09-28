/**
 *
 * Name:
 *   bp_be_detector.v
 *
 * Description:
 *
 *
 * Notes:
 *   We don't need the entirety of the calc_status structure here, but for simplicity
 *     we pass it all. If the compiler doesn't flatten and optimize, we can do it ourselves.
 *   We should get rid of the magic numbers here and replace with constants based on pipeline
 *     stages. However, like the calculator, this is a high risk change that should be postponed
 */

module bp_be_detector
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // Generated parameters
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam isd_status_width_lp = `bp_be_isd_status_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam calc_status_width_lp = `bp_be_calc_status_width(vaddr_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p)
   )
  (input                               clk_i
   , input                             reset_i

   , input [cfg_bus_width_lp-1:0]      cfg_bus_i

   // Dependency information
   , input [isd_status_width_lp-1:0]   isd_status_i
   , input [calc_status_width_lp-1:0]  calc_status_i
   , input                             fe_cmd_full_i
   , input                             credits_full_i
   , input                             credits_empty_i

   // Pipeline control signals from the checker to the calculator
   , output                            chk_dispatch_v_o
   , input [dispatch_pkt_width_lp-1:0] dispatch_pkt_i
  );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  // Casting
  bp_be_isd_status_s       isd_status_cast_i;
  bp_be_calc_status_s      calc_status_cast_i;
  bp_be_dispatch_pkt_s     dispatch_pkt;

  assign isd_status_cast_i  = isd_status_i;
  assign calc_status_cast_i = calc_status_i;
  assign dispatch_pkt       = dispatch_pkt_i;

  // Suppress unused inputs
  wire unused = &{clk_i, reset_i};

  // Declare intermediate signals
  // Integer data hazards
  logic [2:0] irs1_data_haz_v , irs2_data_haz_v;
  // Floating point data hazards
  logic [3:0] frs1_data_haz_v , frs2_data_haz_v, frs3_data_haz_v;
  logic [3:0] rs1_match_vector, rs2_match_vector, rs3_match_vector;
  logic [5:0] poison_r;

  bp_be_dep_status_s [5:0] dep_status_r;

  logic fence_haz_v, queue_haz_v, serial_haz_v;
  logic data_haz_v, control_haz_v, struct_haz_v;
  logic csr_haz_v;
  logic long_haz_v;
  logic mem_in_pipe_v;

  always_comb
    begin
      // Generate matches for rs1, rs2. rs3
      // 3 stages because we only care about ex1, ex2, and iwb dependencies. fwb dependencies
      //   can be handled through forwarding
      for(integer i = 0; i < 4; i++)
        begin
          rs1_match_vector[i] = (isd_status_cast_i.isd_rs1_addr == dep_status_r[i].rd_addr);
          rs2_match_vector[i] = (isd_status_cast_i.isd_rs2_addr == dep_status_r[i].rd_addr);
          rs3_match_vector[i] = (isd_status_cast_i.isd_rs3_addr == dep_status_r[i].rd_addr);
        end

      // Detect integer and float data hazards for EX1
      irs1_data_haz_v[0] = (isd_status_cast_i.isd_irs1_v & rs1_match_vector[0])
                           & (isd_status_cast_i.isd_rs1_addr != '0)
                           & (dep_status_r[0].aux_iwb_v | dep_status_r[0].mul_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fmem_iwb_v)
                           & ~poison_r[0];

      irs2_data_haz_v[0] = (isd_status_cast_i.isd_irs2_v & rs2_match_vector[0])
                           & (isd_status_cast_i.isd_rs2_addr != '0)
                           & (dep_status_r[0].aux_iwb_v | dep_status_r[0].mul_iwb_v | dep_status_r[0].emem_iwb_v | dep_status_r[0].fmem_iwb_v)
                           & ~poison_r[0];

      frs1_data_haz_v[0] = (isd_status_cast_i.isd_frs1_v & rs1_match_vector[0])
                           & (dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v)
                           & ~poison_r[0];

      frs2_data_haz_v[0] = (isd_status_cast_i.isd_frs2_v & rs2_match_vector[0])
                           & (dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v)
                           & ~poison_r[0];

      frs3_data_haz_v[0] = (isd_status_cast_i.isd_frs3_v & rs3_match_vector[0])
                           & (dep_status_r[0].aux_fwb_v | dep_status_r[0].emem_fwb_v | dep_status_r[0].fmem_fwb_v | dep_status_r[0].fma_fwb_v)
                           & ~poison_r[0];

      // Detect integer and float data hazards for EX2
      irs1_data_haz_v[1] = (isd_status_cast_i.isd_irs1_v & rs1_match_vector[1])
                           & (isd_status_cast_i.isd_rs1_addr != '0)
                           & (dep_status_r[1].fmem_iwb_v | dep_status_r[1].mul_iwb_v)
                           & ~poison_r[1];

      irs2_data_haz_v[1] = (isd_status_cast_i.isd_irs2_v & rs2_match_vector[1])
                           & (isd_status_cast_i.isd_rs2_addr != '0)
                           & (dep_status_r[1].fmem_iwb_v | dep_status_r[1].mul_iwb_v)
                           & ~poison_r[1];

      frs1_data_haz_v[1] = (isd_status_cast_i.isd_frs1_v & rs1_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v)
                           & ~poison_r[1];

      frs2_data_haz_v[1] = (isd_status_cast_i.isd_frs2_v & rs2_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v)
                           & ~poison_r[1];

      frs3_data_haz_v[1] = (isd_status_cast_i.isd_frs3_v & rs3_match_vector[1])
                           & (dep_status_r[1].fmem_fwb_v | dep_status_r[1].fma_fwb_v)
                           & ~poison_r[1];

      irs1_data_haz_v[2] = (isd_status_cast_i.isd_irs1_v & rs1_match_vector[2])
                           & (isd_status_cast_i.isd_rs1_addr != '0)
                           & (dep_status_r[2].mul_iwb_v)
                           & ~poison_r[2];

      irs2_data_haz_v[2] = (isd_status_cast_i.isd_irs2_v & rs2_match_vector[2])
                           & (isd_status_cast_i.isd_rs2_addr != '0)
                           & (dep_status_r[2].mul_iwb_v)
                           & ~poison_r[2];

      frs1_data_haz_v[2] = (isd_status_cast_i.isd_frs1_v & rs1_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v)
                           & ~poison_r[2];

      frs2_data_haz_v[2] = (isd_status_cast_i.isd_frs2_v & rs2_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v)
                           & ~poison_r[2];

      frs3_data_haz_v[2] = (isd_status_cast_i.isd_frs3_v & rs3_match_vector[2])
                           & (dep_status_r[2].fma_fwb_v)
                           & ~poison_r[2];

      frs1_data_haz_v[3] = (isd_status_cast_i.isd_frs1_v & rs1_match_vector[3])
                           & (dep_status_r[3].fma_fwb_v)
                           & ~poison_r[3];

      frs2_data_haz_v[3] = (isd_status_cast_i.isd_frs2_v & rs2_match_vector[3])
                           & (dep_status_r[3].fma_fwb_v)
                           & ~poison_r[3];

      frs3_data_haz_v[3] = (isd_status_cast_i.isd_frs3_v & rs3_match_vector[3])
                           & (dep_status_r[3].fma_fwb_v)
                           & ~poison_r[3];

      mem_in_pipe_v      = (dep_status_r[0].mem_v & ~poison_r[0])
                           | (dep_status_r[1].mem_v & ~poison_r[1]);
      fence_haz_v        = (isd_status_cast_i.isd_fence_v & (~credits_empty_i | mem_in_pipe_v))
                           | (isd_status_cast_i.isd_mem_v & credits_full_i);
      queue_haz_v        = fe_cmd_full_i;

      // Conservatively serialize on csr operations.  Could change to only write operations
      serial_haz_v       = (dep_status_r[0].csr_v & ~poison_r[0])
                           | (dep_status_r[1].csr_v & ~poison_r[1])
                           | (dep_status_r[2].csr_v & ~poison_r[2]);

      // This is overly conservative, should add an explicit fflags dependency checker
      csr_haz_v = isd_status_cast_i.isd_csr_v
                  & ((dep_status_r[0].fflags_w_v & ~poison_r[0])
                     | (dep_status_r[1].fflags_w_v & ~poison_r[1])
                     | (dep_status_r[2].fflags_w_v & ~poison_r[2])
                     );

      long_haz_v = isd_status_cast_i.isd_long_v
                   & ((dep_status_r[0].instr_v & ~poison_r[0])
                      | (dep_status_r[1].instr_v & ~poison_r[1])
                      | (dep_status_r[2].instr_v & ~poison_r[2])
                      );

      control_haz_v = fence_haz_v | serial_haz_v | csr_haz_v | long_haz_v;

      // Combine all data hazard information
      // TODO: Parameterize away floating point data hazards without hardware support
      data_haz_v = (|irs1_data_haz_v)
                   | (|irs2_data_haz_v)
                   | (|frs1_data_haz_v)
                   | (|frs2_data_haz_v)
                   | (|frs3_data_haz_v);

      // Combine all structural hazard information
      // We block on mmu not ready even on not memory instructions, because it means there's an
      //   operation being performed asynchronously (such as a page fault)
      struct_haz_v = cfg_bus_cast_i.freeze
                     | calc_status_cast_i.mem_busy
                     | calc_status_cast_i.long_busy
                     | queue_haz_v;
    end

  // Generate calculator control signals
  assign chk_dispatch_v_o = ~(control_haz_v | data_haz_v | struct_haz_v);

  always_comb
    begin
      dep_status_n.instr_v    = dispatch_pkt.v;
      dep_status_n.csr_v      = dispatch_pkt.decode.csr_v;
      dep_status_n.mem_v      = dispatch_pkt.decode.mem_v;
      dep_status_n.fflags_w_v = dispatch_pkt.decode.fflags_w_v;
      dep_status_n.ctl_iwb_v  = dispatch_pkt.decode.pipe_ctl_v & dispatch_pkt.decode.irf_w_v;
      dep_status_n.int_iwb_v  = dispatch_pkt.decode.pipe_int_v & dispatch_pkt.decode.irf_w_v;
      dep_status_n.int_fwb_v  = dispatch_pkt.decode.pipe_int_v & dispatch_pkt.decode.frf_w_v;
      dep_status_n.aux_iwb_v  = dispatch_pkt.decode.pipe_aux_v & dispatch_pkt.decode.irf_w_v;
      dep_status_n.aux_fwb_v  = dispatch_pkt.decode.pipe_aux_v & dispatch_pkt.decode.frf_w_v;
      dep_status_n.emem_iwb_v = dispatch_pkt.decode.pipe_mem_early_v & dispatch_pkt.decode.irf_w_v;
      dep_status_n.emem_fwb_v = dispatch_pkt.decode.pipe_mem_early_v & dispatch_pkt.decode.frf_w_v;
      dep_status_n.fmem_iwb_v = dispatch_pkt.decode.pipe_mem_final_v & dispatch_pkt.decode.irf_w_v;
      dep_status_n.fmem_fwb_v = dispatch_pkt.decode.pipe_mem_final_v & dispatch_pkt.decode.frf_w_v;
      dep_status_n.mul_iwb_v  = dispatch_pkt.decode.pipe_mul_v & dispatch_pkt.decode.irf_w_v;
      dep_status_n.fma_fwb_v  = dispatch_pkt.decode.pipe_fma_v & dispatch_pkt.decode.frf_w_v;

      dep_status_n.rd_addr    = dispatch_pkt.instr.t.rtype.rd_addr;
    end

  bp_be_dep_status_s dep_status_n;
  always_ff @(posedge clk_i)
    begin
      dep_status_r[0]   <= dep_status_n;
      dep_status_r[5:1] <= dep_status_r[4:0];

      poison_r[0]       <= dispatch_pkt.poison;
      poison_r[5:1]     <= poison_r[4:0];
    end

endmodule


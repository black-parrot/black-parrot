
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_nonsynth_if_verif
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_noc_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  ();

  bp_proc_param_s proc_param;
  assign proc_param = all_cfgs_gp[bp_params_p];

  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);

  initial
    begin
      $display("########### BP Parameters ##############");
      //  This throws an std::length_error in Verilator 4.031 based on the length of
      //   this (admittedly massive) parameter
      `ifndef VERILATOR
      $display("bp_params_e %s: bp_proc_param_s %p", bp_params_p.name(), proc_param);
      `endif
      $display("########### TOP IF ##############");
      $display("bp_cfg_bus_s          bits: struct %d width %d", $bits(bp_cfg_bus_s), cfg_bus_width_lp);

      $display("########### FE-BE IF ##############");
      $display("bp_fe_queue_s          bits: struct %d width %d", $bits(bp_fe_queue_s), fe_queue_width_lp);
      $display("bp_fe_cmd_s            bits: struct %d width %d", $bits(bp_fe_cmd_s), fe_cmd_width_lp);

      $display("########### LCE-CCE IF ##############");
      $display("bp_bedrock_lce_req_msg_s       bits: struct %d width %d", $bits(bp_bedrock_lce_req_msg_s), lce_req_msg_width_lp);
      $display("bp_bedrock_lce_cmd_msg_s       bits: struct %d width %d", $bits(bp_bedrock_lce_cmd_msg_s), lce_cmd_msg_width_lp);
      $display("bp_bedrock_lce_resp_msg_s      bits: struct %d width %d", $bits(bp_bedrock_lce_resp_msg_s), lce_resp_msg_width_lp);

      $display("########### CCE-MEM IF ##############");
      $display("bp_bedrock_cce_mem_msg_s       bits: struct %d width %d", $bits(bp_bedrock_cce_mem_msg_s), cce_mem_msg_width_lp);

      if (!(num_cce_p inside {1,2,3,4,6,7,8,12,14,15,16,24,28,30,31,32})) begin
        $fatal("Error: unsupported number of CCE's");
      end

    end

  if (ic_y_dim_p != 1)
    $fatal("Error: Must have exactly 1 row of I/O routers");
  if (mc_y_dim_p > 2)
    $fatal("Error: Multi-row L2 expansion nodes not yet supported");
  if (sac_x_dim_p > 1)
    $fatal("Error: Must have <= 1 column of streaming accelerators");
  if (cac_x_dim_p > 1)
    $fatal("Error: Must have <= 1 column of coherent accelerators");
  if (multicore_p == 1 && !((dcache_block_width_p == icache_block_width_p) && (dcache_block_width_p ==  acache_block_width_p)))
    $fatal("Error: We don't currently support different block widths for multicore configurations");
  if ((cce_block_width_p == 256) && (dcache_assoc_p == 8 || icache_assoc_p == 8))
    $fatal("Error: We can't maintain 64-bit dwords with a 256-bit cache block size and 8-way cache associativity");
  if ((cce_block_width_p == 128) && (dcache_assoc_p == 4 || dcache_assoc_p == 8 || icache_assoc_p == 4 || icache_assoc_p == 8))
    $fatal("Error: We can't maintain 64-bit dwords with a 128-bit cache block size and 4-way or 8-way cache associativity");
  if ((l1_writethrough_p == 1) && (l1_coherent_p == 1))
    $fatal("Error: Writethrough with coherent_l1 is unsupported");
  if ((icache_fill_width_p > icache_block_width_p) || (dcache_fill_width_p > dcache_block_width_p))
    $fatal("Error: Cache fill width should be less or equal to L1 cache block width");
  if ((icache_fill_width_p % (icache_block_width_p/icache_assoc_p) != 0) || (dcache_fill_width_p % (dcache_block_width_p / dcache_assoc_p) != 0))
    $fatal("Error: Cache fill width should be a multiple of cache bank width");
  // TODO: Combine icache & dcache data width into l1 fill width
  // The cce_to_cache supports hetero fill width only when fill width == block width 
  // if (icache_fill_width_p != dcache_fill_width_p) 
  //   $fatal("Error: L1-Cache fill width should be the same");

  if (l2_block_width_p != 512)
    $error("L2 block width must be 512");

  if (vaddr_width_p != 39)
    $warning("Warning: VM will not work without 39 bit vaddr");
  if (paddr_width_p < 40)
    $warning("Warning: paddr < 40 has not been tested");
  if (dram_max_size_p != (1 << 31))
    $warning("Warning: dram size != 4GB");

  if ((multicore_p == 1) && ((amo_swap_p != e_none) || (amo_fetch_logic_p != e_none) || (amo_fetch_arithmetic_p != e_none)))
    $fatal("Error: L2 atomics are not currently supported in bp_multicore");

  if (mem_noc_flit_width_p % l2_fill_width_p != 0)
    $fatal("Memory NoC flit width must match l2 fill width");

endmodule


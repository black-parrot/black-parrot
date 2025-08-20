
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"
`include "bp_fe_defines.svh"

module bp_nonsynth_if_verif
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 import bsg_noc_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_core_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input clk_i
   , input reset_i
   , input en_i
   );

  bp_proc_param_s proc_param;
  assign proc_param = all_cfgs_gp[bp_params_p];

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_core_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_fe_branch_metadata_fwd_s(ras_idx_width_p, btb_tag_width_p, btb_idx_width_p, bht_idx_width_p, ghist_width_p, bht_row_els_p);

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
      $display("bp_bedrock_lce_req_header_s       bits: struct %d width %d", $bits(bp_bedrock_lce_req_header_s), lce_req_header_width_lp);
      $display("bp_bedrock_lce_cmd_header_s       bits: struct %d width %d", $bits(bp_bedrock_lce_cmd_header_s), lce_cmd_header_width_lp);
      $display("bp_bedrock_lce_fill_header_s      bits: struct %d width %d", $bits(bp_bedrock_lce_fill_header_s), lce_fill_header_width_lp);
      $display("bp_bedrock_lce_resp_header_s      bits: struct %d width %d", $bits(bp_bedrock_lce_resp_header_s), lce_resp_header_width_lp);

      $display("########### CCE-MEM IF ##############");
      $display("bp_bedrock_mem_fwd_header_s           bits: struct %d width %d", $bits(bp_bedrock_mem_fwd_header_s), mem_fwd_header_width_lp);
      $display("bp_bedrock_mem_rev_header_s           bits: struct %d width %d", $bits(bp_bedrock_mem_rev_header_s), mem_rev_header_width_lp);

      if (!(num_cce_p inside {1,2,3,4,6,7,8,12,14,15,16,24,28,30,31,32})) begin
        $error("Error: unsupported number of CCE's");
      end

    end

  // General
  if (mc_y_dim_p > 2)
    $error("Error: Multi-row L2 expansion nodes not yet supported");
  if (sac_x_dim_p > 1)
    $error("Error: Must have <= 1 column of streaming accelerators");
  if (cac_x_dim_p > 1)
    $error("Error: Must have <= 1 column of coherent accelerators");
  if (dword_width_gp != 64)
    $error("Error: BlackParrot is only tested with 64-bit dword width");

  // Front End


  // Core or Features
  if (~muldiv_support_p[e_imul])
    $error("IMUL is not currently support in emulation");
  if (~muldiv_support_p[e_idiv])
    $error("IDIV is not currently support in emulation");
  if (~|fpu_support_p)
    $error("FPU cannot currently be disabled");
  if (branch_metadata_fwd_width_p != $bits(bp_fe_branch_metadata_fwd_s))
    $error("Branch metadata width: %d != width of branch metadata struct: %d", branch_metadata_fwd_width_p, $bits(bp_fe_branch_metadata_fwd_s));
  if (~|{dcache_features_p[e_cfg_lr_sc], l2_features_p[e_cfg_lr_sc]})
    $warning("Warning: Atomics cannot be emulated without LR/SC. Those instructions will fail");

  // L1 Caches
  if ((bedrock_block_width_p == 256) && (dcache_assoc_p == 8 || icache_assoc_p == 8))
    $error("Error: We can't maintain 64-bit dwords with a 256-bit cache block size and 8-way cache associativity");
  if ((bedrock_block_width_p == 128) && (dcache_assoc_p == 4 || dcache_assoc_p == 8 || icache_assoc_p == 4 || icache_assoc_p == 8))
    $error("Error: We can't maintain 64-bit dwords with a 128-bit cache block size and 4-way or 8-way cache associativity");
  if ((dcache_features_p[e_cfg_writeback] == 0) && (dcache_features_p[e_cfg_coherent] == 1))
    $error("Error: Writethrough with coherent_l1 is unsupported");
  if ((icache_fill_width_p > icache_block_width_p) || (dcache_fill_width_p > dcache_block_width_p))
    $error("Error: Cache fill width should be less or equal to L1 cache block width");
  if ((icache_fill_width_p % (icache_block_width_p/icache_assoc_p) != 0) || (dcache_fill_width_p % (dcache_block_width_p / dcache_assoc_p) != 0))
    $error("Error: Cache fill width should be a multiple of cache bank width");
  if (icache_fill_width_p != dcache_fill_width_p)
    $error("Error: L1-Cache fill width should be the same");
  if (icache_fill_width_p < (icache_block_width_p / icache_assoc_p))
    $error("Error: L1 I$ requires fill width greater than bank width (block width / assoc)");
  if (dcache_fill_width_p < (dcache_block_width_p / dcache_assoc_p))
    $error("Error: L1 D$ requires fill width greater than bank width (block width / assoc)");
  if (icache_mshr_p != 1 && dcache_mshr_p !=1 || acache_mshr_p != 1)
    $error("MSHR must be 1 for all caches");

  // Address Widths
  if (vaddr_width_p != 39)
    $warning("Warning: VM will not work without 39 bit vaddr");
  if (paddr_width_p > 56)
    $warning("Warning: paddr > 56 has not been tested");
  if (paddr_width_p < 33)
    $warning("Warning: paddr < 33 has not been tested");
  if (daddr_width_p < 32)
    $warning("Warning: daddr < 32 has not been tested");
  if (caddr_width_p < 31)
    $warning("Warning: caddr < 31 has not been tested");
  if (caddr_width_p >= daddr_width_p)
    $warning("Warning: caddr must <= daddr");
  if (daddr_width_p >= paddr_width_p)
    $error("Error: caddr cannot exceed paddr_width_p-1");

  // L2 Cache
  if (l2_fill_width_p < l2_data_width_p)
    $error("Error: L2 fill width must be at least as large as L2 data width");
  if (l2_block_width_p > 1024)
    $error("Error: L2 block width must be less than 1024");
  if (!`BSG_IS_POW2((l2_fill_width_p/l2_data_width_p)))
    $error("Error: L2 fill width must be POW2 multiple of L2 data width");
  if (!`BSG_IS_POW2(l2_dmas_p))
    $error("Error: L2 banks must be a power of two");

  // Unicore
  if ((cce_type_p == e_cce_uce) && (icache_fill_width_p != dcache_fill_width_p))
    $error("Error: unicore requires L1-Cache fill width to match");
  if ((cce_type_p == e_cce_uce) && (num_core_p != 1))
    $error("Error: Unicore only supports a single core configuration in the tethered testbench");
  if ((cce_type_p == e_cce_uce) && (bedrock_fill_width_p < dword_width_gp))
    $error("Error: Unicore requires UCE fill width to be at least dword width");

  // Multicore
  if ((cce_type_p != e_cce_uce) && (ic_y_dim_p != 1))
    $error("Error: Must have exactly 1 row of I/O routers for multicore");
  if ((cce_type_p != e_cce_uce) && (l2_data_width_p != bedrock_fill_width_p))
    $error("Error: Multicore requires L2 data width same as BedRock data width");
  if ((cce_type_p != e_cce_uce) && (icache_fill_width_p != dcache_fill_width_p))
    $error("Error: Multicore requires L1-Cache fill width to be the same");
  if ((cce_type_p != e_cce_uce) && (num_cacc_p > 0) && (icache_fill_width_p != acache_fill_width_p))
    $error("Error: Multicore requires L1-Cache fill width to be the same");
  if ((cce_type_p != e_cce_uce) && (dcache_block_width_p != icache_block_width_p))
    $error("Error: Multicore requires L1-Cache block width to be the same");
  if ((cce_type_p != e_cce_uce) && (num_cacc_p > 0) && (icache_block_width_p != acache_block_width_p))
    $error("Error: Multicore requires L1-Cache block width to be the same");
  if ((cce_type_p != e_cce_uce) && (l2_block_width_p < icache_block_width_p))
    $error("Error: Multicore requires L2-Cache block width to be at least L1-Cache block width");
  if ((cce_type_p != e_cce_uce) && (bedrock_fill_width_p < dword_width_gp))
    $error("Error: Multicore requires BedRock data width to be at least dword width");
  if ((cce_type_p != e_cce_uce) && (bedrock_fill_width_p > icache_fill_width_p))
    $error("Error: Multicore requires BedRock data width to be no larger than cache fill width");
  if ((cce_type_p != e_cce_uce) && l2_features_p[e_cfg_enabled] && (|{l2_features_p[e_cfg_lr_sc], l2_features_p[e_cfg_amo_swap], l2_features_p[e_cfg_amo_fetch_logic], l2_features_p[e_cfg_amo_fetch_arithmetic]}))
    $error("Error: Multicore does not support L2 atomics");
  if ((cce_type_p != e_cce_uce) && (`BSG_SAFE_CLOG2(icache_block_width_p*icache_sets_p/8) > page_offset_width_gp) && (`BSG_SAFE_CLOG2(dcache_block_width_p*dcache_sets_p/8) > page_offset_width_gp))
    $error("Error: Multicore requires total cache size to be equal to 4kB * associativity");

  if (num_cce_p/mc_x_dim_p*l2_dmas_p > 16)
    $error("Round robin arbiter currently only supports 16 entries");

endmodule


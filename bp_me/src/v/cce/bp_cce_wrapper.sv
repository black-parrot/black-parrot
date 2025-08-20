/**
 *
 * Name:
 *   bp_cce_wrapper.sv
 *
 * Description:
 *   This is the top level module for the CCE.
 *
 *   The LCE-CCE Interfaces use the BedRock Burst protocol.
 *   The CCE-MEM Intercaces use the BedRock Stream protocol
 *
 *   It instantiates either the microcode or FSM CCE, based on the param in bp_params_p.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_wrapper
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p      = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Interface Widths
    , localparam cfg_bus_width_lp          = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // Configuration Interface
   , input [cfg_bus_width_lp-1:0]                   cfg_bus_i

   // ucode programming interface, synchronous read, direct connection to RAM
   , input                                          ucode_v_i
   , input                                          ucode_w_i
   , input [cce_pc_width_p-1:0]                     ucode_addr_i
   , input [cce_instr_width_gp-1:0]                 ucode_data_i
   , output logic [cce_instr_width_gp-1:0]          ucode_data_o

   // LCE-CCE Interface
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input [bedrock_fill_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_v_i
   , output logic                                   lce_req_ready_and_o

   , input [lce_resp_header_width_lp-1:0]           lce_resp_header_i
   , input [bedrock_fill_width_p-1:0]               lce_resp_data_i
   , input                                          lce_resp_v_i
   , output logic                                   lce_resp_ready_and_o

   , output logic [lce_cmd_header_width_lp-1:0]     lce_cmd_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_cmd_data_o
   , output logic                                   lce_cmd_v_o
   , input                                          lce_cmd_ready_and_i

   // CCE-MEM Interface
   // BedRock Stream protocol: ready&valid
   , input [mem_rev_header_width_lp-1:0]            mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]               mem_rev_data_i
   , input                                          mem_rev_v_i
   , output logic                                   mem_rev_ready_and_o

   , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_fwd_data_o
   , output logic                                   mem_fwd_v_o
   , input                                          mem_fwd_ready_and_i
  );

  // Config Interface
  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);

  // Config bus casting
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  if (cce_type_p == e_cce_ucode) begin : t
    bp_cce
    #(.bp_params_p(bp_params_p))
    cce
     (.*);
  end else if (cce_type_p == e_cce_fsm) begin : t
    bp_cce_fsm
    #(.bp_params_p(bp_params_p))
    cce
     (.*);
  end

  // parameter checks

  // cache organization
  // all caches must have the same block size, which must equal CCE block size
  // cache assoc and sets must be pow2
  if (icache_block_width_p != bedrock_block_width_p) $error("icache block width must match cce block width");
  if (!(`BSG_IS_POW2(icache_assoc_p) && `BSG_IS_POW2(icache_sets_p)))
    $error("I$ sets and assoc must be power of two");
  if (dcache_block_width_p != bedrock_block_width_p) $error("dcache block width must match cce block width");
  if (!(`BSG_IS_POW2(dcache_assoc_p) && `BSG_IS_POW2(dcache_sets_p)))
    $error("D$ sets and assoc must be power of two");
  // acclereator caches
  if ((num_cacc_p) > 0 && (acache_block_width_p != bedrock_block_width_p)) $error("acache block width must match cce block width");
  if ((num_cacc_p > 0) && !(`BSG_IS_POW2(acache_assoc_p)))
    $error("A$ assoc must be power of two or 0");
  if ((num_cacc_p > 0) && !(`BSG_IS_POW2(acache_sets_p)))
    $error("A$ sets must be power of two or 0");

  // coherence system block width is pow2 and between 64 and 1024 bits
  if (!(`BSG_IS_POW2(bedrock_block_width_p) || bedrock_block_width_p < 64 || bedrock_block_width_p > 1024))
    $error("invalid CCE block width");

  // way groups
  if (!(`BSG_IS_POW2(cce_way_groups_p))) $error("Number of way groups must be a power of two");
  if (cce_way_groups_p < 1) $error("There must be at least one way group");

  // bedrock data width must be pow2 between 64-bits and CCE block size
  if (bedrock_fill_width_p < 64 || bedrock_fill_width_p > bedrock_block_width_p
      || !(`BSG_IS_POW2(bedrock_fill_width_p)))
      $error("CCE requires bedrock data width of between 64-bits and block width and power of 2 bits");

endmodule

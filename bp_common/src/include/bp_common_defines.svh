`ifndef BP_COMMON_DEFINES_SVH
`define BP_COMMON_DEFINES_SVH

  `include "bsg_defines.sv"
  `include "bsg_extra_defines.svh"
  `include "bp_common_addr_defines.svh"
  `include "bp_common_aviary_defines.svh"
  `include "bp_common_aviary_custom_defines.svh"
  `include "bp_common_bedrock_if.svh"
  `include "bp_common_bedrock_wormhole_defines.svh"
  `include "bp_common_cache_engine_if.svh"
  `include "bp_common_core_if.svh"
  `include "bp_common_cfg_bus_defines.svh"
  `include "bp_common_rv64_instr_defines.svh"
  `include "bp_common_rv64_csr_defines.svh"

  /*
   * Clients need only use this macro to declare all parameterized structs for common interfaces.
   */
  `define declare_bp_common_if(vaddr_width_mp, hio_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp, did_width_mp) \
    `declare_bp_cfg_bus_s(vaddr_width_mp, hio_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp, did_width_mp)


  /* Declare width macros so that clients can use structs in ports before struct declaration
   * Each of these macros needs to be kept in sync with the struct definition. The computation
   *   comes from literally counting bits in the struct definition, which is ugly, error-prone,
   *   and an unfortunate, necessary consequence of parameterized structs.
   */
  `define declare_bp_common_if_widths(vaddr_width_mp, hio_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp, did_width_mp) \
    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_mp, hio_width_mp, core_id_width_mp, cce_id_width_mp, lce_id_width_mp, did_width_mp)

  `define bp_cast_i(struct_name_mp, port_mp) \
    struct_name_mp ``port_mp``_cast_i;    \
    assign ``port_mp``_cast_i = ``port_mp``_i

  `define bp_cast_o(struct_name_mp, port_mp) \
    struct_name_mp ``port_mp``_cast_o;    \
    assign ``port_mp``_o = ``port_mp``_cast_o

`endif


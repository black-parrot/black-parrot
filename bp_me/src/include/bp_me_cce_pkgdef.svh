/**
 *
 * Name:
 *   bp_me_cce_pkgdef.svh
 *
 * Description:
 */

`ifndef BP_ME_CCE_PKGDEF_SVH
`define BP_ME_CCE_PKGDEF_SVH

// Struct that defines speculative memory access tracking metadata
// This is used in the decoded instruction and the bp_cce_spec module
typedef struct packed
{
  logic                          spec;
  logic                          squash;
  logic                          fwd_mod;
  bp_coh_states_e                state;
} bp_cce_spec_s;

`endif


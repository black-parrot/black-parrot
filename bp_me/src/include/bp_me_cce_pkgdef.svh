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
    logic           spec;
    logic           squash;
    logic           fwd_mod;
    bp_coh_states_e state;
  } bp_cce_spec_s;

  // Coherence Request Processing Flags
  // TODO: reorder this struct - requires reording in CCE instruction define and ucode assembler
  typedef struct packed {
    // request to cacheable address
    logic cacheable_address;
    // atomics
    logic atomic_no_return;
    logic atomic;
    // GAD flags
    logic upgrade;
    logic replacement;
    logic cached_forward;
    logic cached_owned;
    logic cached_modified;
    logic cached_exclusive;
    logic cached_shared;
    // misc flags
    logic speculative;
    logic pending;
    logic null_writeback;
    // request flags
    logic non_exclusive;
    logic uncached;
    logic write_not_read;
  } bp_cce_flags_s;

`endif


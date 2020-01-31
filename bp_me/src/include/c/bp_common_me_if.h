/**
 * bp_common_me_if.h
 *
 * This file defines the interface between the CCEs and LCEs in the BlackParrot cohrence
 * system. For ease of reuse and flexiblity, this interface is defined as a collection of
 * parameterized structs.
 *
 * This file is derived from bp_common/bp_common_me_if.vh
 *
 */

#ifndef BP_COMMON_ME_IF_H
#define BP_COMMON_ME_IF_H

#include "bp_cce.h"

// LCE Requests
typedef enum {
  e_lce_req_type_rd          = 0 // Read-miss
  ,e_lce_req_type_wr         = 1 // Write-miss
  ,e_lce_req_type_uc_rd      = 2 // Uncached Load
  ,e_lce_req_type_uc_wr      = 3 // Uncached Store
} bp_lce_cce_req_type_e;

#define bp_lce_cce_req_type_width 3

typedef enum {
  e_lce_req_excl             = 0 // Exclusive cache line request (read-only, exclusive request)
  ,e_lce_req_not_excl        = 1 // Non-Exclusive cache line request (read-only, shared request)
} bp_lce_cce_req_non_excl_e;

#define bp_lce_cce_req_non_excl_width 1

typedef enum {
  e_lce_req_lru_clean        = 0 // LRU way from requesting LCE's tag set is clean
  ,e_lce_req_lru_dirty       = 1 // LRU way from requesting LCE's tag set is dirty
} bp_lce_cce_lru_dirty_e;

#define bp_lce_cce_lru_dirty_width 1

typedef enum {
  e_lce_uc_req_1     = 0
  ,e_lce_uc_req_2    = 1
  ,e_lce_uc_req_4    = 2
  ,e_lce_uc_req_8    = 3
} bp_lce_cce_uc_req_size_e;

#define bp_lce_cce_uc_req_size_width 2

// Coherence States
typedef enum {
  e_COH_I  = 0
  ,e_COH_S = 1
  ,e_COH_E = 2
  ,e_COH_F = 3
  // 4 = potentially dirty, not owned, not shared
  // 5 = potentially dirty, not owned, shared
  ,e_COH_M = 6
  ,e_COH_O = 7
} bp_cce_coh_states_e;

#define bp_cce_coh_shared_bit 0
#define bp_cce_coh_owned_bit 1
#define bp_cce_coh_dirty_bit 2

#define bp_cce_coh_bits 3

// LCE Commands
typedef enum {
  e_lce_cmd_sync             = 0
  ,e_lce_cmd_set_clear       = 1
  ,e_lce_cmd_transfer        = 2
  ,e_lce_cmd_writeback       = 3
  ,e_lce_cmd_set_tag         = 4
  ,e_lce_cmd_set_tag_wakeup  = 5
  ,e_lce_cmd_invalidate_tag  = 6
  ,e_lce_cmd_uc_st_done      = 7
  ,e_lce_cmd_data            = 8
  ,e_lce_cmd_uc_data         = 9
} bp_lce_cmd_type_e;

#define bp_lce_cmd_type_width 4

// LCE Responses
typedef enum {
  e_lce_cce_sync_ack         = 0 // Sync Ack
  ,e_lce_cce_inv_ack         = 1 // Invalidate Tag Ack
  ,e_lce_cce_coh_ack         = 2 // Coherence Ack
  ,e_lce_resp_wb             = 3 // Normal Writeback Response
  ,e_lce_resp_null_wb        = 4 // Null Writeback Response
} bp_lce_cce_resp_type_e;

#define bp_lce_cce_ack_type_width 3

// Mem Commands
typedef enum {
  e_cce_mem_rd               = 0
  ,e_cce_mem_wr              = 1
  ,e_cce_mem_uc_rd           = 2
  ,e_cce_mem_uc_wr           = 3
  ,e_cce_mem_wb              = 4
} bp_cce_mem_cmd_type_e;

typedef enum {
  e_mem_cce_inv              = 0
  ,e_mem_cce_flush           = 1
} bp_mem_cce_cmd_type_e;

#define bp_cce_mem_msg_type_width 4

#endif

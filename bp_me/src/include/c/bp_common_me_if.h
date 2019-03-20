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

typedef enum {
  e_lce_req_type_rd          = 0 // Read-miss
  ,e_lce_req_type_wr         = 1 // Write-miss
} bp_lce_cce_req_type_e;

#define bp_lce_cce_req_type_width 1

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
  e_lce_req_cacheable      = 0
  ,e_lce_req_non_cacheable = 1
} bp_lce_cce_req_non_cacheable_e;

#define bp_lce_cce_req_non_cacheable_width 1

typedef enum {
  e_lce_nc_req_1     = 0
  ,e_lce_nc_req_2    = 1
  ,e_lce_nc_req_4    = 2
  ,e_lce_nc_req_8    = 3
} bp_lce_cce_nc_req_size_e;

#define bp_lce_cce_nc_req_size_width 2

typedef enum { // CCE to LCE Commands
  e_lce_cmd_sync             = 0
  ,e_lce_cmd_set_clear       = 1
  ,e_lce_cmd_transfer        = 2
  ,e_lce_cmd_writeback       = 3
  ,e_lce_cmd_set_tag         = 4
  ,e_lce_cmd_set_tag_wakeup  = 5
  ,e_lce_cmd_invalidate_tag  = 6
  ,e_lce_cmd_nc_writeback    = 7
} bp_cce_lce_cmd_type_e;

#define bp_cce_lce_cmd_type_width 3

typedef enum {
  e_lce_resp_wb              = 0 // Normal Writeback Response
  ,e_lce_resp_null_wb        = 1 // Null Writeback Response
  ,e_lce_resp_non_cacheable  = 2 // Non cacheable data response (only 64-bit of data max)
} bp_lce_cce_resp_msg_type_e;

#define bp_lce_cce_resp_msg_type_width 2

typedef enum {
  e_lce_data_cmd_transfer       = 0
  ,e_lce_data_cmd_cce           = 1
  ,e_lce_data_cmd_non_cacheable = 2
} bp_lce_data_cmd_type_e;

#define bp_lce_data_cmd_type_width 2

typedef enum {
  e_lce_cce_sync_ack         = 0 // Sync Ack
  ,e_lce_cce_inv_ack         = 1 // Invalidate Tag Ack
  ,e_lce_cce_tr_ack          = 2 // Transfer Ack
  ,e_lce_cce_coh_ack         = 3 // Coherence Ack
} bp_lce_cce_ack_type_e;

#define bp_lce_cce_ack_type_width 2

// Coherence States

typedef enum {
  e_MESI_I  = 0
  ,e_MESI_S = 1
  ,e_MESI_E = 2
  ,e_MESI_M = 3
} bp_cce_coh_mesi_e;

typedef enum {
  e_VI_I  = 0
  ,e_VI_V = 2
} bp_cce_coh_vi_e;

#define bp_cce_coh_bits 2


#define bp_lce_cce_req_width (LG_N_CCE+LG_N_LCE+bp_lce_cce_req_type_width \
  +bp_lce_cce_req_non_excl_width+ADDR_WIDTH+LG_LCE_ASSOC+bp_lce_cce_lru_dirty_width \
  +bp_lce_cce_req_non_cacheable_width+bp_lce_cce_nc_req_size_width)

#define bp_lce_cce_resp_width (LG_N_CCE+LG_N_LCE+bp_lce_cce_ack_type_width+ADDR_WIDTH)

#define bp_lce_cce_data_resp_width (LG_N_CCE+LG_N_LCE+bp_lce_cce_resp_msg_type_width+ADDR_WIDTH \
  +DATA_WIDTH_BITS)

#define bp_cce_lce_cmd_width (LG_N_CCE+LG_N_LCE+bp_cce_lce_cmd_type_width+ADDR_WIDTH \
  +2*(LG_LCE_ASSOC)+bp_cce_coh_bits+LG_N_LCE)

#define bp_lce_data_cmd_width (LG_N_LCE+bp_lce_data_cmd_type_width+LG_LCE_ASSOC+DATA_WIDTH_BITS)

#define bp_lce_lce_tr_resp_width (LG_N_LCE+LG_N_LCE+LG_LCE_ASSOC+ADDR_WIDTH+DATA_WIDTH_BITS)

#define bp_cce_mem_cmd_payload_width (LG_N_LCE+LG_LCE_ASSOC)

#define bp_cce_mem_data_cmd_payload_width ((2*LG_N_LCE)+(2*LG_LCE_ASSOC)+ADDR_WIDTH+2)

#define bp_cce_mem_cmd_width (bp_lce_cce_req_type_width+ADDR_WIDTH+bp_cce_mem_cmd_payload_width \
  +bp_lce_cce_req_non_cacheable_width+bp_lce_cce_nc_req_size_width)

#define bp_cce_mem_data_cmd_width (bp_lce_cce_req_type_width+ADDR_WIDTH+DATA_WIDTH_BITS \
  +bp_cce_mem_data_cmd_payload_width \
  +bp_lce_cce_req_non_cacheable_width+bp_lce_cce_nc_req_size_width)

#define bp_mem_cce_resp_width (bp_lce_cce_req_type_width+ADDR_WIDTH \
  +bp_cce_mem_data_cmd_payload_width \
  +bp_lce_cce_req_non_cacheable_width+bp_lce_cce_nc_req_size_width)

#define bp_mem_cce_data_resp_width (bp_lce_cce_req_type_width+ADDR_WIDTH+DATA_WIDTH_BITS \
  +bp_cce_mem_cmd_payload_width+bp_lce_cce_req_non_cacheable_width+bp_lce_cce_nc_req_size_width)

#endif

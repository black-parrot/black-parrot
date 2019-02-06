/**
 *  Name:
 *    bp_be_dcache_lce_pkg.vh
 *  
 *  Description:
 *    opcodes for tag_mem_pkt and stat_mem_pkt.
 */

package bp_be_dcache_lce_pkg;

  //  tag_mem opcode
  //
  typedef enum logic [1:0] {

    // clear all blocks in a set for given index.
    e_dcache_lce_tag_mem_set_clear,
    
    // invalidate a block for given index and way_id.
    e_dcache_lce_tag_mem_invalidate,
    
    // set tag and coh_state for given index and way_id.
    e_dcache_lce_tag_mem_set_tag

  } bp_be_dcache_lce_tag_mem_opcode_e;


  // stat_mem opcode
  //
  typedef enum logic [1:0] {

    // clear all dirty bits and LRU bits to zero for given index.
    e_dcache_lce_stat_mem_set_clear,
    
    // read stat_info for given index.
    e_dcache_lce_stat_mem_read,
    
    // clear dirty bit for given index and way_id.
    e_dcache_lce_stat_mem_clear_dirty,
    
    // update LRU bits to point to a block with given index and way_id.
    e_dcache_lce_stat_mem_set_lru

  } bp_be_dcache_lce_stat_mem_opcode_e;

endpackage

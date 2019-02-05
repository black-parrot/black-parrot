/**
 *  bp_be_dcache_lce_pkg.vh
 */

package bp_be_dcache_lce_pkg;

  //  tag_mem opcode
  //
  typedef enum logic [1:0] {
    e_dcache_lce_tag_mem_set_clear,
    e_dcache_lce_tag_mem_invalidate,
    e_dcache_lce_tag_mem_set_tag
  } bp_be_dcache_lce_tag_mem_opcode_e;


  // stat_mem opcode
  //
  typedef enum logic [1:0] {
    e_dcache_lce_stat_mem_set_clear,
    e_dcache_lce_stat_mem_read,
    e_dcache_lce_stat_mem_clear_dirty,
    e_dcache_lce_stat_mem_set_lru
  } bp_be_dcache_lce_stat_mem_opcode_e;

endpackage

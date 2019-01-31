
    `include "bp_common_cfg_defines.vh"
    `include "bp_common_fe_be_if.vh"
    `include "bp_common_me_if.vh"

package bp_common_pkg;

    /*
     * RV64 specifies a 64b effective address and 32b instruction.
     * BlackParrot supports SV39 virtual memory, which specifies 39b virtual / 56b physical address.
     * Effective addresses must have bits 39-63 match bit 38 
     * or a page fault exception will occur during translation.
     */

    localparam bp_eaddr_width_gp = 64;
    localparam bp_vaddr_width_gp = 22;
    localparam bp_paddr_width_gp = 22;
    localparam bp_instr_width_gp = 32;

endpackage : bp_common_pkg


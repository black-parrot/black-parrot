/*
 * bp_fe_top.vh provides all the necessary structs for the Frontend submodules.
 * Backend supplies the frontend with branch prediction results and exceptions
 * codes. The Frontend should update the states accordingly.
*/

`ifndef BP_FE_TOP_VH
`define BP_FE_TOP_VH

`include "bp_common_fe_be_if.vh"

/*
 * bp_fe_pc_gen_s provides the interfaces of the Frontend to pc_gen. The interfaces
 * consist of all the necessary information from Backend to the Frontend, including 
 * subopcodes, branch metadata , misprediction reasons, and whether translation is
 * needed for virtual to physical addresses.
*/
`define declare_bp_fe_pc_gen_s                             \
  typedef struct packed {                                  \
    bp_fe_pc_redirect_operands_s   pc_redirect_operands;   \
  } bp_fe_pc_gen_s

`define bp_fe_pc_gen_width bp_fe_pc_redirect_operands_width

/*
 * bp_fe_icache_s provides the information from Frontend to the icache. It
 * consists of opcodes from the Backend, including state_reset and icache_fence.
 * state reset signals flushing all the information in the icaches. icache_fence
 * informs icache to flush the entries.
*/
typedef enum logic {
  e_op_state_reset
  , e_op_icache_fence
} bp_fe_icache_cmd_e 

`define declare_bp_fe_icache_s        \
  typedef struct packed {             \
    bp_fe_icache_cmd_e icache_cmd;    \
  } bp_fe_icache_s

`define bp_fe_icache_width $bits(bp_fe_icache_cmd_e)

/*
 * bp_fe_itlb_s provides the information for the itlb from the Backend. It
 * consists of the cmd type, itlb fill response information, itlb fence
 * information, and whether translation from virtual to physical address is
 * needed.
*/
typedef enum logic {        \
  e_op_state_reset          \
  , e_op_itlb_fill_response \
  , e_op_itlb_fence         \
} bp_fe_itlb_cmd_e;

`define bp_fe_itlb_cmd_width $bits(bp_fe_itlb_cmd_e)

`define declare_bp_fe_itlb_s                                 \
  typedef struct packed {                                    \
    logic [bp_fe_itlb_cmd_width-1:0]     itlb_cmd;           \
    bp_fe_cmd_itlb_map_s                 itlb_fill_response; \
    bp_fe_cmd_itlb_fence_s               itlb_fence;         \
    logic                                translation_enabled;\
  }  bp_fe_itlb_s

`define bp_fe_itlb_width (vaddr_width_p, paddr_width_p, asid_width_p)\
    (paddr_width_p+`bp_fe_itlb_cmd_width+`bp_fe_cmd_itlb_fence_width+1)

`endif

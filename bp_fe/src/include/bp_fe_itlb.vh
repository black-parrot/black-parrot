/*                                                                         
 * itlb.vh
 * This file declares the internal structs of the BlackParrot Front
 * End I-TLB module. For simplicity and flexibility, these structs are
 * parameterized. Each struct declares its width separately to
 * prevent pre-processor ordering issues. 
*/

`ifndef ITLB_VH
`define ITLB_VH

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

`ifndef BP_COMMON_FE_BE_IF
`define BP_COMMON_FE_BE_IF
`include "bp_common_fe_be_if.vh"
`endif

import itlb_pkg::*;
/*
 * bp_fe_itlb_icache_data_resp_s defines the interface between I-TLB and
 * I-Cache. The I-TLB sends the Physical Page Number (PPN) to the
 * I-Cache. The width of PPN is specified by ppn_width_p parameter.
*/
`define declare_bp_fe_itlb_icache_data_resp_s(ppn_width_p)\
  typedef struct packed {                    \
    logic [ppn_width_p-1:0] ppn;       \
  } bp_fe_itlb_icache_data_resp_s

`define bp_fe_itlb_icache_width(ppn_width_p) (ppn_width_p)

/*
 * In the case of an I-TLB miss, bp_fe_itlb_miss_exception_data_s
 * struct is passed to the BE for I-TLB miss handling. This struct
 * includes the requested Virtual Page Nmuber (VPN) whose PTE does not
 * exist in the I-TLB.
*/

`define declare_bp_fe_itlb_cmd_s                                       \
    typedef struct packed {                                            \
        bp_fe_command_queue_opcodes_e          command_queue_opcodes;  \
        union packed {                                                 \
            bp_fe_cmd_itlb_map_s               itlb_fill_response;     \
            bp_fe_cmd_itlb_fence_s             itlb_fence;             \
        } operands;                                                    \
    } bp_fe_itlb_cmd_s;

`define bp_fe_itlb_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    (`bp_fe_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p))

`define declare_bp_fe_itlb_queue_s           \
    typedef struct packed {                  \
        bp_fe_queue_type_e    msg_type;      \
        union packed {                       \
            bp_fe_fetch_s         fetch;     \
            bp_fe_exception_s     exception; \
        } msg;                               \
    } bp_fe_itlb_queue_s;                                                                               

`define bp_fe_itlb_queue_width(vaddr_width_p,branch_metadata_fwd_width_p) \
     (`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p))

`endif

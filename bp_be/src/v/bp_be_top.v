/**
 *
 * Name:
 *   bp_be_top.v
 * 
 * Description:
 *
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''
 *
 *   num_cce_p                   - 
 *   num_lce_p                   - 
 *   lce_assoc_p                 - 
 *   lce_sets_p                  - 
 *   cce_block_size_in_bytes_p   - 
 * 
 * Inputs:
 *   clk_i                       -
 *   reset_i                     -
 *
 *   fe_queue_i                  -
 *   fe_queue_v_i                -
 *   fe_queue_ready_o              -
 *
 *   lce_cmd_i               -
 *   lce_cmd_v_i             -
 *   lce_cmd_ready_o           -
 *
 *   lce_data_cmd_i          -
 *   lce_data_cmd_v_i        -
 *   lce_data_cmd_ready_o      -
 * 
 *   lce_tr_resp_i           - 
 *   lce_tr_resp_v_i         -
 *   lce_tr_resp_ready_o       -
 * 
 *   proc_cfg_i
 *
 * Outputs:
 *   fe_cmd_o
 *   fe_cmd_v_o
 *   fe_cmd_ready_i
 *
 *   fe_queue_clr_o
 *   fe_queue_dequeue_inc_o
 *   fe_queue_rollback_o
 *
 *   lce_req_o
 *   lce_req_v_o
 *   lce_req_ready_i
 *
 *   lce_resp_o
 *   lce_resp_v_o
 *   lce_resp_ready_i
 *
 *   lce_data_resp_o
 *   lce_data_resp_v_o
 *   lce_data_resp_ready_i
 *
 *   lce_tr_resp_o
 *   lce_tr_resp_v_o
 *   lce_tr_resp_ready_i
 *
 *   cmt_trace_stage_reg_o
 *   cmt_trace_result_o
 *   cmt_trace_exc_o
 *
 *  Keywords:
 *   be, top
 * 
 *  Notes:
 *
 */


module bp_be_top
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   , parameter core_els_p                  = "inv"

   , parameter load_to_use_forwarding_p    = 1
   , parameter trace_p                     = 1

   // MMU parameters
   , parameter num_cce_p                   = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_assoc_p                 = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter cce_block_size_in_bytes_p   = "inv"
 
   // Generated parameters
   , localparam cce_block_size_in_bits_lp  = cce_block_size_in_bytes_p * rv64_byte_width_gp
   , localparam fe_queue_width_lp          = `bp_fe_queue_width(vaddr_width_p
                                                                , branch_metadata_fwd_width_p)
   , localparam fe_cmd_width_lp            = `bp_fe_cmd_width(vaddr_width_p
                                                              , paddr_width_p
                                                              , asid_width_p
                                                              , branch_metadata_fwd_width_p
                                                              )
   , localparam lce_cce_req_width_lp       = `bp_lce_cce_req_width(num_cce_p
                                                            , num_lce_p
                                                            , paddr_width_p
                                                            , lce_assoc_p
                                                            )
   , localparam lce_cce_resp_width_lp      = `bp_lce_cce_resp_width(num_cce_p
                                                              , num_lce_p
                                                              , paddr_width_p
                                                              )
   , localparam lce_cce_data_resp_width_lp = `bp_lce_cce_data_resp_width(num_cce_p
                                                                        , num_lce_p
                                                                        , paddr_width_p
                                                                        , cce_block_size_in_bits_lp
                                                                        )
   , localparam cce_lce_cmd_width_lp       = `bp_cce_lce_cmd_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   , lce_assoc_p
                                                                   )
   , localparam cce_lce_data_cmd_width_lp  = `bp_cce_lce_data_cmd_width(num_cce_p
                                                                       , num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )
   , localparam lce_lce_tr_resp_width_lp   = `bp_lce_lce_tr_resp_width(num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )                                                               
   , localparam proc_cfg_width_lp          = `bp_proc_cfg_width(core_els_p, num_lce_p)

   , localparam fu_op_width_lp             = `bp_be_fu_op_width

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam eaddr_width_lp    = rv64_eaddr_width_gp
   )
  (input                                     clk_i
   , input                                   reset_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_ready_o

   , output                                  fe_queue_clr_o
   , output                                  fe_queue_dequeue_o
   , output                                  fe_queue_rollback_o
 
   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]            fe_cmd_o
   , output                                  fe_cmd_v_o
   , input                                   fe_cmd_ready_i

   // LCE-CCE interface
   , output [lce_cce_req_width_lp-1:0]       lce_req_o
   , output                                  lce_req_v_o
   , input                                   lce_req_ready_i

   , output [lce_cce_resp_width_lp-1:0]      lce_resp_o
   , output                                  lce_resp_v_o
   , input                                   lce_resp_ready_i                                 

   , output [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   , output                                  lce_data_resp_v_o
   , input                                   lce_data_resp_ready_i

   , input [cce_lce_cmd_width_lp-1:0]        lce_cmd_i
   , input                                   lce_cmd_v_i
   , output                                  lce_cmd_ready_o

   , input [cce_lce_data_cmd_width_lp-1:0]   lce_data_cmd_i
   , input                                   lce_data_cmd_v_i
   , output                                  lce_data_cmd_ready_o

   , input [lce_lce_tr_resp_width_lp-1:0]    lce_tr_resp_i
   , input                                   lce_tr_resp_v_i
   , output                                  lce_tr_resp_ready_o

   , output [lce_lce_tr_resp_width_lp-1:0]   lce_tr_resp_o
   , output                                  lce_tr_resp_v_o
   , input                                   lce_tr_resp_ready_i

   // Processor configuration
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i

   // Commit tracer for trace replay
   , output                                  cmt_rd_w_v_o
   , output [reg_addr_width_lp-1:0]          cmt_rd_addr_o
   , output                                  cmt_mem_w_v_o
   , output [eaddr_width_lp-1:0]             cmt_mem_addr_o
   , output [fu_op_width_lp-1:0]             cmt_mem_op_o
   , output [reg_data_width_lp-1:0]          cmt_data_o
   );

// Declare parameterized structures
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Casting
bp_proc_cfg_s proc_cfg;

assign proc_cfg = proc_cfg_i;

// Top-level interface connections
bp_be_issue_pkt_s issue_pkt;
logic issue_pkt_v, issue_pkt_rdy;

bp_be_mmu_cmd_s mmu_cmd;
logic mmu_cmd_v, mmu_cmd_rdy;

bp_be_mmu_resp_s mmu_resp;
logic mmu_resp_v, mmu_resp_rdy;

bp_be_calc_status_s    calc_status;

logic chk_dispatch_v, chk_poison_ex1, chk_poison_ex2, chk_poison_ex3, chk_roll, chk_instr_dequeue_v;

logic [reg_data_width_lp-1:0] chk_mtvec_li, chk_mtvec_lo;
logic                         chk_mtvec_w_v_li;

logic [reg_data_width_lp-1:0] chk_mepc_li, chk_mepc_lo;
logic                         chk_mepc_w_v_li;

// Module instantiations
bp_be_checker_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

   ,.load_to_use_forwarding_p(load_to_use_forwarding_p)
   )
 be_checker
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.chk_dispatch_v_o(chk_dispatch_v)
   ,.chk_roll_o(chk_roll)
   ,.chk_poison_ex1_o(chk_poison_ex1)
   ,.chk_poison_ex2_o(chk_poison_ex2)
   ,.chk_poison_ex3_o(chk_poison_ex3)

   ,.calc_status_i(calc_status)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_ready_i)

   ,.chk_roll_fe_o(fe_queue_rollback_o)
   ,.chk_flush_fe_o(fe_queue_clr_o)
   ,.chk_dequeue_fe_o(fe_queue_dequeue_o)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_ready_o(fe_queue_ready_o)

   ,.issue_pkt_o(issue_pkt)
   ,.issue_pkt_v_o(issue_pkt_v)
   ,.issue_pkt_ready_i(issue_pkt_rdy)

   ,.mtvec_i(chk_mtvec_li)
   ,.mtvec_w_v_i(chk_mtvec_w_v_li)
   ,.mtvec_o(chk_mtvec_lo)

   ,.mepc_i(chk_mepc_li)
   ,.mepc_w_v_i(chk_mepc_w_v_li)
   ,.mepc_o(chk_mepc_lo)
   );

bp_be_calculator_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   
   ,.load_to_use_forwarding_p(load_to_use_forwarding_p)
   ,.trace_p(trace_p)

   ,.core_els_p(core_els_p)
   ,.num_lce_p(num_lce_p)
   ,.lce_sets_p(lce_sets_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   )
 be_calculator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.issue_pkt_i(issue_pkt)
   ,.issue_pkt_v_i(issue_pkt_v)
   ,.issue_pkt_ready_o(issue_pkt_rdy)
   
   ,.chk_dispatch_v_i(chk_dispatch_v)

   ,.chk_roll_i(chk_roll)
   ,.chk_poison_ex1_i(chk_poison_ex1)
   ,.chk_poison_ex2_i(chk_poison_ex2)
   ,.chk_poison_ex3_i(chk_poison_ex3)

   ,.calc_status_o(calc_status)

   ,.mmu_cmd_o(mmu_cmd)
   ,.mmu_cmd_v_o(mmu_cmd_v)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.mmu_resp_i(mmu_resp) 
   ,.mmu_resp_v_i(mmu_resp_v)
   ,.mmu_resp_ready_o(mmu_resp_rdy)   

   ,.proc_cfg_i(proc_cfg_i)     

   ,.cmt_rd_w_v_o(cmt_rd_w_v_o)
   ,.cmt_rd_addr_o(cmt_rd_addr_o)
   ,.cmt_mem_w_v_o(cmt_mem_w_v_o)
   ,.cmt_mem_addr_o(cmt_mem_addr_o)
   ,.cmt_mem_op_o(cmt_mem_op_o)
   ,.cmt_data_o(cmt_data_o)

   ,.mtvec_o(chk_mtvec_li)
   ,.mtvec_w_v_o(chk_mtvec_w_v_li)
   ,.mtvec_i(chk_mtvec_lo)

   ,.mepc_o(chk_mepc_li)
   ,.mepc_w_v_o(chk_mepc_w_v_li)
   ,.mepc_i(chk_mepc_lo)
   );

bp_be_mmu_top
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   )
 be_mmu
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.mmu_cmd_i(mmu_cmd)
    ,.mmu_cmd_v_i(mmu_cmd_v)
    ,.mmu_cmd_ready_o(mmu_cmd_rdy)

    ,.chk_poison_ex_i(chk_poison_ex2)

    ,.mmu_resp_o(mmu_resp)
    ,.mmu_resp_v_o(mmu_resp_v)
    ,.mmu_resp_ready_i(mmu_resp_rdy)      

    ,.lce_req_o(lce_req_o)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_resp_o)
    ,.lce_resp_v_o(lce_resp_v_o)
    ,.lce_resp_ready_i(lce_resp_ready_i)        

    ,.lce_data_resp_o(lce_data_resp_o)
    ,.lce_data_resp_v_o(lce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_ready_o(lce_cmd_ready_o)

    ,.lce_data_cmd_i(lce_data_cmd_i)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

    ,.lce_tr_resp_i(lce_tr_resp_i)
    ,.lce_tr_resp_v_i(lce_tr_resp_v_i)
    ,.lce_tr_resp_ready_o(lce_tr_resp_ready_o)

    ,.lce_tr_resp_o(lce_tr_resp_o)
    ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
    ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)

    ,.dcache_id_i(proc_cfg.dcache_id)
    );

endmodule : bp_be_top


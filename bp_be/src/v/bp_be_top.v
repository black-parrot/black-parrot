/**
 *
 *  Name:
 *    bp_be_top.v
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

   , parameter num_core_p                  = "inv"

   , parameter load_to_use_forwarding_p    = 1
   , parameter trace_p                     = 0
   , parameter calc_debug_p                = 0
   , parameter calc_debug_file_p           = "calc_debug.log"

   // MMU parameters
   , parameter num_cce_p                   = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_assoc_p                 = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter cce_block_size_in_bytes_p   = "inv"
 
   // Generated parameters
   , localparam lce_data_width_lp = cce_block_size_in_bytes_p * 8
   , localparam fe_queue_width_lp          = `bp_fe_queue_width(vaddr_width_p
                                                                , branch_metadata_fwd_width_p)
   , localparam fe_cmd_width_lp            = `bp_fe_cmd_width(vaddr_width_p
                                                              , paddr_width_p
                                                              , asid_width_p
                                                              , branch_metadata_fwd_width_p
                                                              )
  , parameter data_width_p = rv64_reg_data_width_gp

    , localparam lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p, num_lce_p, paddr_width_p,lce_assoc_p, data_width_p)
    , localparam lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p, num_lce_p, paddr_width_p)
    , localparam lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, paddr_width_p, lce_data_width_lp)
    , localparam cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p)
    , localparam lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p, lce_data_width_lp, lce_assoc_p)


   , localparam proc_cfg_width_lp          = `bp_proc_cfg_width(num_core_p, num_lce_p)

   , localparam fu_op_width_lp             = `bp_be_fu_op_width

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam eaddr_width_lp    = rv64_eaddr_width_gp
   , localparam instr_width_lp    = rv64_instr_width_gp
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

   , input [lce_data_cmd_width_lp-1:0]   lce_data_cmd_i
   , input                                   lce_data_cmd_v_i
   , output                                  lce_data_cmd_ready_o

   , output [lce_data_cmd_width_lp-1:0]   lce_data_cmd_o
   , output                                   lce_data_cmd_v_o
   , input                                  lce_data_cmd_ready_i

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
`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
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

bp_be_csr_cmd_s csr_cmd;
logic csr_cmd_v, csr_cmd_rdy;

bp_be_mem_resp_s mem_resp;
logic mem_resp_v, mem_resp_rdy;

bp_be_calc_status_s    calc_status;

logic chk_dispatch_v, chk_poison_isd;
logic chk_poison_ex1, chk_poison_ex2, chk_poison_ex3, chk_roll, chk_instr_dequeue_v;

logic [reg_data_width_lp-1:0] chk_mtvec_li;
logic [reg_data_width_lp-1:0] chk_mepc_li;

logic                      instret;
logic [vaddr_width_p-1:0]  exception_pc;
logic [instr_width_lp-1:0] exception_instr;
logic                      exception_v;

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
   ,.chk_poison_isd_o(chk_poison_isd)
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

   ,.mepc_i(chk_mepc_li)
   ,.mtvec_i(chk_mtvec_li)
   );

bp_be_calculator_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   
   ,.load_to_use_forwarding_p(load_to_use_forwarding_p)
   ,.trace_p(trace_p)
   ,.debug_p(calc_debug_p)
   ,.debug_file_p(calc_debug_file_p)

   ,.num_core_p(num_core_p)
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
   ,.chk_poison_isd_i(chk_poison_isd)
   ,.chk_poison_ex1_i(chk_poison_ex1)
   ,.chk_poison_ex2_i(chk_poison_ex2)
   ,.chk_poison_ex3_i(chk_poison_ex3)

   ,.calc_status_o(calc_status)

   ,.mmu_cmd_o(mmu_cmd)
   ,.mmu_cmd_v_o(mmu_cmd_v)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.csr_cmd_o(csr_cmd)
   ,.csr_cmd_v_o(csr_cmd_v)
   ,.csr_cmd_ready_i(csr_cmd_rdy)

   ,.mem_resp_i(mem_resp) 
   ,.mem_resp_v_i(mem_resp_v)
   ,.mem_resp_ready_o(mem_resp_rdy)   

   ,.proc_cfg_i(proc_cfg_i)

   ,.instret_o(instret)
   ,.exception_pc_o(exception_pc)
   ,.exception_instr_o(exception_instr)
   ,.exception_v_o(exception_v)

   ,.cmt_rd_w_v_o(cmt_rd_w_v_o)
   ,.cmt_rd_addr_o(cmt_rd_addr_o)
   ,.cmt_mem_w_v_o(cmt_mem_w_v_o)
   ,.cmt_mem_addr_o(cmt_mem_addr_o)
   ,.cmt_mem_op_o(cmt_mem_op_o)
   ,.cmt_data_o(cmt_data_o)
   );

bp_be_mem_top
 #(.num_core_p(num_core_p)
   ,.vaddr_width_p(vaddr_width_p)
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

    ,.proc_cfg_i(proc_cfg_i)

    ,.chk_poison_ex_i(chk_poison_ex2)

    ,.mmu_cmd_i(mmu_cmd)
    ,.mmu_cmd_v_i(mmu_cmd_v)
    ,.mmu_cmd_ready_o(mmu_cmd_rdy)

    ,.csr_cmd_i(csr_cmd)
    ,.csr_cmd_v_i(csr_cmd_v)
    ,.csr_cmd_ready_o(csr_cmd_rdy)

    ,.mem_resp_o(mem_resp)
    ,.mem_resp_v_o(mem_resp_v)
    ,.mem_resp_ready_i(mem_resp_rdy)

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

    ,.lce_data_cmd_o(lce_data_cmd_o)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

    ,.instret_i(instret)
    ,.exception_pc_i(exception_pc)
    ,.exception_instr_i(exception_instr)
    ,.exception_v_i(exception_v)

    ,.mepc_o(chk_mepc_li)
    ,.mtvec_o(chk_mtvec_li)
    );

endmodule : bp_be_top


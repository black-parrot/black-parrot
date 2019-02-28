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
 *   fe_queue_rdy_o              -
 *
 *   cce_lce_cmd_i               -
 *   cce_lce_cmd_v_i             -
 *   cce_lce_cmd_rdy_o           -
 *
 *   cce_lce_data_cmd_i          -
 *   cce_lce_data_cmd_v_i        -
 *   cce_lce_data_cmd_rdy_o      -
 * 
 *   lce_lce_tr_resp_i           - 
 *   lce_lce_tr_resp_v_i         -
 *   lce_lce_tr_resp_rdy_o       -
 * 
 *   proc_cfg_i                  -
 *
 * Outputs:
 *   fe_cmd_o                    -
 *   fe_cmd_v_o                  -
 *   fe_cmd_rdy_i                -
 *
 *   fe_queue_clr_o              -
 *   fe_queue_dequeue_inc_o      -
 *   fe_queue_rollback_o         -
 *
 *   lce_cce_req_o               -
 *   lce_cce_req_v_o             -
 *   lce_cce_req_rdy_i           -
 *
 *   lce_cce_resp_o              -
 *   lce_cce_resp_v_o            -
 *   lce_cce_resp_rdy_i          -
 *
 *   lce_cce_data_resp_o         -
 *   lce_cce_data_resp_v_o       -
 *   lce_cce_data_resp_rdy_i     -
 *
 *   lce_lce_tr_resp_o           -
 *   lce_lce_tr_resp_v_o         -
 *   lce_lce_tr_resp_rdy_i       -
 *
 *   cmt_trace_stage_reg_o       -
 *   cmt_trace_result_o          -
 *   cmt_trace_exc_o             -
 *
 * Keywords:
 *   be, top
 * 
 * Notes:
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

   , localparam pipe_stage_reg_width_lp    = `bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp       = `bp_be_calc_result_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp         = `bp_be_exception_width
   )
  (input                                     clk_i
   , input                                   reset_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_rdy_o

   , output                                  fe_queue_clr_o
   , output                                  fe_queue_dequeue_o
   , output                                  fe_queue_rollback_o
 
   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]            fe_cmd_o
   , output                                  fe_cmd_v_o
   , input                                   fe_cmd_rdy_i

   // LCE-CCE interface
   , output [lce_cce_req_width_lp-1:0]       lce_cce_req_o
   , output                                  lce_cce_req_v_o
   , input                                   lce_cce_req_rdy_i

   , output [lce_cce_resp_width_lp-1:0]      lce_cce_resp_o
   , output                                  lce_cce_resp_v_o
   , input                                   lce_cce_resp_rdy_i                                 

   , output [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o
   , output                                  lce_cce_data_resp_v_o
   , input                                   lce_cce_data_resp_rdy_i

   , input [cce_lce_cmd_width_lp-1:0]        cce_lce_cmd_i
   , input                                   cce_lce_cmd_v_i
   , output                                  cce_lce_cmd_rdy_o

   , input [cce_lce_data_cmd_width_lp-1:0]   cce_lce_data_cmd_i
   , input                                   cce_lce_data_cmd_v_i
   , output                                  cce_lce_data_cmd_rdy_o

   , input [lce_lce_tr_resp_width_lp-1:0]    lce_lce_tr_resp_i
   , input                                   lce_lce_tr_resp_v_i
   , output                                  lce_lce_tr_resp_rdy_o

   , output [lce_lce_tr_resp_width_lp-1:0]   lce_lce_tr_resp_o
   , output                                  lce_lce_tr_resp_v_o
   , input                                   lce_lce_tr_resp_rdy_i

   // Processor configuration
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i

   // Commit tracer
   , output [pipe_stage_reg_width_lp-1:0]    cmt_trace_stage_reg_o
   , output [calc_result_width_lp-1:0]       cmt_trace_result_o
   , output [exception_width_lp-1:0]         cmt_trace_exc_o
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
bp_be_exception_s      cmt_trace_exc;
bp_be_pipe_stage_reg_s cmt_trace_stage_reg;
bp_be_calc_result_s    cmt_trace_result;

logic chk_dispatch_v, chk_psn_isd, chk_psn_ex, chk_roll, chk_instr_dequeue_v;

// Module instantiations
bp_be_checker_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   )
 be_checker
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.chk_dispatch_v_o(chk_dispatch_v)
   ,.chk_roll_o(chk_roll)
   ,.chk_poison_isd_o(chk_psn_isd)
   ,.chk_poison_ex_o(chk_psn_ex)

   ,.calc_status_i(calc_status)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_rdy_i)

   ,.chk_roll_fe_o(fe_queue_rollback_o)
   ,.chk_flush_fe_o(fe_queue_clr_o)
   ,.chk_dequeue_fe_o(fe_queue_dequeue_o)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_ready_o(fe_queue_rdy_o)

   ,.issue_pkt_o(issue_pkt)
   ,.issue_pkt_v_o(issue_pkt_v)
   ,.issue_pkt_ready_i(issue_pkt_rdy)
   );

// STD: TODO -- remove synth hack and find real solution
wire [`bp_be_fu_op_width-1:0] decoded_fu_op_n;
reg  [`bp_be_fu_op_width-1:0] decoded_fu_op_r;

// STD: TODO -- remove synth hack and find real solution
always_ff @(posedge clk_i)
  begin
    decoded_fu_op_r <= decoded_fu_op_n;
  end

bp_be_calculator_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

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
   ,.chk_poison_ex_i(chk_psn_ex)
   ,.chk_poison_isd_i(chk_psn_isd)

   ,.calc_status_o(calc_status)

   ,.mmu_cmd_o(mmu_cmd)
   ,.mmu_cmd_v_o(mmu_cmd_v)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.mmu_resp_i(mmu_resp) 
   ,.mmu_resp_v_i(mmu_resp_v)
   ,.mmu_resp_ready_o(mmu_resp_rdy)   

   ,.proc_cfg_i(proc_cfg_i)     

   ,.cmt_trace_stage_reg_o(cmt_trace_stage_reg_o)
   ,.cmt_trace_result_o(cmt_trace_result_o)
   ,.cmt_trace_exc_o(cmt_trace_exc_o)

    // STD: TODO -- remove synth hack and find real solution
   ,.decoded_fu_op_o(decoded_fu_op_n)
    );

// STD: TODO -- remove synth hack and find real solution
localparam mmu_sub_width_lp = $bits(mmu_cmd)-`bp_be_fu_op_width;

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

    // STD: TODO -- remove synth hack and find real solution
    ,.mmu_cmd_i({decoded_fu_op_r, mmu_cmd[mmu_sub_width_lp-1:0]})
    ,.mmu_cmd_v_i(mmu_cmd_v)
    ,.mmu_cmd_ready_o(mmu_cmd_rdy)

    ,.chk_psn_ex_i(chk_psn_ex)

    ,.mmu_resp_o(mmu_resp)
    ,.mmu_resp_v_o(mmu_resp_v)
    ,.mmu_resp_ready_i(mmu_resp_rdy)      

    ,.lce_req_o(lce_cce_req_o)
    ,.lce_req_v_o(lce_cce_req_v_o)
    ,.lce_req_ready_i(lce_cce_req_rdy_i)

    ,.lce_resp_o(lce_cce_resp_o)
    ,.lce_resp_v_o(lce_cce_resp_v_o)
    ,.lce_resp_ready_i(lce_cce_resp_rdy_i)        

    ,.lce_data_resp_o(lce_cce_data_resp_o)
    ,.lce_data_resp_v_o(lce_cce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_cce_data_resp_rdy_i)

    ,.lce_cmd_i(cce_lce_cmd_i)
    ,.lce_cmd_v_i(cce_lce_cmd_v_i)
    ,.lce_cmd_ready_o(cce_lce_cmd_rdy_o)

    ,.lce_data_cmd_i(cce_lce_data_cmd_i)
    ,.lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
    ,.lce_data_cmd_ready_o(cce_lce_data_cmd_rdy_o)

    ,.lce_tr_resp_i(lce_lce_tr_resp_i)
    ,.lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
    ,.lce_tr_resp_ready_o(lce_lce_tr_resp_rdy_o)

    ,.lce_tr_resp_o(lce_lce_tr_resp_o)
    ,.lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
    ,.lce_tr_resp_ready_i(lce_lce_tr_resp_rdy_i)

    ,.dcache_id_i(proc_cfg.dcache_id)
    );

endmodule : bp_be_top


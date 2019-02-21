/**
 *
 * test_bp.v
 *
 */

module test_bp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
   , parameter btb_indx_width_p            = "inv"
   , parameter bht_indx_width_p            = "inv"
   , parameter ras_addr_width_p            = "inv"
   , parameter core_els_p                  = "inv"
   , parameter num_cce_p                   = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter lce_assoc_p                 = "inv"
   , parameter cce_block_size_in_bytes_p   = "inv"
   , parameter cce_num_inst_ram_els_p      = "inv"

   , parameter boot_rom_width_p            = "inv"
   , parameter boot_rom_els_p              = "inv"
   , localparam lg_boot_rom_els_lp         = `BSG_SAFE_CLOG2(boot_rom_els_p)
   
   // Trace replay parameters
   , parameter trace_ring_width_p          = "inv"
   , parameter trace_rom_addr_width_p      = "inv"
   , localparam trace_rom_data_width_lp    = trace_ring_width_p + 4

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam byte_width_lp     = rv64_byte_width_gp
 );

// Declare parameterized structs
`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    );
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

logic clk, reset;

logic [num_cce_p-1:0][lg_boot_rom_els_lp-1:0] boot_rom_addr;
logic [num_cce_p-1:0][boot_rom_width_p-1:0]   boot_rom_data;

bp_be_pipe_stage_reg_s[core_els_p-1:0] cmt_trace_stage_reg;
bp_be_calc_result_s   [core_els_p-1:0] cmt_trace_result;
bp_be_exception_s     [core_els_p-1:0] cmt_trace_exc;

logic [trace_ring_width_p-1:0]      tr_data_i;
logic                               tr_v_i, tr_ready_o;
logic [trace_rom_addr_width_p-1:0]  tr_rom_addr_i;
logic [trace_rom_data_width_lp-1:0] tr_rom_data_o;
logic test_done;

bsg_nonsynth_clock_gen 
 #(.cycle_time_p(10))
 clock_gen 
  (.o(clk));

bsg_nonsynth_reset_gen 
 #(.num_clocks_p(1)
   ,.reset_cycles_lo_p(1)
   ,.reset_cycles_hi_p(10)
   )
 reset_gen
  (.clk_i(clk)
   ,.async_reset_o(reset)
   );

bp_multi_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   ,.btb_indx_width_p(btb_indx_width_p)
   ,.bht_indx_width_p(bht_indx_width_p)
   ,.ras_addr_width_p(ras_addr_width_p)
   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.lce_sets_p(lce_sets_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.cce_num_inst_ram_els_p(cce_num_inst_ram_els_p)

   ,.boot_rom_width_p(boot_rom_width_p)
   ,.boot_rom_els_p(boot_rom_els_p)
   )
 dut
  (.clk_i(clk)
   ,.reset_i(reset)

   ,.boot_rom_addr_o(boot_rom_addr)
   ,.boot_rom_data_i(boot_rom_data)

   ,.cmt_trace_stage_reg_o(cmt_trace_stage_reg)
   ,.cmt_trace_result_o(cmt_trace_result)
   ,.cmt_trace_exc_o(cmt_trace_exc)
   );

bp_be_trace_replay_gen 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   ,.trace_ring_width_p(trace_ring_width_p)
   )
 be_trace_gen
  (.clk_i(clk)
   ,.reset_i(reset)

   ,.cmt_trace_stage_reg_i(cmt_trace_stage_reg)
   ,.cmt_trace_result_i(cmt_trace_result)
   ,.cmt_trace_exc_i(cmt_trace_exc)

   ,.data_o(tr_data_i)
   ,.v_o(tr_v_i)
   ,.ready_i(tr_ready_o)
   );

bsg_fsb_node_trace_replay 
 #(.ring_width_p(trace_ring_width_p)
   ,.rom_addr_width_p(trace_rom_addr_width_p)
   )
 be_trace_replay 
  (.clk_i(clk)
   ,.reset_i(reset)
   ,.en_i(1'b1)
                    
   ,.v_i(tr_v_i)
   ,.data_i(tr_data_i)
   ,.ready_o(tr_ready_o)
         
   ,.v_o()
   ,.data_o()
   ,.yumi_i(1'b0)
         
   ,.rom_addr_o(tr_rom_addr_i)
   ,.rom_data_i(tr_rom_data_o)
         
   ,.done_o(test_done)
   ,.error_o()
   );

bp_trace_rom 
 #(.width_p(trace_rom_data_width_lp)
   ,.addr_width_p(trace_rom_addr_width_p)
   )
 trace_rom 
  (.addr_i(tr_rom_addr_i)
   ,.data_o(tr_rom_data_o)
   );

for (genvar i = 0; i < num_cce_p; i++)
  begin : rof1
    bp_boot_rom 
     #(.width_p(boot_rom_width_p)
       ,.addr_width_p(lg_boot_rom_els_lp)
       ) 
     me_boot_rom 
      (.addr_i(boot_rom_addr[i])
       ,.data_o(boot_rom_data[i])
       );
  end // rof1

always_ff @(posedge clk) 
  begin
    if (test_done) 
      begin
        $display("Test PASSed!");
        $finish(0);
      end
  end

endmodule : test_bp


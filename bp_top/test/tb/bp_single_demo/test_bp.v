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

   , localparam reg_data_width_lp          = rv64_reg_data_width_gp
   , localparam byte_width_lp              = rv64_byte_width_gp
 );

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

bp_proc_cfg_s proc_cfg;

always_comb
  begin
    proc_cfg.mhartid   = 1'b0;
    proc_cfg.icache_id = 1'b0;
    proc_cfg.dcache_id = 1'b1;
  end

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
 DUT
  (.clk_i(clk)
   ,.reset_i(reset)

   ,.boot_rom_addr_o(boot_rom_addr)
   ,.boot_rom_data_i(boot_rom_data)

   ,.cmt_trace_stage_reg_o(cmt_trace_stage_reg)
   ,.cmt_trace_result_o(cmt_trace_result)
   ,.cmt_trace_exc_o(cmt_trace_exc)
   );

for (genvar i = 0; i < core_els_p; i++)
  begin : rof1
    bp_be_nonsynth_tracer
     #(.vaddr_width_p(vaddr_width_p)
       ,.paddr_width_p(paddr_width_p)
       ,.asid_width_p(asid_width_p)
       ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
       ,.core_els_p(core_els_p)
       ,.num_lce_p(num_lce_p)
       )
     tracer
     (.clk_i(clk)
      ,.reset_i(reset)
    
      ,.proc_cfg_i(proc_cfg)
    
      ,.cmt_trace_stage_reg_i(cmt_trace_stage_reg[i])
      ,.cmt_trace_result_i(cmt_trace_result[i])
      ,.cmt_trace_exc_i(cmt_trace_exc[i])
      );
  end // rof1

for (genvar i = 0; i < num_cce_p; i++)
  begin : rof2
    bp_boot_rom 
     #(.width_p(boot_rom_width_p)
       ,.addr_width_p(lg_boot_rom_els_lp)
       ) 
     me_boot_rom 
      (.addr_i(boot_rom_addr[i])
       ,.data_o(boot_rom_data[i])
       );
  end // rof2

endmodule : test_bp


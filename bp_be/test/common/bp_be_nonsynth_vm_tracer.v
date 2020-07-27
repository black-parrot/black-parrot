
module bp_be_nonsynth_vm_tracer
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_fe_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter vm_trace_file_p = "vm"

   , localparam itlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   , localparam dtlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                             clk_i
   , input                           reset_i
   , input                           freeze_i

   , input [core_id_width_p-1:0]     mhartid_i

   //, input                           map_v
   //, input [vtag_width_p-1:0]        vtag_i
   //, input [ptag_width_p-1:0]        ptag_i

   , input                           itlb_clear_i
   , input                           itlb_fill_v_i
   , input [vtag_width_p-1:0]        itlb_vtag_i
   , input [itlb_entry_width_lp-1:0] itlb_entry_i
   , input                           itlb_cam_r_v_i

   , input                           dtlb_clear_i
   , input                           dtlb_fill_v_i
   , input [vtag_width_p-1:0]        dtlb_vtag_i
   , input [dtlb_entry_width_lp-1:0] dtlb_entry_i
   , input                           dtlb_cam_r_v_i

   //, input                           sfence_i
   //, input [rv64_priv_width_gp-1:0]  priv_i
   //, input [rv64_priv_width_gp-1:0]  shadow_priv_i

   , input [num_core_p-1:0]          program_finish_i
   );

  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_fe_mem_structs(vaddr_width_p, lce_sets_p, cce_block_width_p, vtag_width_p, ptag_width_p)
  `declare_bp_be_mem_structs(vaddr_width_p, paddr_width_p, lce_sets_p, cce_block_width_p/8)
  bp_fe_tlb_entry_s   itlb_w_entry;
  bp_pte_entry_leaf_s dtlb_w_entry;

  assign itlb_w_entry = itlb_entry_i;
  assign dtlb_w_entry = dtlb_entry_i;

  integer file;
  string file_name;

  logic [63:0] itlb_read_count_r;
  logic [63:0] dtlb_read_count_r;

  wire delay_li = reset_i | freeze_i;
  always_ff @(negedge delay_li)
    begin
      file_name = $sformatf("%s_%x.trace", vm_trace_file_p, mhartid_i);
      file      = $fopen(file_name, "w");
    end

  always_ff @(negedge clk_i)
    begin
      if (itlb_clear_i)
        $fwrite(file, "[%t] ITLB Clear\n", $time);
      if (itlb_fill_v_i)
        $fwrite(file, "[%t] ITLB map %x -> %x [R:%x W:%x X:%x]\n" //A:%x D:%x]"
                ,$time
                ,itlb_vtag_i
                ,itlb_w_entry.ptag
                ,itlb_w_entry.r
                ,itlb_w_entry.w
                ,itlb_w_entry.x
                //,itlb_w_entry.a
                //,itlb_w_entry.d
                );
      if (dtlb_clear_i)
        $fwrite(file, "[%t] DTLB Clear\n", $time);
      if (dtlb_fill_v_i)
        $fwrite(file, "[%t] DTLB map %x -> %x [R:%x W:%x X:%x]\n" //A:%x D:%x]"
                ,$time
                ,dtlb_vtag_i
                ,dtlb_w_entry.ptag
                ,dtlb_w_entry.r
                ,dtlb_w_entry.w
                ,dtlb_w_entry.x
                //,dtlb_w_entry.a
                //,dtlb_w_entry.d
                );
    end

  // the following counters count how often itlb and dtlb are read
  always_ff @(posedge clk_i)
    begin
      if (reset_i)
        begin
          itlb_read_count_r <= '0;
          dtlb_read_count_r <= '0;
        end
      else if (program_finish_i)
        begin
          $fwrite(file, "[%t] Total ITLB read access count is %0d.\n", $time, itlb_read_count_r);
          $fwrite(file, "[%t] Total DTLB read access count is %0d.\n", $time, dtlb_read_count_r);
        end
      else
        begin
          itlb_read_count_r <= itlb_cam_r_v_i + itlb_read_count_r;
          dtlb_read_count_r <= dtlb_cam_r_v_i + dtlb_read_count_r;
        end
    end

endmodule


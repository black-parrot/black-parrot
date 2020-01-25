
module bp_nonsynth_if_verif
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_io_if_widths(paddr_width_p, dword_width_p, lce_id_width_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   )
  ();

bp_proc_param_s proc_param;
assign proc_param = all_cfgs_gp[bp_params_p];

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
`declare_bp_io_if(paddr_width_p, dword_width_p, lce_id_width_p);

initial 
  begin
    $display("########### BP Parameters ##############");
    $display("bp_proc_param_s %p", proc_param);
    $display("########### TOP IF ##############");
    $display("bp_cfg_bus_s          bits: struct %d width %d", $bits(bp_cfg_bus_s), cfg_bus_width_lp);

    $display("########### FE-BE IF ##############");
    $display("bp_fe_queue_s          bits: struct %d width %d", $bits(bp_fe_queue_s), fe_queue_width_lp);
    $display("bp_fe_cmd_s            bits: struct %d width %d", $bits(bp_fe_cmd_s), fe_cmd_width_lp);

    $display("########### LCE-CCE IF ##############");
    $display("bp_lce_cce_req_s       bits: struct %d width %d", $bits(bp_lce_cce_req_s), lce_cce_req_width_lp);
    $display("bp_lce_cmd_s           bits: struct %d width %d", $bits(bp_lce_cmd_s), lce_cmd_width_lp);
    $display("bp_lce_cce_resp_s      bits: struct %d width %d", $bits(bp_lce_cce_resp_s), lce_cce_resp_width_lp);

    $display("########### CCE-MEM IF ##############");
    $display("bp_cce_mem_msg_s       bits: struct %d width %d", $bits(bp_cce_mem_msg_s), cce_mem_msg_width_lp);

    $display("########### CCE IO IF  ##############");
    $display("bp_cce_io_msg_s        bits: struct %d width %d", $bits(bp_cce_io_msg_s), cce_io_msg_width_lp);

    if (!(num_cce_p inside {1,2,3,4,6,7,8,12,14,15,16,24,28,30,31,32})) begin
      $fatal("Error: unsupported number of CCE's");
    end

  end

  if (ic_y_dim_p != 1)
    $fatal("Error: Must have exactly 1 row of I/O routers");
  if (mc_y_dim_p != 0)
    $fatal("Error: L2 expansion nodes not yet supported, MC must have 0 rows");
/*  if (ac_x_dim_p != 0)
    $fatal("Error: CAC not yet supported");
*/
  if (vaddr_width_p != 39)
    $warning("Warning: VM will not work without 39 bit vaddr");
  if (paddr_width_p != 40)
    $warning("Warning: paddr != 40 has not been tested");

endmodule


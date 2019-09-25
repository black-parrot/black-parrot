
module bp_nonsynth_if_verif
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_fe_be_if_widths
     (vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)
   `declare_bp_lce_cce_if_widths
     (num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths
     (paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
   )
  ();

bp_proc_param_s proc_param;
assign proc_param = all_cfgs_gp[cfg_p];

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p);
`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);

initial 
  begin
    $display("########### BP Parameters ##############");
    $display("bp_proc_param_s %p", proc_param);
    $display("########### TOP IF ##############");
    $display("bp_proc_cfg_s          bits: struct %d width %d", $bits(bp_proc_cfg_s), proc_cfg_width_lp);

    $display("########### FE-BE IF ##############");
    $display("bp_fe_queue_s          bits: struct %d width %d", $bits(bp_fe_queue_s), fe_queue_width_lp);
    $display("bp_fe_cmd_s            bits: struct %d width %d", $bits(bp_fe_cmd_s), fe_cmd_width_lp);

    $display("########### LCE-CCE IF ##############");
    $display("bp_lce_cce_req_s       bits: struct %d width %d", $bits(bp_lce_cce_req_s), lce_cce_req_width_lp);
    $display("bp_lce_cmd_s           bits: struct %d width %d", $bits(bp_lce_cmd_s), lce_cmd_width_lp);
    $display("bp_lce_cce_resp_s      bits: struct %d width %d", $bits(bp_lce_cce_resp_s), lce_cce_resp_width_lp);

    $display("########### CCE-MEM IF ##############");
    $display("bp_cce_mem_msg_s       bits: struct %d width %d", $bits(bp_cce_mem_msg_s), cce_mem_msg_width_lp);
  end

endmodule


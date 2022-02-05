
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_cfg_slice
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [mem_header_width_lp-1:0]                mem_cmd_header_i
   , input [bedrock_data_width_p-1:0]               mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , output logic                                   mem_cmd_ready_and_o
   , input                                          mem_cmd_last_i

   , output logic [mem_header_width_lp-1:0]         mem_resp_header_o
   , output logic [bedrock_data_width_p-1:0]        mem_resp_data_o
   , output logic                                   mem_resp_v_o
   , input                                          mem_resp_ready_and_i
   , output logic                                   mem_resp_last_o

   , output logic [cfg_bus_width_lp-1:0]            cfg_bus_o
   , input [did_width_p-1:0]                        did_i
   , input [did_width_p-1:0]                        host_did_i
   , input [coh_noc_cord_width_p-1:0]               cord_i

   // ucode programming interface, synchronous read, direct connection to RAM
   , output logic                                   cce_ucode_v_o
   , output logic                                   cce_ucode_w_o
   , output logic [cce_pc_width_p-1:0]              cce_ucode_addr_o
   , output logic [cce_instr_width_gp-1:0]          cce_ucode_data_o
   , input [cce_instr_width_gp-1:0]                 cce_ucode_data_i
   );

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_o(bp_cfg_bus_s, cfg_bus);

  logic cord_r_v_li, did_r_v_li, host_did_r_v_li, hio_mask_r_v_li;
  logic cord_w_v_li, did_w_v_li, host_did_w_v_li, hio_mask_w_v_li;
  logic cce_ucode_r_v_li, cce_mode_r_v_li, dcache_mode_r_v_li, icache_mode_r_v_li, freeze_r_v_li;
  logic cce_ucode_w_v_li, cce_mode_w_v_li, dcache_mode_w_v_li, icache_mode_w_v_li, freeze_w_v_li;
  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [8:0][dword_width_gp-1:0] data_li;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.els_p(9)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.base_addr_p({cfg_reg_cord_gp, cfg_reg_did_gp, cfg_reg_host_did_gp, cfg_reg_hio_mask_gp
                    ,cfg_reg_cce_mode_gp, cfg_reg_dcache_mode_gp, cfg_reg_icache_mode_gp
                    ,cfg_mem_cce_ucode_match_gp
                    ,cfg_reg_freeze_gp
                    })
     )
   register
    (.*
     ,.r_v_o({cord_r_v_li, did_r_v_li, host_did_r_v_li, hio_mask_r_v_li
              ,cce_mode_r_v_li, dcache_mode_r_v_li, icache_mode_r_v_li
              ,cce_ucode_r_v_li
              ,freeze_r_v_li
              })
     ,.w_v_o({cord_w_v_li, did_w_v_li, host_did_w_v_li, hio_mask_w_v_li
              ,cce_mode_w_v_li, dcache_mode_w_v_li, icache_mode_w_v_li
              ,cce_ucode_w_v_li
              ,freeze_w_v_li
              })
     ,.addr_o(addr_lo)
     ,.size_o()
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );

  logic         freeze_r;
  bp_lce_mode_e icache_mode_r;
  bp_lce_mode_e dcache_mode_r;
  bp_cce_mode_e cce_mode_r;
  logic [hio_width_p-1:0] hio_mask_r;
  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        freeze_r            <= 1'b1;
        icache_mode_r       <= e_lce_mode_uncached;
        dcache_mode_r       <= e_lce_mode_uncached;
        cce_mode_r          <= e_cce_mode_uncached;
        hio_mask_r          <= '0;
      end
    else
      begin
        freeze_r <= freeze_w_v_li ? data_lo : freeze_r;
        icache_mode_r <= icache_mode_w_v_li ? bp_lce_mode_e'(data_lo) : icache_mode_r;
        dcache_mode_r <= dcache_mode_w_v_li ? bp_lce_mode_e'(data_lo) : dcache_mode_r;
        cce_mode_r <= cce_mode_w_v_li ? bp_cce_mode_e'(data_lo) : cce_mode_r;
        hio_mask_r <= hio_mask_w_v_li ? data_lo : hio_mask_r;
      end

  // Access to CCE ucode memory must be aligned
  localparam cce_pc_offset_width_lp = `BSG_SAFE_CLOG2(`BSG_CDIV(cce_instr_width_gp,8));
  assign cce_ucode_v_o    = cce_ucode_r_v_li | cce_ucode_w_v_li;
  assign cce_ucode_w_o    = cce_ucode_w_v_li;
  assign cce_ucode_addr_o = addr_lo[cce_pc_offset_width_lp+:cce_pc_width_p];
  assign cce_ucode_data_o = data_lo[0+:cce_instr_width_gp];

  logic [core_id_width_p-1:0] core_id_li;
  logic [cce_id_width_p-1:0]  cce_id_li;
  logic [lce_id_width_p-1:0]  icache_id_li, dcache_id_li;
  bp_me_cord_to_id
   #(.bp_params_p(bp_params_p))
   id_map
    (.cord_i(cord_i)
     ,.core_id_o(core_id_li)
     ,.cce_id_o(cce_id_li)
     ,.lce_id0_o(icache_id_li)
     ,.lce_id1_o(dcache_id_li)
     );

  assign cfg_bus_cast_o = '{freeze: freeze_r
                            ,core_id: core_id_li
                            ,icache_id: icache_id_li
                            ,icache_mode: icache_mode_r
                            ,dcache_id: dcache_id_li
                            ,dcache_mode: dcache_mode_r
                            ,cce_id: cce_id_li
                            ,cce_mode: cce_mode_r
                            ,hio_mask: hio_mask_r
                            };

  assign data_li[0] = freeze_r;
  assign data_li[1] = cce_ucode_data_i;
  assign data_li[2] = icache_mode_r;
  assign data_li[3] = dcache_mode_r;
  assign data_li[4] = cce_mode_r;
  assign data_li[5] = hio_mask_r;
  assign data_li[6] = host_did_i;
  assign data_li[7] = did_i;
  assign data_li[8] = cord_i;

endmodule


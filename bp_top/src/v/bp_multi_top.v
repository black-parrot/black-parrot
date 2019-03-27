/**
 *
 * bp_multi_top.v
 *
 */

module bp_multi_top
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(// System parameters
   parameter core_els_p                    = "inv"
   , parameter vaddr_width_p               = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
   , parameter btb_indx_width_p            = "inv"
   , parameter bht_indx_width_p            = "inv"
   , parameter ras_addr_width_p            = "inv"

   // ME parameters
   , parameter num_cce_p                 = "inv"
   , parameter num_lce_p                 = "inv"
   , parameter lce_assoc_p               = "inv"
   , parameter lce_sets_p                = "inv"
   , parameter cce_block_size_in_bytes_p = "inv"
   , parameter cce_num_inst_ram_els_p    = "inv"
 
   // Generated parameters
   , localparam lg_core_els_p      = `BSG_SAFE_CLOG2(core_els_p)
   , localparam lg_num_lce_p       = `BSG_SAFE_CLOG2(num_lce_p)
   , localparam mhartid_width_lp   = `BSG_SAFE_CLOG2(core_els_p)
   , localparam lce_id_width_lp    = `BSG_SAFE_CLOG2(num_lce_p)

   , localparam cce_block_size_in_bits_lp = 8*cce_block_size_in_bytes_p
   , localparam fe_queue_width_lp         =`bp_fe_queue_width(vaddr_width_p
                                                              , branch_metadata_fwd_width_p
                                                              )
   , localparam fe_cmd_width_lp           =`bp_fe_cmd_width(vaddr_width_p
                                                            , paddr_width_p
                                                            , asid_width_p
                                                            , branch_metadata_fwd_width_p
                                                            )
   , localparam proc_cfg_width_lp         = `bp_proc_cfg_width(core_els_p, num_lce_p)

   , localparam icache_lce_id_lp          = 0 // Base ID for icache
   , localparam dcache_lce_id_lp          = 1 // Base ID for dcache

   , localparam cce_inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(cce_num_inst_ram_els_p)


   , localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p
                                                                 ,num_lce_p
                                                                 ,lce_assoc_p)

   , localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p
                                                                           ,cce_block_size_in_bits_lp
                                                                           ,num_lce_p
                                                                           ,lce_assoc_p)

   , localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p
                                                               ,num_lce_p
                                                               ,lce_assoc_p)

   , localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p
                                                                         ,cce_block_size_in_bits_lp
                                                                         ,num_lce_p
                                                                         ,lce_assoc_p)
   , localparam fu_op_width_lp=`bp_be_fu_op_width

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam eaddr_width_lp    = rv64_eaddr_width_gp

   )
  (input                                                      clk_i
   , input                                                    reset_i

   , output logic [cce_inst_ram_addr_width_lp-1:0]            cce_inst_boot_rom_addr_o
   , input logic [`bp_cce_inst_width-1:0]                     cce_inst_boot_rom_data_i

   , input [num_cce_p-1:0][bp_mem_cce_resp_width_lp-1:0]      mem_resp_i
   , input [num_cce_p-1:0]                                    mem_resp_v_i
   , output [num_cce_p-1:0]                                   mem_resp_ready_o

   , input [num_cce_p-1:0][bp_mem_cce_data_resp_width_lp-1:0] mem_data_resp_i
   , input [num_cce_p-1:0]                                    mem_data_resp_v_i
   , output [num_cce_p-1:0]                                   mem_data_resp_ready_o

   , output [num_cce_p-1:0][bp_cce_mem_cmd_width_lp-1:0]      mem_cmd_o
   , output [num_cce_p-1:0]                                   mem_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_cmd_yumi_i

   , output [num_cce_p-1:0][bp_cce_mem_data_cmd_width_lp-1:0] mem_data_cmd_o
   , output [num_cce_p-1:0]                                   mem_data_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_data_cmd_yumi_i

   // Commit tracer for trace replay
   , output [core_els_p-1:0]                                  cmt_rd_w_v_o
   , output [core_els_p-1:0][reg_addr_width_lp-1:0]           cmt_rd_addr_o
   , output [core_els_p-1:0]                                  cmt_mem_w_v_o
   , output [core_els_p-1:0][eaddr_width_lp-1:0]              cmt_mem_addr_o
   , output [core_els_p-1:0][fu_op_width_lp-1:0]              cmt_mem_op_o
   , output [core_els_p-1:0][reg_data_width_lp-1:0]           cmt_data_o
  );

`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)

`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, reg_data_width_lp);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_data_cmd_s(num_lce_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Top-level interface connections

bp_lce_cce_req_s [core_els_p-1:0][1:0] lce_req;
logic [core_els_p-1:0][1:0] lce_req_v, lce_req_ready;

bp_lce_cce_resp_s [core_els_p-1:0][1:0] lce_resp;
logic [core_els_p-1:0][1:0] lce_resp_v, lce_resp_ready;

bp_lce_cce_data_resp_s [core_els_p-1:0][1:0] lce_data_resp;
logic [core_els_p-1:0][1:0] lce_data_resp_v, lce_data_resp_ready;

bp_cce_lce_cmd_s [core_els_p-1:0][1:0] lce_cmd;
logic [core_els_p-1:0][1:0] lce_cmd_v, lce_cmd_ready;

bp_lce_data_cmd_s [core_els_p-1:0][1:0] lce_data_cmd_li;
logic [core_els_p-1:0][1:0] lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_lce_data_cmd_s [core_els_p-1:0][1:0] lce_data_cmd_lo;
logic [core_els_p-1:0][1:0] lce_data_cmd_v_lo, lce_data_cmd_ready_li;

bp_proc_cfg_s [core_els_p-1:0] proc_cfg;

// Module instantiations
genvar core_id;
generate 
for(core_id = 0; core_id < core_els_p; core_id++) 
  begin : rof1
    localparam mhartid = (mhartid_width_lp)'(core_id);
    localparam icache_id = (core_id*2+icache_lce_id_lp);
    localparam dcache_id = (core_id*2+dcache_lce_id_lp);

    assign proc_cfg[core_id].mhartid   = mhartid;
    assign proc_cfg[core_id].icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg[core_id].dcache_id = dcache_id[0+:lce_id_width_lp];

    bp_core   
      #(.core_els_p(core_els_p)
        ,.num_lce_p(num_lce_p)
        ,.num_cce_p(num_cce_p)
        ,.lce_sets_p(lce_sets_p)
        ,.lce_assoc_p(lce_assoc_p)
        ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
        ,.data_width_p(reg_data_width_lp)
        ,.vaddr_width_p(vaddr_width_p)
        ,.paddr_width_p(paddr_width_p)
        ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
        ,.asid_width_p(asid_width_p)
        ,.btb_indx_width_p(btb_indx_width_p)
        ,.bht_indx_width_p(bht_indx_width_p)
        ,.ras_addr_width_p(ras_addr_width_p)
      ) core (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.proc_cfg_i(proc_cfg[core_id])

        ,.lce_req_o(lce_req[core_id])
        ,.lce_req_v_o(lce_req_v[core_id])
        ,.lce_req_ready_i(lce_req_ready[core_id])

        ,.lce_resp_o(lce_resp[core_id])
        ,.lce_resp_v_o(lce_resp_v[core_id])
        ,.lce_resp_ready_i(lce_resp_ready[core_id])

        ,.lce_data_resp_o(lce_data_resp[core_id])
        ,.lce_data_resp_v_o(lce_data_resp_v[core_id])
        ,.lce_data_resp_ready_i(lce_data_resp_ready[core_id])

        ,.lce_cmd_i(lce_cmd[core_id])
        ,.lce_cmd_v_i(lce_cmd_v[core_id])
        ,.lce_cmd_ready_o(lce_cmd_ready[core_id])

        ,.lce_data_cmd_i(lce_data_cmd_li[core_id])
        ,.lce_data_cmd_v_i(lce_data_cmd_v_li[core_id])
        ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo[core_id])

        ,.lce_data_cmd_o(lce_data_cmd_lo[core_id])
        ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[core_id])
        ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[core_id])

        ,.cmt_rd_w_v_o(cmt_rd_w_v_o[core_id])
        ,.cmt_rd_addr_o(cmt_rd_addr_o[core_id])
        ,.cmt_mem_w_v_o(cmt_mem_w_v_o[core_id])
        ,.cmt_mem_addr_o(cmt_mem_addr_o[core_id])
        ,.cmt_mem_op_o(cmt_mem_op_o[core_id])
        ,.cmt_data_o(cmt_data_o[core_id])
        );

  end
endgenerate 

bp_me_top 
 #(.num_lce_p(num_lce_p)
   ,.num_cce_p(num_cce_p)
   ,.paddr_width_p(paddr_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   ,.block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.num_inst_ram_els_p(cce_num_inst_ram_els_p)
   )
 me
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.lce_req_i(lce_req)
   ,.lce_req_v_i(lce_req_v)
   ,.lce_req_ready_o(lce_req_ready)

   ,.lce_resp_i(lce_resp)
   ,.lce_resp_v_i(lce_resp_v)
   ,.lce_resp_ready_o(lce_resp_ready)        

   ,.lce_data_resp_i(lce_data_resp)
   ,.lce_data_resp_v_i(lce_data_resp_v)
   ,.lce_data_resp_ready_o(lce_data_resp_ready)

   ,.lce_cmd_o(lce_cmd)
   ,.lce_cmd_v_o(lce_cmd_v)
   ,.lce_cmd_ready_i(lce_cmd_ready)

   ,.lce_data_cmd_o(lce_data_cmd_li)
   ,.lce_data_cmd_v_o(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_i(lce_data_cmd_ready_lo)

   ,.lce_data_cmd_i(lce_data_cmd_lo)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_li)

   ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr_o)
   ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data_i)
  
   ,.mem_resp_i(mem_resp_i)
   ,.mem_resp_v_i(mem_resp_v_i)
   ,.mem_resp_ready_o(mem_resp_ready_o)

   ,.mem_data_resp_i(mem_data_resp_i)
   ,.mem_data_resp_v_i(mem_data_resp_v_i)
   ,.mem_data_resp_ready_o(mem_data_resp_ready_o)

   ,.mem_cmd_o(mem_cmd_o)
   ,.mem_cmd_v_o(mem_cmd_v_o)
   ,.mem_cmd_yumi_i(mem_cmd_yumi_i)

   ,.mem_data_cmd_o(mem_data_cmd_o)
   ,.mem_data_cmd_v_o(mem_data_cmd_v_o)
   ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i)

   );

endmodule : bp_multi_top

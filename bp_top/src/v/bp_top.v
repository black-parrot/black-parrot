/**
 *
 * bp_top.v
 *
 */

module bp_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, dword_width_p, num_lce_p, lce_assoc_p)

   // Used to enable trace replay outputs for testbench
   , parameter trace_p      = 0
   , parameter calc_debug_p = 0
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // This will go away with the manycore bridge
   , output logic [num_cce_p-1:0][`BSG_SAFE_CLOG2(num_cce_instr_ram_els_p)-1:0] cce_inst_boot_rom_addr_o
   , input logic [num_cce_p-1:0][`bp_cce_inst_width-1:0]                        cce_inst_boot_rom_data_i

   , input [num_cce_p-1:0][mem_cce_resp_width_lp-1:0]         mem_resp_i
   , input [num_cce_p-1:0]                                    mem_resp_v_i
   , output [num_cce_p-1:0]                                   mem_resp_ready_o

   , input [num_cce_p-1:0][mem_cce_data_resp_width_lp-1:0]    mem_data_resp_i
   , input [num_cce_p-1:0]                                    mem_data_resp_v_i
   , output [num_cce_p-1:0]                                   mem_data_resp_ready_o

   , output [num_cce_p-1:0][cce_mem_cmd_width_lp-1:0]         mem_cmd_o
   , output [num_cce_p-1:0]                                   mem_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_cmd_yumi_i

   , output [num_cce_p-1:0][cce_mem_data_cmd_width_lp-1:0]    mem_data_cmd_o
   , output [num_cce_p-1:0]                                   mem_data_cmd_v_o
   , input [num_cce_p-1:0]                                    mem_data_cmd_yumi_i

   , input                                                    timer_int_i
   , input                                                    software_int_i
   , input                                                    external_int_i

   // Commit tracer for trace replay
   , output [num_core_p-1:0]                                  cmt_rd_w_v_o
   , output [num_core_p-1:0][rv64_reg_addr_width_gp-1:0]      cmt_rd_addr_o
   , output [num_core_p-1:0]                                  cmt_mem_w_v_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_mem_addr_o
   , output [num_core_p-1:0][`bp_be_fu_op_width-1:0]          cmt_mem_op_o
   , output [num_core_p-1:0][dword_width_p-1:0]               cmt_data_o
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_lce_p)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )

// Top-level interface connections
bp_lce_cce_req_s [num_core_p-1:0][1:0] lce_req_lo;
logic [num_core_p-1:0][1:0] lce_req_v_lo, lce_req_ready_li;

bp_lce_cce_resp_s [num_core_p-1:0][1:0] lce_resp_lo;
logic [num_core_p-1:0][1:0] lce_resp_v_lo, lce_resp_ready_li;

bp_lce_cce_data_resp_s [num_core_p-1:0][1:0] lce_data_resp_lo;
logic [num_core_p-1:0][1:0] lce_data_resp_v_lo, lce_data_resp_ready_li;

bp_cce_lce_cmd_s [num_core_p-1:0][1:0] lce_cmd_li;
logic [num_core_p-1:0][1:0] lce_cmd_v_li, lce_cmd_ready_lo;

bp_lce_data_cmd_s [num_core_p-1:0][1:0] lce_data_cmd_li;
logic [num_core_p-1:0][1:0] lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_lce_data_cmd_s [num_core_p-1:0][1:0] lce_data_cmd_lo;
logic [num_core_p-1:0][1:0] lce_data_cmd_v_lo, lce_data_cmd_ready_li;

// Module instantiations
generate 
for(genvar core_id = 0; core_id < num_core_p; core_id++) 
  begin : rof1
    localparam mhartid   = core_id;
    localparam icache_id = (core_id * 2 + 0);
    localparam dcache_id = (core_id * 2 + 1);

    localparam mhartid_width_lp = `BSG_SAFE_CLOG2(num_core_p);
    localparam lce_id_width_lp  = `BSG_SAFE_CLOG2(num_lce_p);

    bp_proc_cfg_s proc_cfg;
    assign proc_cfg.mhartid   = mhartid[0+:mhartid_width_lp];
    assign proc_cfg.icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg.dcache_id = dcache_id[0+:lce_id_width_lp];

    bp_core   
     #(.cfg_p(cfg_p)
       ,.trace_p(trace_p)
       ,.calc_debug_p(calc_debug_p)
       )
     core 
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.proc_cfg_i(proc_cfg)

       ,.lce_req_o(lce_req_lo[core_id])
       ,.lce_req_v_o(lce_req_v_lo[core_id])
       ,.lce_req_ready_i(lce_req_ready_li[core_id])

       ,.lce_resp_o(lce_resp_lo[core_id])
       ,.lce_resp_v_o(lce_resp_v_lo[core_id])
       ,.lce_resp_ready_i(lce_resp_ready_li[core_id])

       ,.lce_data_resp_o(lce_data_resp_lo[core_id])
       ,.lce_data_resp_v_o(lce_data_resp_v_lo[core_id])
       ,.lce_data_resp_ready_i(lce_data_resp_ready_li[core_id])

       ,.lce_cmd_i(lce_cmd_li[core_id])
       ,.lce_cmd_v_i(lce_cmd_v_li[core_id])
       ,.lce_cmd_ready_o(lce_cmd_ready_lo[core_id])

       ,.lce_data_cmd_i(lce_data_cmd_li[core_id])
       ,.lce_data_cmd_v_i(lce_data_cmd_v_li[core_id])
       ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo[core_id])

       ,.lce_data_cmd_o(lce_data_cmd_lo[core_id])
       ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[core_id])
       ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[core_id])

       ,.timer_int_i(timer_int_i)
       ,.software_int_i(software_int_i)
       ,.external_int_i(external_int_i)

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
 #(.cfg_p(cfg_p))
 me
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.lce_req_i(lce_req_lo)
   ,.lce_req_v_i(lce_req_v_lo)
   ,.lce_req_ready_o(lce_req_ready_li)

   ,.lce_resp_i(lce_resp_lo)
   ,.lce_resp_v_i(lce_resp_v_lo)
   ,.lce_resp_ready_o(lce_resp_ready_li)        

   ,.lce_data_resp_i(lce_data_resp_lo)
   ,.lce_data_resp_v_i(lce_data_resp_v_lo)
   ,.lce_data_resp_ready_o(lce_data_resp_ready_li)

   ,.lce_cmd_o(lce_cmd_li)
   ,.lce_cmd_v_o(lce_cmd_v_li)
   ,.lce_cmd_ready_i(lce_cmd_ready_lo)

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

endmodule : bp_top


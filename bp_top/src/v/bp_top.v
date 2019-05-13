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
 import bsg_noc_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   // Used to enable trace replay outputs for testbench
   , parameter trace_p      = 0
   , parameter calc_debug_p = 1
   , parameter cce_trace_p  = 0

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1

   , localparam lce_cce_req_network_width_lp = lce_cce_req_width_lp+x_cord_width_p+1
   , localparam lce_cce_resp_network_width_lp = lce_cce_resp_width_lp+x_cord_width_p+1
   , localparam cce_lce_cmd_network_width_lp = cce_lce_cmd_width_lp+x_cord_width_p+1

   , localparam lce_cce_data_resp_num_flits_lp = bp_data_resp_num_flit_gp
   , localparam lce_cce_data_resp_len_width_lp = `BSG_SAFE_CLOG2(lce_cce_data_resp_num_flits_lp)
   , localparam lce_cce_data_resp_packet_width_lp = lce_cce_data_resp_width_lp+x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp
   , localparam lce_cce_data_resp_router_width_lp = (lce_cce_data_resp_packet_width_lp/lce_cce_data_resp_num_flits_lp) + ((lce_cce_data_resp_packet_width_lp%lce_cce_data_resp_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_cce_data_resp_payload_offset_lp = (x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp)

   , localparam lce_data_cmd_num_flits_lp = bp_data_cmd_num_flit_gp
   , localparam lce_data_cmd_len_width_lp = `BSG_SAFE_CLOG2(lce_data_cmd_num_flits_lp)
   , localparam lce_data_cmd_packet_width_lp = lce_data_cmd_width_lp+x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp
   , localparam lce_data_cmd_router_width_lp = (lce_data_cmd_packet_width_lp/lce_data_cmd_num_flits_lp) + ((lce_data_cmd_packet_width_lp%lce_data_cmd_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_data_cmd_payload_offset_lp = (x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   , input [num_cce_p-1:0]                                    freeze_i

   // Config channel
   , input [num_cce_p-1:0][bp_cfg_link_addr_width_gp-2:0]        config_addr_i
   , input [num_cce_p-1:0][bp_cfg_link_data_width_gp-1:0]        config_data_i
   , input [num_cce_p-1:0]                                       config_v_i
   , input [num_cce_p-1:0]                                       config_w_i
   , output logic [num_cce_p-1:0]                                config_ready_o

   , output logic [num_cce_p-1:0][bp_cfg_link_data_width_gp-1:0] config_data_o
   , output logic [num_cce_p-1:0]                                config_v_o
   , input [num_cce_p-1:0]                                       config_ready_i

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

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )

logic [num_core_p:0][E:W][2+lce_cce_req_network_width_lp-1:0] lce_req_link_stitch_lo, lce_req_link_stitch_li;
logic [num_core_p:0][E:W][2+lce_cce_resp_network_width_lp-1:0] lce_resp_link_stitch_lo, lce_resp_link_stitch_li;
logic [num_core_p:0][E:W][2+cce_lce_cmd_network_width_lp-1:0] lce_cmd_link_stitch_lo, lce_cmd_link_stitch_li;

logic [num_core_p:0][E:W][lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_lo, lce_data_resp_li;
logic [num_core_p:0][E:W] lce_data_resp_v_lo, lce_data_resp_ready_li, lce_data_resp_v_li, lce_data_resp_ready_lo;

logic [num_core_p:0][E:W][lce_data_cmd_router_width_lp-1:0] lce_data_cmd_lo, lce_data_cmd_li;
logic [num_core_p:0][E:W] lce_data_cmd_v_lo, lce_data_cmd_ready_li, lce_data_cmd_v_li, lce_data_cmd_ready_lo;

for(genvar i = 0; i <= num_core_p; i++) 
  begin : rof1
    localparam core_id   = i;
    localparam cce_id    = i;
    localparam icache_id = (i * 2 + 0);
    localparam dcache_id = (i * 2 + 1);

    localparam core_id_width_lp = `BSG_SAFE_CLOG2(num_core_p);
    localparam cce_id_width_lp  = `BSG_SAFE_CLOG2(num_cce_p);
    localparam lce_id_width_lp  = `BSG_SAFE_CLOG2(num_lce_p);

    bp_proc_cfg_s proc_cfg;
    assign proc_cfg.core_id   = core_id[0+:core_id_width_lp];
    assign proc_cfg.cce_id    = cce_id[0+:cce_id_width_lp];
    assign proc_cfg.icache_id = icache_id[0+:lce_id_width_lp];
    assign proc_cfg.dcache_id = dcache_id[0+:lce_id_width_lp];

    if (i == 0)
      begin
        assign lce_req_link_stitch_li[i][W]  = '0;
        assign lce_resp_link_stitch_li[i][W] = '0;
        assign lce_data_resp_li[i][W]        = '0;
        assign lce_data_resp_v_li[i][W]      = '0;
        assign lce_data_resp_ready_li[i][W]  = '0;
        assign lce_cmd_link_stitch_li[i][W]  = '0;
        assign lce_data_cmd_li[i][W]         = '0;
        assign lce_data_cmd_v_li[i][W]       = '0;
        assign lce_data_cmd_ready_li[i][W]   = '0;
      end
    else  
      begin
        assign lce_req_link_stitch_li[i][W]  = lce_req_link_stitch_lo[i-1][E];
        assign lce_resp_link_stitch_li[i][W] = lce_resp_link_stitch_lo[i-1][E];
        assign lce_data_resp_li[i][W]        = lce_data_resp_lo[i-1][E];
        assign lce_data_resp_v_li[i][W]      = lce_data_resp_v_lo[i-1][E];
        assign lce_data_resp_ready_li[i][W]  = lce_data_resp_ready_lo[i-1][E];
        assign lce_cmd_link_stitch_li[i][W]  = lce_cmd_link_stitch_lo[i-1][E];
        assign lce_data_cmd_li[i][W]         = lce_data_cmd_lo[i-1][E];
        assign lce_data_cmd_v_li[i][W]       = lce_data_cmd_v_lo[i-1][E];
        assign lce_data_cmd_ready_li[i][W]   = lce_data_cmd_ready_lo[i-1][E];
      end

    if (i == num_core_p)
      begin
        assign lce_req_link_stitch_li[i][E]  = '0;
        assign lce_resp_link_stitch_li[i][E] = '0;
        assign lce_data_resp_li[i][E]        = '0;
        assign lce_data_resp_v_li[i][E]      = '0;
        assign lce_data_resp_ready_li[i][E]  = '0;
        assign lce_cmd_link_stitch_li[i][E]  = '0;
        assign lce_data_cmd_li[i][E]         = '0;
        assign lce_data_cmd_v_li[i][E]       = '0;
        assign lce_data_cmd_ready_li[i][E]   = '0;
      end
    else
      begin
        assign lce_req_link_stitch_li[i][E]  = lce_req_link_stitch_lo[i+1][W];
        assign lce_resp_link_stitch_li[i][E] = lce_resp_link_stitch_lo[i+1][W];
        assign lce_data_resp_li[i][E]        = lce_data_resp_lo[i+1][W];
        assign lce_data_resp_v_li[i][E]      = lce_data_resp_v_lo[i+1][W];
        assign lce_data_resp_ready_li[i][E]  = lce_data_resp_ready_lo[i+1][W];
        assign lce_cmd_link_stitch_li[i][E]  = lce_cmd_link_stitch_lo[i+1][W];
        assign lce_data_cmd_li[i][E]         = lce_data_cmd_lo[i+1][W];
        assign lce_data_cmd_v_li[i][E]       = lce_data_cmd_v_lo[i+1][W];
        assign lce_data_cmd_ready_li[i][E]   = lce_data_cmd_ready_lo[i+1][W];
      end

  if (i < num_core_p)
    begin 
      bp_tile
       #(.cfg_p(cfg_p)
         ,.trace_p(trace_p)
         ,.calc_debug_p(calc_debug_p)
         ,.cce_trace_p(cce_trace_p)
         )
       tile
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.proc_cfg_i(proc_cfg)

         ,.my_x_i(x_cord_width_p'(i))
         ,.my_y_i(y_cord_width_p'(1))

         ,.freeze_i(freeze_i[i])

         ,.config_addr_i(config_addr_i[i])
         ,.config_data_i(config_data_i[i])
         ,.config_v_i(config_v_i[i])
         ,.config_w_i(config_w_i[i])
         ,.config_ready_o(config_ready_o[i])

         ,.config_data_o(config_data_o[i])
         ,.config_v_o(config_v_o[i])
         ,.config_ready_i(config_ready_i[i])

         // Router inputs
         ,.lce_req_link_i(lce_req_link_stitch_li[i])
         ,.lce_resp_link_i(lce_resp_link_stitch_li[i])
         ,.lce_data_resp_i(lce_data_resp_li[i])
         ,.lce_data_resp_v_i(lce_data_resp_v_li[i])
         ,.lce_data_resp_ready_o(lce_data_resp_ready_lo[i])
         ,.lce_cmd_link_i(lce_cmd_link_stitch_li[i])
         ,.lce_data_cmd_i(lce_data_cmd_li[i])
         ,.lce_data_cmd_v_i(lce_data_cmd_v_li[i])
         ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo[i])

         // Router outputs
         ,.lce_req_link_o(lce_req_link_stitch_lo[i+1])
         ,.lce_resp_link_o(lce_resp_link_stitch_lo[i+1])
         ,.lce_data_resp_o(lce_data_resp_lo[i+1])
         ,.lce_data_resp_v_o(lce_data_resp_v_lo[i+1])
         ,.lce_data_resp_ready_i(lce_data_resp_ready_li[i+1])
         ,.lce_cmd_link_o(lce_cmd_link_stitch_lo[i+1])
         ,.lce_data_cmd_o(lce_data_cmd_lo[i+1])
         ,.lce_data_cmd_v_o(lce_data_cmd_v_lo[i+1])
         ,.lce_data_cmd_ready_i(lce_data_cmd_ready_li[i+1])

         ,.mem_resp_i(mem_resp_i[i])
         ,.mem_resp_v_i(mem_resp_v_i[i])
         ,.mem_resp_ready_o(mem_resp_ready_o[i])

         ,.mem_data_resp_i(mem_data_resp_i[i])
         ,.mem_data_resp_v_i(mem_data_resp_v_i[i])
         ,.mem_data_resp_ready_o(mem_data_resp_ready_o[i])

         ,.mem_cmd_o(mem_cmd_o[i])
         ,.mem_cmd_v_o(mem_cmd_v_o[i])
         ,.mem_cmd_yumi_i(mem_cmd_yumi_i[i])

         ,.mem_data_cmd_o(mem_data_cmd_o[i])
         ,.mem_data_cmd_v_o(mem_data_cmd_v_o[i])
         ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_i[i])

         ,.timer_int_i(timer_int_i)
         ,.software_int_i(software_int_i)
         ,.external_int_i(external_int_i)

         ,.cmt_rd_w_v_o(cmt_rd_w_v_o[i])
         ,.cmt_rd_addr_o(cmt_rd_addr_o[i])
         ,.cmt_mem_w_v_o(cmt_mem_w_v_o[i])
         ,.cmt_mem_addr_o(cmt_mem_addr_o[i])
         ,.cmt_mem_op_o(cmt_mem_op_o[i])
         ,.cmt_data_o(cmt_data_o[i])
         );
    end
  end // rof1

endmodule : bp_top


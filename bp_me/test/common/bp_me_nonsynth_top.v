/**
 *
 * bp_me_nonsynth_top.v
 *
 */

module bp_me_nonsynth_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   ,localparam mshr_width_lp=`bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mshr_width_lp)
   `declare_bp_lce_cce_if_widths(num_cce_p
                                 ,num_lce_p
                                 ,paddr_width_p
                                 ,lce_assoc_p
                                 ,dword_width_p
                                 ,cce_block_width_p
                                 )

   // Used to enable trace replay outputs for testbench
   , parameter trace_p      = 0
   , parameter calc_debug_p = 0
   , parameter cce_trace_p  = 0
   , parameter axe_trace_p  = 0

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1

   , localparam lce_cce_req_network_width_lp = lce_cce_req_width_lp+x_cord_width_p+1
   , localparam lce_cce_resp_network_width_lp = lce_cce_resp_width_lp+x_cord_width_p+1
   , localparam cce_lce_cmd_network_width_lp = cce_lce_cmd_width_lp+x_cord_width_p+1

   , localparam lce_cce_data_resp_num_flits_lp = bp_data_resp_num_flit_gp
   , localparam lce_cce_data_resp_len_width_lp = `BSG_SAFE_CLOG2(lce_cce_data_resp_num_flits_lp)
   , localparam lce_cce_data_resp_packet_width_lp =
       lce_cce_data_resp_width_lp+x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp
   , localparam lce_cce_data_resp_router_width_lp =
       (lce_cce_data_resp_packet_width_lp/lce_cce_data_resp_num_flits_lp)
       + ((lce_cce_data_resp_packet_width_lp%lce_cce_data_resp_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_cce_data_resp_payload_offset_lp =
       (x_cord_width_p+y_cord_width_p+lce_cce_data_resp_len_width_lp)

   , localparam lce_data_cmd_num_flits_lp = bp_data_cmd_num_flit_gp
   , localparam lce_data_cmd_len_width_lp = `BSG_SAFE_CLOG2(lce_data_cmd_num_flits_lp)
   , localparam lce_data_cmd_packet_width_lp =
       lce_data_cmd_width_lp+x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp
   , localparam lce_data_cmd_router_width_lp =
       (lce_data_cmd_packet_width_lp/lce_data_cmd_num_flits_lp)
       + ((lce_data_cmd_packet_width_lp%lce_data_cmd_num_flits_lp) == 0 ? 0 : 1)
   , localparam lce_data_cmd_payload_offset_lp = (x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp)

   , localparam dcache_opcode_width_lp=$bits(bp_be_dcache_opcode_e)
   , localparam tr_ring_width_lp=(dcache_opcode_width_lp+paddr_width_p+dword_width_p)

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

   // connections to trace replay units
   , input [num_lce_p-1:0][tr_ring_width_lp-1:0]              tr_pkt_i
   , input [num_lce_p-1:0]                                    tr_pkt_v_i
   , output logic [num_lce_p-1:0]                             tr_pkt_yumi_o

   , input [num_lce_p-1:0]                                    tr_pkt_ready_i
   , output logic [num_lce_p-1:0]                             tr_pkt_v_o
   , output logic [num_lce_p-1:0][tr_ring_width_lp-1:0]       tr_pkt_o

   // connections to memory
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
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mshr_width_lp)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )

logic [num_core_p-1:0][E:W][2+lce_cce_req_network_width_lp-1:0] lce_req_link_stitch_lo, lce_req_link_stitch_li;
logic [num_core_p-1:0][E:W][2+lce_cce_resp_network_width_lp-1:0] lce_resp_link_stitch_lo, lce_resp_link_stitch_li;
logic [num_core_p-1:0][E:W][2+lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_link_stitch_lo, lce_data_resp_link_stitch_li;
logic [num_core_p-1:0][E:W][2+cce_lce_cmd_network_width_lp-1:0] lce_cmd_link_stitch_lo, lce_cmd_link_stitch_li;
logic [num_core_p-1:0][E:W][2+lce_data_cmd_router_width_lp-1:0] lce_data_cmd_link_stitch_lo, lce_data_cmd_link_stitch_li;

logic [num_core_p-1:0][E:W][lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_lo, lce_data_resp_li;
logic [num_core_p-1:0][E:W] lce_data_resp_v_lo, lce_data_resp_ready_li, lce_data_resp_v_li, lce_data_resp_ready_lo;

logic [num_core_p-1:0][E:W][lce_data_cmd_router_width_lp-1:0] lce_data_cmd_lo, lce_data_cmd_li;
logic [num_core_p-1:0][E:W] lce_data_cmd_v_lo, lce_data_cmd_ready_li, lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_mem_cce_resp_s      [num_cce_p-1:0] me_mem_resp_li;
logic                  [num_cce_p-1:0] me_mem_resp_v_li, me_mem_resp_ready_lo;

bp_mem_cce_data_resp_s [num_cce_p-1:0] me_mem_data_resp_li;
logic                  [num_cce_p-1:0] me_mem_data_resp_v_li, me_mem_data_resp_ready_lo;

bp_cce_mem_cmd_s       [num_cce_p-1:0] me_mem_cmd_lo;
logic                  [num_cce_p-1:0] me_mem_cmd_v_lo, me_mem_cmd_yumi_li;

bp_cce_mem_data_cmd_s  [num_cce_p-1:0] me_mem_data_cmd_lo;
logic                  [num_cce_p-1:0] me_mem_data_cmd_v_lo, me_mem_data_cmd_yumi_li;

  assign lce_req_link_stitch_li[0][W]                  = '0;
  assign lce_resp_link_stitch_li[0][W]                 = '0;
  assign lce_data_resp_link_stitch_li[0][W]            = '0;
  assign lce_cmd_link_stitch_li[0][W]                  = '0;
  assign lce_data_cmd_link_stitch_li[0][W]             = '0;

  assign lce_req_link_stitch_li[num_core_p-1][E]       = '0;
  assign lce_resp_link_stitch_li[num_core_p-1][E]      = '0;
  assign lce_data_resp_link_stitch_li[num_core_p-1][E] = '0;
  assign lce_cmd_link_stitch_li[num_core_p-1][E]       = '0;
  assign lce_data_cmd_link_stitch_li[num_core_p-1][E]  = '0;

for(genvar i = 0; i < num_core_p; i++)
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

    if (i > 0) begin
    assign lce_req_link_stitch_li[i][W]  = lce_req_link_stitch_lo[i-1][E];
    assign lce_resp_link_stitch_li[i][W] = lce_resp_link_stitch_lo[i-1][E];
    assign lce_data_resp_link_stitch_li[i][W] = lce_data_resp_link_stitch_lo[i-1][E];
    assign lce_cmd_link_stitch_li[i][W]  = lce_cmd_link_stitch_lo[i-1][E];
    assign lce_data_cmd_link_stitch_li[i][W]  = lce_data_cmd_link_stitch_lo[i-1][E];
    end

    if (i < num_core_p-1) begin
    assign lce_req_link_stitch_li[i][E]  = lce_req_link_stitch_lo[i+1][W];
    assign lce_resp_link_stitch_li[i][E] = lce_resp_link_stitch_lo[i+1][W];
    assign lce_data_resp_link_stitch_li[i][E] = lce_data_resp_link_stitch_lo[i+1][W];
    assign lce_cmd_link_stitch_li[i][E]  = lce_cmd_link_stitch_lo[i+1][W];
    assign lce_data_cmd_link_stitch_li[i][E]  = lce_data_cmd_link_stitch_lo[i+1][W];
    end

    bp_me_nonsynth_tile
     #(.cfg_p(cfg_p)
       ,.trace_p(trace_p)
       ,.calc_debug_p(calc_debug_p)
       ,.cce_trace_p(cce_trace_p)
       ,.axe_trace_p(axe_trace_p)
       )
     tile
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.proc_cfg_i(proc_cfg)

       ,.my_x_i(x_cord_width_p'(i))
       ,.my_y_i(y_cord_width_p'(0))

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
       ,.lce_data_resp_link_i(lce_data_resp_link_stitch_li[i])
       ,.lce_cmd_link_i(lce_cmd_link_stitch_li[i])
       ,.lce_data_cmd_link_i(lce_data_cmd_link_stitch_li[i])

       // Router outputs
       ,.lce_req_link_o(lce_req_link_stitch_lo[i])
       ,.lce_resp_link_o(lce_resp_link_stitch_lo[i])
       ,.lce_data_resp_link_o(lce_data_resp_link_stitch_lo[i])
       ,.lce_cmd_link_o(lce_cmd_link_stitch_lo[i])
       ,.lce_data_cmd_link_o(lce_data_cmd_link_stitch_lo[i])

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

       ,.tr_pkt_i(tr_pkt_i[(i*2)+1 : (i*2)])
       ,.tr_pkt_v_i(tr_pkt_v_i[(i*2)+1 : (i*2)])
       ,.tr_pkt_yumi_o(tr_pkt_yumi_o[(i*2)+1 : (i*2)])

       ,.tr_pkt_v_o(tr_pkt_v_o[(i*2)+1 : (i*2)])
       ,.tr_pkt_o(tr_pkt_o[(i*2)+1 : (i*2)])
       ,.tr_pkt_ready_i(tr_pkt_ready_i[(i*2)+1 : (i*2)])

       );

  end // rof1

endmodule : bp_me_nonsynth_top


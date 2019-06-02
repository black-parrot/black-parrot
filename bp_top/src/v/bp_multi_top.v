/**
 *
 * bp_multi_top.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_multi_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_cfg_link_pkg::*;
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
   , parameter calc_trace_p = 1
   , parameter cce_trace_p  = 1

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1

   , localparam dirs_lp = 5
   
   , localparam noc_x_cord_width_lp = `BSG_SAFE_CLOG2(num_cce_p)
   , localparam noc_y_cord_width_lp = 1
   
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
   
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // channel tunnel interface
   , input [noc_width_p-1:0] multi_data_i
   , input multi_v_i
   , output multi_ready_o
   
   , output [noc_width_p-1:0] multi_data_o
   , output multi_v_o
   , input multi_yumi_i
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )
`declare_bsg_ready_and_link_sif_s(noc_width_p,bsg_ready_and_link_sif_s);

logic [num_core_p-1:0][E:W][2+lce_cce_req_network_width_lp-1:0] lce_req_link_stitch_lo, lce_req_link_stitch_li;
logic [num_core_p-1:0][E:W][2+lce_cce_resp_network_width_lp-1:0] lce_resp_link_stitch_lo, lce_resp_link_stitch_li;
logic [num_core_p-1:0][E:W][2+lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_link_stitch_lo, lce_data_resp_link_stitch_li;
logic [num_core_p-1:0][E:W][2+cce_lce_cmd_network_width_lp-1:0] lce_cmd_link_stitch_lo, lce_cmd_link_stitch_li;
logic [num_core_p-1:0][E:W][2+lce_data_cmd_router_width_lp-1:0] lce_data_cmd_link_stitch_lo, lce_data_cmd_link_stitch_li;

logic [num_core_p-1:0][E:W][lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_lo, lce_data_resp_li;
logic [num_core_p-1:0][E:W] lce_data_resp_v_lo, lce_data_resp_ready_li, lce_data_resp_v_li, lce_data_resp_ready_lo;

logic [num_core_p-1:0][E:W][lce_data_cmd_router_width_lp-1:0] lce_data_cmd_lo, lce_data_cmd_li;
logic [num_core_p-1:0][E:W] lce_data_cmd_v_lo, lce_data_cmd_ready_li, lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_mem_cce_resp_s      [num_cce_p-1:0] mem_resp_li;
logic                  [num_cce_p-1:0] mem_resp_v_li, mem_resp_ready_lo;

bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp_li;
logic                  [num_cce_p-1:0] mem_data_resp_v_li, mem_data_resp_ready_lo;

bp_cce_mem_cmd_s       [num_cce_p-1:0] mem_cmd_lo;
logic                  [num_cce_p-1:0] mem_cmd_v_lo, mem_cmd_yumi_li;

bp_cce_mem_data_cmd_s  [num_cce_p-1:0] mem_data_cmd_lo;
logic                  [num_cce_p-1:0] mem_data_cmd_v_lo, mem_data_cmd_yumi_li;
  
logic [num_core_p-1:0] timer_irq_lo, soft_irq_lo, external_irq_lo;

logic [noc_x_cord_width_lp-1:0] clint_x_cord, dram_x_cord;
logic [noc_y_cord_width_lp-1:0] clint_y_cord, dram_y_cord;

bsg_ready_and_link_sif_s [num_core_p-1:0][dirs_lp-1:0] cmd_wh_link_li, cmd_wh_link_lo, resp_wh_link_li, resp_wh_link_lo;
bsg_ready_and_link_sif_s [num_core_p-1:0] master_wh_link_li, master_wh_link_lo;

logic [num_core_p-1:0][noc_x_cord_width_lp-1:0] mem_cmd_dest_x, mem_data_cmd_dest_x;
logic [num_core_p-1:0][noc_y_cord_width_lp-1:0] mem_cmd_dest_y, mem_data_cmd_dest_y;

bp_mem_cce_resp_s      clint_resp_lo;
logic                  clint_resp_v_lo, clint_resp_ready_li;

bp_mem_cce_data_resp_s clint_data_resp_lo;
logic                  clint_data_resp_v_lo, clint_data_resp_ready_li;

bp_cce_mem_cmd_s       clint_cmd_li;
logic                  clint_cmd_v_li, clint_cmd_yumi_lo;

bp_cce_mem_data_cmd_s  clint_data_cmd_li;
logic                  clint_data_cmd_v_li, clint_data_cmd_yumi_lo;

logic [num_core_p-1:0]                                cfg_link_w_v_lo;
logic [num_core_p-1:0][bp_cfg_link_addr_width_gp-1:0] cfg_link_addr_lo;
logic [num_core_p-1:0][bp_cfg_link_data_width_gp-1:0] cfg_link_data_lo;

bsg_ready_and_link_sif_s client_wh_link_li, client_wh_link_lo;
bsg_ready_and_link_sif_s [1:0] ct_link_li, ct_link_lo;

localparam clint_x_cord_lp = (num_core_p/2)-1;
localparam clint_y_cord_lp = 1;
localparam dram_x_cord_lp  = (num_core_p/2);
localparam dram_y_cord_lp  = 1;

assign clint_x_cord = (noc_x_cord_width_lp)'(clint_x_cord_lp);
assign clint_y_cord = (noc_y_cord_width_lp)'(clint_y_cord_lp);
assign dram_x_cord  = (noc_x_cord_width_lp)'(dram_x_cord_lp);
assign dram_y_cord  = (noc_y_cord_width_lp)'(dram_y_cord_lp);

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

// Individual core reset or global?
// bsg_tag vs cfg_link?
logic reset_r;
always_ff @(posedge clk_i) 
  begin
    if (reset_i)
      reset_r <= 1'b0;
    else if (cfg_link_w_v_lo[0] & (cfg_link_addr_lo[0] == bp_cfg_reg_reset_gp)) 
      reset_r <= cfg_link_data_lo[0];
  end


// BP Tiles
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
    
    assign master_wh_link_li[i].v = resp_wh_link_lo[i][P].v;
    assign master_wh_link_li[i].data = resp_wh_link_lo[i][P].data;
    assign master_wh_link_li[i].ready_and_rev = cmd_wh_link_lo[i][P].ready_and_rev;

    bp_tile
     #(.cfg_p(cfg_p)
       ,.calc_trace_p(calc_trace_p)
       ,.cce_trace_p(cce_trace_p)
       )
     tile
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.proc_cfg_i(proc_cfg)

       ,.my_x_i(x_cord_width_p'(i))
       ,.my_y_i(y_cord_width_p'(0))

       ,.cfg_w_v_i(cfg_link_w_v_lo[i])
       ,.cfg_addr_i(cfg_link_addr_lo[i])
       ,.cfg_data_i(cfg_link_data_lo[i])

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

       ,.mem_resp_i(mem_resp_li[i])
       ,.mem_resp_v_i(mem_resp_v_li[i])
       ,.mem_resp_ready_o(mem_resp_ready_lo[i])

       ,.mem_data_resp_i(mem_data_resp_li[i])
       ,.mem_data_resp_v_i(mem_data_resp_v_li[i])
       ,.mem_data_resp_ready_o(mem_data_resp_ready_lo[i])

       ,.mem_cmd_o(mem_cmd_lo[i])
       ,.mem_cmd_v_o(mem_cmd_v_lo[i])
       ,.mem_cmd_yumi_i(mem_cmd_yumi_li[i])

       ,.mem_data_cmd_o(mem_data_cmd_lo[i])
       ,.mem_data_cmd_v_o(mem_data_cmd_v_lo[i])
       ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_li[i])

       ,.timer_int_i(timer_irq_lo[i])
       ,.software_int_i(soft_irq_lo[i])
       ,.external_int_i(external_irq_lo[i])
       );
       
    bp_addr_map
     #(.cfg_p(cfg_p)
       ,.x_cord_width_p(noc_x_cord_width_lp)
       ,.y_cord_width_p(noc_y_cord_width_lp)
       )
     mem_cmd_addr_map
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       
       ,.paddr_i(mem_cmd_lo[i].addr)
       
       ,.clint_x_cord_i(clint_x_cord)
       ,.clint_y_cord_i(clint_y_cord)
       ,.dram_x_cord_i(dram_x_cord)
       ,.dram_y_cord_i(dram_y_cord)
       
       ,.dest_x_o(mem_cmd_dest_x[i])
       ,.dest_y_o(mem_cmd_dest_y[i])
       );
       
    bp_addr_map
     #(.cfg_p(cfg_p)
       ,.x_cord_width_p(noc_x_cord_width_lp)
       ,.y_cord_width_p(noc_y_cord_width_lp)
       )
     mem_data_cmd_addr_map
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       
       ,.paddr_i(mem_data_cmd_lo[i].addr)
       
       ,.clint_x_cord_i(clint_x_cord)
       ,.clint_y_cord_i(clint_y_cord)
       ,.dram_x_cord_i(dram_x_cord)
       ,.dram_y_cord_i(dram_y_cord)
       
       ,.dest_x_o(mem_data_cmd_dest_x[i])
       ,.dest_y_o(mem_data_cmd_dest_y[i])
       );
    
    bp_me_cce_to_wormhole_link_master
     #(.num_lce_p(num_lce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.block_size_in_bytes_p(cce_block_width_p/8)
      ,.lce_req_data_width_p(dword_width_p)
      ,.width_p(noc_width_p)
      ,.x_cord_width_p(noc_x_cord_width_lp)
      ,.y_cord_width_p(noc_y_cord_width_lp)
      ,.len_width_p(4)
      ,.reserved_width_p(2))
      master_link
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.mem_cmd_i(mem_cmd_lo[i])
      ,.mem_cmd_v_i(mem_cmd_v_lo[i])
      ,.mem_cmd_yumi_o(mem_cmd_yumi_li[i])

      ,.mem_data_cmd_i(mem_data_cmd_lo[i])
      ,.mem_data_cmd_v_i(mem_data_cmd_v_lo[i])
      ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_li[i])

      ,.mem_resp_o(mem_resp_li[i])
      ,.mem_resp_v_o(mem_resp_v_li[i])
      ,.mem_resp_ready_i(mem_resp_ready_lo[i])

      ,.mem_data_resp_o(mem_data_resp_li[i])
      ,.mem_data_resp_v_o(mem_data_resp_v_li[i])
      ,.mem_data_resp_ready_i(mem_data_resp_ready_lo[i])
      
      ,.my_x_i(noc_x_cord_width_lp'(i))
      ,.my_y_i(noc_y_cord_width_lp'(0))
      
      ,.mem_cmd_dest_x_i(mem_cmd_dest_x[i])
      ,.mem_cmd_dest_y_i(mem_cmd_dest_y[i])
      ,.mem_data_cmd_dest_x_i(mem_data_cmd_dest_x[i])
      ,.mem_data_cmd_dest_y_i(mem_data_cmd_dest_y[i])
      
      ,.link_i(master_wh_link_li[i])
      ,.link_o(master_wh_link_lo[i])
      );
  end

// Clint
assign client_wh_link_li.v = cmd_wh_link_lo[clint_x_cord_lp][S].v;
assign client_wh_link_li.data = cmd_wh_link_lo[clint_x_cord_lp][S].data;
assign client_wh_link_li.ready_and_rev = resp_wh_link_lo[clint_x_cord_lp][S].ready_and_rev;

bp_clint
 #(.cfg_p(cfg_p)
   )
 clint
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.mem_cmd_i(clint_cmd_li)
   ,.mem_cmd_v_i(clint_cmd_v_li)
   ,.mem_cmd_yumi_o(clint_cmd_yumi_lo)
   
   ,.mem_data_cmd_i(clint_data_cmd_li)
   ,.mem_data_cmd_v_i(clint_data_cmd_v_li)
   ,.mem_data_cmd_yumi_o(clint_data_cmd_yumi_lo)
   
   ,.mem_resp_o(clint_resp_lo)
   ,.mem_resp_v_o(clint_resp_v_lo)
   ,.mem_resp_ready_i(clint_resp_ready_li)
   
   ,.mem_data_resp_o(clint_data_resp_lo)
   ,.mem_data_resp_v_o(clint_data_resp_v_lo)
   ,.mem_data_resp_ready_i(clint_data_resp_ready_li)
   
   ,.soft_irq_o(soft_irq_lo)
   ,.timer_irq_o(timer_irq_lo)
   ,.external_irq_o(external_irq_lo)
   
   ,.cfg_link_w_v_o(cfg_link_w_v_lo)
   ,.cfg_link_addr_o(cfg_link_addr_lo)
   ,.cfg_link_data_o(cfg_link_data_lo)
   );

bp_me_cce_to_wormhole_link_client
 #(.num_lce_p(num_lce_p)
  ,.paddr_width_p(paddr_width_p)
  ,.lce_assoc_p(lce_assoc_p)
  ,.block_size_in_bytes_p(cce_block_width_p/8)
  ,.lce_req_data_width_p(dword_width_p)
  ,.width_p(noc_width_p)
  ,.x_cord_width_p(noc_x_cord_width_lp)
  ,.y_cord_width_p(noc_y_cord_width_lp)
  ,.len_width_p(4)
  ,.reserved_width_p(2))   
  client_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)
   
  ,.mem_cmd_o(clint_cmd_li)
  ,.mem_cmd_v_o(clint_cmd_v_li)
  ,.mem_cmd_yumi_i(clint_cmd_yumi_lo)
   
  ,.mem_data_cmd_o(clint_data_cmd_li)
  ,.mem_data_cmd_v_o(clint_data_cmd_v_li)
  ,.mem_data_cmd_yumi_i(clint_data_cmd_yumi_lo)
   
  ,.mem_resp_i(clint_resp_lo)
  ,.mem_resp_v_i(clint_resp_v_lo)
  ,.mem_resp_ready_o(clint_resp_ready_li)
   
  ,.mem_data_resp_i(clint_data_resp_lo)
  ,.mem_data_resp_v_i(clint_data_resp_v_lo)
  ,.mem_data_resp_ready_o(clint_data_resp_ready_li)
     
  ,.my_x_i(clint_x_cord)
  ,.my_y_i(clint_y_cord)
     
  ,.link_i(client_wh_link_li)
  ,.link_o(client_wh_link_lo)
  );   
  
// Routers
// Command Routers
assign cmd_wh_link_li[clint_x_cord_lp][S].ready_and_rev = client_wh_link_lo.ready_and_rev;
for(genvar i = 0; i < num_core_p; i++) 
  begin : cmd_wh
  
    // stub_in_p generation
    localparam stub_in_NS_lp = (i == dram_x_cord_lp) ? 5'b01000 : 5'b11000;
    localparam stub_in_W_lp = ((i > dram_x_cord_lp) || (i == 0)) ? 5'b00010 : '0;
    localparam stub_in_E_lp = ((i < clint_x_cord_lp) || (i == num_core_p-1)) ? 5'b00100 : '0;
    localparam stub_in_lp = stub_in_NS_lp | stub_in_W_lp | stub_in_E_lp;

    //stub_out_p generation
    localparam stub_out_P_lp = 5'b00001;
    localparam stub_out_NS_lp = ((i == dram_x_cord_lp) || (i == clint_x_cord_lp))? 5'b01000 : 5'b11000;
    localparam stub_out_E_lp = (i > clint_x_cord_lp)? 5'b00100 : '0;
    localparam stub_out_W_lp = (i < dram_x_cord_lp)? 5'b00010 : '0;
    localparam stub_out_lp = stub_out_P_lp | stub_out_NS_lp | stub_out_E_lp | stub_out_W_lp;
    
    //Proc
    assign cmd_wh_link_li[i][P].v = master_wh_link_lo[i].v;
    assign cmd_wh_link_li[i][P].data = master_wh_link_lo[i].data;
    //West
    if(i > 0) begin
      assign cmd_wh_link_li[i][W] = cmd_wh_link_lo[i-1][E];
    end
    //East
    if(i < num_core_p-1) begin
      assign cmd_wh_link_li[i][E] = cmd_wh_link_lo[i+1][W];
    end
    //North
    assign cmd_wh_link_li[i][N] = '0;
    
    bsg_wormhole_router
     #(
        .width_p(noc_width_p)
        ,.x_cord_width_p(noc_x_cord_width_lp)
        ,.y_cord_width_p(noc_y_cord_width_lp)
        ,.len_width_p(4)
        ,.reserved_width_p(2)
        ,.enable_2d_routing_p(1)
        ,.enable_yx_routing_p(0)
        ,.header_on_lsb_p(0)
        
        //,.debug_p(1)
        
        ,.stub_in_p(stub_in_lp)
        ,.stub_out_p(stub_out_lp)
       )
     cmd_wh_router
      (
        .clk_i(clk_i)
        ,.reset_i(reset_i)
        
        ,.link_i(cmd_wh_link_li[i])
        ,.link_o(cmd_wh_link_lo[i])
        
        ,.my_x_i(noc_x_cord_width_lp'(i))
        ,.my_y_i(noc_y_cord_width_lp'(0))
       );
end


//Response Routers
assign resp_wh_link_li[clint_x_cord_lp][S].v = client_wh_link_lo.v;
assign resp_wh_link_li[clint_x_cord_lp][S].data = client_wh_link_lo.data;

for(genvar i = 0; i < num_core_p; i++) 
  begin : resp_wh
  
    // stub_out_p generation
    localparam stub_out_NS_lp = (i == dram_x_cord_lp) ? 5'b01000 : 5'b11000;
    localparam stub_out_W_lp = ((i > dram_x_cord_lp) || (i == 0)) ? 5'b00010 : '0;
    localparam stub_out_E_lp = ((i < clint_x_cord_lp) || (i == num_core_p-1)) ? 5'b00100 : '0;
    localparam stub_out_lp = stub_out_NS_lp | stub_out_W_lp | stub_out_E_lp;

    //stub_in_p generation
    localparam stub_in_P_lp = 5'b00001;
    localparam stub_in_NS_lp = ((i == dram_x_cord_lp) || (i == clint_x_cord_lp))? 5'b01000 : 5'b11000;
    localparam stub_in_E_lp = (i > clint_x_cord_lp)? 5'b00100 : '0;
    localparam stub_in_W_lp = (i < dram_x_cord_lp)? 5'b00010 : '0;
    localparam stub_in_lp = stub_in_P_lp | stub_in_NS_lp | stub_in_E_lp | stub_in_W_lp;
    //Proc
    assign resp_wh_link_li[i][P].ready_and_rev = master_wh_link_lo[i].ready_and_rev; 
    //West
    if(i > 0) begin
      assign resp_wh_link_li[i][W] = resp_wh_link_lo[i-1][E];
    end
    //East
    if(i < num_core_p-1) begin
      assign resp_wh_link_li[i][E] = resp_wh_link_lo[i+1][W];
    end
    //North
    assign resp_wh_link_li[i][N] = '0;
    
    bsg_wormhole_router
     #(
        .width_p(noc_width_p)
        ,.x_cord_width_p(noc_x_cord_width_lp)
        ,.y_cord_width_p(noc_y_cord_width_lp)
        ,.len_width_p(4)
        ,.reserved_width_p(2)
        ,.enable_2d_routing_p(1)
        ,.enable_yx_routing_p(0)
        ,.header_on_lsb_p(0)
        
        //,.debug_p(2)
        
        ,.stub_in_p(stub_in_lp)
        ,.stub_out_p(stub_out_lp)
       )
     resp_wh_router
      (
        .clk_i(clk_i)
        ,.reset_i(reset_i)
        
        ,.link_i(resp_wh_link_li[i])
        ,.link_o(resp_wh_link_lo[i])
        
        ,.my_x_i(noc_x_cord_width_lp'(i))
        ,.my_y_i(noc_y_cord_width_lp'(0))
       );
end


//Channel Tunnel
assign ct_link_li = {resp_wh_link_lo[dram_x_cord_lp][S], cmd_wh_link_lo[dram_x_cord_lp][S]};
assign {cmd_wh_link_li[dram_x_cord_lp][S], resp_wh_link_li[dram_x_cord_lp][S]} = ct_link_lo;

bsg_channel_tunnel_wormhole
 #(.width_p(noc_width_p)
   ,.x_cord_width_p(noc_x_cord_width_lp)
   ,.y_cord_width_p(noc_y_cord_width_lp)
   ,.len_width_p(4)
   ,.reserved_width_p(2)
   ,.num_in_p(2)
   ,.remote_credits_p(16)
   ,.max_payload_flits_p(8)
   ,.lg_credit_decimation_p(2)
  )
 channel_tunnel
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   
   ,.multi_data_i(multi_data_i)
   ,.multi_v_i(multi_v_i)
   ,.multi_ready_o(multi_ready_o)
   
   ,.multi_data_o(multi_data_o)
   ,.multi_v_o(multi_v_o)
   ,.multi_yumi_i(multi_yumi_i)
   
   ,.link_i(ct_link_li)
   ,.link_o(ct_link_lo)
   );


endmodule : bp_multi_top


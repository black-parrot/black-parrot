/**
 *
 * bp_top.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_top
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
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

   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1
   
   // FIXME: hardcoded
   , localparam noc_x_cord_width_lp = `BSG_SAFE_CLOG2(num_cce_p+2)
   , localparam noc_y_cord_width_lp = 1

   // Wormhole parameters
   , localparam dims_lp = 1
   , localparam int cord_markers_pos_lp[dims_lp:0] = '{noc_x_cord_width_lp+noc_y_cord_width_lp, 0}
   , localparam cord_width_lp = cord_markers_pos_lp[dims_lp]
   , localparam dirs_lp = dims_lp*2+1
   , localparam bit [1:0][dirs_lp-1:0][dirs_lp-1:0] routing_matrix_lp = StrictX
   
   // Tile parameters
   , localparam num_tiles_lp = num_cce_p
   , localparam num_routers_lp = num_tiles_lp+1
   
   // Other parameters
   // FIXME: not needed when IO complex is used
   , localparam link_width_lp = noc_width_p+2
   
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
   , input [link_width_lp-1:0] multi_data_i
   , input multi_v_i
   , output multi_yumi_o
   
   , output [link_width_lp-1:0] multi_data_o
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

logic [E:W][2+lce_cce_req_network_width_lp-1:0] lce_req_link_stitch_lo, lce_req_link_stitch_li;
logic [E:W][2+lce_cce_resp_network_width_lp-1:0] lce_resp_link_stitch_lo, lce_resp_link_stitch_li;
logic [E:W][2+lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_link_stitch_lo, lce_data_resp_link_stitch_li;
logic [E:W][2+cce_lce_cmd_network_width_lp-1:0] lce_cmd_link_stitch_lo, lce_cmd_link_stitch_li;
logic [E:W][2+lce_data_cmd_router_width_lp-1:0] lce_data_cmd_link_stitch_lo, lce_data_cmd_link_stitch_li;

logic [E:W][lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_lo, lce_data_resp_li;
logic [E:W] lce_data_resp_v_lo, lce_data_resp_ready_li, lce_data_resp_v_li, lce_data_resp_ready_lo;

logic [E:W][lce_data_cmd_router_width_lp-1:0] lce_data_cmd_lo, lce_data_cmd_li;
logic [E:W] lce_data_cmd_v_lo, lce_data_cmd_ready_li, lce_data_cmd_v_li, lce_data_cmd_ready_lo;

bp_mem_cce_resp_s      mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;

bp_mem_cce_data_resp_s mem_data_resp_li;
logic                  mem_data_resp_v_li, mem_data_resp_ready_lo;

bp_cce_mem_cmd_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;

bp_cce_mem_data_cmd_s  mem_data_cmd_lo;
logic                  mem_data_cmd_v_lo, mem_data_cmd_yumi_li;
  
logic  timer_irq_lo, soft_irq_lo, external_irq_lo;

bsg_ready_and_link_sif_s [num_routers_lp-1:0][dirs_lp-1:0] cmd_link_li,  cmd_link_lo;
bsg_ready_and_link_sif_s [num_routers_lp-1:0][dirs_lp-1:0] resp_link_li, resp_link_lo;

bp_mem_cce_resp_s      clint_resp_lo;
logic                  clint_resp_v_lo, clint_resp_ready_li;

bp_mem_cce_data_resp_s clint_data_resp_lo;
logic                  clint_data_resp_v_lo, clint_data_resp_ready_li;

bp_cce_mem_cmd_s       clint_cmd_li;
logic                  clint_cmd_v_li, clint_cmd_yumi_lo;

bp_cce_mem_data_cmd_s  clint_data_cmd_li;
logic                  clint_data_cmd_v_li, clint_data_cmd_yumi_lo;

logic                        cfg_link_w_v_lo;
logic [cfg_addr_width_p-1:0] cfg_link_addr_lo;
logic [cfg_data_width_p-1:0] cfg_link_data_lo;

bsg_ready_and_link_sif_s master_wh_link_li, master_wh_link_lo;
bsg_ready_and_link_sif_s client_wh_link_li, client_wh_link_lo;
bsg_ready_and_link_sif_s [1:0] ct_link_li, ct_link_lo;

logic [1:0] ct_fifo_valid_lo, ct_fifo_yumi_li;
logic [1:0] ct_fifo_valid_li, ct_fifo_yumi_lo;
logic [1:0][noc_width_p-1:0] ct_fifo_data_lo, ct_fifo_data_li;

assign lce_req_link_stitch_li[W]       = '0;
assign lce_resp_link_stitch_li[W]      = '0;
assign lce_data_resp_link_stitch_li[W] = '0;
assign lce_cmd_link_stitch_li[W]       = '0;
assign lce_data_cmd_link_stitch_li[W]  = '0;

assign lce_req_link_stitch_li[E]       = '0;
assign lce_resp_link_stitch_li[E]      = '0;
assign lce_data_resp_link_stitch_li[E] = '0;
assign lce_cmd_link_stitch_li[E]       = '0;
assign lce_data_cmd_link_stitch_li[E]  = '0;

genvar i;

/************************* RESET *************************/

// Config Registers
logic reset_r;
always_ff @(posedge clk_i) 
  begin
    if (reset_i)
        reset_r <= 1'b1;
    else
        if (cfg_link_w_v_lo & (cfg_link_addr_lo == bp_cfg_reg_reset_gp)) 
            reset_r <= cfg_link_data_lo[0];
  end


/************************* BSG TAG *************************/

// FIXME: hardcoded router IDs, should replace with bsg_tag_clients
logic [num_routers_lp-1:0][cord_width_lp-1:0] my_cord_lo, dest_cord_lo;
for (i = 0; i < num_routers_lp; i++)
  begin
    assign my_cord_lo[i]   = cord_width_lp'(i);
    assign dest_cord_lo[i] = cord_width_lp'(num_routers_lp);
  end


/************************* Clint Node *************************/

// Mapping clint to router-pos
// Clint is in the middle of chain, for single core it is at position 1
localparam clint_pos_lp = `BSG_CDIV(num_cce_p, 2);

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

bp_me_cce_to_wormhole_link_async_client
 #(.cfg_p(cfg_p)
  ,.x_cord_width_p(noc_x_cord_width_lp)
  ,.y_cord_width_p(noc_y_cord_width_lp)
  )
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
     
  ,.my_x_i(my_cord_lo[clint_pos_lp][noc_x_cord_width_lp-1:0])
  ,.my_y_i(noc_y_cord_width_lp'(0))
  
  // FIXME: connect to another clock domain
  ,.wormhole_clk_i(clk_i)
  ,.wormhole_reset_i(reset_i)
     
  ,.link_i(client_wh_link_li)
  ,.link_o(client_wh_link_lo)
  );

// Clint client link
// cmd
assign client_wh_link_li.v                         = cmd_link_lo[clint_pos_lp][P].v;
assign client_wh_link_li.data                      = cmd_link_lo[clint_pos_lp][P].data;
assign cmd_link_li [clint_pos_lp][P].ready_and_rev = client_wh_link_lo.ready_and_rev;
// resp                                            
assign resp_link_li[clint_pos_lp][P].v             = client_wh_link_lo.v;
assign resp_link_li[clint_pos_lp][P].data          = client_wh_link_lo.data;
assign client_wh_link_li.ready_and_rev             = resp_link_lo[clint_pos_lp][P].ready_and_rev;
// stub
assign cmd_link_li [clint_pos_lp][P].v             = 1'b0;
assign resp_link_li[clint_pos_lp][P].ready_and_rev = 1'b1;


/************************* BP Tiles *************************/

    // FIXME: index hardcoded to 0
    localparam i_lp = 0;
    // Mapping tile-index to router-pos
    // Tiles with index >= clint_pos_lp has position (index+1)
    localparam tile_pos_lp = i_lp + (i_lp / clint_pos_lp);

    // BP Tiles
    bp_proc_cfg_s proc_cfg;
    assign proc_cfg.core_id   = 1'b0;
    assign proc_cfg.cce_id    = 1'b0;
    assign proc_cfg.icache_id = 1'b0;
    assign proc_cfg.dcache_id = 1'b1;

    bp_tile
     #(.cfg_p(cfg_p)
       ,.calc_trace_p(calc_trace_p)
       ,.cce_trace_p(cce_trace_p)
       )
     tile
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.proc_cfg_i(proc_cfg)

       ,.my_x_i(x_cord_width_p'(0))
       ,.my_y_i(y_cord_width_p'(0))

       ,.cfg_w_v_i(cfg_link_w_v_lo)
       ,.cfg_addr_i(cfg_link_addr_lo)
       ,.cfg_data_i(cfg_link_data_lo)

       // Router inputs
       ,.lce_req_link_i(lce_req_link_stitch_li)
       ,.lce_resp_link_i(lce_resp_link_stitch_li)
       ,.lce_data_resp_link_i(lce_data_resp_link_stitch_li)
       ,.lce_cmd_link_i(lce_cmd_link_stitch_li)
       ,.lce_data_cmd_link_i(lce_data_cmd_link_stitch_li)

       // Router outputs
       ,.lce_req_link_o(lce_req_link_stitch_lo)
       ,.lce_resp_link_o(lce_resp_link_stitch_lo)
       ,.lce_data_resp_link_o(lce_data_resp_link_stitch_lo)
       ,.lce_cmd_link_o(lce_cmd_link_stitch_lo)
       ,.lce_data_cmd_link_o(lce_data_cmd_link_stitch_lo)

       ,.mem_resp_i(mem_resp_li)
       ,.mem_resp_v_i(mem_resp_v_li)
       ,.mem_resp_ready_o(mem_resp_ready_lo)

       ,.mem_data_resp_i(mem_data_resp_li)
       ,.mem_data_resp_v_i(mem_data_resp_v_li)
       ,.mem_data_resp_ready_o(mem_data_resp_ready_lo)

       ,.mem_cmd_o(mem_cmd_lo)
       ,.mem_cmd_v_o(mem_cmd_v_lo)
       ,.mem_cmd_yumi_i(mem_cmd_yumi_li)

       ,.mem_data_cmd_o(mem_data_cmd_lo)
       ,.mem_data_cmd_v_o(mem_data_cmd_v_lo)
       ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_li)

       ,.timer_int_i(timer_irq_lo)
       ,.software_int_i(soft_irq_lo)
       ,.external_int_i(external_irq_lo)
       );
    
    bp_me_cce_to_wormhole_link_async_master
     #(.cfg_p(cfg_p)
      ,.x_cord_width_p(noc_x_cord_width_lp)
      ,.y_cord_width_p(noc_y_cord_width_lp)
      )
      master_async_link
      (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.mem_cmd_i(mem_cmd_lo)
      ,.mem_cmd_v_i(mem_cmd_v_lo)
      ,.mem_cmd_yumi_o(mem_cmd_yumi_li)

      ,.mem_data_cmd_i(mem_data_cmd_lo)
      ,.mem_data_cmd_v_i(mem_data_cmd_v_lo)
      ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_li)

      ,.mem_resp_o(mem_resp_li)
      ,.mem_resp_v_o(mem_resp_v_li)
      ,.mem_resp_ready_i(mem_resp_ready_lo)

      ,.mem_data_resp_o(mem_data_resp_li)
      ,.mem_data_resp_v_o(mem_data_resp_v_li)
      ,.mem_data_resp_ready_i(mem_data_resp_ready_lo)
      
      ,.my_x_i(my_cord_lo[tile_pos_lp][noc_x_cord_width_lp-1:0])
      ,.my_y_i(noc_y_cord_width_lp'(0))
      
      ,.clint_x_cord_i(my_cord_lo[clint_pos_lp][noc_x_cord_width_lp-1:0])
      ,.clint_y_cord_i(noc_y_cord_width_lp'(0))
      
      ,.dram_x_cord_i(dest_cord_lo[tile_pos_lp][noc_x_cord_width_lp-1:0])
      ,.dram_y_cord_i(noc_y_cord_width_lp'(0))
      
      // FIXME: connect to another clock domain
      ,.wormhole_clk_i(clk_i)
      ,.wormhole_reset_i(reset_i)
     
      ,.link_i(master_wh_link_li)
      ,.link_o(master_wh_link_lo)
      );
      
    // BP Tile master link
    // cmd
    assign cmd_link_li[tile_pos_lp][P].v              = master_wh_link_lo.v;
    assign cmd_link_li[tile_pos_lp][P].data           = master_wh_link_lo.data;
    assign master_wh_link_li.ready_and_rev            = cmd_link_lo[tile_pos_lp][P].ready_and_rev;
    // resp
    assign master_wh_link_li.v                        = resp_link_lo[tile_pos_lp][P].v;
    assign master_wh_link_li.data                     = resp_link_lo[tile_pos_lp][P].data;
    assign resp_link_li[tile_pos_lp][P].ready_and_rev = master_wh_link_lo.ready_and_rev;
    // stub
    assign cmd_link_li [tile_pos_lp][P].ready_and_rev = 1'b1;
    assign resp_link_li[tile_pos_lp][P].v             = 1'b0;


/************************* Wormhole Router *************************/

for (i = 0; i < num_routers_lp; i++)
  begin
    // cmd router
    bsg_wormhole_router_generalized
   #(.flit_width_p      (noc_width_p)
    ,.dims_p            (dims_lp)
    ,.cord_markers_pos_p(cord_markers_pos_lp)
    ,.routing_matrix_p  (routing_matrix_lp)
    ,.len_width_p       (noc_len_width_p)
    )
    cmd_router
    (.clk_i    (clk_i)
	,.reset_i  (reset_i)
	,.my_cord_i(my_cord_lo[i])
    ,.link_i   (cmd_link_li[i])
    ,.link_o   (cmd_link_lo[i])
	);
  
    // resp router
    bsg_wormhole_router_generalized
   #(.flit_width_p      (noc_width_p)
    ,.dims_p            (dims_lp)
    ,.cord_markers_pos_p(cord_markers_pos_lp)
    ,.routing_matrix_p  (routing_matrix_lp)
    ,.len_width_p       (noc_len_width_p)
    )
    resp_router
    (.clk_i    (clk_i)
	,.reset_i  (reset_i)
	,.my_cord_i(my_cord_lo[i])
    ,.link_i   (resp_link_li[i])
    ,.link_o   (resp_link_lo[i])
	);
    
    // Link to next router
    if (i != num_routers_lp-1)
      begin
        assign cmd_link_li [i]  [E] = cmd_link_lo [i+1][W];
        assign resp_link_li[i]  [E] = resp_link_lo[i+1][W];
        assign cmd_link_li [i+1][W] = cmd_link_lo [i]  [E];
        assign resp_link_li[i+1][W] = resp_link_lo[i]  [E];
      end
  end


/************************* Channel Tunnel *************************/

// Stub one side of router chain
assign cmd_link_li [0][W].v             = 1'b0;
assign cmd_link_li [0][W].ready_and_rev = 1'b1;
assign resp_link_li[0][W].v             = 1'b0;
assign resp_link_li[0][W].ready_and_rev = 1'b1;

// Connect channel tunnel on the other side of router chain
assign ct_link_li = {cmd_link_lo[num_routers_lp-1][E], resp_link_lo[num_routers_lp-1][E]};
assign {cmd_link_li[num_routers_lp-1][E], resp_link_li[num_routers_lp-1][E]} = ct_link_lo;

  for (i = 0; i < 2; i++) 
  begin: rof0
    // Must add a fifo here, convert yumi_o to ready_o
    bsg_two_fifo
   #(.width_p(noc_width_p)
    ) ct_fifo
    (.clk_i  (clk_i  )
    ,.reset_i(reset_i)
    ,.ready_o(ct_link_lo[i].ready_and_rev)
    ,.data_i (ct_link_li[i].data         )
    ,.v_i    (ct_link_li[i].v            )
    ,.v_o    (ct_fifo_valid_lo[i])
    ,.data_o (ct_fifo_data_lo [i])
    ,.yumi_i (ct_fifo_yumi_li [i])
    );
    assign ct_link_lo     [i].v    = ct_fifo_valid_li[i];
    assign ct_link_lo     [i].data = ct_fifo_data_li [i];
    assign ct_fifo_yumi_lo[i]      = ct_link_lo[i].v & ct_link_li[i].ready_and_rev;
  end

  bsg_channel_tunnel
 #(.width_p                (noc_width_p)
  ,.num_in_p               (2)
  ,.remote_credits_p       (ct_remote_credits_p)
  ,.use_pseudo_large_fifo_p(1)
  ,.lg_credit_decimation_p (ct_lg_credit_decimation_p)
  )
  ct
  (.clk_i  (clk_i  )
  ,.reset_i(reset_i)

  // incoming multiplexed data
  ,.multi_data_i(multi_data_i)
  ,.multi_v_i   (multi_v_i   )
  ,.multi_yumi_o(multi_yumi_o)

  // outgoing multiplexed data
  ,.multi_data_o(multi_data_o)
  ,.multi_v_o   (multi_v_o   )
  ,.multi_yumi_i(multi_yumi_i)

  // incoming demultiplexed data
  ,.data_i(ct_fifo_data_lo )
  ,.v_i   (ct_fifo_valid_lo)
  ,.yumi_o(ct_fifo_yumi_li )

  // outgoing demultiplexed data
  ,.data_o(ct_fifo_data_li )
  ,.v_o   (ct_fifo_valid_li)
  ,.yumi_i(ct_fifo_yumi_lo )
  );

endmodule : bp_top


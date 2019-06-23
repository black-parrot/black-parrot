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
 import bsg_wormhole_router_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   , localparam cce_mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)
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
   
   // FIXME: hardcoded
   , localparam noc_x_cord_width_lp = 8
   , localparam noc_y_cord_width_lp = 1

   // Wormhole parameters
   , localparam dims_lp = 1
   , localparam int cord_markers_pos_lp[dims_lp:0] = '{noc_x_cord_width_lp+noc_y_cord_width_lp, 0}
   , localparam cord_width_lp = cord_markers_pos_lp[dims_lp]
   , localparam dirs_lp = dims_lp*2+1
   , localparam bit [1:0][dirs_lp-1:0][dirs_lp-1:0] routing_matrix_lp = StrictX
   
   // Tile parameters
   , localparam num_tiles_lp = num_core_p
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

   // Arbitrarily set, should be set based on PD constraints
   , localparam reset_pipe_depth_lp = 10
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
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)
`declare_bp_lce_cce_if(num_cce_p
                       ,num_lce_p
                       ,paddr_width_p
                       ,lce_assoc_p
                       ,dword_width_p
                       ,cce_block_width_p
                       )
`declare_bsg_ready_and_link_sif_s(noc_width_p,bsg_ready_and_link_sif_s);

bp_mem_cce_resp_s      [num_cce_p-1:0] mem_resp_li;
logic                  [num_cce_p-1:0] mem_resp_v_li, mem_resp_ready_lo;

bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp_li;
logic                  [num_cce_p-1:0] mem_data_resp_v_li, mem_data_resp_ready_lo;

bp_cce_mem_cmd_s       [num_cce_p-1:0] mem_cmd_lo;
logic                  [num_cce_p-1:0] mem_cmd_v_lo, mem_cmd_yumi_li;

bp_cce_mem_data_cmd_s  [num_cce_p-1:0] mem_data_cmd_lo;
logic                  [num_cce_p-1:0] mem_data_cmd_v_lo, mem_data_cmd_yumi_li;
  
logic [num_core_p-1:0] timer_irq_lo, soft_irq_lo, external_irq_lo;

bsg_ready_and_link_sif_s [num_routers_lp-1:0][dirs_lp-1:0] cmd_link_li,  cmd_link_lo;
bsg_ready_and_link_sif_s [num_routers_lp-1:0][dirs_lp-1:0] resp_link_li, resp_link_lo;

logic [num_core_p-1:0]                       cfg_w_v_lo;
logic [num_core_p-1:0][cfg_addr_width_p-1:0] cfg_addr_lo;
logic [num_core_p-1:0][cfg_data_width_p-1:0] cfg_data_lo;

bsg_ready_and_link_sif_s [num_core_p-1:0] master_wh_link_li, master_wh_link_lo;
bsg_ready_and_link_sif_s                  client_wh_link_li, client_wh_link_lo;
bsg_ready_and_link_sif_s [1:0] ct_link_li, ct_link_lo;

logic [1:0] ct_fifo_valid_lo, ct_fifo_yumi_li;
logic [1:0] ct_fifo_valid_li, ct_fifo_yumi_lo;
logic [1:0][noc_width_p-1:0] ct_fifo_data_lo, ct_fifo_data_li;

/************************* RESET *************************/

logic reset_r;
bsg_dff_chain
 #(.width_p(1)
   ,.num_stages_p(reset_pipe_depth_lp)
   )
 reset_pipe
  (.clk_i(clk_i)
   ,.data_i(reset_i)
   ,.data_o(reset_r)
   );


/************************* BSG TAG *************************/

// FIXME: hardcoded router IDs, should replace with bsg_tag_clients
logic [num_routers_lp-1:0][cord_width_lp-1:0] my_cord_lo, dest_cord_lo;
for (genvar i = 0; i < num_routers_lp; i++)
  begin
    assign my_cord_lo  [i] = cord_width_lp'(i);
    assign dest_cord_lo[i] = cord_width_lp'(num_routers_lp);
  end

bsg_ready_and_link_sif_s [num_routers_lp-1:0] cc_cmd_link_li, cc_cmd_link_lo;
bsg_ready_and_link_sif_s [num_routers_lp-1:0] cc_resp_link_li, cc_resp_link_lo;

for (genvar i = 0; i < num_routers_lp; i++)
  begin : rof1
    assign cc_cmd_link_li[i]  = cmd_link_lo[i][P];
    assign cmd_link_li[i][P]  = cc_cmd_link_lo[i];
    assign cc_resp_link_li[i] = resp_link_lo[i][P];
    assign resp_link_li[i][P] = cc_resp_link_lo[i];
  end

bp_core_complex
 #(.cfg_p(cfg_p)
   ,.calc_trace_p(calc_trace_p)
   ,.cce_trace_p(cce_trace_p)
   )
  cc
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.my_cord_i(my_cord_lo)
   ,.dest_cord_i(dest_cord_lo)

   ,.cmd_link_i(cc_cmd_link_li)
   ,.cmd_link_o(cc_cmd_link_lo)

   ,.resp_link_i(cc_resp_link_li)
   ,.resp_link_o(cc_resp_link_lo)
   );

/************************* Wormhole Router *************************/

for (genvar i = 0; i < num_routers_lp; i++)
  begin: wh_router
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
	,.reset_i  (reset_r)
	,.my_cord_i(my_cord_lo [i])
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
	,.reset_i  (reset_r)
	,.my_cord_i(my_cord_lo [i])
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

  for (genvar i = 0; i < 2; i++) 
  begin: rof0
    // Must add a fifo here, convert yumi_o to ready_o
    bsg_two_fifo
   #(.width_p(noc_width_p)
    ) ct_fifo
    (.clk_i  (clk_i  )
    ,.reset_i(reset_r)
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
  ,.reset_i(reset_r)

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

endmodule : bp_multi_top


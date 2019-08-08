/**
 *
 * bp_tile.v
 *
 */

module bp_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::StrictYX;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)

   // Generalized Wormhole Router parameters
   , localparam dims_lp                                = 2
   , localparam coh_x_cord_width_lp                    = `BSG_SAFE_CLOG2(num_lce_p)
   , localparam coh_y_cord_width_lp                    = 1
   , localparam int coh_cord_markers_pos_lp[dims_lp:0] = 
     '{ coh_x_cord_width_lp+coh_y_cord_width_lp, coh_x_cord_width_lp, 0 }
   , localparam coh_cord_width_lp = coh_cord_markers_pos_lp[dims_lp]

   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_width_p)
   )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [proc_cfg_width_lp-1:0]                         proc_cfg_i

   // Config channel
   , input                                                 cfg_w_v_i
   , input [cfg_addr_width_p-1:0]                          cfg_addr_i
   , input [cfg_data_width_p-1:0]                          cfg_data_i

   // Connected to other tiles on east and west
   , input [E:W][coh_noc_ral_link_width_lp-1:0]            lce_req_link_i
   , output [E:W][coh_noc_ral_link_width_lp-1:0]           lce_req_link_o

   , input [E:W][coh_noc_ral_link_width_lp-1:0]            lce_cmd_link_i
   , output [E:W][coh_noc_ral_link_width_lp-1:0]           lce_cmd_link_o

   , input [E:W][coh_noc_ral_link_width_lp-1:0]            lce_resp_link_i
   , output [E:W][coh_noc_ral_link_width_lp-1:0]           lce_resp_link_o

   // Memory side connection
   , input [mem_noc_cord_width_p-1:0]                      my_cord_i
   , input [mem_noc_cord_width_p-1:0]                      dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                      mmio_cord_i

   , input [mem_noc_ral_link_width_lp-1:0]                 cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                 resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                resp_link_o

   // Interrupts
   , input                                                 timer_int_i
   , input                                                 software_int_i
   , input                                                 external_int_i
   );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

// Proc-side connections network connections
bp_lce_cce_req_s  [1:0] lce_req_lo;
logic             [1:0] lce_req_v_lo, lce_req_ready_li;
bp_lce_cce_resp_s [1:0] lce_resp_lo;
logic             [1:0] lce_resp_v_lo, lce_resp_ready_li;
bp_lce_cmd_s      [1:0] lce_cmd_li;
logic             [1:0] lce_cmd_v_li, lce_cmd_ready_lo;
bp_lce_cmd_s      [1:0] lce_cmd_lo;
logic             [1:0] lce_cmd_v_lo, lce_cmd_ready_li;

// CCE connections
bp_lce_cce_req_s  lce_req_li;
logic             lce_req_v_li, lce_req_ready_lo;
bp_lce_cce_resp_s lce_resp_li;
logic             lce_resp_v_li, lce_resp_ready_lo;
bp_lce_cmd_s      cce_lce_cmd_lo;
logic             cce_lce_cmd_v_lo, cce_lce_cmd_ready_li;

bp_proc_cfg_s proc_cfg_cast_i;
assign proc_cfg_cast_i = proc_cfg_i;

logic reset_r;
always_ff @(posedge clk_i)
  begin
    // This doesn't have a reset because it's a reset register
    if (reset_i)
      reset_r <= 1'b1;
    else if (cfg_w_v_i & (cfg_addr_i == bp_cfg_reg_reset_gp))
      reset_r <= cfg_data_i[0];
  end

logic freeze_r;
always_ff @(posedge clk_i)
  begin
    if (reset_i)
      freeze_r <= 1'b1;
    else if (cfg_w_v_i & (cfg_addr_i == bp_cfg_reg_freeze_gp))
      freeze_r <= cfg_data_i[0];
  end


// Module instantiations
bp_core   
 #(.cfg_p(cfg_p))
 core 
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.freeze_i(freeze_r)
   ,.proc_cfg_i(proc_cfg_i)

   ,.cfg_w_v_i(cfg_w_v_i)
   ,.cfg_addr_i(cfg_addr_i)
   ,.cfg_data_i(cfg_data_i)

   ,.lce_req_o(lce_req_lo)
   ,.lce_req_v_o(lce_req_v_lo)
   ,.lce_req_ready_i(lce_req_ready_li)

   ,.lce_resp_o(lce_resp_lo)
   ,.lce_resp_v_o(lce_resp_v_lo)
   ,.lce_resp_ready_i(lce_resp_ready_li)

   ,.lce_cmd_i(lce_cmd_li)
   ,.lce_cmd_v_i(lce_cmd_v_li)
   ,.lce_cmd_ready_o(lce_cmd_ready_lo)

   ,.lce_cmd_o(lce_cmd_lo)
   ,.lce_cmd_v_o(lce_cmd_v_lo)
   ,.lce_cmd_ready_i(lce_cmd_ready_li)
    
   ,.timer_int_i(timer_int_i)
   ,.software_int_i(software_int_i)
   ,.external_int_i(external_int_i)
   );

// Declare the routing links
`declare_bsg_ready_and_link_sif_s(coh_noc_width_p, bp_coh_ready_and_link_s);

// Intermediate 'stitch' connections between the routers
bp_coh_ready_and_link_s [1:0][S:P] lce_req_link_i_stitch, lce_req_link_o_stitch;
bp_coh_ready_and_link_s [1:0][S:P] lce_resp_link_i_stitch, lce_resp_link_o_stitch;
bp_coh_ready_and_link_s [1:0][S:P] lce_cmd_link_i_stitch, lce_cmd_link_o_stitch;

// Stitch together I$ and D$
assign lce_req_link_i_stitch[1][E]  = lce_req_link_i[E];
assign lce_resp_link_i_stitch[1][E] = lce_resp_link_i[E];
assign lce_cmd_link_i_stitch[1][E]  = lce_cmd_link_i[E];

assign lce_req_link_i_stitch[0][E]  = lce_req_link_o_stitch[1][W];
assign lce_resp_link_i_stitch[0][E] = lce_resp_link_o_stitch[1][W];
assign lce_cmd_link_i_stitch[0][E]  = lce_cmd_link_o_stitch[1][W];

assign lce_req_link_o[W]  = lce_req_link_o_stitch[0][W];
assign lce_resp_link_o[W] = lce_resp_link_o_stitch[0][W];
assign lce_cmd_link_o[W]  = lce_cmd_link_o_stitch[0][W];

assign lce_req_link_i_stitch[0][W]  = lce_req_link_i[W];
assign lce_resp_link_i_stitch[0][W] = lce_resp_link_i[W];
assign lce_cmd_link_i_stitch[0][W]  = lce_cmd_link_i[W];

assign lce_req_link_i_stitch[1][W]  = lce_req_link_o_stitch[0][E];
assign lce_resp_link_i_stitch[1][W] = lce_resp_link_o_stitch[0][E];
assign lce_cmd_link_i_stitch[1][W]  = lce_cmd_link_o_stitch[0][E];

assign lce_req_link_o[E]  = lce_req_link_o_stitch[1][E];
assign lce_resp_link_o[E] = lce_resp_link_o_stitch[1][E];
assign lce_cmd_link_o[E]  = lce_cmd_link_o_stitch[1][E];

// Stub unused inputs
// CCE doesn't connect on P at x=1 (D$) location, stub the input links
assign lce_req_link_i_stitch[1][P]  = '0;
assign lce_resp_link_i_stitch[1][P] = '0;

assign lce_req_link_i_stitch[1][S]  = '0;
assign lce_resp_link_i_stitch[1][S] = '0;
assign lce_cmd_link_i_stitch[1][S]  = '0;

// CCE is destination for req and resp networks
assign lce_req_link_i_stitch[0][S]  = '0;
assign lce_resp_link_i_stitch[0][S] = '0;

`declare_bsg_wormhole_router_packet_s(coh_cord_width_lp, coh_noc_len_width_p, lce_cce_req_width_lp, lce_req_packet_s);
`declare_bsg_wormhole_router_packet_s(coh_cord_width_lp, coh_noc_len_width_p, lce_cce_resp_width_lp, lce_resp_packet_s);
`declare_bsg_wormhole_router_packet_s(coh_cord_width_lp, coh_noc_len_width_p, lce_cmd_width_lp, lce_cmd_packet_s);

for (genvar i = 0; i < 2; i++)
  begin : rof3
    wire [coh_cord_width_lp-1:0] lce_id_li = (i == 0) ? proc_cfg_cast_i.icache_id : proc_cfg_cast_i.dcache_id;

    lce_req_packet_s lce_req_packet_lo;
    bp_me_wormhole_packet_encode_lce_req
     #(.cfg_p(cfg_p))
     req_encode
      (.payload_i(lce_req_lo[i])
       ,.packet_o(lce_req_packet_lo)
       );

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p(lce_cce_req_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(coh_cord_width_lp)
       ,.link_width_p(coh_noc_width_p)
       )
     req_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i(lce_req_packet_lo)
       ,.v_i(lce_req_v_lo[i])
       ,.ready_o(lce_req_ready_li[i])

       ,.link_i(lce_req_link_o_stitch[i][N])
       ,.link_o(lce_req_link_i_stitch[i][N])
       );

    bsg_wormhole_router_generalized
     #(.flit_width_p(coh_noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(coh_cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(coh_noc_len_width_p)
       )
     req_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.link_i(lce_req_link_i_stitch[i])
       ,.link_o(lce_req_link_o_stitch[i])

       ,.my_cord_i(lce_id_li)
       );

    lce_cmd_packet_s lce_cmd_packet_lo;
    bp_me_wormhole_packet_encode_lce_cmd
     #(.cfg_p(cfg_p))
     cmd_encode
      (.payload_i(lce_cmd_lo[i])
       ,.packet_o(lce_cmd_packet_lo)
       );

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p(lce_cmd_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(coh_cord_width_lp)
       ,.link_width_p(coh_noc_width_p)
       )
     cmd_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i(lce_cmd_packet_lo)
       ,.v_i(lce_cmd_v_lo[i])
       ,.ready_o(lce_cmd_ready_li[i])

       ,.link_i(lce_cmd_link_o_stitch[i][N])
       ,.link_o(lce_cmd_link_i_stitch[i][N])
       );
    
    bsg_wormhole_router_generalized
     #(.flit_width_p(coh_noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(coh_cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(coh_noc_len_width_p)
       )
     cmd_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
       
       ,.link_i(lce_cmd_link_i_stitch[i])
       ,.link_o(lce_cmd_link_o_stitch[i])

       ,.my_cord_i(lce_id_li)
       );

    lce_cmd_packet_s lce_cmd_packet_li;
    bsg_wormhole_router_adapter_out
     #(.max_payload_width_p(lce_cmd_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(coh_cord_width_lp)
       ,.link_width_p(coh_noc_width_p)
       )
     cmd_adapter_out
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.link_i(lce_cmd_link_o_stitch[i][P])
       ,.link_o(lce_cmd_link_i_stitch[i][P])

       ,.packet_o(lce_cmd_packet_li)
       ,.v_o(lce_cmd_v_li[i])
       ,.yumi_i(lce_cmd_ready_lo[i] & lce_cmd_v_li[i])
       );
    assign lce_cmd_li[i] = lce_cmd_packet_li.payload;

    lce_resp_packet_s lce_resp_packet_lo;
    bp_me_wormhole_packet_encode_lce_resp
     #(.cfg_p(cfg_p))
     resp_encode
      (.payload_i(lce_resp_lo[i])
       ,.packet_o(lce_resp_packet_lo)
       );

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p(lce_cce_resp_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(coh_cord_width_lp)
       ,.link_width_p(coh_noc_width_p)
       )
     resp_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i(lce_resp_packet_lo)
       ,.v_i(lce_resp_v_lo[i])
       ,.ready_o(lce_resp_ready_li[i])

       ,.link_i(lce_resp_link_o_stitch[i][N])
       ,.link_o(lce_resp_link_i_stitch[i][N])
       );

    bsg_wormhole_router_generalized
     #(.flit_width_p(coh_noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(coh_cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(coh_noc_len_width_p)
       )
     resp_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
       
       ,.link_i(lce_resp_link_i_stitch[i])
       ,.link_o(lce_resp_link_o_stitch[i])
       
       ,.my_cord_i(lce_id_li)
       );
  end // rof3
    
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
bp_cce_mem_cmd_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;
bp_mem_cce_resp_s      mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;

lce_req_packet_s lce_req_packet_li;
bsg_wormhole_router_adapter_out
 #(.max_payload_width_p(lce_cce_req_width_lp)
   ,.len_width_p(coh_noc_len_width_p)
   ,.cord_width_p(coh_cord_width_lp)
   ,.link_width_p(coh_noc_width_p)
   )
 req_adapter_out
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.link_i(lce_req_link_o_stitch[0][P])
   ,.link_o(lce_req_link_i_stitch[0][P])

   ,.packet_o(lce_req_packet_li)
   ,.v_o(lce_req_v_li)
   ,.yumi_i(lce_req_ready_lo & lce_req_v_li)
   );
assign lce_req_li = lce_req_packet_li.payload;

lce_cmd_packet_s cce_lce_cmd_packet_lo;
bp_me_wormhole_packet_encode_lce_cmd
 #(.cfg_p(cfg_p))
 cmd_encode
  (.payload_i(cce_lce_cmd_lo)
   ,.packet_o(cce_lce_cmd_packet_lo)
   );

bsg_wormhole_router_adapter_in
 #(.max_payload_width_p(lce_cmd_width_lp)
   ,.len_width_p(coh_noc_len_width_p)
   ,.cord_width_p(coh_cord_width_lp)
   ,.link_width_p(coh_noc_width_p)
   )
 cmd_adapter_in
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.packet_i(cce_lce_cmd_packet_lo)
   ,.v_i(cce_lce_cmd_v_lo)
   ,.ready_o(cce_lce_cmd_ready_li)

   ,.link_i(lce_cmd_link_o_stitch[0][S])
   ,.link_o(lce_cmd_link_i_stitch[0][S])
   );

lce_resp_packet_s lce_resp_packet_li;
bsg_wormhole_router_adapter_out
 #(.max_payload_width_p(lce_cce_resp_width_lp)
   ,.len_width_p(coh_noc_len_width_p)
   ,.cord_width_p(coh_cord_width_lp)
   ,.link_width_p(coh_noc_width_p)
   )
 resp_adapter_out
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.link_i(lce_resp_link_o_stitch[0][P])
   ,.link_o(lce_resp_link_i_stitch[0][P])

   ,.packet_o(lce_resp_packet_li)
   ,.v_o(lce_resp_v_li)
   ,.yumi_i(lce_resp_ready_lo & lce_resp_v_li)
   );
assign lce_resp_li = lce_resp_packet_li.payload;

bp_cce_top
 #(.cfg_p(cfg_p))
 cce
  (.clk_i(clk_i)
   ,.reset_i(reset_r)
   ,.freeze_i(freeze_r)

   ,.cfg_w_v_i(cfg_w_v_i)
   ,.cfg_addr_i(cfg_addr_i)
   ,.cfg_data_i(cfg_data_i)

   // To CCE
   ,.lce_req_i(lce_req_li)
   ,.lce_req_v_i(lce_req_v_li)
   ,.lce_req_ready_o(lce_req_ready_lo)

   ,.lce_resp_i(lce_resp_li)
   ,.lce_resp_v_i(lce_resp_v_li)
   ,.lce_resp_ready_o(lce_resp_ready_lo)

   // From CCE
   ,.lce_cmd_o(cce_lce_cmd_lo)
   ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
   ,.lce_cmd_ready_i(cce_lce_cmd_ready_li)

   // To CCE
   ,.mem_resp_i(mem_resp_li)
   ,.mem_resp_v_i(mem_resp_v_li)
   ,.mem_resp_ready_o(mem_resp_ready_lo)

   // From CCE
   ,.mem_cmd_o(mem_cmd_lo)
   ,.mem_cmd_v_o(mem_cmd_v_lo)
   ,.mem_cmd_yumi_i(mem_cmd_yumi_li)

   ,.cce_id_i(proc_cfg_cast_i.cce_id) 
   );


// CCE-MEM IF to Wormhole routed interface

`declare_bsg_ready_and_link_sif_s(mem_noc_width_p, bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s cmd_link_cast_i, cmd_link_cast_o;
bsg_ready_and_link_sif_s resp_link_cast_i, resp_link_cast_o;

assign cmd_link_cast_i  = cmd_link_i;
assign cmd_link_o       = cmd_link_cast_o;

assign resp_link_cast_i = resp_link_i;
assign resp_link_o      = resp_link_cast_o;

logic [mem_noc_cord_width_p-1:0] cmd_dest_cord_lo;
bp_addr_map
 #(.cfg_p(cfg_p))
 cmd_map
  (.paddr_i(mem_cmd_lo.addr)

  ,.mmio_cord_i(mmio_cord_i)
  ,.dram_cord_i(dram_cord_i)

  ,.dest_cord_o(cmd_dest_cord_lo)
  );

bsg_ready_and_link_sif_s wh_master_link_li, wh_master_link_lo;
bp_me_cce_to_wormhole_link_master
 #(.cfg_p(cfg_p))
 master_link
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.mem_cmd_i(mem_cmd_lo)
   ,.mem_cmd_v_i(mem_cmd_v_lo)
   ,.mem_cmd_yumi_o(mem_cmd_yumi_li)

   ,.mem_resp_o(mem_resp_li)
   ,.mem_resp_v_o(mem_resp_v_li)
   ,.mem_resp_ready_i(mem_resp_ready_lo)

   ,.my_cord_i(my_cord_i)
   ,.mem_cmd_dest_cord_i(cmd_dest_cord_lo)

   ,.link_i(wh_master_link_li)
   ,.link_o(wh_master_link_lo)
   );

// Not used at the moment by bp_tile, stubbed
bsg_ready_and_link_sif_s wh_client_link_li, wh_client_link_lo;
bp_me_cce_to_wormhole_link_client
 #(.cfg_p(cfg_p))
 client_link
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.mem_cmd_o()
   ,.mem_cmd_v_o()
   ,.mem_cmd_yumi_i('0)

   ,.mem_resp_i('0)
   ,.mem_resp_v_i('0)
   ,.mem_resp_ready_o()

   ,.my_cord_i(my_cord_i)

   ,.link_i(wh_client_link_li)
   ,.link_o(wh_client_link_lo)
   );

assign wh_client_link_li.v             = cmd_link_cast_i.v;
assign wh_client_link_li.data          = cmd_link_cast_i.data;
assign wh_client_link_li.ready_and_rev = resp_link_cast_i.ready_and_rev;

assign wh_master_link_li.v             = resp_link_cast_i.v;
assign wh_master_link_li.data          = resp_link_cast_i.data;
assign wh_master_link_li.ready_and_rev = cmd_link_cast_i.ready_and_rev;

assign resp_link_cast_o.v = wh_client_link_lo.v;
assign resp_link_cast_o.data = wh_client_link_lo.data;
assign resp_link_cast_o.ready_and_rev = wh_master_link_lo.ready_and_rev;

assign cmd_link_cast_o.v = wh_master_link_lo.v;
assign cmd_link_cast_o.data = wh_master_link_lo.data;
assign cmd_link_cast_o.ready_and_rev = wh_client_link_lo.ready_and_rev;

endmodule : bp_tile


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
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
   `declare_bp_lce_cce_if_widths
     (num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)

   , localparam dirs_lp = 5 // S (Mem side) EW (LCE sides), P (Proc side)

   // Used to enable trace replay outputs for testbench
   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1

   , localparam lce_cce_req_network_width_lp = 
       lce_cce_req_width_lp+x_cord_width_p+y_cord_width_p
   , localparam lce_cce_resp_network_width_lp = 
       lce_cce_resp_width_lp+x_cord_width_p+y_cord_width_p
   , localparam cce_lce_cmd_network_width_lp = 
       cce_lce_cmd_width_lp+x_cord_width_p+y_cord_width_p

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
   , localparam lce_data_cmd_payload_offset_lp = 
       (x_cord_width_p+y_cord_width_p+lce_data_cmd_len_width_lp)

   // Generalized Wormhole Router parameters
   , localparam dims_lp = 2
   , localparam int cord_markers_pos_lp[dims_lp:0] =
       '{ x_cord_width_p+y_cord_width_p, x_cord_width_p, 0 }

   // CCE-MEM Wormhole link parameters
   , parameter noc_x_cord_width_p = "inv"
   , parameter noc_y_cord_width_p = "inv"
   // Wormhole parameters
   , localparam mem_wh_dims_lp = 1
   , localparam int mem_wh_cord_markers_pos_lp[mem_wh_dims_lp:0] =
       '{noc_x_cord_width_p+noc_y_cord_width_p, 0}
   , localparam cord_width_lp = mem_wh_cord_markers_pos_lp[mem_wh_dims_lp]

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
   )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [proc_cfg_width_lp-1:0]                         proc_cfg_i

   , input [x_cord_width_p-1:0]                            my_x_i
   , input [y_cord_width_p-1:0]                            my_y_i

   // Config channel
   , input                                                 cfg_w_v_i
   , input [cfg_addr_width_p-1:0]                          cfg_addr_i
   , input [cfg_data_width_p-1:0]                          cfg_data_i

   // Router - Inputs 
   // Connected on east and west
   , input [E:W][2+lce_cce_req_network_width_lp-1:0]       lce_req_link_i
   , input [E:W][2+lce_cce_resp_network_width_lp-1:0]      lce_resp_link_i
   , input [E:W][2+lce_cce_data_resp_router_width_lp-1:0]  lce_data_resp_link_i
   , input [E:W][2+cce_lce_cmd_network_width_lp-1:0]       lce_cmd_link_i
   , input [E:W][2+lce_data_cmd_router_width_lp-1:0]       lce_data_cmd_link_i

   // Router - Outputs
   // Connected on east and west
   , output [E:W][2+lce_cce_req_network_width_lp-1:0]      lce_req_link_o
   , output [E:W][2+lce_cce_resp_network_width_lp-1:0]     lce_resp_link_o
   , output [E:W][2+lce_cce_data_resp_router_width_lp-1:0] lce_data_resp_link_o
   , output [E:W][2+cce_lce_cmd_network_width_lp-1:0]      lce_cmd_link_o
   , output [E:W][2+lce_data_cmd_router_width_lp-1:0]      lce_data_cmd_link_o

   // Memory side connection
   , input [noc_cord_width_p-1:0]                          my_cord_i
   , input [noc_cord_width_p-1:0]                          dram_cord_i
   , input [noc_cord_width_p-1:0]                          clint_cord_i
   , input [noc_cord_width_p-1:0]                          openpiton_cord_i

   , input [bsg_ready_and_link_sif_width_lp-1:0]           cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]          cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]           resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]          resp_link_o

   // Interrupts
   , input                                     timer_int_i
   , input                                     software_int_i
   , input                                     external_int_i
  );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_lce_cce_if
  (num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

// Proc-side connections network connections
bp_lce_cce_req_s       [1:0] lce_req_lo;
logic                  [1:0] lce_req_v_lo, lce_req_ready_li;
bp_lce_cce_resp_s      [1:0] lce_resp_lo;
logic                  [1:0] lce_resp_v_lo, lce_resp_ready_li;
bp_lce_cce_data_resp_s [1:0] lce_data_resp_lo;
logic                  [1:0] lce_data_resp_v_lo, lce_data_resp_ready_li;
bp_cce_lce_cmd_s       [1:0] lce_cmd_li;
logic                  [1:0] lce_cmd_v_li, lce_cmd_ready_lo;
bp_lce_data_cmd_s      [1:0] lce_data_cmd_li;
logic                  [1:0] lce_data_cmd_v_li, lce_data_cmd_ready_lo;
bp_lce_data_cmd_s      [1:0] lce_lce_data_cmd_lo;
logic                  [1:0] lce_lce_data_cmd_v_lo, lce_lce_data_cmd_ready_li;

// CCE connections
bp_lce_cce_req_s             lce_req_li;
logic                        lce_req_v_li, lce_req_ready_lo;
bp_lce_cce_resp_s            lce_resp_li;
logic                        lce_resp_v_li, lce_resp_ready_lo;
bp_lce_cce_data_resp_s       lce_data_resp_li;
logic                        lce_data_resp_v_li, lce_data_resp_ready_lo;
bp_cce_lce_cmd_s             lce_cmd_lo;
logic                        lce_cmd_v_lo, lce_cmd_ready_li;
bp_lce_data_cmd_s            cce_lce_data_cmd_lo;
logic                        cce_lce_data_cmd_v_lo, cce_lce_data_cmd_ready_li;

bp_proc_cfg_s proc_cfg_cast_i;
assign proc_cfg_cast_i = proc_cfg_i;

logic freeze_r;
always_ff @(posedge clk_i)
  begin
    if (reset_i)
      freeze_r <= 1'b1;
    else if (cfg_w_v_i & (cfg_addr_i == bp_cfg_reg_freeze_gp))
      freeze_r <= cfg_data_i[0];
  end

logic reset_r;
bsg_dff
 #(.width_p(1))
 reset_reg
  (.clk_i(clk_i)
   ,.data_i(reset_i)
   ,.data_o(reset_r)
   );


// Module instantiations
bp_core   
 #(.cfg_p(cfg_p)
   ,.calc_trace_p(calc_trace_p)
   )
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

   ,.lce_data_resp_o(lce_data_resp_lo)
   ,.lce_data_resp_v_o(lce_data_resp_v_lo)
   ,.lce_data_resp_ready_i(lce_data_resp_ready_li)

   ,.lce_cmd_i(lce_cmd_li)
   ,.lce_cmd_v_i(lce_cmd_v_li)
   ,.lce_cmd_ready_o(lce_cmd_ready_lo)

   ,.lce_data_cmd_i(lce_data_cmd_li)
   ,.lce_data_cmd_v_i(lce_data_cmd_v_li)
   ,.lce_data_cmd_ready_o(lce_data_cmd_ready_lo)

   ,.lce_data_cmd_o(lce_lce_data_cmd_lo)
   ,.lce_data_cmd_v_o(lce_lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_i(lce_lce_data_cmd_ready_li)
    
   ,.timer_int_i(timer_int_i)
   ,.software_int_i(software_int_i)
   ,.external_int_i(external_int_i)
   );

// Declare the routing links
`declare_bsg_ready_and_link_sif_s(lce_cce_req_network_width_lp, bp_lce_req_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_cce_resp_network_width_lp, bp_lce_resp_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(cce_lce_cmd_network_width_lp, bp_lce_cmd_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_cce_data_resp_router_width_lp, bp_lce_data_resp_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_data_cmd_router_width_lp, bp_lce_data_cmd_ready_and_link_sif_s);

// Intermediate 'stitch' connections between the routers
bp_lce_req_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_req_link_i_stitch, lce_req_link_o_stitch;
bp_lce_resp_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_resp_link_i_stitch, lce_resp_link_o_stitch;
bp_lce_data_resp_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_data_resp_link_i_stitch, lce_data_resp_link_o_stitch;
bp_lce_cmd_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_cmd_link_i_stitch, lce_cmd_link_o_stitch;
bp_lce_data_cmd_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_data_cmd_link_i_stitch, lce_data_cmd_link_o_stitch;

logic [1:0][lce_cce_data_resp_packet_width_lp-1:0] lce_data_resp_packet;
logic [1:0][lce_data_cmd_packet_width_lp-1:0]      lce_lce_data_cmd_packet;
logic [lce_data_cmd_packet_width_lp-1:0]           cce_lce_data_cmd_packet;

// Extract destination ids from packets
// Note: We shift by 1 to make a CCE id of 1 -> x=2
wire [x_cord_width_p-1:0] lce_req_dst_x_cord_0_lo  = lce_req_lo[0].dst_id << 1;
wire [x_cord_width_p-1:0] lce_req_dst_x_cord_1_lo  = lce_req_lo[1].dst_id << 1;
wire [x_cord_width_p-1:0] lce_resp_dst_x_cord_0_lo = lce_resp_lo[0].dst_id << 1;
wire [x_cord_width_p-1:0] lce_resp_dst_x_cord_1_lo = lce_resp_lo[1].dst_id << 1;
wire [x_cord_width_p-1:0] lce_cmd_dst_x_cord_lo    = lce_cmd_lo.dst_id;

for (genvar i = 0; i < dirs_lp; i++)
  begin : rof1
    if (i == E) // Transfer side
      begin : fi1_E
        assign lce_req_link_i_stitch[1][E]  = lce_req_link_i[E];
        assign lce_resp_link_i_stitch[1][E] = lce_resp_link_i[E];
        assign lce_data_resp_link_i_stitch[1][E] = lce_data_resp_link_i[E];
        assign lce_cmd_link_i_stitch[1][E]  = lce_cmd_link_i[E];
        assign lce_data_cmd_link_i_stitch[1][E] = lce_data_cmd_link_i[E];

        assign lce_req_link_i_stitch[0][E]  = lce_req_link_o_stitch[1][W];
        assign lce_resp_link_i_stitch[0][E] = lce_resp_link_o_stitch[1][W];
        assign lce_data_resp_link_i_stitch[0][E] = lce_data_resp_link_o_stitch[1][W];
        assign lce_cmd_link_i_stitch[0][E]  = lce_cmd_link_o_stitch[1][W];
        assign lce_data_cmd_link_i_stitch[0][E] = lce_data_cmd_link_o_stitch[1][W];

        assign lce_req_link_o[W]  = lce_req_link_o_stitch[0][W];
        assign lce_resp_link_o[W] = lce_resp_link_o_stitch[0][W];
        assign lce_data_resp_link_o[W]  = lce_data_resp_link_o_stitch[0][W];
        assign lce_cmd_link_o[W]  = lce_cmd_link_o_stitch[0][W];
        assign lce_data_cmd_link_o[W]  = lce_data_cmd_link_o_stitch[0][W];
      end
    else if (i == W) // Transfer side
      begin : fi1_W
        assign lce_req_link_i_stitch[0][W]  = lce_req_link_i[W];
        assign lce_resp_link_i_stitch[0][W] = lce_resp_link_i[W];
        assign lce_data_resp_link_i_stitch[0][W] = lce_data_resp_link_i[W];
        assign lce_cmd_link_i_stitch[0][W]  = lce_cmd_link_i[W];
        assign lce_data_cmd_link_i_stitch[0][W]  = lce_data_cmd_link_i[W];

        assign lce_req_link_i_stitch[1][W]  = lce_req_link_o_stitch[0][E];
        assign lce_resp_link_i_stitch[1][W] = lce_resp_link_o_stitch[0][E];
        assign lce_data_resp_link_i_stitch[1][W]  = lce_data_resp_link_o_stitch[0][E];
        assign lce_cmd_link_i_stitch[1][W]  = lce_cmd_link_o_stitch[0][E];
        assign lce_data_cmd_link_i_stitch[1][W]  = lce_data_cmd_link_o_stitch[0][E];

        assign lce_req_link_o[E]  = lce_req_link_o_stitch[1][E];
        assign lce_resp_link_o[E] = lce_resp_link_o_stitch[1][E];
        assign lce_data_resp_link_o[E] = lce_data_resp_link_o_stitch[1][E];
        assign lce_cmd_link_o[E]  = lce_cmd_link_o_stitch[1][E];
        assign lce_data_cmd_link_o[E]  = lce_data_cmd_link_o_stitch[1][E];
      end
    else if (i == P) // Destination side
      begin : fi1_P
        // To CCE - attached at I$ (x-cord 0)
        assign lce_req_li   = lce_req_link_o_stitch[0][P].data[1+x_cord_width_p+:lce_cce_req_width_lp];
        assign lce_req_v_li = lce_req_link_o_stitch[0][P].v;
        assign lce_req_link_i_stitch[0][P] = '{ready_and_rev: lce_req_ready_lo, default: '0};

        assign lce_resp_li   = lce_resp_link_o_stitch[0][P].data[1+x_cord_width_p+:lce_cce_resp_width_lp];
        assign lce_resp_v_li = lce_resp_link_o_stitch[0][P].v;
        assign lce_resp_link_i_stitch[0][P] = '{ready_and_rev: lce_resp_ready_lo, default: '0};

        // LCE Data Response at x=0 driven by wormhole adapter
        // LCE Data Command at x=0 driven by wormhole adapter

        // To I$
        assign lce_cmd_li[0]   = lce_cmd_link_o_stitch[0][P].data[1+x_cord_width_p+:cce_lce_cmd_width_lp]; 
        assign lce_cmd_v_li[0] = lce_cmd_link_o_stitch[0][P].v;
        assign lce_cmd_link_i_stitch[0][P]  = '{ready_and_rev: lce_cmd_ready_lo[0], default: '0};

        // CCE doesn't connect on P at x=1 (D$) location, stub the input links
        assign lce_req_link_i_stitch[1][P] = '0;
        assign lce_resp_link_i_stitch[1][P] = '0;
        assign lce_data_resp_link_i_stitch[1][P] = '0;

        assign lce_cmd_li[1]   = lce_cmd_link_o_stitch[1][P].data[1+x_cord_width_p+:cce_lce_cmd_width_lp]; 
        assign lce_cmd_v_li[1] = lce_cmd_link_o_stitch[1][P].v;
        assign lce_cmd_link_i_stitch[1][P]  = '{ready_and_rev: lce_cmd_ready_lo[1], default: '0};

        // LCE Data Command at x=1 driven by wormhole adapter
      end
    else if (i == S) // Source side
      begin : fi1_S
        assign lce_req_link_i_stitch[0][S].data          = {lce_req_lo[0], 1'b0, lce_req_dst_x_cord_0_lo}; 
        assign lce_req_link_i_stitch[0][S].v             = lce_req_v_lo[0];
        assign lce_req_link_i_stitch[0][S].ready_and_rev = '0;
        assign lce_req_ready_li[0] = lce_req_link_o_stitch[0][S].ready_and_rev;

        assign lce_resp_link_i_stitch[0][S].data          = {lce_resp_lo[0], 1'b0, lce_resp_dst_x_cord_0_lo};
        assign lce_resp_link_i_stitch[0][S].v             = lce_resp_v_lo[0];
        assign lce_resp_link_i_stitch[0][S].ready_and_rev = '0;
        assign lce_resp_ready_li[0] = lce_resp_link_o_stitch[0][S].ready_and_rev;

        assign lce_cmd_link_i_stitch[0][S].data          = {lce_cmd_lo, 1'b0, lce_cmd_dst_x_cord_lo};
        assign lce_cmd_link_i_stitch[0][S].v             = lce_cmd_v_lo;
        assign lce_cmd_link_i_stitch[0][S].ready_and_rev = '0;
        assign lce_cmd_ready_li = lce_cmd_link_o_stitch[0][S].ready_and_rev;

        // LCE Data Command at x=0 driven by wormhole adapter

        // LCE Data Response is sent on North port
        assign lce_data_resp_link_i_stitch[0][S] = '0;

        assign lce_req_link_i_stitch[1][S].data          = {lce_req_lo[1], 1'b0, lce_req_dst_x_cord_1_lo}; 
        assign lce_req_link_i_stitch[1][S].v             = lce_req_v_lo[1];
        assign lce_req_link_i_stitch[1][S].ready_and_rev = '0;
        assign lce_req_ready_li[1] = lce_req_link_o_stitch[1][S].ready_and_rev;

        assign lce_resp_link_i_stitch[1][S].data          = {lce_resp_lo[1], 1'b0, lce_resp_dst_x_cord_1_lo}; 
        assign lce_resp_link_i_stitch[1][S].v             = lce_resp_v_lo[1];
        assign lce_resp_link_i_stitch[1][S].ready_and_rev = '0;
        assign lce_resp_ready_li[1] = lce_resp_link_o_stitch[1][S].ready_and_rev;

        // CCE is attached at x=0 only
        assign lce_cmd_link_i_stitch[1][S]             = '0;
        assign lce_data_cmd_link_i_stitch[1][S]        = '0;

        // LCE Data Response is sent on North port
        assign lce_data_resp_link_i_stitch[1][S]       = '0;
      end
    else
      begin : fi_N
        assign lce_req_link_i_stitch[0][N]     = '0;
        assign lce_resp_link_i_stitch[0][N]    = '0;
        // I$ data resp wh router fed from adapter
        //assign lce_data_resp_link_i_stitch[0][N] = '0;
        assign lce_cmd_link_i_stitch[0][N]     = '0;
        // I$ data cmd wh router fed from adapter
        //assign lce_data_cmd_link_i_stitch[0][N]  = '0;

        assign lce_req_link_i_stitch[1][N]     = '0;
        assign lce_resp_link_i_stitch[1][N]    = '0;
        // D$ data resp wh router fed from adapter
        //assign lce_data_resp_link_i_stitch[1][N] ='0;
        assign lce_cmd_link_i_stitch[1][N]     = '0;
        // D$ data cmd wh router fed from adapter
        //assign lce_data_cmd_link_i_stitch[1][N]  = '0;
      end
  end // rof1

for (genvar i = 0; i < 2; i++)
  begin : rof3
    bsg_mesh_router_buffered
     #(.width_p(lce_cce_req_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     req_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
       ,.link_i(lce_req_link_i_stitch[i])
       ,.link_o(lce_req_link_o_stitch[i])
       ,.my_x_i(x_cord_width_p'(2*my_x_i+i))
       ,.my_y_i(my_y_i)
       );
    
    bsg_mesh_router_buffered
     #(.width_p(lce_cce_resp_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     resp_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
       ,.link_i(lce_resp_link_i_stitch[i])
       ,.link_o(lce_resp_link_o_stitch[i])
       ,.my_x_i(x_cord_width_p'(2*my_x_i+i))
       ,.my_y_i(my_y_i)
       );
    
    bsg_mesh_router_buffered
     #(.width_p(cce_lce_cmd_network_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.XY_order_p(0)
       )
     cmd_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
       ,.link_i(lce_cmd_link_i_stitch[i])
       ,.link_o(lce_cmd_link_o_stitch[i])
       ,.my_x_i(x_cord_width_p'(2*my_x_i+i))
       ,.my_y_i(my_y_i)
       );

    bp_me_network_pkt_encode_data_cmd 
     #(.num_lce_p(num_lce_p)
       ,.block_size_in_bits_p(cce_block_width_p)
       ,.lce_assoc_p(lce_assoc_p)
       ,.max_num_flit_p(lce_data_cmd_num_flits_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ) 
     lce_data_cmd_pkt_encode 
      (.payload_i(lce_lce_data_cmd_lo[i])
       ,.packet_o(lce_lce_data_cmd_packet[i])
       );

    bsg_wormhole_router_adapter_in
     #(.max_num_flit_p(lce_data_cmd_num_flits_lp)
       ,.max_payload_width_p(lce_data_cmd_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       )
     data_cmd_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.data_i(lce_lce_data_cmd_packet[i])
       ,.v_i(lce_lce_data_cmd_v_lo[i])
       ,.ready_o(lce_lce_data_cmd_ready_li[i])

       ,.link_o(lce_data_cmd_link_i_stitch[i][N])
       ,.link_i(lce_data_cmd_link_o_stitch[i][N])
       );

    // StrictYX routing, route Y first (allows N/S sending to E/W)
    // LCEs send from N, CCEs (on even numbered routers) send from S.
    bsg_wormhole_router_generalized
     #(.flit_width_p(lce_data_cmd_router_width_lp)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(lce_data_cmd_len_width_lp)
       )
     data_cmd_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.link_i(lce_data_cmd_link_i_stitch[i])
       ,.link_o(lce_data_cmd_link_o_stitch[i])

       ,.my_cord_i({my_y_i, {x_cord_width_p'(2*my_x_i+i)}})
       );

  wire [lce_data_cmd_payload_offset_lp-1:0] lce_data_cmd_nonpayload;
    bsg_wormhole_router_adapter_out
     #(.max_num_flit_p(lce_data_cmd_num_flits_lp)
       ,.max_payload_width_p(lce_data_cmd_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       )
     data_cmd_adapter_out
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
    
       ,.link_i(lce_data_cmd_link_o_stitch[i][P])
       ,.link_o(lce_data_cmd_link_i_stitch[i][P])

       ,.data_o({lce_data_cmd_li[i], lce_data_cmd_nonpayload})
       ,.v_o(lce_data_cmd_v_li[i])
       ,.ready_i(lce_data_cmd_ready_lo[i])
       );

    bp_me_network_pkt_encode_data_resp
     #(.num_cce_p(num_cce_p)
       ,.num_lce_p(num_lce_p)
       ,.paddr_width_p(paddr_width_p)
       ,.block_size_in_bits_p(cce_block_width_p)
       ,.max_num_flit_p(lce_cce_data_resp_num_flits_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       )
     lce_data_resp_pkt_encode
      (.payload_i(lce_data_resp_lo[i])
       ,.packet_o(lce_data_resp_packet[i])
       );

    bsg_wormhole_router_adapter_in 
     #(.max_num_flit_p(lce_cce_data_resp_num_flits_lp)
       ,.max_payload_width_p(lce_cce_data_resp_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       )
     data_resp_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.data_i(lce_data_resp_packet[i])
       ,.v_i(lce_data_resp_v_lo[i])
       ,.ready_o(lce_data_resp_ready_li[i])

       ,.link_o(lce_data_resp_link_i_stitch[i][N])
       ,.link_i(lce_data_resp_link_o_stitch[i][N])
       );

    // StrictYX routing, route Y first (allows N/S sending to E/W)
    bsg_wormhole_router_generalized
     #(.flit_width_p(lce_cce_data_resp_router_width_lp)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(lce_cce_data_resp_len_width_lp)
       )
     data_resp_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.link_i(lce_data_resp_link_i_stitch[i])
       ,.link_o(lce_data_resp_link_o_stitch[i])

       ,.my_cord_i({my_y_i, {x_cord_width_p'(2*my_x_i+i)}})
       );

  end // rof3    
    
bp_me_network_pkt_encode_data_cmd
 #(.num_lce_p(num_lce_p)
   ,.block_size_in_bits_p(cce_block_width_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.max_num_flit_p(lce_data_cmd_num_flits_lp)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   )
 lce_data_cmd_pkt_encode
  (.payload_i(cce_lce_data_cmd_lo)
   ,.packet_o(cce_lce_data_cmd_packet)
   );

bsg_wormhole_router_adapter_in
 #(.max_num_flit_p(lce_data_cmd_num_flits_lp)
   ,.max_payload_width_p(lce_data_cmd_width_lp)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   )
 data_cmd_adapter_in
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.data_i(cce_lce_data_cmd_packet)
   ,.v_i(cce_lce_data_cmd_v_lo)
   ,.ready_o(cce_lce_data_cmd_ready_li)

   ,.link_o(lce_data_cmd_link_i_stitch[0][S])
   ,.link_i(lce_data_cmd_link_o_stitch[0][S])
   );

wire [lce_cce_data_resp_payload_offset_lp-1:0] lce_data_resp_nonpayload;
bsg_wormhole_router_adapter_out
 #(.max_num_flit_p(lce_cce_data_resp_num_flits_lp)
   ,.max_payload_width_p(lce_cce_data_resp_width_lp)
   ,.x_cord_width_p(x_cord_width_p)
   ,.y_cord_width_p(y_cord_width_p)
   )
 data_resp_adapter_out
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.link_i(lce_data_resp_link_o_stitch[0][P])
   ,.link_o(lce_data_resp_link_i_stitch[0][P])

   ,.data_o({lce_data_resp_li, lce_data_resp_nonpayload})
   ,.v_o(lce_data_resp_v_li)
   ,.ready_i(lce_data_resp_ready_lo)
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
bp_cce_mem_cmd_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;
bp_cce_mem_data_cmd_s  mem_data_cmd_lo;
logic                  mem_data_cmd_v_lo, mem_data_cmd_yumi_li;
bp_mem_cce_resp_s      mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;
bp_mem_cce_data_resp_s mem_data_resp_li;
logic                  mem_data_resp_v_li, mem_data_resp_ready_lo;

bp_cce_top
 #(.cfg_p(cfg_p)
   ,.cce_trace_p(cce_trace_p)
   )
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

   ,.lce_data_resp_i(lce_data_resp_li)
   ,.lce_data_resp_v_i(lce_data_resp_v_li)
   ,.lce_data_resp_ready_o(lce_data_resp_ready_lo)

   // From CCE
   ,.lce_cmd_o(lce_cmd_lo)
   ,.lce_cmd_v_o(lce_cmd_v_lo)
   ,.lce_cmd_ready_i(lce_cmd_ready_li)

   ,.lce_data_cmd_o(cce_lce_data_cmd_lo)
   ,.lce_data_cmd_v_o(cce_lce_data_cmd_v_lo)
   ,.lce_data_cmd_ready_i(cce_lce_data_cmd_ready_li)

   // To CCE
   ,.mem_resp_i(mem_resp_li)
   ,.mem_resp_v_i(mem_resp_v_li)
   ,.mem_resp_ready_o(mem_resp_ready_lo)
   ,.mem_data_resp_i(mem_data_resp_li)
   ,.mem_data_resp_v_i(mem_data_resp_v_li)
   ,.mem_data_resp_ready_o(mem_data_resp_ready_lo)

   // From CCE
   ,.mem_cmd_o(mem_cmd_lo)
   ,.mem_cmd_v_o(mem_cmd_v_lo)
   ,.mem_cmd_yumi_i(mem_cmd_yumi_li)
   ,.mem_data_cmd_o(mem_data_cmd_lo)
   ,.mem_data_cmd_v_o(mem_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi_li)

   ,.cce_id_i(proc_cfg_cast_i.cce_id) 
   );


// CCE-MEM IF to Wormhole routed interface

`declare_bsg_ready_and_link_sif_s(noc_width_p, bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s cmd_link_cast_i, cmd_link_cast_o;
bsg_ready_and_link_sif_s resp_link_cast_i, resp_link_cast_o;

assign cmd_link_cast_i  = cmd_link_i;
assign cmd_link_o       = cmd_link_cast_o;

assign resp_link_cast_i = resp_link_i;
assign resp_link_o      = resp_link_cast_o;

logic [noc_cord_width_p-1:0] cmd_dest_cord_lo;
bp_addr_map
 #(.cfg_p(cfg_p))
 cmd_map
  (.paddr_i(mem_cmd_lo.addr)

  ,.clint_cord_i(clint_cord_i)
  ,.dram_cord_i(dram_cord_i)
  ,.openpiton_cord_i(openpiton_cord_i)

  ,.dest_cord_o(cmd_dest_cord_lo)
  );

logic [noc_cord_width_p-1:0] data_cmd_dest_cord_lo;
bp_addr_map
 #(.cfg_p(cfg_p))
 data_cmd_map
  (.paddr_i(mem_data_cmd_lo.addr)
   ,.clint_cord_i(clint_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.openpiton_cord_i(openpiton_cord_i)

   ,.dest_cord_o(data_cmd_dest_cord_lo)
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

   ,.mem_data_cmd_i(mem_data_cmd_lo)
   ,.mem_data_cmd_v_i(mem_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi_li)

   ,.mem_resp_o(mem_resp_li)
   ,.mem_resp_v_o(mem_resp_v_li)
   ,.mem_resp_ready_i(mem_resp_ready_lo)

   ,.mem_data_resp_o(mem_data_resp_li)
   ,.mem_data_resp_v_o(mem_data_resp_v_li)
   ,.mem_data_resp_ready_i(mem_data_resp_ready_lo)

   ,.my_cord_i(my_cord_i)
   ,.mem_cmd_dest_cord_i(cmd_dest_cord_lo)
   ,.mem_data_cmd_dest_cord_i(data_cmd_dest_cord_lo)

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

   ,.mem_data_cmd_o()
   ,.mem_data_cmd_v_o()
   ,.mem_data_cmd_yumi_i('0)

   ,.mem_resp_i('0)
   ,.mem_resp_v_i('0)
   ,.mem_resp_ready_o()

   ,.mem_data_resp_i('0)
   ,.mem_data_resp_v_i('0)
   ,.mem_data_resp_ready_o()

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


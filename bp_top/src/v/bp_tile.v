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
   `declare_bp_lce_cce_if_widths
     (num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)

   , localparam dirs_lp = 5 // S (Mem side) EW (LCE sides), P (Proc side)

   // Used to enable trace replay outputs for testbench
   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0

   , parameter x_cord_width_p = `BSG_SAFE_CLOG2(num_lce_p)
   , parameter y_cord_width_p = 1

   , localparam lce_cce_req_network_width_lp = coh_noc_width_p
   , localparam lce_cce_resp_network_width_lp = coh_noc_width_p
   , localparam cce_lce_cmd_network_width_lp = coh_noc_width_p

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
   , input [E:W][2+cce_lce_cmd_network_width_lp-1:0]       lce_cmd_link_i

   // Router - Outputs
   // Connected on east and west
   , output [E:W][2+lce_cce_req_network_width_lp-1:0]      lce_req_link_o
   , output [E:W][2+lce_cce_resp_network_width_lp-1:0]     lce_resp_link_o
   , output [E:W][2+cce_lce_cmd_network_width_lp-1:0]      lce_cmd_link_o

   // Memory side connection
   , input [noc_cord_width_p-1:0]                             my_cord_i
   , input [noc_cord_width_p-1:0]                             dram_cord_i
   , input [noc_cord_width_p-1:0]                             clint_cord_i

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
bp_lce_cmd_s           [1:0] lce_cmd_li;
logic                  [1:0] lce_cmd_v_li, lce_cmd_ready_lo;
bp_lce_cmd_s           [1:0] lce_cmd_lo;
logic                  [1:0] lce_cmd_v_lo, lce_cmd_ready_li;

// CCE connections
bp_lce_cce_req_s             lce_req_li;
logic                        lce_req_v_li, lce_req_ready_lo;
bp_lce_cce_resp_s            lce_resp_li;
logic                        lce_resp_v_li, lce_resp_ready_lo;
bp_lce_cmd_s                 cce_lce_cmd_lo;
logic                        cce_lce_cmd_v_lo, cce_lce_cmd_ready_li;

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
`declare_bsg_ready_and_link_sif_s(lce_cce_req_network_width_lp, bp_lce_req_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(lce_cce_resp_network_width_lp, bp_lce_resp_ready_and_link_sif_s);
`declare_bsg_ready_and_link_sif_s(cce_lce_cmd_network_width_lp, bp_lce_cmd_ready_and_link_sif_s);

// Intermediate 'stitch' connections between the routers
bp_lce_req_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_req_link_i_stitch, lce_req_link_o_stitch;
bp_lce_resp_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_resp_link_i_stitch, lce_resp_link_o_stitch;
bp_lce_cmd_ready_and_link_sif_s [1:0][dirs_lp-1:0] lce_cmd_link_i_stitch, lce_cmd_link_o_stitch;

for (genvar i = 0; i < dirs_lp; i++)
  begin : rof1
    if (i == E) // Transfer side
      begin : fi1_E
        assign lce_req_link_i_stitch[1][E]  = lce_req_link_i[E];
        assign lce_resp_link_i_stitch[1][E] = lce_resp_link_i[E];
        assign lce_cmd_link_i_stitch[1][E]  = lce_cmd_link_i[E];

        assign lce_req_link_i_stitch[0][E]  = lce_req_link_o_stitch[1][W];
        assign lce_resp_link_i_stitch[0][E] = lce_resp_link_o_stitch[1][W];
        assign lce_cmd_link_i_stitch[0][E]  = lce_cmd_link_o_stitch[1][W];

        assign lce_req_link_o[W]  = lce_req_link_o_stitch[0][W];
        assign lce_resp_link_o[W] = lce_resp_link_o_stitch[0][W];
        assign lce_cmd_link_o[W]  = lce_cmd_link_o_stitch[0][W];
      end
    else if (i == W) // Transfer side
      begin : fi1_W
        assign lce_req_link_i_stitch[0][W]  = lce_req_link_i[W];
        assign lce_resp_link_i_stitch[0][W] = lce_resp_link_i[W];
        assign lce_cmd_link_i_stitch[0][W]  = lce_cmd_link_i[W];

        assign lce_req_link_i_stitch[1][W]  = lce_req_link_o_stitch[0][E];
        assign lce_resp_link_i_stitch[1][W] = lce_resp_link_o_stitch[0][E];
        assign lce_cmd_link_i_stitch[1][W]  = lce_cmd_link_o_stitch[0][E];

        assign lce_req_link_o[E]  = lce_req_link_o_stitch[1][E];
        assign lce_resp_link_o[E] = lce_resp_link_o_stitch[1][E];
        assign lce_cmd_link_o[E]  = lce_cmd_link_o_stitch[1][E];
      end
    else if (i == P) // Destination side
      begin : fi1_P
        // To I$
        // From I$
        // CCE doesn't connect on P at x=1 (D$) location, stub the input links
        assign lce_req_link_i_stitch[1][P] = '0;
        assign lce_resp_link_i_stitch[1][P] = '0;

        // To D$

        // From I$
      end
    else if (i == S) // LCE source side
      begin : fi1_S
        assign lce_req_link_i_stitch[0][S] = '0;
        assign lce_resp_link_i_stitch[0][S] = '0;

        // CCE is attached at x=0 only
        assign lce_req_link_i_stitch[1][S] = '0;
        assign lce_resp_link_i_stitch[1][S] = '0;
        assign lce_cmd_link_i_stitch[1][S] = '0;
      end
    else
      begin : fi_N
      end
  end // rof1

`declare_bsg_wormhole_router_packet_s(x_cord_width_p+y_cord_width_p, coh_noc_len_width_p, lce_cce_req_width_lp, lce_req_packet_s);
`declare_bsg_wormhole_router_packet_s(x_cord_width_p+y_cord_width_p, coh_noc_len_width_p, lce_cce_resp_width_lp, lce_resp_packet_s);
`declare_bsg_wormhole_router_packet_s(x_cord_width_p+y_cord_width_p, coh_noc_len_width_p, lce_cmd_width_lp, lce_cmd_packet_s);

localparam lce_req_num_flits_lp  = `BSG_CDIV($bits(lce_req_packet_s), coh_noc_width_p);
localparam lce_resp_num_flits_lp = `BSG_CDIV($bits(lce_resp_packet_s), coh_noc_width_p);
localparam lce_cmd_num_flits_lp  = `BSG_CDIV($bits(lce_cmd_packet_s), coh_noc_width_p);

for (genvar i = 0; i < 2; i++)
  begin : rof3
    wire [coh_noc_len_width_p-1:0] lce_req_len_lo    = lce_req_num_flits_lp-1;
    wire [x_cord_width_p-1:0] lce_req_dst_x_cord_lo  = lce_req_lo[i].dst_id << 1;
    wire [y_cord_width_p-1:0] lce_req_dst_y_cord_lo  = '0;

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p(lce_cce_req_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(x_cord_width_p+y_cord_width_p)
       ,.link_width_p(coh_noc_width_p)
       )
     req_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i({lce_req_lo[i], lce_req_len_lo, lce_req_dst_y_cord_lo, lce_req_dst_x_cord_lo})
       ,.v_i(lce_req_v_lo[i])
       ,.ready_o(lce_req_ready_li[i])

       ,.link_i(lce_req_link_o_stitch[i][N])
       ,.link_o(lce_req_link_i_stitch[i][N])
       );

    bsg_wormhole_router_generalized
     #(.flit_width_p(coh_noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(coh_noc_len_width_p)
       )
     req_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.link_i(lce_req_link_i_stitch[i])
       ,.link_o(lce_req_link_o_stitch[i])

       ,.my_cord_i({my_y_i, {x_cord_width_p'(2*my_x_i+i)}})
       );

    wire [coh_noc_len_width_p-1:0] lce_cmd_len_lo = lce_cmd_num_flits_lp - 1;
    wire [x_cord_width_p-1:0] lce_cmd_dst_x_cord_lo  = lce_cmd_lo[i].dst_id;
    wire [y_cord_width_p-1:0] lce_cmd_dst_y_cord_lo  = '0;

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p(lce_cmd_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(x_cord_width_p+y_cord_width_p)
       ,.link_width_p(coh_noc_width_p)
       )
     cmd_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.packet_i({lce_cmd_lo[i], lce_cmd_len_lo, lce_cmd_dst_y_cord_lo, lce_cmd_dst_x_cord_lo})
       ,.v_i(lce_cmd_v_lo[i])
       ,.ready_o(lce_cmd_ready_li[i])

       ,.link_i(lce_cmd_link_o_stitch[i][N])
       ,.link_o(lce_cmd_link_i_stitch[i][N])
       );
    
    bsg_wormhole_router_generalized
     #(.flit_width_p(coh_noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(coh_noc_len_width_p)
       )
     cmd_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
       
       ,.link_i(lce_cmd_link_i_stitch[i])
       ,.link_o(lce_cmd_link_o_stitch[i])

       ,.my_cord_i({my_y_i, {x_cord_width_p'(2*my_x_i+i)}})
       );

    localparam lce_cmd_payload_offset_lp = (x_cord_width_p+y_cord_width_p+coh_noc_len_width_p);
    wire [lce_cmd_payload_offset_lp-1:0] lce_cmd_nonpayload;
    bsg_wormhole_router_adapter_out
     #(.max_payload_width_p(lce_cmd_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(x_cord_width_p+y_cord_width_p)
       ,.link_width_p(coh_noc_width_p)
       )
     cmd_adapter_out
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.link_i(lce_cmd_link_o_stitch[i][P])
       ,.link_o(lce_cmd_link_i_stitch[i][P])

       ,.packet_o({lce_cmd_li[i], lce_cmd_nonpayload})
       ,.v_o(lce_cmd_v_li[i])
       ,.ready_i(lce_cmd_ready_lo[i])
       );
    
    wire [coh_noc_len_width_p-1:0] lce_resp_len_lo = lce_resp_num_flits_lp - 1;
    wire [x_cord_width_p-1:0] lce_resp_dst_x_cord_lo  = lce_resp_lo[i].dst_id << 1;
    wire [y_cord_width_p-1:0] lce_resp_dst_y_cord_lo  = '0;

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p(lce_cce_resp_width_lp)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(x_cord_width_p+y_cord_width_p)
       ,.link_width_p(coh_noc_width_p)
       )
     resp_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i({lce_resp_lo[i], lce_resp_len_lo, lce_resp_dst_y_cord_lo, lce_resp_dst_x_cord_lo})
       ,.v_i(lce_resp_v_lo[i])
       ,.ready_o(lce_resp_ready_li[i])

       ,.link_i(lce_resp_link_o_stitch[i][N])
       ,.link_o(lce_resp_link_i_stitch[i][N])
       );

    bsg_wormhole_router_generalized
     #(.flit_width_p(coh_noc_width_p)
       ,.dims_p(dims_lp)
       ,.cord_markers_pos_p(cord_markers_pos_lp)
       ,.routing_matrix_p(StrictYX)
       ,.reverse_order_p(1)
       ,.len_width_p(coh_noc_len_width_p)
       )
     resp_router
      (.clk_i(clk_i)
       ,.reset_i(reset_r)
       
       ,.link_i(lce_resp_link_i_stitch[i])
       ,.link_o(lce_resp_link_o_stitch[i])
       
       ,.my_cord_i({my_y_i, {x_cord_width_p'(2*my_x_i+i)}})
       );
  end // rof3
    
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
bp_cce_mem_cmd_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_yumi_li;
bp_mem_cce_resp_s      mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;

localparam lce_cce_req_payload_offset_lp = (x_cord_width_p+y_cord_width_p+coh_noc_len_width_p);
wire [lce_cce_req_payload_offset_lp-1:0] lce_cce_req_nonpayload;
bsg_wormhole_router_adapter_out
 #(.max_payload_width_p(lce_cce_req_width_lp)
   ,.len_width_p(coh_noc_len_width_p)
   ,.cord_width_p(x_cord_width_p+y_cord_width_p)
   ,.link_width_p(coh_noc_width_p)
   )
 req_adapter_out
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.link_i(lce_req_link_o_stitch[0][P])
   ,.link_o(lce_req_link_i_stitch[0][P])

   ,.packet_o({lce_req_li, lce_cce_req_nonpayload})
   ,.v_o(lce_req_v_li)
   ,.ready_i(lce_req_ready_lo)
   );


wire [coh_noc_len_width_p-1:0] cce_lce_cmd_len_lo = lce_cmd_num_flits_lp - 1;
wire [x_cord_width_p-1:0] cce_lce_cmd_dst_x_cord_lo  = cce_lce_cmd_lo.dst_id;
wire [y_cord_width_p-1:0] cce_lce_cmd_dst_y_cord_lo  = '0;

bsg_wormhole_router_adapter_in
 #(.max_payload_width_p(lce_cmd_width_lp)
   ,.len_width_p(coh_noc_len_width_p)
   ,.cord_width_p(x_cord_width_p+y_cord_width_p)
   ,.link_width_p(coh_noc_width_p)
   )
 cmd_adapter_in
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.packet_i({cce_lce_cmd_lo, cce_lce_cmd_len_lo, cce_lce_cmd_dst_y_cord_lo, cce_lce_cmd_dst_x_cord_lo})
   ,.v_i(cce_lce_cmd_v_lo)
   ,.ready_o(cce_lce_cmd_ready_li)

   ,.link_i(lce_cmd_link_o_stitch[0][S])
   ,.link_o(lce_cmd_link_i_stitch[0][S])
   );

localparam lce_cce_resp_payload_offset_lp = (x_cord_width_p+y_cord_width_p+coh_noc_len_width_p);
wire [lce_cce_resp_payload_offset_lp-1:0] lce_cce_resp_nonpayload;
bsg_wormhole_router_adapter_out
 #(.max_payload_width_p(lce_cce_resp_width_lp)
   ,.len_width_p(coh_noc_len_width_p)
   ,.cord_width_p(x_cord_width_p+y_cord_width_p)
   ,.link_width_p(coh_noc_width_p)
   )
 resp_adapter_out
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.link_i(lce_resp_link_o_stitch[0][P])
   ,.link_o(lce_resp_link_i_stitch[0][P])

   ,.packet_o({lce_resp_li, lce_cce_resp_nonpayload})
   ,.v_o(lce_resp_v_li)
   ,.ready_i(lce_resp_ready_lo)
   );

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


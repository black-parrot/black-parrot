/**
 *
 * bp_tile.v
 *
 */

module bp_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   // Memory side connection
   , input [io_noc_did_width_p-1:0]                           my_did_i
   , input [io_noc_did_width_p-1:0]                           host_did_i
   , input [coh_noc_cord_width_p-1:0]                         my_cord_i

   // Connected to other tiles on east and west
   , input [coh_noc_ral_link_width_lp-1:0]                    lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_resp_link_o

   , output [mem_noc_ral_link_width_lp-1:0]                   mem_cmd_link_o
   , input [mem_noc_ral_link_width_lp-1:0]                    mem_resp_link_i
   );

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

// Cast the routing links
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

bp_coh_ready_and_link_s lce_req_link_cast_i, lce_req_link_cast_o;
bp_coh_ready_and_link_s lce_resp_link_cast_i, lce_resp_link_cast_o;
bp_coh_ready_and_link_s lce_cmd_link_cast_i, lce_cmd_link_cast_o;

assign lce_req_link_cast_i  = lce_req_link_i;
assign lce_cmd_link_cast_i  = lce_cmd_link_i;
assign lce_resp_link_cast_i = lce_resp_link_i;

assign lce_req_link_o  = lce_req_link_cast_o;
assign lce_cmd_link_o  = lce_cmd_link_cast_o;
assign lce_resp_link_o = lce_resp_link_cast_o;

logic timer_irq_li, software_irq_li, external_irq_li;

// Proc-side connections network connections
bp_lce_cce_req_s  [1:0] lce_req_lo;
logic             [1:0] lce_req_v_lo, lce_req_ready_li;
bp_lce_cce_resp_s [1:0] lce_resp_lo;
logic             [1:0] lce_resp_v_lo, lce_resp_ready_li;
bp_lce_cmd_s      [1:0] lce_cmd_li;
logic             [1:0] lce_cmd_v_li, lce_cmd_yumi_lo;
bp_lce_cmd_s      [1:0] lce_cmd_lo;
logic             [1:0] lce_cmd_v_lo, lce_cmd_ready_li;

// CCE connections
bp_lce_cce_req_s  cce_lce_req_li;
logic             cce_lce_req_v_li, cce_lce_req_yumi_lo;
bp_lce_cmd_s      cce_lce_cmd_lo;
logic             cce_lce_cmd_v_lo, cce_lce_cmd_ready_li;
bp_lce_cce_resp_s cce_lce_resp_li;
logic             cce_lce_resp_v_li, cce_lce_resp_yumi_lo;

// Mem connections
bp_cce_mem_msg_s       cce_mem_cmd_lo;
logic                  cce_mem_cmd_v_lo, cce_mem_cmd_ready_li;
bp_cce_mem_msg_s       cce_mem_resp_li;
logic                  cce_mem_resp_v_li, cce_mem_resp_yumi_lo;

bp_cce_mem_msg_s       cache_mem_cmd_li;
logic                  cache_mem_cmd_v_li, cache_mem_cmd_ready_lo;
bp_cce_mem_msg_s       cache_mem_resp_lo;
logic                  cache_mem_resp_v_lo, cache_mem_resp_yumi_li;

bp_cce_mem_msg_s       cfg_mem_cmd_li;
logic                  cfg_mem_cmd_v_li, cfg_mem_cmd_ready_lo;
bp_cce_mem_msg_s       cfg_mem_resp_lo;
logic                  cfg_mem_resp_v_lo, cfg_mem_resp_yumi_li;

bp_cce_mem_msg_s       clint_mem_cmd_li;
logic                  clint_mem_cmd_v_li, clint_mem_cmd_ready_lo;
bp_cce_mem_msg_s       clint_mem_resp_lo;
logic                  clint_mem_resp_v_lo, clint_mem_resp_yumi_li;

logic reset_r;
always_ff @(posedge clk_i)
  reset_r <= reset_i;

bp_cfg_bus_s cfg_bus_lo;
logic [dword_width_p-1:0] cfg_irf_data_li;
logic [vaddr_width_p-1:0] cfg_npc_data_li;
logic [dword_width_p-1:0] cfg_csr_data_li;
logic [1:0]               cfg_priv_data_li;
logic [cce_instr_width_p-1:0] cfg_cce_ucode_data_li;
bp_cfg
 #(.bp_params_p(bp_params_p))
 cfg
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.mem_cmd_i(cfg_mem_cmd_li)
   ,.mem_cmd_v_i(cfg_mem_cmd_v_li)
   ,.mem_cmd_ready_o(cfg_mem_cmd_ready_lo)

   ,.mem_resp_o(cfg_mem_resp_lo)
   ,.mem_resp_v_o(cfg_mem_resp_v_lo)
   ,.mem_resp_yumi_i(cfg_mem_resp_yumi_li)

   ,.cfg_bus_o(cfg_bus_lo)
   ,.did_i(my_did_i)
   ,.host_did_i(host_did_i)
   ,.cord_i(my_cord_i)
   ,.irf_data_i(cfg_irf_data_li)
   ,.npc_data_i(cfg_npc_data_li)
   ,.csr_data_i(cfg_csr_data_li)
   ,.priv_data_i(cfg_priv_data_li)
   ,.cce_ucode_data_i(cfg_cce_ucode_data_li)
   );

bp_clint_slice
 #(.bp_params_p(bp_params_p))
 clint
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.mem_cmd_i(clint_mem_cmd_li)
   ,.mem_cmd_v_i(clint_mem_cmd_v_li)
   ,.mem_cmd_ready_o(clint_mem_cmd_ready_lo)

   ,.mem_resp_o(clint_mem_resp_lo)
   ,.mem_resp_v_o(clint_mem_resp_v_lo)
   ,.mem_resp_yumi_i(clint_mem_resp_yumi_li)

   ,.timer_irq_o(timer_irq_li)
   ,.software_irq_o(software_irq_li)
   ,.external_irq_o(external_irq_li)
   );

// Module instantiations
bp_core
 #(.bp_params_p(bp_params_p))
 core
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.cfg_bus_i(cfg_bus_lo)
   ,.cfg_irf_data_o(cfg_irf_data_li)
   ,.cfg_npc_data_o(cfg_npc_data_li)
   ,.cfg_csr_data_o(cfg_csr_data_li)
   ,.cfg_priv_data_o(cfg_priv_data_li)

   ,.lce_req_o(lce_req_lo)
   ,.lce_req_v_o(lce_req_v_lo)
   ,.lce_req_ready_i(lce_req_ready_li)

   ,.lce_cmd_i(lce_cmd_li)
   ,.lce_cmd_v_i(lce_cmd_v_li)
   ,.lce_cmd_yumi_o(lce_cmd_yumi_lo)

   ,.lce_cmd_o(lce_cmd_lo)
   ,.lce_cmd_v_o(lce_cmd_v_lo)
   ,.lce_cmd_ready_i(lce_cmd_ready_li)

   ,.lce_resp_o(lce_resp_lo)
   ,.lce_resp_v_o(lce_resp_v_lo)
   ,.lce_resp_ready_i(lce_resp_ready_li)

   ,.timer_irq_i(timer_irq_li)
   ,.software_irq_i(software_irq_li)
   ,.external_irq_i(external_irq_li)
   );

bp_cce_wrapper
 #(.bp_params_p(bp_params_p))
 cce
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.cfg_bus_i(cfg_bus_lo)
   ,.cfg_cce_ucode_data_o(cfg_cce_ucode_data_li)

   ,.lce_req_i(cce_lce_req_li)
   ,.lce_req_v_i(cce_lce_req_v_li)
   ,.lce_req_yumi_o(cce_lce_req_yumi_lo)

   ,.lce_cmd_o(cce_lce_cmd_lo)
   ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
   ,.lce_cmd_ready_i(cce_lce_cmd_ready_li)

   ,.lce_resp_i(cce_lce_resp_li)
   ,.lce_resp_v_i(cce_lce_resp_v_li)
   ,.lce_resp_yumi_o(cce_lce_resp_yumi_lo)

   ,.mem_cmd_o(cce_mem_cmd_lo)
   ,.mem_cmd_v_o(cce_mem_cmd_v_lo)
   ,.mem_cmd_ready_i(cce_mem_cmd_ready_li)

   ,.mem_resp_i(cce_mem_resp_li)
   ,.mem_resp_v_i(cce_mem_resp_v_li)
   ,.mem_resp_yumi_o(cce_mem_resp_yumi_lo)
   );

`declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp, lce_req_packet_s);
`declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cmd_width_lp, lce_cmd_packet_s);
`declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_resp_width_lp, lce_resp_packet_s);

lce_req_packet_s [1:0]  lce_req_packet_lo;
lce_cmd_packet_s [1:0]  lce_cmd_packet_lo, lce_cmd_packet_li;
lce_resp_packet_s [1:0] lce_resp_packet_lo;

bp_coh_ready_and_link_s [1:0] lce_req_link_li, lce_req_link_lo;
bp_coh_ready_and_link_s [1:0] lce_cmd_link_li, lce_cmd_link_lo;
bp_coh_ready_and_link_s [1:0] lce_resp_link_li, lce_resp_link_lo;

bp_coh_ready_and_link_s cce_lce_req_link_li, cce_lce_req_link_lo;
bp_coh_ready_and_link_s cce_lce_cmd_link_li, cce_lce_cmd_link_lo;
bp_coh_ready_and_link_s cce_lce_resp_link_li, cce_lce_resp_link_lo;

for (genvar i = 0; i < 2; i++)
  begin : lce
    bp_me_wormhole_packet_encode_lce_req
     #(.bp_params_p(bp_params_p))
     req_encode
      (.payload_i(lce_req_lo[i])
       ,.packet_o(lce_req_packet_lo[i])
       );

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p($bits(lce_req_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       )
     lce_req_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i(lce_req_packet_lo[i])
       ,.v_i(lce_req_v_lo[i])
       ,.ready_o(lce_req_ready_li[i])

       ,.link_i(lce_req_link_li[i])
       ,.link_o(lce_req_link_lo[i])
       );

    bp_me_wormhole_packet_encode_lce_cmd
     #(.bp_params_p(bp_params_p))
     cmd_encode
      (.payload_i(lce_cmd_lo[i])
       ,.packet_o(lce_cmd_packet_lo[i])
       );

    bsg_wormhole_router_adapter
     #(.max_payload_width_p($bits(lce_cmd_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       )
     cmd_adapter
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i(lce_cmd_packet_lo[i])
       ,.v_i(lce_cmd_v_lo[i])
       ,.ready_o(lce_cmd_ready_li[i])

       ,.link_i(lce_cmd_link_li[i])
       ,.link_o(lce_cmd_link_lo[i])

       ,.packet_o(lce_cmd_packet_li[i])
       ,.v_o(lce_cmd_v_li[i])
       ,.yumi_i(lce_cmd_yumi_lo[i])
       );
    assign lce_cmd_li[i] = lce_cmd_packet_li[i].payload;

    bp_me_wormhole_packet_encode_lce_resp
     #(.bp_params_p(bp_params_p))
     resp_encode
      (.payload_i(lce_resp_lo[i])
       ,.packet_o(lce_resp_packet_lo[i])
       );

    bsg_wormhole_router_adapter_in
     #(.max_payload_width_p($bits(lce_resp_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       )
     lce_resp_adapter_in
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.packet_i(lce_resp_packet_lo[i])
       ,.v_i(lce_resp_v_lo[i])
       ,.ready_o(lce_resp_ready_li[i])

       ,.link_i(lce_resp_link_li[i])
       ,.link_o(lce_resp_link_lo[i])
       );
  end

  lce_req_packet_s cce_lce_req_packet_li;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p($bits(lce_req_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cce_req_adapter_out
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_i(lce_req_link_i)
    ,.link_o(cce_lce_req_link_lo)

    ,.packet_o(cce_lce_req_packet_li)
    ,.v_o(cce_lce_req_v_li)
    ,.yumi_i(cce_lce_req_yumi_lo)
    );
  assign cce_lce_req_li = cce_lce_req_packet_li.payload;

  lce_cmd_packet_s cce_lce_cmd_packet_lo;
  bp_me_wormhole_packet_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cmd_encode
    (.payload_i(cce_lce_cmd_lo)
     ,.packet_o(cce_lce_cmd_packet_lo)
     );

  bsg_wormhole_router_adapter_in
   #(.max_payload_width_p($bits(lce_cmd_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cmd_adapter_in
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.packet_i(cce_lce_cmd_packet_lo)
     ,.v_i(cce_lce_cmd_v_lo)
     ,.ready_o(cce_lce_cmd_ready_li)

     ,.link_i(cce_lce_cmd_link_li)
     ,.link_o(cce_lce_cmd_link_lo)
     );

  lce_resp_packet_s cce_lce_resp_packet_li;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p($bits(lce_resp_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cce_resp_adapter_out
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_i(lce_resp_link_i)
    ,.link_o(cce_lce_resp_link_lo)

    ,.packet_o(cce_lce_resp_packet_li)
    ,.v_o(cce_lce_resp_v_li)
    ,.yumi_i(cce_lce_resp_yumi_lo)
    );
  assign cce_lce_resp_li = cce_lce_resp_packet_li.payload;

  bp_coh_ready_and_link_s req_concentrated_link_li, req_concentrated_link_lo;
  bp_coh_ready_and_link_s cmd_concentrated_link_li, cmd_concentrated_link_lo;
  bp_coh_ready_and_link_s resp_concentrated_link_li, resp_concentrated_link_lo;

  assign req_concentrated_link_li = lce_req_link_cast_i;
  assign lce_req_link_cast_o = '{data          : req_concentrated_link_lo.data
                                 ,v            : req_concentrated_link_lo.v
                                 ,ready_and_rev: cce_lce_req_link_lo.ready_and_rev
                                 };
  bsg_wormhole_concentrator_in
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     )
   req_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i(lce_req_link_lo)
     ,.links_o(lce_req_link_li)

     ,.concentrated_link_i(req_concentrated_link_li)
     ,.concentrated_link_o(req_concentrated_link_lo)
     );

  assign cmd_concentrated_link_li = lce_cmd_link_cast_i;
  assign lce_cmd_link_cast_o = cmd_concentrated_link_lo;
  bsg_wormhole_concentrator
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(3)
     ,.cord_width_p(coh_noc_cord_width_p)
     )
   cmd_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i({cce_lce_cmd_link_lo, lce_cmd_link_lo})
     ,.links_o({cce_lce_cmd_link_li, lce_cmd_link_li})

     ,.concentrated_link_i(cmd_concentrated_link_li)
     ,.concentrated_link_o(cmd_concentrated_link_lo)
     );

  assign resp_concentrated_link_li = lce_resp_link_cast_i;
  assign lce_resp_link_cast_o = '{data          : resp_concentrated_link_lo.data
                                  ,v            : resp_concentrated_link_lo.v
                                  ,ready_and_rev: cce_lce_resp_link_lo.ready_and_rev
                                  };
  bsg_wormhole_concentrator_in
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     )
   resp_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i(lce_resp_link_lo)
     ,.links_o(lce_resp_link_li)

     ,.concentrated_link_i(resp_concentrated_link_li)
     ,.concentrated_link_o(resp_concentrated_link_lo)
     );

  /* TODO: Extract local memory map to module */
  wire local_cmd_li    = (cce_mem_cmd_lo.header.addr < 32'h8000_0000);
  wire [3:0] device_li =  cce_mem_cmd_lo.header.addr[20+:4];

  assign cce_mem_cmd_ready_li = cache_mem_cmd_ready_lo & cfg_mem_cmd_ready_lo & clint_mem_cmd_ready_lo;

  assign cfg_mem_cmd_li       = cce_mem_cmd_lo;
  assign cfg_mem_cmd_v_li     = cce_mem_cmd_v_lo &  local_cmd_li & (device_li == cfg_dev_gp);

  assign clint_mem_cmd_li     = cce_mem_cmd_lo;
  assign clint_mem_cmd_v_li   = cce_mem_cmd_v_lo &  local_cmd_li & (device_li == clint_dev_gp);

  assign cache_mem_cmd_li      = cce_mem_cmd_lo;
  assign cache_mem_cmd_v_li    = cce_mem_cmd_v_lo & ~cfg_mem_cmd_v_li & ~clint_mem_cmd_v_li;

  bsg_arb_fixed
   #(.inputs_p(3)
     ,.lo_to_hi_p(1)
     )
   resp_arb
    (.ready_i(cce_mem_resp_yumi_lo)
     ,.reqs_i({clint_mem_resp_v_lo, cfg_mem_resp_v_lo, cache_mem_resp_v_lo})
     ,.grants_o({clint_mem_resp_yumi_li, cfg_mem_resp_yumi_li, cache_mem_resp_yumi_li})
     );
  assign cce_mem_resp_v_li = cache_mem_resp_v_lo | cfg_mem_resp_v_lo | clint_mem_resp_v_lo;
  assign cce_mem_resp_li = cache_mem_resp_v_lo
                           ? cache_mem_resp_lo
                           : cfg_mem_resp_v_lo
                             ? cfg_mem_resp_lo
                               : clint_mem_resp_lo;

  bp_cce_mem_msg_s dma_mem_cmd_lo;
  logic dma_mem_cmd_v_lo, dma_mem_cmd_ready_li;
  bp_cce_mem_msg_s dma_mem_resp_li;
  logic dma_mem_resp_v_li, dma_mem_resp_ready_lo, dma_mem_resp_yumi_lo;
  if (l2_en_p)
    begin : l2s
      bp_me_cache_slice
       #(.bp_params_p(bp_params_p))
       l2s
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.mem_cmd_i(cache_mem_cmd_li)
         ,.mem_cmd_v_i(cache_mem_cmd_v_li)
         ,.mem_cmd_ready_o(cache_mem_cmd_ready_lo)

         ,.mem_resp_o(cache_mem_resp_lo)
         ,.mem_resp_v_o(cache_mem_resp_v_lo)
         ,.mem_resp_yumi_i(cache_mem_resp_yumi_li)

         ,.mem_cmd_o(dma_mem_cmd_lo)
         ,.mem_cmd_v_o(dma_mem_cmd_v_lo)
         ,.mem_cmd_yumi_i(dma_mem_cmd_ready_li & dma_mem_cmd_v_lo)

         ,.mem_resp_i(dma_mem_resp_li)
         ,.mem_resp_v_i(dma_mem_resp_v_li)
         ,.mem_resp_ready_o(dma_mem_resp_ready_lo)
         );
         assign dma_mem_resp_yumi_lo = dma_mem_resp_ready_lo & dma_mem_resp_v_li;
    end
  else
    begin : no_l2s
      assign dma_mem_cmd_lo = cache_mem_cmd_li;
      assign dma_mem_cmd_v_lo = cache_mem_cmd_v_li;
      assign cache_mem_cmd_ready_lo = dma_mem_cmd_ready_li;

      assign cache_mem_resp_lo = dma_mem_resp_li;
      assign cache_mem_resp_v_lo = dma_mem_resp_v_li;
      assign dma_mem_resp_yumi_lo = cache_mem_resp_yumi_li;
    end

  localparam dram_y_cord_lp = ic_y_dim_p + cc_y_dim_p + mc_y_dim_p;
  wire [mem_noc_cord_width_p-1:0] dst_cord_li = dram_y_cord_lp;
  bp_me_cce_to_mem_link_master
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     )
   dma_link
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.mem_cmd_i(dma_mem_cmd_lo)
     ,.mem_cmd_v_i(dma_mem_cmd_v_lo)
     ,.mem_cmd_ready_o(dma_mem_cmd_ready_li)

     ,.mem_resp_o(dma_mem_resp_li)
     ,.mem_resp_v_o(dma_mem_resp_v_li)
     ,.mem_resp_yumi_i(dma_mem_resp_yumi_lo)

     ,.my_cord_i(my_cord_i[coh_noc_x_cord_width_p+:mem_noc_y_cord_width_p])
     // TODO: CID == noc cord right now (1 DMC per column)
     ,.my_cid_i(my_cord_i[0+:mem_noc_cid_width_p]-sac_x_dim_p[0+:mem_noc_cid_width_p])
     ,.dst_cord_i(dst_cord_li)
     ,.dst_cid_i('0)

     ,.cmd_link_o(mem_cmd_link_o)
     ,.resp_link_i(mem_resp_link_i)
     );

endmodule


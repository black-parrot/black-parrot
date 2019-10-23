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
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

    , localparam cfg_bus_width_lp        = `bp_cfg_bus_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)
   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

    , output [cfg_bus_width_lp-1:0]                          cfg_bus_o

   // Memory side connection
   , input [mem_noc_cord_width_p-1:0]                         my_cord_i
   , input [mem_noc_cord_width_p-1:0]                         dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                         clint_cord_i
   , input [mem_noc_cord_width_p-1:0]                         host_cord_i

   // Connected to other tiles on east and west
   , input [coh_noc_ral_link_width_lp-1:0]                    lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_resp_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                    mem_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                   mem_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                    mem_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                   mem_resp_link_o

   // Interrupts
   , input                                                    timer_irq_i
   , input                                                    software_irq_i
   , input                                                    external_irq_i
   );

`declare_bp_cfg_bus_s(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

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
bp_lce_cce_req_s  cce_lce_req_li;
logic             cce_lce_req_v_li, cce_lce_req_ready_lo;
bp_lce_cmd_s      cce_lce_cmd_lo;
logic             cce_lce_cmd_v_lo, cce_lce_cmd_ready_li;
bp_lce_cce_resp_s cce_lce_resp_li;
logic             cce_lce_resp_v_li, cce_lce_resp_ready_lo;

// Mem connections
bp_cce_mem_msg_s       cce_mem_cmd_lo;
logic                  cce_mem_cmd_v_lo, cce_mem_cmd_ready_li;
bp_cce_mem_msg_s       cce_mem_resp_lo;
logic                  cce_mem_resp_v_lo, cce_mem_resp_ready_li;
bp_cce_mem_msg_s       cce_mem_resp_li;
logic                  cce_mem_resp_v_li, cce_mem_resp_ready_lo;
bp_cce_mem_msg_s       cce_mem_cmd_li;
logic                  cce_mem_cmd_v_li, cce_mem_cmd_ready_lo;

bp_cce_mem_msg_s       cfg_mem_cmd_li;
logic                  cfg_mem_cmd_v_li, cfg_mem_cmd_yumi_lo;
bp_cce_mem_msg_s       cfg_mem_resp_lo;
logic                  cfg_mem_resp_v_lo, cfg_mem_resp_ready_li;

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
   ,.reset_i(reset_i)

   ,.mem_cmd_i(cfg_mem_cmd_li)
   ,.mem_cmd_v_i(cfg_mem_cmd_v_li)
   ,.mem_cmd_yumi_o(cfg_mem_cmd_yumi_lo)

   ,.mem_resp_o(cfg_mem_resp_lo)
   ,.mem_resp_v_o(cfg_mem_resp_v_lo)
   ,.mem_resp_ready_i(cfg_mem_resp_ready_li)

   ,.cfg_bus_o(cfg_bus_lo)
   ,.irf_data_i(cfg_irf_data_li)
   ,.npc_data_i(cfg_npc_data_li)
   ,.csr_data_i(cfg_csr_data_li)
   ,.priv_data_i(cfg_priv_data_li)
   ,.cce_ucode_data_i(cfg_cce_ucode_data_li)
   );
// TODO: Find more elegant way to do this
assign cfg_bus_o = cfg_bus_lo;

// Module instantiations
bp_core   
 #(.bp_params_p(bp_params_p))
 core 
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_lo)
   ,.cfg_irf_data_o(cfg_irf_data_li)
   ,.cfg_npc_data_o(cfg_npc_data_li)
   ,.cfg_csr_data_o(cfg_csr_data_li)
   ,.cfg_priv_data_o(cfg_priv_data_li)

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
    
   ,.timer_irq_i(timer_irq_i)
   ,.software_irq_i(software_irq_i)
   ,.external_irq_i(external_irq_i)
   );

bp_cce_top
 #(.bp_params_p(bp_params_p))
 cce
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.cfg_bus_i(cfg_bus_lo)
   ,.cfg_cce_ucode_data_o(cfg_cce_ucode_data_li)

   // To CCE
   ,.lce_req_i(cce_lce_req_li)
   ,.lce_req_v_i(cce_lce_req_v_li)
   ,.lce_req_ready_o(cce_lce_req_ready_lo)

   ,.lce_resp_i(cce_lce_resp_li)
   ,.lce_resp_v_i(cce_lce_resp_v_li)
   ,.lce_resp_ready_o(cce_lce_resp_ready_lo)

   // From CCE
   ,.lce_cmd_o(cce_lce_cmd_lo)
   ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
   ,.lce_cmd_ready_i(cce_lce_cmd_ready_li)

   // To CCE
   ,.mem_resp_i(cce_mem_resp_li)
   ,.mem_resp_v_i(cce_mem_resp_v_li)
   ,.mem_resp_ready_o(cce_mem_resp_ready_lo)

   // TODO: Reconnect with concentrator
   ,.mem_cmd_i(cce_mem_cmd_li)
   ,.mem_cmd_v_i(cce_mem_cmd_v_li)
   ,.mem_cmd_ready_o(cce_mem_cmd_ready_lo)

   // From CCE
   ,.mem_cmd_o(cce_mem_cmd_lo)
   ,.mem_cmd_v_o(cce_mem_cmd_v_lo)
   ,.mem_cmd_yumi_i(cce_mem_cmd_ready_li & cce_mem_cmd_v_lo)

   ,.mem_resp_o(cce_mem_resp_lo)
   ,.mem_resp_v_o(cce_mem_resp_v_lo)
   ,.mem_resp_yumi_i(cce_mem_resp_ready_li & cce_mem_resp_v_lo)
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
       ,.reset_i(reset_i)

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
       ,.reset_i(reset_i)

       ,.packet_i(lce_cmd_packet_lo[i])
       ,.v_i(lce_cmd_v_lo[i])
       ,.ready_o(lce_cmd_ready_li[i])

       ,.link_i(lce_cmd_link_li[i])
       ,.link_o(lce_cmd_link_lo[i])

       ,.packet_o(lce_cmd_packet_li[i])
       ,.v_o(lce_cmd_v_li[i])
       ,.yumi_i(lce_cmd_ready_lo[i] & lce_cmd_v_li[i])
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
       ,.reset_i(reset_i)

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
    ,.reset_i(reset_i)
  
    ,.link_i(lce_req_link_i)
    ,.link_o(cce_lce_req_link_lo)
  
    ,.packet_o(cce_lce_req_packet_li)
    ,.v_o(cce_lce_req_v_li)
    ,.yumi_i(cce_lce_req_ready_lo & cce_lce_req_v_li)
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
     ,.reset_i(reset_i)
  
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
    ,.reset_i(reset_i)
  
    ,.link_i(lce_resp_link_i)
    ,.link_o(cce_lce_resp_link_lo)
  
    ,.packet_o(cce_lce_resp_packet_li)
    ,.v_o(cce_lce_resp_v_li)
    ,.yumi_i(cce_lce_resp_ready_lo & cce_lce_resp_v_li)
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
     ,.reset_i(reset_i)

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
     ,.reset_i(reset_i)

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
     ,.reset_i(reset_i)

     ,.links_i(lce_resp_link_lo)
     ,.links_o(lce_resp_link_li)

     ,.concentrated_link_i(resp_concentrated_link_li)
     ,.concentrated_link_o(resp_concentrated_link_lo)
     );

logic [mem_noc_cord_width_p-1:0] dst_cord_lo;
logic [mem_noc_cid_width_p-1:0]  dst_cid_lo;
bp_addr_map
 #(.bp_params_p(bp_params_p))
 cmd_map
  (.paddr_i(cce_mem_cmd_lo.addr)

   ,.clint_cord_i(clint_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.host_cord_i(host_cord_i)

   ,.dst_cid_o(dst_cid_lo)
   ,.dst_cord_o(dst_cord_lo)
   );

bp_mem_ready_and_link_s cce_mem_cmd_link_li, cce_mem_cmd_link_lo;
bp_mem_ready_and_link_s cce_mem_resp_link_li, cce_mem_resp_link_lo;

bp_mem_ready_and_link_s cfg_mem_cmd_link_li, cfg_mem_cmd_link_lo;
bp_mem_ready_and_link_s cfg_mem_resp_link_li, cfg_mem_resp_link_lo;

bp_mem_ready_and_link_s mem_cmd_concentrated_link_li, mem_cmd_concentrated_link_lo;
bp_mem_ready_and_link_s mem_resp_concentrated_link_li, mem_resp_concentrated_link_lo;

assign mem_cmd_concentrated_link_li = mem_cmd_link_i;
assign mem_cmd_link_o = mem_cmd_concentrated_link_lo;
bsg_wormhole_concentrator
 #(.flit_width_p(mem_noc_flit_width_p)
   ,.len_width_p(mem_noc_len_width_p)
   ,.cid_width_p(mem_noc_cid_width_p)
   ,.num_in_p(2)
   ,.cord_width_p(mem_noc_cord_width_p)
   )
 mem_cmd_concentrator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.links_i({cfg_mem_cmd_link_lo, cce_mem_cmd_link_lo})
   ,.links_o({cfg_mem_cmd_link_li, cce_mem_cmd_link_li})

   ,.concentrated_link_i(mem_cmd_concentrated_link_li)
   ,.concentrated_link_o(mem_cmd_concentrated_link_lo)
   );

assign mem_resp_concentrated_link_li = mem_resp_link_i;
assign mem_resp_link_o = mem_resp_concentrated_link_lo;
bsg_wormhole_concentrator
 #(.flit_width_p(mem_noc_flit_width_p)
   ,.len_width_p(mem_noc_len_width_p)
   ,.cid_width_p(mem_noc_cid_width_p)
   ,.num_in_p(2)
   ,.cord_width_p(mem_noc_cord_width_p)
   )
 mem_resp_concentrator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.links_i({cfg_mem_resp_link_lo, cce_mem_resp_link_lo})
   ,.links_o({cfg_mem_resp_link_li, cce_mem_resp_link_li})

   ,.concentrated_link_i(mem_resp_concentrated_link_li)
   ,.concentrated_link_o(mem_resp_concentrated_link_lo)
   );

bp_me_cce_to_wormhole_link_bidir
 #(.bp_params_p(bp_params_p))
 cce_link
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(cce_mem_cmd_lo)
   ,.mem_cmd_v_i(cce_mem_cmd_v_lo)
   ,.mem_cmd_ready_o(cce_mem_cmd_ready_li)

   ,.mem_resp_o(cce_mem_resp_li)
   ,.mem_resp_v_o(cce_mem_resp_v_li)
   ,.mem_resp_yumi_i(cce_mem_resp_ready_lo & cce_mem_resp_v_li)

   ,.mem_cmd_o(cce_mem_cmd_li)
   ,.mem_cmd_v_o(cce_mem_cmd_v_li)
   ,.mem_cmd_yumi_i(cce_mem_cmd_ready_lo & cce_mem_cmd_v_li)

   ,.mem_resp_i(cce_mem_resp_lo)
   ,.mem_resp_v_i(cce_mem_resp_v_lo)
   ,.mem_resp_ready_o(cce_mem_resp_ready_li)

   ,.my_cord_i(my_cord_i)
   ,.my_cid_i(mem_noc_cid_width_p'(0))
   ,.dst_cord_i(dst_cord_lo)
   ,.dst_cid_i(dst_cid_lo)

   ,.cmd_link_i(cce_mem_cmd_link_li)
   ,.cmd_link_o(cce_mem_cmd_link_lo)

   ,.resp_link_i(cce_mem_resp_link_li)
   ,.resp_link_o(cce_mem_resp_link_lo)
   );

bp_me_cce_to_wormhole_link_client
 #(.bp_params_p(bp_params_p))
 cfg_link
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_o(cfg_mem_cmd_li)
   ,.mem_cmd_v_o(cfg_mem_cmd_v_li)
   ,.mem_cmd_yumi_i(cfg_mem_cmd_yumi_lo)

   ,.mem_resp_i(cfg_mem_resp_lo)
   ,.mem_resp_v_i(cfg_mem_resp_v_lo)
   ,.mem_resp_ready_o(cfg_mem_resp_ready_li)

   ,.my_cord_i(my_cord_i)
   ,.my_cid_i(mem_noc_cid_width_p'(1))

   ,.cmd_link_i(cfg_mem_cmd_link_li)
   ,.cmd_link_o(cfg_mem_cmd_link_lo)

   ,.resp_link_i(cfg_mem_resp_link_li)
   ,.resp_link_o(cfg_mem_resp_link_lo)
   );

endmodule


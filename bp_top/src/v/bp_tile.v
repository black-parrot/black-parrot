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
 import bp_cfg_link_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
   `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)

   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
   )
  (input                                                      clk_i
   , input                                                    reset_i

   , input [proc_cfg_width_lp-1:0]                            proc_cfg_i

   // Memory side connection
   , input [mem_noc_cord_width_p-1:0]                         my_cord_i
   , input [mem_noc_cid_width_p-1:0]                          my_cid_i
   , input [mem_noc_cord_width_p-1:0]                         dram_cord_i
   , input [mem_noc_cord_width_p-1:0]                         mmio_cord_i
   , input [mem_noc_cord_width_p-1:0]                         host_cord_i

   // Config channel
   , input                                                    cfg_w_v_i
   , input [cfg_addr_width_p-1:0]                             cfg_addr_i
   , input [cfg_data_width_p-1:0]                             cfg_data_i

   // Connected to other tiles on east and west
   , input [coh_noc_ral_link_width_lp-1:0]                    lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output [coh_noc_ral_link_width_lp-1:0]                   lce_resp_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                    cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                   cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                    resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]                   resp_link_o

   // Interrupts
   , input                                                    timer_int_i
   , input                                                    software_int_i
   , input                                                    external_int_i
   );

`declare_bp_common_proc_cfg_s(num_core_p, num_cce_p, num_lce_p)
`declare_bp_lce_cce_if(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

// Cast the routing links
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);

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
bp_cce_mem_msg_s       mem_cmd_lo;
logic                  mem_cmd_v_lo, mem_cmd_ready_li;
bp_cce_mem_msg_s       mem_resp_lo;
logic                  mem_resp_v_lo, mem_resp_ready_li;
bp_cce_mem_msg_s       mem_resp_li;
logic                  mem_resp_v_li, mem_resp_ready_lo;
bp_cce_mem_msg_s       mem_cmd_li;
logic                  mem_cmd_v_li, mem_cmd_ready_lo;

// TODO: connect mem_cmd_li and mem_resp_lo
assign mem_cmd_li = '0;
assign mem_cmd_v_li = '0;
assign mem_resp_ready_li = '0;

bp_proc_cfg_s proc_cfg_cast_i;
assign proc_cfg_cast_i = proc_cfg_i;

logic reset_r;
always_ff @(posedge clk_i)
  begin
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
   ,.mem_resp_i(mem_resp_li)
   ,.mem_resp_v_i(mem_resp_v_li)
   ,.mem_resp_ready_o(mem_resp_ready_lo)

   ,.mem_cmd_i(mem_cmd_li)
   ,.mem_cmd_v_i(mem_cmd_v_li)
   ,.mem_cmd_ready_o(mem_cmd_ready_lo)

   // From CCE
   ,.mem_cmd_o(mem_cmd_lo)
   ,.mem_cmd_v_o(mem_cmd_v_lo)
   ,.mem_cmd_yumi_i(mem_cmd_ready_li & mem_cmd_v_lo)

   ,.mem_resp_o(mem_resp_lo)
   ,.mem_resp_v_o(mem_resp_v_lo)
   ,.mem_resp_yumi_i(mem_resp_ready_li & mem_resp_v_lo)

   ,.cce_id_i(proc_cfg_cast_i.cce_id) 
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
     #(.cfg_p(cfg_p))
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
     #(.cfg_p(cfg_p))
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
       ,.yumi_i(lce_cmd_ready_lo[i] & lce_cmd_v_li[i])
       );
    assign lce_cmd_li[i] = lce_cmd_packet_li[i].payload;

    bp_me_wormhole_packet_encode_lce_resp
     #(.cfg_p(cfg_p))
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
    ,.yumi_i(cce_lce_req_ready_lo & cce_lce_req_v_li)
    );
  assign cce_lce_req_li = cce_lce_req_packet_li.payload;
      
  lce_cmd_packet_s cce_lce_cmd_packet_lo;
  bp_me_wormhole_packet_encode_lce_cmd
   #(.cfg_p(cfg_p))
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

bp_me_cce_to_wormhole_link_master
 #(.cfg_p(cfg_p))
 master_link
  (.clk_i(clk_i)
   ,.reset_i(reset_r)

   ,.mem_cmd_i(mem_cmd_lo)
   ,.mem_cmd_v_i(mem_cmd_v_lo)
   ,.mem_cmd_ready_o(mem_cmd_ready_li)

   ,.mem_resp_o(mem_resp_li)
   ,.mem_resp_v_o(mem_resp_v_li)
   ,.mem_resp_yumi_i(mem_resp_ready_lo & mem_resp_v_li)

   ,.my_cord_i(my_cord_i)
   ,.my_cid_i(my_cid_i)
   ,.dram_cord_i(dram_cord_i)
   ,.mmio_cord_i(mmio_cord_i)
   ,.host_cord_i(host_cord_i)

   ,.cmd_link_i(cmd_link_i)
   ,.cmd_link_o(cmd_link_o)

   ,.resp_link_i(resp_link_i)
   ,.resp_link_o(resp_link_o)
   );

endmodule


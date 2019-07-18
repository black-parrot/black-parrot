/**
 * bp_me_cce_to_wormhole_link_client.v
 */

`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_client

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
  
  `declare_bp_proc_params(cfg_p)
  , localparam cce_mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp)
  
  // wormhole parameters
  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)

  ,localparam word_select_bits_lp  = `BSG_SAFE_CLOG2(cce_block_width_p / dword_width_p)
  ,localparam byte_offset_bits_lp  = `BSG_SAFE_CLOG2(dword_width_p / 8)
  ,localparam num_outstanding_req_p = 16
  )
  
  (input clk_i
  ,input reset_i

  // MEM -> CCE Interface
  ,output logic [cce_mem_cmd_width_lp-1:0]       mem_cmd_o
  ,output logic                                  mem_cmd_v_o
  ,input  logic                                  mem_cmd_yumi_i
                                                 
  ,output logic [cce_mem_data_cmd_width_lp-1:0]  mem_data_cmd_o
  ,output logic                                  mem_data_cmd_v_o
  ,input  logic                                  mem_data_cmd_yumi_i
                                                 
  // CCE -> MEM Interface                        
  ,input  logic [mem_cce_resp_width_lp-1:0]      mem_resp_i
  ,input  logic                                  mem_resp_v_i
  ,output logic                                  mem_resp_ready_o

  ,input  logic [mem_cce_data_resp_width_lp-1:0] mem_data_resp_i
  ,input  logic                                  mem_data_resp_v_i
  ,output logic                                  mem_data_resp_ready_o
    
  // Configuration
  ,input [noc_cord_width_p-1:0] my_cord_i
    
  // bsg_noc_wormhole interface
  ,input  [bsg_ready_and_link_sif_width_lp-1:0] link_i
  ,output [bsg_ready_and_link_sif_width_lp-1:0] link_o
  );
  
  /********************** noc link interface ***********************/
  
  `declare_bsg_ready_and_link_sif_s(noc_width_p,bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s link_i_cast, link_o_cast;
    
  assign link_i_cast = link_i;
  assign link_o = link_o_cast;
  
  /********************** Packet definition ***********************/
  
  // CCE-MEM interface packets
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, cce_mshr_width_lp);
  
  // Wormhole packet definition
  `declare_bp_mem_wormhole_packet_s(noc_reserved_width_p, noc_cord_width_p, noc_len_width_p, cce_mem_data_cmd_width_lp, bp_data_cmd_wormhole_packet_s);
  `declare_bp_mem_wormhole_packet_s(noc_reserved_width_p, noc_cord_width_p, noc_len_width_p, mem_cce_data_resp_width_lp, bp_data_resp_wormhole_packet_s);
  
  // Wormhole header definition
  `declare_wormhole_header_flit_s(noc_width_p, noc_cord_width_p, noc_len_width_p, wormhole_header_flit_s);
  
  // Wormhole packet length
  localparam nc_offset_lp = cce_block_width_p-dword_width_p;
  localparam data_cmd_hdr_width_lp  = cce_mem_data_cmd_width_lp - cce_block_width_p;
  localparam data_resp_hdr_width_lp = mem_cce_data_resp_width_lp - cce_block_width_p;
  
  localparam resp_wormhole_packet_width_lp = `bp_mem_wormhole_packet_width(noc_reserved_width_p, noc_cord_width_p, noc_len_width_p, mem_cce_resp_width_lp);
  localparam data_resp_wormhole_packet_width_lp = `bp_mem_wormhole_packet_width(noc_reserved_width_p, noc_cord_width_p, noc_len_width_p, mem_cce_data_resp_width_lp);
  localparam data_resp_nc_wormhole_packet_width_lp = data_resp_wormhole_packet_width_lp-nc_offset_lp;

  localparam resp_ratio_lp = `BSG_CDIV(resp_wormhole_packet_width_lp, noc_width_p);
  localparam data_resp_ratio_lp = `BSG_CDIV(data_resp_wormhole_packet_width_lp, noc_width_p);
  localparam data_resp_nc_ratio_lp = `BSG_CDIV(data_resp_nc_wormhole_packet_width_lp, noc_width_p);
  localparam data_cmd_ratio_lp = `BSG_CDIV($bits(bp_data_cmd_wormhole_packet_s), noc_width_p);
  
  /********************** Between receiving and sending ***********************/
  
  logic fifo_valid_i, fifo_ready_o, fifo_valid_o, fifo_yumi_i;
  logic [noc_cord_width_p-1:0] fifo_cord_i, fifo_cord_o;
  
  bsg_fifo_1r1w_small 
 #(.width_p(noc_cord_width_p)
  ,.els_p(num_outstanding_req_p)
  ) cord_fifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(fifo_ready_o)
  ,.data_i (fifo_cord_i)
  ,.v_i    (fifo_valid_i)

  ,.v_o    (fifo_valid_o)
  ,.data_o (fifo_cord_o)
  ,.yumi_i (fifo_yumi_i)
  );

  /********************** Receiving Side ***********************/
  
  wormhole_header_flit_s receive_header;
  assign receive_header = link_i_cast.data;
  
  logic receive_valid_lo, receive_yumi_li;
  logic [data_cmd_ratio_lp*noc_width_p-1:0] receive_data_lo;
  
  bp_data_cmd_wormhole_packet_s receive_wormhole_packet_lo;
  assign receive_wormhole_packet_lo = receive_data_lo;
  assign mem_cmd_v_o                = fifo_ready_o & receive_valid_lo 
                                      & ~receive_wormhole_packet_lo.write_en;
  assign mem_data_cmd_v_o           = fifo_ready_o & receive_valid_lo 
                                      & receive_wormhole_packet_lo.write_en;
  assign receive_yumi_li            = mem_cmd_yumi_i | mem_data_cmd_yumi_i;
  
  assign fifo_valid_i               = receive_yumi_li;
  assign fifo_cord_i                = receive_wormhole_packet_lo.src_cord;
  
  bsg_serial_in_parallel_out_dynamic
 #(.width_p  (noc_width_p      )
  ,.max_els_p(data_cmd_ratio_lp)
  )
  sipod
  (.clk_i      (clk_i  )
  ,.reset_i    (reset_i)
               
  ,.v_i        (link_i_cast.v            )
  ,.len_i      (`BSG_SAFE_CLOG2(data_cmd_ratio_lp)'(receive_header.len))
  ,.data_i     (link_i_cast.data         )
  ,.ready_o    (link_o_cast.ready_and_rev)
  ,.len_ready_o(                         )
  
  ,.v_o   (receive_valid_lo)
  ,.data_o(receive_data_lo )
  ,.yumi_i(receive_yumi_li )
  );
  
  bp_cce_mem_data_cmd_s mem_data_cmd;
  bp_cce_mem_cmd_s      mem_cmd;
  
  assign mem_cmd_o      = mem_cmd;
  assign mem_data_cmd_o = mem_data_cmd;
  
  assign mem_cmd = cce_mem_cmd_width_lp'(receive_wormhole_packet_lo.data);
  
  // CCE packet format: {data_cmd_hdr, data_cmd_data}
  // Wormhole packet format: {data_cmd_data, data_cmd_hdr}
  // Need to swizzle
  //
  
  assign mem_data_cmd[cce_block_width_p+:data_cmd_hdr_width_lp] = 
        receive_wormhole_packet_lo.data[0+:data_cmd_hdr_width_lp];

  always_comb
  begin
    if (receive_wormhole_packet_lo.non_cacheable)
      begin
        mem_data_cmd.data          = '0;
        mem_data_cmd.data[0+:dword_width_p] = 
            receive_wormhole_packet_lo.data[data_cmd_hdr_width_lp+:dword_width_p];
      end
    else
      begin
        mem_data_cmd.data = 
            receive_wormhole_packet_lo.data[data_cmd_hdr_width_lp+:cce_block_width_p];
      end
  end

  /********************** Sending Side ***********************/
  
  logic send_valid_li, send_ready_lo;
  logic [data_resp_ratio_lp*noc_width_p-1:0] send_data_li;
  
  bp_data_resp_wormhole_packet_s send_wormhole_packet_lo;
  assign mem_data_resp_ready_o = fifo_valid_o & send_ready_lo;
  assign mem_resp_ready_o      = fifo_valid_o & send_ready_lo & ~mem_data_resp_v_i;
  assign send_valid_li         = fifo_valid_o & (mem_resp_v_i | mem_data_resp_v_i);
  assign send_data_li          = {'0, send_wormhole_packet_lo};
  
  assign fifo_yumi_i           = fifo_valid_o & send_ready_lo & send_valid_li;
  
  bsg_parallel_in_serial_out_dynamic                          
 #(.width_p  (noc_width_p       )
  ,.max_els_p(data_resp_ratio_lp)
  )
  pisod
  (.clk_i  (clk_i           )
  ,.reset_i(reset_i         )
  
  ,.v_i    (send_valid_li   )
  ,.len_i  (`BSG_SAFE_CLOG2(data_resp_ratio_lp)'(send_wormhole_packet_lo.len))
  ,.data_i (send_data_li    )
  ,.ready_o(send_ready_lo   )
  
  ,.v_o    (link_o_cast.v   )
  ,.len_v_o(                )
  ,.data_o (link_o_cast.data)
  ,.yumi_i (link_o_cast.v & link_i_cast.ready_and_rev)
  );
  
  bp_mem_cce_resp_s mem_resp;
  bp_mem_cce_data_resp_s mem_data_resp;
  
  assign mem_resp = mem_resp_i;
  assign mem_data_resp = mem_data_resp_i;
  
  logic [mem_cce_data_resp_width_lp-1:0]              send_data_lo;
  logic [mem_cce_data_resp_width_lp-nc_offset_lp-1:0] send_nc_data_lo;
  
  // CCE packet format: {data_resp_hdr, data_resp_data}
  // Wormhole packet format: {data_resp_data, data_resp_hdr}
  // Need to swizzle
  //
  assign send_data_lo    = {mem_data_resp.data, mem_data_resp[cce_block_width_p+:data_resp_hdr_width_lp]};
  assign send_nc_data_lo = {mem_data_resp.data[0+:dword_width_p], mem_data_resp[cce_block_width_p+:data_resp_hdr_width_lp]};
  
  always_comb
  begin
    send_wormhole_packet_lo.reserved      = '0;
    send_wormhole_packet_lo.src_cord      = my_cord_i;
    send_wormhole_packet_lo.cord          = fifo_cord_o;
    // Default state is mem_resp
    send_wormhole_packet_lo.write_en      = 1'b1;
    send_wormhole_packet_lo.non_cacheable = mem_resp.non_cacheable;
    send_wormhole_packet_lo.data          = mem_resp;
    send_wormhole_packet_lo.len           = resp_ratio_lp-1;

    if (mem_data_resp_v_i)
      begin
        send_wormhole_packet_lo.write_en      = 1'b0;
        send_wormhole_packet_lo.non_cacheable = mem_data_resp.non_cacheable;
        send_wormhole_packet_lo.data          = (mem_data_resp.non_cacheable)? 
                                                send_nc_data_lo : send_data_lo;
        send_wormhole_packet_lo.len           = (mem_data_resp.non_cacheable)? 
                                                data_resp_nc_ratio_lp-1 : data_resp_ratio_lp-1;
      end
  end
  
endmodule

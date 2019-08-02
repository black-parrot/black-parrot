/**
 * bp_me_cce_to_wormhole_link_client.v
 */

`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_client

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
  
  `declare_bp_proc_params(cfg_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  
  // wormhole parameters
  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_width_p)

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
                                                 
  // CCE -> MEM Interface                        
  ,input  logic [mem_cce_resp_width_lp-1:0]      mem_resp_i
  ,input  logic                                  mem_resp_v_i
  ,output logic                                  mem_resp_ready_o

  // Configuration
  ,input [mem_noc_cord_width_p-1:0] my_cord_i
    
  // bsg_noc_wormhole interface
  ,input  [bsg_ready_and_link_sif_width_lp-1:0] link_i
  ,output [bsg_ready_and_link_sif_width_lp-1:0] link_o
  );
  
  /********************** noc link interface ***********************/
  
  `declare_bsg_ready_and_link_sif_s(mem_noc_width_p,bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s link_i_cast, link_o_cast;
    
  assign link_i_cast = link_i;
  assign link_o = link_o_cast;
  
  /********************** Packet definition ***********************/
  
  // CCE-MEM interface packets
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  
  // Wormhole packet definition
  `declare_bp_mem_wormhole_packet_s(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, cce_mem_cmd_width_lp, bp_cmd_wormhole_packet_s);
  `declare_bp_mem_wormhole_packet_s(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_cce_resp_width_lp, bp_resp_wormhole_packet_s);
  
  // Wormhole header definition
  `declare_wormhole_header_flit_s(mem_noc_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, wormhole_header_flit_s);
  
  // Wormhole packet widths and lengths
  localparam cmd_header_width_lp = cce_mem_cmd_width_lp - cce_block_width_p;
  // currently, mem cmd and resp messages have same format
  localparam resp_header_Width_lp = cmd_header_width_lp;

  localparam cmd_data_wh_pkt_width_lp = `bp_mem_wormhole_packet_width(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, cce_mem_cmd_width_lp);
  localparam cmd_uc_data_wh_pkt_width_lp = `bp_mem_wormhole_packet_width(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, cce_mem_cmd_width_lp-cce_block_width_p+dword_width_p);
  localparam cmd_wh_pkt_width_lp = `bp_mem_wormhole_packet_width(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, cce_mem_cmd_width_lp-cce_block_width_p);

  localparam cmd_data_ratio_lp = `BSG_CDIV(cmd_data_wh_pkt_width_lp, mem_noc_width_p);
  localparam cmd_uc_data_ratio_lp = `BSG_CDIV(cmd_uc_data_wh_pkt_width_lp, mem_noc_width_p);
  localparam cmd_ratio_lp = `BSG_CDIV(cmd_wh_pkt_width_lp, mem_noc_width_p);

  localparam resp_data_wh_pkt_width_lp = `bp_mem_wormhole_packet_width(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_cce_resp_width_lp);
  localparam resp_uc_data_wh_pkt_width_lp = `bp_mem_wormhole_packet_width(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_cce_resp_width_lp-cce_block_width_p+dword_width_p);
  localparam resp_wh_pkt_width_lp = `bp_mem_wormhole_packet_width(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_cce_resp_width_lp-cce_block_width_p);

  localparam resp_data_ratio_lp = `BSG_CDIV(resp_data_wh_pkt_width_lp, mem_noc_width_p);
  localparam resp_uc_data_ratio_lp = `BSG_CDIV(resp_uc_data_wh_pkt_width_lp, mem_noc_width_p);
  localparam resp_ratio_lp = `BSG_CDIV(resp_wh_pkt_width_lp, mem_noc_width_p);

  /********************** Between receiving and sending ***********************/
  
  logic fifo_valid_i, fifo_ready_o, fifo_valid_o, fifo_yumi_i;
  logic [mem_noc_cord_width_p-1:0] fifo_cord_i, fifo_cord_o;
  
  bsg_fifo_1r1w_small 
 #(.width_p(mem_noc_cord_width_p)
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
  logic [cmd_data_ratio_lp*mem_noc_width_p-1:0] receive_data_lo;
  
  bp_cmd_wormhole_packet_s receive_wormhole_packet_lo;
  assign receive_wormhole_packet_lo = receive_data_lo;
  assign mem_cmd_v_o                = fifo_ready_o & receive_valid_lo 
                                      & ~receive_wormhole_packet_lo.write_en;
  assign receive_yumi_li            = mem_cmd_yumi_i;
  
  assign fifo_valid_i               = receive_yumi_li;
  assign fifo_cord_i                = receive_wormhole_packet_lo.src_cord;
  
  bsg_serial_in_parallel_out_dynamic
 #(.width_p  (mem_noc_width_p      )
  ,.max_els_p(cmd_data_ratio_lp)
  )
  sipod
  (.clk_i      (clk_i  )
  ,.reset_i    (reset_i)
               
  ,.v_i        (link_i_cast.v            )
  ,.len_i      (`BSG_SAFE_CLOG2(cmd_data_ratio_lp)'(receive_header.len))
  ,.data_i     (link_i_cast.data         )
  ,.ready_o    (link_o_cast.ready_and_rev)
  ,.len_ready_o(                         )
  
  ,.v_o   (receive_valid_lo)
  ,.data_o(receive_data_lo )
  ,.yumi_i(receive_yumi_li )
  );
  
  bp_cce_mem_cmd_s      mem_cmd;
  
  assign mem_cmd_o      = mem_cmd;
  
  assign mem_cmd = cce_mem_cmd_width_lp'(receive_wormhole_packet_lo.data);
 

  /********************** Sending Side ***********************/
  
  logic send_valid_li, send_ready_lo;
  logic [resp_data_ratio_lp*mem_noc_width_p-1:0] send_data_li;
  
  bp_resp_wormhole_packet_s send_wormhole_packet_lo;
  assign mem_resp_ready_o      = fifo_valid_o & send_ready_lo;
  assign send_valid_li         = fifo_valid_o & mem_resp_v_i;
  assign send_data_li          = {'0, send_wormhole_packet_lo};
  
  assign fifo_yumi_i           = fifo_valid_o & send_ready_lo & send_valid_li;
  
  bsg_parallel_in_serial_out_dynamic                          
 #(.width_p  (mem_noc_width_p       )
  ,.max_els_p(resp_data_ratio_lp)
  )
  pisod
  (.clk_i  (clk_i           )
  ,.reset_i(reset_i         )
  
  ,.v_i    (send_valid_li   )
  ,.len_i  (`BSG_SAFE_CLOG2(resp_data_ratio_lp)'(send_wormhole_packet_lo.len))
  ,.data_i (send_data_li    )
  ,.ready_o(send_ready_lo   )
  
  ,.v_o    (link_o_cast.v   )
  ,.len_v_o(                )
  ,.data_o (link_o_cast.data)
  ,.yumi_i (link_o_cast.v & link_i_cast.ready_and_rev)
  );
  
  bp_mem_cce_resp_s mem_resp;
  
  assign mem_resp = mem_resp_i;
  
  always_comb
  begin
    send_wormhole_packet_lo.reserved      = '0;
    send_wormhole_packet_lo.src_cord      = my_cord_i;
    send_wormhole_packet_lo.cord          = fifo_cord_o;
    // Default state is mem_resp
    send_wormhole_packet_lo.write_en      = 1'b1;
    send_wormhole_packet_lo.non_cacheable = (mem_resp.msg_type == e_cce_mem_uc_rd
                                             | mem_resp.msg_type == e_cce_mem_uc_wr);
    send_wormhole_packet_lo.data          = mem_resp;
    // length is determined by the message type of the mem_resp message
    send_wormhole_packet_lo.len =
      (mem_resp.msg_type == e_cce_mem_rd | mem_resp.msg_type == e_cce_mem_wr)
      ? resp_data_ratio_lp-1
      : (mem_resp.msg_type == e_cce_mem_uc_rd)
        ? resp_uc_data_ratio_lp-1
        : resp_ratio_lp-1;

  end
  
endmodule

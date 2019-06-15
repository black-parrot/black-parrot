/**
 * bp_me_cce_to_wormhole_link_client.v
 */

`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_client

  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
  
  `declare_bp_proc_params(cfg_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  
  // wormhole parameters
  ,parameter  x_cord_width_p = "inv"
  ,parameter  y_cord_width_p = "inv"
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
  ,input [x_cord_width_p-1:0] my_x_i
  ,input [y_cord_width_p-1:0] my_y_i
    
  // bsg_noc_wormhole interface
  ,input  [bsg_ready_and_link_sif_width_lp-1:0] link_i
  ,output [bsg_ready_and_link_sif_width_lp-1:0] link_o
  );
  
  // Interfacing bsg_noc links 

  logic valid_o, ready_i;
  logic [noc_width_p-1:0] data_o;
  
  logic valid_i, ready_o;
  logic [noc_width_p-1:0] data_i;
  
  `declare_bsg_ready_and_link_sif_s(noc_width_p,bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s link_i_cast, link_o_cast;
    
  assign link_i_cast = link_i;
  assign link_o = link_o_cast;
    
  assign valid_i = link_i_cast.v;
  assign data_i = link_i_cast.data;
  assign link_o_cast.ready_and_rev = ready_o;
    
  assign link_o_cast.v = valid_o;
  assign link_o_cast.data = data_o;
  assign ready_i = link_i_cast.ready_and_rev;
  
  
  // CCE-MEM interface packets
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  
  // Wormhole packet definition
  `declare_bp_mem_wormhole_packet_s(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, mem_cce_data_resp_width_lp, bp_send_wormhole_packet_s);
  `declare_bp_mem_wormhole_packet_s(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, cce_mem_data_cmd_width_lp, bp_receive_wormhole_packet_s);
  
  // Wormhole packet length
  localparam nc_offset_lp = cce_block_width_p-dword_width_p;
  
  localparam resp_wormhole_packet_width_lp = `bp_mem_wormhole_packet_width(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, mem_cce_resp_width_lp);
  localparam data_resp_wormhole_packet_width_lp = `bp_mem_wormhole_packet_width(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, mem_cce_data_resp_width_lp);
  localparam data_resp_nc_wormhole_packet_width_lp = data_resp_wormhole_packet_width_lp-nc_offset_lp;

  localparam resp_ratio_lp = `BSG_CDIV(resp_wormhole_packet_width_lp, noc_width_p);
  localparam data_resp_ratio_lp = `BSG_CDIV(data_resp_wormhole_packet_width_lp, noc_width_p);
  localparam data_resp_nc_ratio_lp = `BSG_CDIV(data_resp_nc_wormhole_packet_width_lp, noc_width_p);
  
  
  /********************** Between receiving and sending ***********************/
  
  logic fifo_valid_i, fifo_ready_o, fifo_valid_o, fifo_yumi_i;
  logic [x_cord_width_p-1:0] fifo_x_i, fifo_x_o;
  logic [y_cord_width_p-1:0] fifo_y_i, fifo_y_o;
  
  bsg_fifo_1r1w_small 
 #(.width_p(y_cord_width_p+x_cord_width_p)
  ,.els_p(num_outstanding_req_p)
  ) ofifo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(fifo_ready_o)
  ,.data_i ({fifo_y_i, fifo_x_i})
  ,.v_i    (fifo_valid_i)

  ,.v_o    (fifo_valid_o)
  ,.data_o ({fifo_y_o, fifo_x_o})
  ,.yumi_i (fifo_yumi_i)
  );

  /********************** Receiving Side ***********************/
  
  bp_cce_mem_cmd_s mem_cmd;
  bp_cce_mem_data_cmd_s mem_data_cmd;
  
  assign mem_cmd_o = mem_cmd;
  assign mem_data_cmd_o = mem_data_cmd;
  
  typedef enum logic [1:0] {
     RECEIVE_RESET
    ,RECEIVE_READY
    ,RECEIVE_CMD
  } receive_state_e;
  
  receive_state_e receive_state_r, receive_state_n;
  logic [noc_len_width_p-1:0] receive_counter_r, receive_counter_n;
  
  logic [word_select_bits_lp-1:0] receive_sel_lo;
  assign receive_sel_lo = mem_data_cmd.addr[byte_offset_bits_lp+:word_select_bits_lp];
    
  bp_receive_wormhole_packet_s receive_wormhole_packet_r, receive_wormhole_packet_n;
  
  assign mem_cmd = cce_mem_cmd_width_lp'(receive_wormhole_packet_r.data);
  
  bp_cce_mem_data_cmd_s mem_data_cmd_nc_cast;
  assign mem_data_cmd_nc_cast = {receive_wormhole_packet_r.data, nc_offset_lp'(0)};
  
  always_comb
  begin
    if (receive_wormhole_packet_r.non_cacheable)
      begin
        mem_data_cmd.msg_type = mem_data_cmd_nc_cast.msg_type;
        mem_data_cmd.addr = mem_data_cmd_nc_cast.addr;
        mem_data_cmd.payload = mem_data_cmd_nc_cast.payload;
        mem_data_cmd.non_cacheable = mem_data_cmd_nc_cast.non_cacheable;
        mem_data_cmd.nc_size = mem_data_cmd_nc_cast.nc_size;
        mem_data_cmd.data = '0;
        mem_data_cmd.data[(receive_sel_lo*dword_width_p)+:dword_width_p] = mem_data_cmd_nc_cast.data[nc_offset_lp+: dword_width_p];
      end
    else
      begin
        mem_data_cmd = receive_wormhole_packet_r.data;
      end
  end
  
  assign fifo_x_i = receive_wormhole_packet_r.src_x_cord;
  assign fifo_y_i = receive_wormhole_packet_r.src_y_cord;
  
  always_ff @(posedge clk_i) 
  begin
    if (reset_i)
      begin
        receive_state_r <= RECEIVE_RESET;
        receive_counter_r <= '0;
        receive_wormhole_packet_r <= '0;
      end
    else
      begin
        receive_state_r <= receive_state_n;
        receive_counter_r <= receive_counter_n;
        receive_wormhole_packet_r <= receive_wormhole_packet_n;
      end
  end
  
  always_comb 
  begin
  
    receive_state_n = receive_state_r;
    receive_counter_n = receive_counter_r;
    
    receive_wormhole_packet_n = receive_wormhole_packet_r;
    
    mem_cmd_v_o = 1'b0;
    mem_data_cmd_v_o = 1'b0;
    ready_o = 1'b0;
    
    fifo_valid_i = 1'b0;
    
    if (receive_state_r == RECEIVE_RESET)
      begin
        receive_state_n = RECEIVE_READY;
      end
    else if (receive_state_r == RECEIVE_READY)
      begin
        ready_o = 1'b1;
        if (valid_i) 
          begin
            receive_wormhole_packet_n[(receive_counter_r*noc_width_p)+:noc_width_p] = data_i;
            receive_counter_n = receive_counter_r + 1'b1;
            if (receive_counter_r == receive_wormhole_packet_n.len)
              begin
                receive_counter_n = 1'b0;
                receive_state_n = RECEIVE_CMD;
              end
          end
      end
    else if (receive_state_r == RECEIVE_CMD & fifo_ready_o) 
      begin
        if (receive_wormhole_packet_r.write_en) 
          begin
            mem_data_cmd_v_o = 1'b1;
            if (mem_data_cmd_yumi_i)
              begin
                fifo_valid_i = 1'b1;
                receive_wormhole_packet_n = '0;
                receive_state_n = RECEIVE_READY;
              end
          end
        else
          begin
            mem_cmd_v_o = 1'b1;
            if (mem_cmd_yumi_i)
              begin
                fifo_valid_i = 1'b1;
                receive_wormhole_packet_n = '0;
                receive_state_n = RECEIVE_READY;
              end
          end
      end
 
  end
  
  /********************** Sending Side ***********************/
  
  bp_mem_cce_resp_s mem_resp, mem_resp_r, mem_resp_n;
  bp_mem_cce_data_resp_s mem_data_resp, mem_data_resp_r, mem_data_resp_n;
  
  assign mem_resp = mem_resp_i;
  assign mem_data_resp = mem_data_resp_i;
  
  typedef enum logic [1:0] {
     SEND_RESET
    ,SEND_READY
    ,SEND_STORE
    ,SEND_LOAD
  } send_state_e;
  
  send_state_e send_state_r, send_state_n;
  logic [noc_len_width_p-1:0] send_counter_r, send_counter_n;
  
  bp_mem_cce_data_resp_s mem_data_resp_r_cast;
  assign mem_data_resp_r_cast.msg_type = mem_data_resp_r.msg_type;
  assign mem_data_resp_r_cast.addr = mem_data_resp_r.addr;
  assign mem_data_resp_r_cast.payload = mem_data_resp_r.payload;
  assign mem_data_resp_r_cast.non_cacheable = mem_data_resp_r.non_cacheable;
  assign mem_data_resp_r_cast.nc_size = mem_data_resp_r.nc_size;
  assign mem_data_resp_r_cast.data = mem_data_resp_r.data;
  
  bp_mem_cce_data_resp_s mem_data_resp_nc_r_cast;
  assign mem_data_resp_nc_r_cast.msg_type = mem_data_resp_r.msg_type;
  assign mem_data_resp_nc_r_cast.addr = mem_data_resp_r.addr;
  assign mem_data_resp_nc_r_cast.payload = mem_data_resp_r.payload;
  assign mem_data_resp_nc_r_cast.non_cacheable = mem_data_resp_r.non_cacheable;
  assign mem_data_resp_nc_r_cast.nc_size = mem_data_resp_r.nc_size;
  assign mem_data_resp_nc_r_cast.data = {mem_data_resp_r.data[0+:dword_width_p], nc_offset_lp'(0)};
  
  bp_send_wormhole_packet_s send_wormhole_packet_lo;
  logic [data_resp_ratio_lp*noc_width_p-1:0] send_wormhole_packet_lo_padded;
  
  assign send_wormhole_packet_lo_padded = {'0, send_wormhole_packet_lo};
  assign data_o = send_wormhole_packet_lo[(send_counter_r*noc_width_p)+:noc_width_p];
  
  always_ff @(posedge clk_i) 
  begin
    if (reset_i) 
      begin
        send_state_r <= SEND_RESET;
        send_counter_r <= '0;
      end 
    else 
      begin
        send_state_r <= send_state_n;
        send_counter_r <= send_counter_n;
      end
    mem_resp_r <= mem_resp_n;
    mem_data_resp_r <= mem_data_resp_n;
  end
  
  always_comb
  begin
  
    send_state_n = send_state_r;
    send_counter_n = send_counter_r;
    
    mem_resp_n = mem_resp_r;
    mem_data_resp_n = mem_data_resp_r;
    
    send_wormhole_packet_lo.reserved = '0;
    send_wormhole_packet_lo.src_x_cord = my_x_i;
    send_wormhole_packet_lo.src_y_cord = my_y_i;
    send_wormhole_packet_lo.x_cord = fifo_x_o;
    send_wormhole_packet_lo.y_cord = fifo_y_o;
    
    // Default state is mem_resp
    send_wormhole_packet_lo.write_en = 1'b1;
    send_wormhole_packet_lo.non_cacheable = mem_resp_r.non_cacheable;
    send_wormhole_packet_lo.data = mem_resp_r;
    send_wormhole_packet_lo.len = resp_ratio_lp-1;
    
    mem_resp_ready_o = 1'b0;
    mem_data_resp_ready_o = 1'b0;
    valid_o = 1'b0;
    
    fifo_yumi_i = 1'b0;
    
    if (send_state_r == SEND_RESET) 
      begin
        send_state_n = SEND_READY;
      end
    else if (send_state_r == SEND_READY) 
      begin
        mem_data_resp_ready_o = 1'b1;
        if (mem_data_resp_v_i)
          begin
            mem_data_resp_n = mem_data_resp;
            send_state_n = SEND_LOAD;
          end 
        else
          begin
            mem_resp_ready_o = 1'b1;
            if (mem_resp_v_i) 
              begin
                mem_resp_n = mem_resp;
                send_state_n = SEND_STORE;
              end
          end
      end
    else if (send_state_r == SEND_STORE & fifo_valid_o) 
      begin
        valid_o = 1'b1;
        if (ready_i)
          begin
            send_counter_n = send_counter_r + 1'b1;
            if (send_counter_r == resp_ratio_lp-1)
              begin
                fifo_yumi_i = 1'b1;
                send_counter_n = 1'b0;
                send_state_n = SEND_READY;
              end
          end
      end
    else if (send_state_r == SEND_LOAD & fifo_valid_o) 
      begin
        send_wormhole_packet_lo.write_en = 1'b0;
        send_wormhole_packet_lo.non_cacheable = mem_data_resp_r.non_cacheable;
        send_wormhole_packet_lo.data = (mem_data_resp_r.non_cacheable)? mem_data_resp_nc_r_cast[mem_cce_data_resp_width_lp-1:nc_offset_lp] : mem_data_resp_r_cast;
        send_wormhole_packet_lo.len = (mem_data_resp_r.non_cacheable)? data_resp_nc_ratio_lp-1 : data_resp_ratio_lp-1;
        valid_o = 1'b1;
        if (ready_i)
          begin
            send_counter_n = send_counter_r + 1'b1;
            if (send_counter_r==data_resp_ratio_lp-1 & ~mem_data_resp_r.non_cacheable
              | send_counter_r==data_resp_nc_ratio_lp-1 & mem_data_resp_r.non_cacheable) 
              begin
                fifo_yumi_i = 1'b1;
                send_counter_n = 1'b0;
                send_state_n = SEND_READY;
              end
          end
      end
    
  end
  
endmodule
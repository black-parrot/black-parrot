/**
 * bp_me_cce_to_wormhole_link_master.v
 */
 
`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_master

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
  )
  
  (input clk_i
  ,input reset_i

  // CCE-MEM Interface
  // CCE to Mem, Mem is demanding and uses vaild->ready (valid-yumi)
  ,input  logic [cce_mem_cmd_width_lp-1:0]       mem_cmd_i
  ,input  logic                                  mem_cmd_v_i
  ,output logic                                  mem_cmd_yumi_o
                                                 
  ,input  logic [cce_mem_data_cmd_width_lp-1:0]  mem_data_cmd_i
  ,input  logic                                  mem_data_cmd_v_i
  ,output logic                                  mem_data_cmd_yumi_o
                                                 
  // Mem to CCE, Mem is demanding and uses ready->valid
  ,output logic [mem_cce_resp_width_lp-1:0]      mem_resp_o
  ,output logic                                  mem_resp_v_o
  ,input  logic                                  mem_resp_ready_i
                                                 
  ,output logic [mem_cce_data_resp_width_lp-1:0] mem_data_resp_o
  ,output logic                                  mem_data_resp_v_o
  ,input  logic                                  mem_data_resp_ready_i
  
  // Configuration
  ,input [x_cord_width_p-1:0] my_x_i
  ,input [y_cord_width_p-1:0] my_y_i
  
  ,input [x_cord_width_p-1:0] mem_cmd_dest_x_i
  ,input [y_cord_width_p-1:0] mem_cmd_dest_y_i
  
  ,input [x_cord_width_p-1:0] mem_data_cmd_dest_x_i
  ,input [y_cord_width_p-1:0] mem_data_cmd_dest_y_i
  
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
  `declare_bp_mem_wormhole_packet_s(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, cce_mem_data_cmd_width_lp, bp_send_wormhole_packet_s);
  `declare_bp_mem_wormhole_packet_s(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, mem_cce_data_resp_width_lp, bp_receive_wormhole_packet_s);
  
  // Wormhole packet length
  localparam nc_offset_lp = cce_block_width_p-dword_width_p;
  
  localparam cmd_wormhole_packet_width_lp = `bp_mem_wormhole_packet_width(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, cce_mem_cmd_width_lp);
  localparam data_cmd_wormhole_packet_width_lp = `bp_mem_wormhole_packet_width(noc_reserved_width_p, x_cord_width_p, y_cord_width_p, noc_len_width_p, cce_mem_data_cmd_width_lp);
  localparam data_cmd_nc_wormhole_packet_width_lp = data_cmd_wormhole_packet_width_lp-nc_offset_lp;

  localparam cmd_ratio_lp = `BSG_CDIV(cmd_wormhole_packet_width_lp, noc_width_p);
  localparam data_cmd_ratio_lp = `BSG_CDIV(data_cmd_wormhole_packet_width_lp, noc_width_p);
  localparam data_cmd_nc_ratio_lp = `BSG_CDIV(data_cmd_nc_wormhole_packet_width_lp, noc_width_p);
  

  /********************** Sending Side ***********************/
  
  bp_cce_mem_cmd_s mem_cmd, mem_cmd_r, mem_cmd_n;
  bp_cce_mem_data_cmd_s mem_data_cmd, mem_data_cmd_r, mem_data_cmd_n;
  
  assign mem_cmd = mem_cmd_i;
  assign mem_data_cmd = mem_data_cmd_i;
  
  typedef enum logic [1:0] {
     SEND_RESET
    ,SEND_READY
    ,SEND_LOAD
    ,SEND_STORE
  } send_state_e;
  
  send_state_e send_state_r, send_state_n;
  logic [noc_len_width_p-1:0] send_counter_r, send_counter_n;
  
  logic [word_select_bits_lp-1:0] send_sel_lo;
  assign send_sel_lo = mem_data_cmd_r.addr[byte_offset_bits_lp+:word_select_bits_lp];
  
  bp_cce_mem_data_cmd_s mem_data_cmd_r_cast;
  assign mem_data_cmd_r_cast.msg_type = mem_data_cmd_r.msg_type;
  assign mem_data_cmd_r_cast.addr = mem_data_cmd_r.addr;
  assign mem_data_cmd_r_cast.payload = mem_data_cmd_r.payload;
  assign mem_data_cmd_r_cast.non_cacheable = mem_data_cmd_r.non_cacheable;
  assign mem_data_cmd_r_cast.nc_size = mem_data_cmd_r.nc_size;
  assign mem_data_cmd_r_cast.data = mem_data_cmd_r.data;
  
  bp_cce_mem_data_cmd_s mem_data_cmd_nc_r_cast;
  assign mem_data_cmd_nc_r_cast.msg_type = mem_data_cmd_r.msg_type;
  assign mem_data_cmd_nc_r_cast.addr = mem_data_cmd_r.addr;
  assign mem_data_cmd_nc_r_cast.payload = mem_data_cmd_r.payload;
  assign mem_data_cmd_nc_r_cast.non_cacheable = mem_data_cmd_r.non_cacheable;
  assign mem_data_cmd_nc_r_cast.nc_size = mem_data_cmd_r.nc_size;
  assign mem_data_cmd_nc_r_cast.data = {mem_data_cmd_r.data[(send_sel_lo*dword_width_p)+:dword_width_p], nc_offset_lp'(0)};
  
  bp_send_wormhole_packet_s send_wormhole_packet_lo;
  logic [data_cmd_ratio_lp*noc_width_p-1:0] send_wormhole_packet_lo_padded;
  
  assign send_wormhole_packet_lo_padded = {'0, send_wormhole_packet_lo};
  assign data_o = send_wormhole_packet_lo_padded[(send_counter_r*noc_width_p)+:noc_width_p];
  
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
    mem_cmd_r <= mem_cmd_n;
    mem_data_cmd_r <= mem_data_cmd_n;
  end
  
  always_comb 
  begin
  
    send_state_n = send_state_r;
    send_counter_n = send_counter_r;
    
    mem_cmd_n = mem_cmd_r;
    mem_data_cmd_n = mem_data_cmd_r;
    
    send_wormhole_packet_lo.reserved = '0;
    send_wormhole_packet_lo.src_x_cord = my_x_i;
    send_wormhole_packet_lo.src_y_cord = my_y_i;
    
    // Default state is mem_cmd
    send_wormhole_packet_lo.x_cord = mem_cmd_dest_x_i;
    send_wormhole_packet_lo.y_cord = mem_cmd_dest_y_i;
    send_wormhole_packet_lo.write_en = 1'b0;
    send_wormhole_packet_lo.non_cacheable = mem_cmd_r.non_cacheable;
    send_wormhole_packet_lo.data = mem_cmd_r;
    send_wormhole_packet_lo.len = cmd_ratio_lp-1;
    
    mem_cmd_yumi_o = 1'b0;
    mem_data_cmd_yumi_o = 1'b0;
    valid_o = 1'b0;
    
    if (send_state_r == SEND_RESET) 
      begin
        send_state_n = SEND_READY;
      end
    else if (send_state_r == SEND_READY) 
      begin
        if (mem_data_cmd_v_i) 
          begin
            mem_data_cmd_n = mem_data_cmd;
            mem_data_cmd_yumi_o = 1'b1;
            send_state_n = SEND_STORE;
          end 
        else if (mem_cmd_v_i) 
          begin
            mem_cmd_n = mem_cmd;
            mem_cmd_yumi_o = 1'b1;
            send_state_n = SEND_LOAD;
          end
      end
    else if (send_state_r == SEND_LOAD) 
      begin
        valid_o = 1'b1;
        if (ready_i) 
          begin
            send_counter_n = send_counter_r + 1'b1;
            if (send_counter_r == cmd_ratio_lp-1) 
              begin
                send_counter_n = 1'b0;
                send_state_n = SEND_READY;
              end
          end
      end
    else if (send_state_r == SEND_STORE) 
      begin
        send_wormhole_packet_lo.x_cord = mem_data_cmd_dest_x_i;
        send_wormhole_packet_lo.y_cord = mem_data_cmd_dest_y_i;
        send_wormhole_packet_lo.write_en = 1'b1;
        send_wormhole_packet_lo.non_cacheable = mem_data_cmd_r.non_cacheable;
        send_wormhole_packet_lo.data = (mem_data_cmd_r.non_cacheable)? mem_data_cmd_nc_r_cast[cce_mem_data_cmd_width_lp-1:nc_offset_lp] : mem_data_cmd_r_cast;
        send_wormhole_packet_lo.len = (mem_data_cmd_r.non_cacheable)? data_cmd_nc_ratio_lp-1 : data_cmd_ratio_lp-1;
        valid_o = 1'b1;
        if (ready_i)
          begin
            send_counter_n = send_counter_r + 1'b1;
            if (send_counter_r==data_cmd_ratio_lp-1 & ~mem_data_cmd_r.non_cacheable
              | send_counter_r==data_cmd_nc_ratio_lp-1 & mem_data_cmd_r.non_cacheable) 
              begin
                send_counter_n = 1'b0;
                send_state_n = SEND_READY;
              end
          end
      end
    
  end

  /********************** Receiving Side ***********************/
  
  bp_mem_cce_data_resp_s mem_data_resp;
  assign mem_data_resp_o = mem_data_resp;
  
  typedef enum logic [1:0] {
     RECEIVE_RESET
    ,RECEIVE_READY
    ,RECEIVE_RESP
  } receive_state_e;
  
  receive_state_e receive_state_r, receive_state_n;
  logic [noc_len_width_p-1:0] receive_counter_r, receive_counter_n;
  
  bp_receive_wormhole_packet_s receive_wormhole_packet_r, receive_wormhole_packet_n;
  
  assign mem_resp_o = mem_cce_resp_width_lp'(receive_wormhole_packet_r.data);
  
  bp_mem_cce_data_resp_s mem_data_resp_nc_cast;
  assign mem_data_resp_nc_cast = {receive_wormhole_packet_r.data, nc_offset_lp'(0)};
  
  always_comb
  begin
    if (receive_wormhole_packet_r.non_cacheable)
      begin
        mem_data_resp.msg_type = mem_data_resp_nc_cast.msg_type;
        mem_data_resp.addr = mem_data_resp_nc_cast.addr;
        mem_data_resp.payload = mem_data_resp_nc_cast.payload;
        mem_data_resp.non_cacheable = mem_data_resp_nc_cast.non_cacheable;
        mem_data_resp.nc_size = mem_data_resp_nc_cast.nc_size;
        mem_data_resp.data = {'0, mem_data_resp_nc_cast.data[nc_offset_lp+: dword_width_p]};
      end
    else
      begin
        mem_data_resp = receive_wormhole_packet_r.data;
      end
  end
  
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
    
    mem_resp_v_o = 1'b0;
    mem_data_resp_v_o = 1'b0;
    ready_o = 1'b0;
    
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
                receive_state_n = RECEIVE_RESP;
              end
          end
      end
    else if (receive_state_r == RECEIVE_RESP) 
      begin
        if (receive_wormhole_packet_r.write_en) 
          begin
            mem_resp_v_o = 1'b1;
            if (mem_resp_ready_i)
              begin
                receive_wormhole_packet_n = '0;
                receive_state_n = RECEIVE_READY;
              end
          end
        else
          begin
            mem_data_resp_v_o = 1'b1;
            if (mem_data_resp_ready_i)
              begin
                receive_wormhole_packet_n = '0;
                receive_state_n = RECEIVE_READY;
              end
          end
      end
 
  end

endmodule
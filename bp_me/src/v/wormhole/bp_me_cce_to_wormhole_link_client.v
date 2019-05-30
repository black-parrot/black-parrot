/**
 * bp_me_cce_to_wormhole_link_client.v
 */
 
`include "bsg_noc_links.vh"
`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_client

  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  
  #(parameter num_lce_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter block_size_in_bytes_p="inv"
    ,parameter lce_req_data_width_p="inv"
    
    // wormhole parameters
    ,parameter width_p = "inv"
    ,parameter x_cord_width_p = "inv"
    ,parameter y_cord_width_p = "inv"
    ,parameter len_width_p = "inv"
    ,parameter reserved_width_p = "inv"
    
    ,localparam block_size_in_bits_lp=block_size_in_bytes_p*8
    ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(width_p)
    
    ,localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)


    ,localparam word_select_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p/8)
    ,localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    ,localparam byte_width_lp=8
    ,localparam byte_offset_bits_lp=`BSG_SAFE_CLOG2(lce_req_data_width_p/8)
  )
  (
    input clk_i
    ,input reset_i

    // MEM -> CCE Interface
    ,output logic [bp_cce_mem_cmd_width_lp-1:0] mem_cmd_o
    ,output logic mem_cmd_v_o
    ,input logic mem_cmd_yumi_i

    ,output logic [bp_cce_mem_data_cmd_width_lp-1:0] mem_data_cmd_o
    ,output logic mem_data_cmd_v_o
    ,input logic mem_data_cmd_yumi_i

    // CCE -> MEM Interface
    ,input logic [bp_mem_cce_resp_width_lp-1:0] mem_resp_i
    ,input logic mem_resp_v_i
    ,output logic mem_resp_ready_o

    ,input logic [bp_mem_cce_data_resp_width_lp-1:0] mem_data_resp_i
    ,input logic mem_data_resp_v_i
    ,output logic mem_data_resp_ready_o
    
    // Configuration
    ,input [x_cord_width_p-1:0] my_x_i
    ,input [y_cord_width_p-1:0] my_y_i
    
    // bsg_noc_wormhole interface
    ,input [bsg_ready_and_link_sif_width_lp-1:0] link_i
    ,output [bsg_ready_and_link_sif_width_lp-1:0] link_o
  );
  
  
  // Interfacing bsg_noc links 

  logic valid_o, ready_i;
  logic [width_p-1:0] data_o;
  
  logic valid_i, ready_o;
  logic [width_p-1:0] data_i;
  
  `declare_bsg_ready_and_link_sif_s(width_p,bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s link_i_cast, link_o_cast;
    
  assign link_i_cast = link_i;
  assign link_o = link_o_cast;
    
  assign valid_i = link_i_cast.v;
  assign data_i = link_i_cast.data;
  assign link_o_cast.ready_and_rev = ready_o;
    
  assign link_o_cast.v = valid_o;
  assign link_o_cast.data = data_o;
  assign ready_i = link_i_cast.ready_and_rev;
  
  
  // BP mem wormhole packets
  
  `declare_bp_mem_wormhole_header_s(width_p, reserved_width_p, x_cord_width_p, y_cord_width_p, len_width_p, `bp_lce_cce_nc_req_size_width, paddr_width_p, bp_mem_wormhole_header_s);
  
  bp_mem_wormhole_header_s data_i_cast, data_o_cast;
  assign data_i_cast = data_i;
  
  
  // Registered data
  bp_mem_wormhole_header_s data_i_cast_r, data_i_cast_n;
  logic [block_size_in_bits_lp-1:0] data_i_r, data_i_n;
  logic [block_size_in_bits_lp-1:0] data_o_r, data_o_n;
  
  
  // CCE-MEM interface packets
  
  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);
  
  bp_cce_mem_cmd_s mem_cmd_r;
  bp_cce_mem_data_cmd_s mem_data_cmd_r;
  bp_mem_cce_resp_s mem_resp;
  bp_mem_cce_data_resp_s mem_data_resp;

  assign mem_cmd_o = mem_cmd_r;
  assign mem_data_cmd_o = mem_data_cmd_r;
  assign mem_resp = mem_resp_i;
  assign mem_data_resp = mem_data_resp_i;
  

  typedef enum logic [3:0] {
     RESET
    ,READY
    ,LOAD
    ,POST_LOAD
    ,PRE_STORE
    ,STORE
    ,POST_STORE
    ,PRE_LOAD_RESP
    ,LOAD_RESP
    ,STORE_ACK
  } mem_state_e;

  mem_state_e state_r, state_n;
  logic [3:0] counter_r, counter_n;
  
  
  // Select write word
  
  logic [word_select_bits_lp-1:0] write_word_sel_r, write_word_sel_n;
  
  
  // Select read word
  
  logic [word_select_bits_lp-1:0] read_word_sel_r, read_word_sel_n;
  assign data_o = (state_r == LOAD_RESP)? 
        data_o_r[(read_word_sel_r*lce_req_data_width_p)+:lce_req_data_width_p] : data_o_cast;
  
  
  always_ff @(posedge clk_i) begin
  
    if (reset_i) begin
        state_r <= RESET;
        counter_r <= 0;
        write_word_sel_r <= 0;
        read_word_sel_r <= 0;
        data_i_cast_r <= 0;
        data_i_r <= 0;
        data_o_r <= 0;
    end else begin
        state_r <= state_n;
        counter_r <= counter_n;
        write_word_sel_r <= write_word_sel_n;
        read_word_sel_r <= read_word_sel_n;
        data_i_cast_r <= data_i_cast_n;
        data_i_r <= data_i_n;
        data_o_r <= data_o_n;
    end

  end
  
  
  always_comb begin
  
    state_n = state_r;
    counter_n = counter_r;
    write_word_sel_n = write_word_sel_r;
    read_word_sel_n = read_word_sel_r;
    
    data_i_cast_n = data_i_cast_r;
    data_i_n = data_i_r;
    data_o_n = data_o_r;
    
    data_o_cast.reserved = data_i_cast_r.reserved;
    data_o_cast.x_cord = data_i_cast_r.src_x_cord;
    data_o_cast.y_cord = data_i_cast_r.src_y_cord;
    data_o_cast.dummy = data_i_cast_r.dummy;
    data_o_cast.src_x_cord = my_x_i;
    data_o_cast.src_y_cord = my_y_i;
    data_o_cast.write_en = data_i_cast_r.write_en;
    data_o_cast.non_cacheable = data_i_cast_r.non_cacheable;
    data_o_cast.nc_size = data_i_cast_r.nc_size;
    data_o_cast.addr = data_i_cast_r.addr;
    
    // Default state is store
    data_o_cast.len = 0;
    
    valid_o = 0;
    ready_o = 0;
    
    mem_cmd_v_o = 0;
    mem_data_cmd_v_o = 0;
    mem_resp_ready_o = 1;
    mem_data_resp_ready_o = 1;
    
    mem_cmd_r = 0;
    mem_cmd_r.non_cacheable = bp_lce_cce_req_non_cacheable_e'(data_i_cast_r.non_cacheable);
    mem_cmd_r.nc_size = bp_lce_cce_nc_req_size_e'(data_i_cast_r.nc_size);
    mem_cmd_r.addr = data_i_cast_r.addr;
    
    mem_data_cmd_r = 0;
    mem_data_cmd_r.non_cacheable = bp_lce_cce_req_non_cacheable_e'(data_i_cast_r.non_cacheable);
    mem_data_cmd_r.nc_size = bp_lce_cce_nc_req_size_e'(data_i_cast_r.nc_size);
    mem_data_cmd_r.addr = data_i_cast_r.addr;
    mem_data_cmd_r.data = data_i_r;
    
    if (state_r == RESET) begin

        state_n = READY;
        
    end
    
    else if (state_r == READY) begin
    
        ready_o = 1;
        if (valid_i) begin
            data_i_cast_n = data_i_cast;
            counter_n = (data_i_cast.non_cacheable)? 1 : 
                    (block_size_in_bits_lp/lce_req_data_width_p);
            write_word_sel_n = (data_i_cast.non_cacheable)? 
                    data_i_cast.addr[byte_offset_bits_lp+:word_select_bits_lp] : 0;
            read_word_sel_n = 0;
            state_n = (data_i_cast.write_en)? PRE_STORE : LOAD;
        end
    
    end
    
    else if (state_r == LOAD) begin
    
        mem_cmd_v_o = 1;
        if (mem_cmd_yumi_i) begin
            state_n = POST_LOAD;
        end
        
    end
    
    else if (state_r == POST_LOAD) begin
    
        if (mem_data_resp_v_i) begin
            data_o_n = mem_data_resp.data;
            state_n = PRE_LOAD_RESP;
        end
    
    end
    
    else if (state_r == PRE_STORE) begin
    
        ready_o = 1;
        if (valid_i) begin
            data_i_n[(write_word_sel_r*lce_req_data_width_p)+:lce_req_data_width_p] = data_i;
            counter_n = counter_r - 1;
            write_word_sel_n = write_word_sel_r + 1;
            if (counter_r == 1) begin
                state_n = STORE;
            end
        end
    
    end
    
    else if (state_r == STORE) begin
        
        mem_data_cmd_v_o = 1;
        if (mem_data_cmd_yumi_i) begin
            state_n = POST_STORE;
        end
    
    end
    
    else if (state_r == POST_STORE) begin
    
        if (mem_resp_v_i) begin
            state_n = STORE_ACK;
        end
    
    end
    
    else if (state_r == PRE_LOAD_RESP) begin
    
        data_o_cast.len = (data_i_cast_r.non_cacheable)? 1 : 
            (block_size_in_bits_lp/lce_req_data_width_p);
        valid_o = 1;
        if (ready_i) begin
            state_n = LOAD_RESP;
        end
    
    end
    
    else if (state_r == LOAD_RESP) begin
    
        valid_o = 1;
        if (ready_i) begin
            counter_n = counter_r - 1;
            read_word_sel_n = read_word_sel_r + 1;
            if (counter_r == 1) begin
                state_n = READY;
            end
        end
    
    end
    
    else if (state_r == STORE_ACK) begin
    
        valid_o = 1;
        if (ready_i) begin
            state_n = READY;
        end
    
    end
  
  end
  
endmodule
/**
 * bp_me_cce_to_wormhole_link.v
 */
 
`include "bsg_noc_links.vh"
`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link

  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  
  #(parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter block_size_in_bytes_p="inv"
    ,localparam block_size_in_bits_lp=block_size_in_bytes_p*8
    ,parameter lce_sets_p="inv"

    ,parameter lce_req_data_width_p="inv"
    
    // wormhole parameters
    ,parameter width_p = "inv"
    ,parameter x_cord_width_p = "inv"
    ,parameter y_cord_width_p = "inv"
    ,parameter len_width_p = "inv"
    ,parameter reserved_width_p = "inv"
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

    // CCE-MEM Interface
    // CCE to Mem, Mem is demanding and uses vaild->ready (valid-yumi)
    ,input logic [bp_cce_mem_cmd_width_lp-1:0] mem_cmd_i
    ,input logic mem_cmd_v_i
    ,output logic mem_cmd_yumi_o

    ,input logic [bp_cce_mem_data_cmd_width_lp-1:0] mem_data_cmd_i
    ,input logic mem_data_cmd_v_i
    ,output logic mem_data_cmd_yumi_o

    // Mem to CCE, Mem is demanding and uses ready->valid
    ,output logic [bp_mem_cce_resp_width_lp-1:0] mem_resp_o
    ,output logic mem_resp_v_o
    ,input logic mem_resp_ready_i

    ,output logic [bp_mem_cce_data_resp_width_lp-1:0] mem_data_resp_o
    ,output logic mem_data_resp_v_o
    ,input logic mem_data_resp_ready_i
    
    // Configuration
    ,input [x_cord_width_p-1:0] my_x_i
    ,input [y_cord_width_p-1:0] my_y_i
    
    ,input [x_cord_width_p-1:0] dest_x_i
    ,input [y_cord_width_p-1:0] dest_y_i
    
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
  
  
  // CCE-MEM interface packets
  
  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);
  
  logic [block_size_in_bits_lp-1:0] mem_data_cmd_data_r, mem_data_cmd_data_n;
  bp_cce_mem_cmd_s mem_cmd;
  bp_cce_mem_data_cmd_s mem_data_cmd;
  bp_mem_cce_resp_s mem_resp_r, mem_resp_n;
  bp_mem_cce_data_resp_s mem_data_resp_r, mem_data_resp_n;

  assign mem_cmd = mem_cmd_i;
  assign mem_data_cmd = mem_data_cmd_i;
  assign mem_resp_o = mem_resp_r;
  assign mem_data_resp_o = mem_data_resp_r;
  
  
  // BP mem wormhole packets
  
  `declare_bp_mem_wormhole_header_s(width_p, reserved_width_p, x_cord_width_p, y_cord_width_p, len_width_p, `bp_lce_cce_nc_req_size_width, paddr_width_p, bp_mem_wormhole_header_s);
  
  bp_mem_wormhole_header_s data_o_cast;
  

  typedef enum logic [2:0] {
     RESET
    ,READY
    ,PRE_LOAD
    ,LOAD
    ,STORE
    ,LOAD_RESP
    ,PRE_STORE_ACK
    ,STORE_ACK
  } mem_state_e;


  mem_state_e state_r, state_n;
  logic [3:0] counter_r, counter_n;
  
  
  // Select write word
  
  logic [word_select_bits_lp-1:0] write_word_sel_r, write_word_sel_n;
  assign data_o = (state_r == READY)? data_o_cast : 
        mem_data_cmd_data_r[(write_word_sel_r*lce_req_data_width_p)+:lce_req_data_width_p];
  
  
  // Select read word
  
  logic [word_select_bits_lp-1:0] read_word_sel_r, read_word_sel_n;
  
  
  always @(posedge clk_i) begin
  
    if (reset_i) begin
        state_r <= RESET;
        counter_r <= 0;
        write_word_sel_r <= 0;
        read_word_sel_r <= 0;
    end else begin
        state_r <= state_n;
        counter_r <= counter_n;
        write_word_sel_r <= write_word_sel_n;
        read_word_sel_r <= read_word_sel_n;
    end
    
    mem_data_cmd_data_r <= mem_data_cmd_data_n;
    mem_resp_r <= mem_resp_n;
    mem_data_resp_r <= mem_data_resp_n;
  
  end
  
  
  always_comb begin
  
    state_n = state_r;
    counter_n = counter_r;
    write_word_sel_n = write_word_sel_r;
    read_word_sel_n = read_word_sel_r;
    
    mem_data_cmd_data_n = mem_data_cmd_data_r;
    mem_resp_n = mem_resp_r;
    mem_data_resp_n = mem_data_resp_r;
    
    data_o_cast.reserved = 0;
    data_o_cast.x_cord = dest_x_i;
    data_o_cast.y_cord = dest_y_i;
    data_o_cast.dummy = 0;
    data_o_cast.src_x_cord = my_x_i;
    data_o_cast.src_y_cord = my_y_i;
    
    mem_cmd_yumi_o = 0;
    mem_data_cmd_yumi_o = 0;
    mem_resp_v_o = 0;
    mem_data_resp_v_o = 0;
    
    valid_o = 0;
    ready_o = 1;
    
    if (state_r == RESET) begin
    
        state_n = READY;
        
    end

    else if (state_r == READY) begin
    
        if (mem_data_cmd_v_i) begin
            
            data_o_cast.write_en = 1;
            data_o_cast.non_cacheable = mem_data_cmd.non_cacheable;
            data_o_cast.nc_size = mem_data_cmd.nc_size;
            data_o_cast.addr = mem_data_cmd.addr;
            data_o_cast.len = (mem_data_cmd.non_cacheable)? 1 : 
                    (block_size_in_bits_lp/lce_req_data_width_p);
            
            mem_data_cmd_data_n = mem_data_cmd.data;
            
            mem_resp_n.msg_type = mem_data_cmd.msg_type;
            mem_resp_n.addr = mem_data_cmd.addr;
            mem_resp_n.payload.lce_id = mem_data_cmd.payload.lce_id;
            mem_resp_n.payload.way_id = mem_data_cmd.payload.way_id;
            mem_resp_n.payload.req_addr = mem_data_cmd.payload.req_addr;
            mem_resp_n.payload.tr_lce_id = mem_data_cmd.payload.tr_lce_id;
            mem_resp_n.payload.tr_way_id = mem_data_cmd.payload.tr_way_id;
            mem_resp_n.payload.transfer = mem_data_cmd.payload.transfer;
            mem_resp_n.payload.replacement = mem_data_cmd.payload.replacement;
            mem_resp_n.non_cacheable = mem_data_cmd.non_cacheable;
            mem_resp_n.nc_size = mem_data_cmd.nc_size;
            
            counter_n = (mem_data_cmd.non_cacheable)? 1 : 
                    (block_size_in_bits_lp/lce_req_data_width_p);
            write_word_sel_n = (mem_data_cmd.non_cacheable)?
                mem_data_cmd.addr[byte_offset_bits_lp+:word_select_bits_lp] : 0;
            
            valid_o = 1;
            if (ready_i) begin
                mem_data_cmd_yumi_o = 1;
                state_n = STORE;
            end
            
        end else if (mem_cmd_v_i) begin
            
            data_o_cast.write_en = 0;
            data_o_cast.non_cacheable = mem_cmd.non_cacheable;
            data_o_cast.nc_size = mem_cmd.nc_size;
            data_o_cast.addr = mem_cmd.addr;
            data_o_cast.len = 0;
            
            mem_data_resp_n.msg_type = mem_cmd.msg_type;
            mem_data_resp_n.payload.lce_id = mem_cmd.payload.lce_id;
            mem_data_resp_n.payload.way_id = mem_cmd.payload.way_id;
            mem_data_resp_n.addr = mem_cmd.addr;
            mem_data_resp_n.data = 0;
            mem_data_resp_n.non_cacheable = mem_cmd.non_cacheable;
            mem_data_resp_n.nc_size = mem_cmd.nc_size;
            
            counter_n = (mem_cmd.non_cacheable)? 1 : 
                    (block_size_in_bits_lp/lce_req_data_width_p);
            read_word_sel_n = 0;
            
            valid_o = 1;
            if (ready_i) begin
                mem_cmd_yumi_o = 1;
                state_n = PRE_LOAD;
            end
            
        end
    
    end

    else if (state_r == PRE_LOAD) begin
    
        if (valid_i) begin
            state_n = LOAD;
        end
    
    end
    
    else if (state_r == LOAD) begin
    
        if (valid_i) begin
            mem_data_resp_n.data[(read_word_sel_r*lce_req_data_width_p)+:lce_req_data_width_p] 
                = data_i;
            counter_n = counter_r - 1;
            read_word_sel_n = read_word_sel_r + 1;
            if (counter_r == 1) begin
                state_n = LOAD_RESP;
            end
        end
    
    end
    
    else if (state_r == STORE) begin
        
        valid_o = 1;
        if (ready_i) begin
            counter_n = counter_r - 1;
            write_word_sel_n = write_word_sel_r + 1;
            if (counter_r == 1) begin
                state_n = PRE_STORE_ACK;
            end
        end
        
    end
    
    else if (state_r == LOAD_RESP) begin
    
        if (mem_data_resp_ready_i) begin
            mem_data_resp_v_o = 1;
            state_n = READY;
        end
    
    end
    
    else if (state_r == PRE_STORE_ACK) begin
    
        if (valid_i) begin
            state_n = STORE_ACK;
        end
    
    end
    
    else if (state_r == STORE_ACK) begin
    
        if (mem_resp_ready_i) begin
            mem_resp_v_o = 1;
            state_n = READY;
        end
    
    end
    
  
  end
  
endmodule


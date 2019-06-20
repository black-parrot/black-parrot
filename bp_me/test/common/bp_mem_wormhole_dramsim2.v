/**
 * bp_mem_wormhole_dramsim2.v
 */
 
`include "bsg_noc_links.vh"
`include "bp_mem_wormhole.vh"

module bp_mem_wormhole_dramsim2

  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  
  #(parameter mem_id_p="inv"
    ,parameter clock_period_in_ps_p="inv"
    ,parameter prog_name_p="inv"
    ,parameter dram_cfg_p="inv"
    ,parameter dram_sys_cfg_p="inv"
    ,parameter dram_capacity_p="inv"

    ,parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter block_size_in_bytes_p="inv"
    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8
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
  bp_mem_wormhole_header_s data_i_cast_r;
  logic [block_size_in_bits_lp-1:0] data_i_r;
  logic [block_size_in_bits_lp-1:0] data_o_r;


  // signals for dramsim2
  logic [511:0] dramsim_data;
  logic dramsim_valid;
  logic [511:0] dramsim_data_n;
  logic read_accepted, write_accepted;
  

  // Uncached access read and write selection
  logic [lce_req_data_width_p-1:0] mem_nc_data, nc_data;

  // get the 64-bit word for reads
  // address: [tag, set index, block offset] = [tag, word select, byte select]
  int word_select;
  assign word_select = data_i_cast_r.addr[byte_offset_bits_lp+:word_select_bits_lp];

  int byte_select;
  assign byte_select = data_i_cast_r.addr[0+:byte_offset_bits_lp];

  assign mem_nc_data = dramsim_data[(word_select*lce_req_data_width_p)+:lce_req_data_width_p];

  assign nc_data = (data_i_cast_r.nc_size == e_lce_nc_req_1)
    ? {56'('0),mem_nc_data[(byte_select*8)+:8]}
    : (data_i_cast_r.nc_size == e_lce_nc_req_2)
      ? {48'('0),mem_nc_data[(byte_select*8)+:16]}
      : (data_i_cast_r.nc_size == e_lce_nc_req_4)
        ? {32'('0),mem_nc_data[(byte_select*8)+:32]}
        : mem_nc_data;
        
        
  // memory signals
  logic [paddr_width_p-1:0] block_rd_addr, wr_addr;
  assign block_rd_addr = {data_i_cast_r.addr[paddr_width_p-1:block_offset_bits_lp], block_offset_bits_lp'(0)};
  // send full address on writes, let c++ code modify as needed based on cached or uncached
  assign wr_addr = data_i_cast_r.addr;
        

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

  mem_state_e state_r;
  logic [3:0] counter_r;
  logic [word_select_bits_lp-1:0] word_sel_r;
  
  
  assign data_o = (state_r == LOAD_RESP)? 
        data_o_r[(word_sel_r*lce_req_data_width_p)+:lce_req_data_width_p] : data_o_cast;
  
  assign valid_o = (state_r == PRE_LOAD_RESP) | (state_r == LOAD_RESP) | (state_r == STORE_ACK);
  assign ready_o = (state_r == READY) | (state_r == PRE_STORE);
    
  assign data_o_cast.reserved = data_i_cast_r.reserved;
  assign data_o_cast.x_cord = data_i_cast_r.src_x_cord;
  assign data_o_cast.y_cord = data_i_cast_r.src_y_cord;
  assign data_o_cast.dummy = data_i_cast_r.dummy;
  assign data_o_cast.src_x_cord = 0;
  assign data_o_cast.src_y_cord = 0;
  assign data_o_cast.write_en = data_i_cast_r.write_en;
  assign data_o_cast.non_cacheable = data_i_cast_r.non_cacheable;
  assign data_o_cast.nc_size = data_i_cast_r.nc_size;
  assign data_o_cast.addr = data_i_cast_r.addr;
  assign data_o_cast.len = (state_r == PRE_LOAD_RESP)
                            ? ((data_i_cast_r.non_cacheable)? 1 : (block_size_in_bits_lp/lce_req_data_width_p))
                            : '0;
  
  always_ff @(posedge clk_i) begin
    if(reset_i) begin
      state_r <= RESET;
      counter_r <= 0;
      word_sel_r <= 0;
      data_i_cast_r <= 0;
      data_i_r <= 0;
      data_o_r <= 0;
    end
    else begin
      read_accepted = '0;
      write_accepted = '0;
      if (state_r == RESET) begin
        state_r <= READY;
      end
      else if (state_r == READY) begin
        if (valid_i) begin
          data_i_cast_r <= data_i_cast;
          counter_r <= (data_i_cast.non_cacheable)? 1 : 
                  (block_size_in_bits_lp/lce_req_data_width_p);
          word_sel_r <= (data_i_cast.non_cacheable)? 
                  data_i_cast.addr[byte_offset_bits_lp+:word_select_bits_lp] : 0;
          state_r <= (data_i_cast.write_en)? PRE_STORE : LOAD;
        end
      end
      
      else if (state_r == LOAD) begin
        read_accepted = mem_read_req(block_rd_addr);
        state_r <= read_accepted ? POST_LOAD : LOAD;
      end
      
      else if (state_r == POST_LOAD) begin
        if (dramsim_valid) begin
          if (data_i_cast_r.non_cacheable) begin
            data_o_r <= {(block_size_in_bits_lp-lce_req_data_width_p)'('0),nc_data};
            word_sel_r <= 0;
          end else begin
            data_o_r <= dramsim_data;
          end 
          state_r <= PRE_LOAD_RESP;
        end
      end
      
      else if (state_r == PRE_STORE) begin
        if (valid_i) begin
          data_i_r[(word_sel_r*lce_req_data_width_p)+:lce_req_data_width_p] <= data_i;
          counter_r <= counter_r - 1;
          word_sel_r <= word_sel_r + 1;
          if (counter_r == 1) begin
            state_r <= STORE;
          end
        end
      end
      
      else if (state_r == STORE) begin
        // do the write to memory ram if available
        // uncached write, send correct size
        if (data_i_cast_r.non_cacheable) begin
          write_accepted =
            (data_i_cast_r.nc_size == e_lce_nc_req_1)
            ? mem_write_req(wr_addr, data_i_r, 1)
            : (data_i_cast_r.nc_size == e_lce_nc_req_2)
              ? mem_write_req(wr_addr, data_i_r, 2)
              : (data_i_cast_r.nc_size == e_lce_nc_req_4)
                ? mem_write_req(wr_addr, data_i_r, 4)
                : mem_write_req(wr_addr, data_i_r, 8);
        end else begin
          // cached access, size == 0 tells c++ code to write full cache block
          write_accepted = mem_write_req(wr_addr, data_i_r, 0);
        end
        state_r <= write_accepted ? POST_STORE : STORE;
      end
      
      else if (state_r == POST_STORE) begin
        if (dramsim_valid) begin
          state_r <= STORE_ACK;
        end
      end
      
      else if (state_r == PRE_LOAD_RESP) begin
        if (ready_i) begin
          state_r <= LOAD_RESP;
        end
      end
      
      else if (state_r == LOAD_RESP) begin
        if (ready_i) begin
          counter_r <= counter_r - 1;
          word_sel_r <= word_sel_r + 1;
          if (counter_r == 1) begin
            state_r <= READY;
          end
        end
      end
      
      else if (state_r == STORE_ACK) begin
        if (ready_i) begin
          state_r <= READY;
        end
      end
    end
  end
  

import "DPI-C" function void init(input longint clock_period
                                  , input string prog_name
                                  , input string dram_cfg_name
                                  , input string system_cfg_name
                                  , input longint dram_capacity
                                  , input longint dram_req_width
                                  , input longint block_offset_bits
                                  );
import "DPI-C" context function bit tick();

import "DPI-C" context function bit mem_read_req(input longint addr);
import "DPI-C" context function bit mem_write_req(input longint addr
                                                  , input bit [block_size_in_bits_lp-1:0] data
                                                  , input int reqSize = 0
                                                  );

export "DPI-C" function read_resp;
export "DPI-C" function write_resp;

function void read_resp(input bit [block_size_in_bits_lp-1:0] data);
  dramsim_data_n  = data;
endfunction

function void write_resp();

endfunction

initial 
  begin
    init(clock_period_in_ps_p, prog_name_p, dram_cfg_p, dram_sys_cfg_p, dram_capacity_p, block_size_in_bits_lp, block_offset_bits_lp);
  end

always_ff @(posedge clk_i)
  begin
    dramsim_valid <= tick(); 
    dramsim_data  <= dramsim_data_n;
  end

endmodule

/**
 *  Name:
 *    bp_me_cce_to_manycore_link_tx.v
 *
 *  Description:
 *    TX module in manycore bridge.
 */

`include "bsg_manycore_packet.vh"

module bp_me_cce_to_manycore_link_tx
  import bp_common_pkg::*;
  #(parameter link_data_width_p="inv"
    , parameter link_addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter paddr_width_p="inv"
    , parameter num_lce_p="inv"
    , parameter lce_assoc_p="inv"
    , parameter block_size_in_bits_p="inv"

    , localparam link_byte_offset_width_lp=`BSG_SAFE_CLOG2(link_data_width_p>>3)
    , localparam link_mask_width_lp=(link_data_width_p>>3)
    , localparam num_flits_lp=(block_size_in_bits_p/link_data_width_p)
    , localparam tx_counter_width_lp=`BSG_SAFE_CLOG2(num_flits_lp+1)
    , localparam lg_num_flits_lp=`BSG_SAFE_CLOG2(num_flits_lp)

    , localparam x_cord_offset_lp = (link_byte_offset_width_lp+link_addr_width_p)
    , localparam y_cord_offset_lp = (x_cord_offset_lp+x_cord_width_p)

    , localparam bp_cce_mem_data_cmd_width_lp=
      `bp_cce_mem_data_cmd_width(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
    , localparam bp_cce_mem_msg_width_lp=
      `bp_mem_cce_resp_width(paddr_width_p,num_lce_p,lce_assoc_p)

    , localparam packet_width_lp=
      `bsg_manycore_packet_width(link_addr_width_p,link_data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    // cce side
    , input [bp_cce_mem_data_cmd_width_lp-1:0] mem_data_cmd_i
    , input mem_data_cmd_v_i
    , output logic mem_data_cmd_yumi_o

    , output logic [bp_cce_mem_msg_width_lp-1:0] mem_resp_o
    , output logic mem_resp_v_o
    , input mem_resp_ready_i

    // manycore side
    , output logic [packet_width_lp-1:0] tx_pkt_o
    , output logic tx_pkt_v_o
    , input tx_pkt_yumi_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // manycore_packet struct
  //
  `declare_bsg_manycore_packet_s(link_addr_width_p,link_data_width_p,
    x_cord_width_p,y_cord_width_p,load_id_width_p);
  
  bsg_manycore_packet_s tx_pkt;
  assign tx_pkt_o = tx_pkt;

  // black-parrot mem interface
  //
  `declare_bp_me_if(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p);

  bp_cce_mem_data_cmd_s mem_data_cmd;
  bp_mem_cce_resp_s mem_resp;

  assign mem_data_cmd = mem_data_cmd_i;
  assign mem_resp_o = mem_resp;

  // mem_data_cmd
  //
  typedef enum logic [1:0] {
    WAIT_DATA_CMD
    ,SEND_WRITE_BLOCK
    ,SEND_UNCACHED
    ,SEND_RESP
  } tx_state_e;

  tx_state_e tx_state_r, tx_state_n;
  bp_cce_mem_data_cmd_s mem_data_cmd_r, mem_data_cmd_n;
  logic [lg_num_flits_lp-1:0] count_r, count_n;


  // mux
  //
  logic [link_data_width_p-1:0] mux_data_lo;
  logic [lg_num_flits_lp-1:0] mux_sel;

  bsg_mux #(
    .width_p(link_data_width_p)  
    ,.els_p(num_flits_lp)
  ) data_mux (
    .data_i(mem_data_cmd_r.data)
    ,.sel_i(mux_sel)
    ,.data_o(mux_data_lo)
  );

  // uncached mask
  //
  logic [link_mask_width_lp-1:0] uncached_mask;
  logic [link_data_width_p-1:0] uncached_data;

  if (link_data_width_p == 32) begin
    always_comb begin
      uncached_mask = (mem_data_cmd_r.nc_size == e_lce_nc_req_1)
        ? {( mem_data_cmd_r.addr[1] &  mem_data_cmd_r.addr[0]),
           ( mem_data_cmd_r.addr[1] & ~mem_data_cmd_r.addr[0]),
           (~mem_data_cmd_r.addr[1] &  mem_data_cmd_r.addr[0]),
           (~mem_data_cmd_r.addr[1] & ~mem_data_cmd_r.addr[0])}
        : ((mem_data_cmd_r.nc_size == e_lce_nc_req_2)
          ? {{2{mem_data_cmd_r.addr[1]}}, {2{~mem_data_cmd_r.addr[1]}}}
          : 4'b1111);

      uncached_data = (mem_data_cmd_r.nc_size == e_lce_nc_req_1)
        ? {4{mux_data_lo[7:0]}}
        : ((mem_data_cmd_r.nc_size == e_lce_nc_req_2)
          ? {2{mux_data_lo[15:0]}}
          : mux_data_lo);
    end
  end

  always_comb begin

    tx_state_n = tx_state_r;
    count_n = count_r;
    mux_sel = '0;

    mem_data_cmd_yumi_o = 1'b0;
    mem_data_cmd_n = mem_data_cmd_r;
    
    mem_resp.msg_type = mem_data_cmd_r.msg_type;
    mem_resp.addr = mem_data_cmd_r.addr;
    mem_resp.payload = mem_data_cmd_r.payload;
    mem_resp.non_cacheable = mem_data_cmd_r.non_cacheable;
    mem_resp.nc_size = mem_data_cmd_r.nc_size;
    mem_resp_v_o = 1'b0;
    
    tx_pkt_v_o = 1'b0;
    tx_pkt.op = `ePacketOp_remote_store;
    tx_pkt.op_ex = {link_mask_width_lp{1'b1}};
    tx_pkt.payload = mux_data_lo;
    tx_pkt.src_y_cord = my_y_i;
    tx_pkt.src_x_cord = my_x_i;
    tx_pkt.y_cord = '0;
    tx_pkt.x_cord = '0;

    case (tx_state_r)

      WAIT_DATA_CMD: begin
        if (mem_data_cmd_v_i) begin
          mem_data_cmd_yumi_o = 1'b1;
          mem_data_cmd_n = mem_data_cmd;
          count_n = '0;
          tx_state_n = mem_data_cmd.non_cacheable
            ? SEND_UNCACHED
            : SEND_WRITE_BLOCK;
        end
      end

      SEND_WRITE_BLOCK: begin
        tx_pkt_v_o = 1'b1;
        tx_pkt.y_cord = mem_data_cmd_r.addr[y_cord_offset_lp+:y_cord_width_p];
        tx_pkt.x_cord = mem_data_cmd_r.addr[x_cord_offset_lp+:x_cord_width_p];
        tx_pkt.addr = {
          mem_data_cmd_r.addr[link_byte_offset_width_lp+lg_num_flits_lp+:link_addr_width_p-lg_num_flits_lp],
          count_r
        };

        tx_pkt.op_ex = {link_mask_width_lp{1'b1}};
        tx_pkt.payload = mux_data_lo;
        
        mux_sel = count_r;
        
        count_n = tx_pkt_yumi_i
          ? count_r + 1
          : count_r;

        tx_state_n = tx_pkt_yumi_i & (count_r == num_flits_lp-1)
          ? SEND_RESP
          : SEND_WRITE_BLOCK;
      end
      
      SEND_UNCACHED: begin
        tx_pkt_v_o = 1'b1;
        tx_pkt.y_cord = mem_data_cmd_r.addr[y_cord_offset_lp+:y_cord_width_p];
        tx_pkt.x_cord = mem_data_cmd_r.addr[x_cord_offset_lp+:x_cord_width_p];
        tx_pkt.addr = (mem_data_cmd_r.nc_size == e_lce_nc_req_8)
          ? {mem_data_cmd_r.addr[link_byte_offset_width_lp+1+:link_addr_width_p-1], count_r[0]}
          : mem_data_cmd_r.addr[link_byte_offset_width_lp+:link_addr_width_p];
    
        tx_pkt.op_ex = uncached_mask;
        tx_pkt.payload = uncached_data;

        mux_sel = count_r;
       
        count_n = tx_pkt_yumi_i
          ? count_r + 1
          : count_r;

        tx_state_n = (mem_data_cmd_r.nc_size == e_lce_nc_req_8) 
          ? ((tx_pkt_yumi_i & (count_r == 1))
            ? SEND_RESP
            : SEND_UNCACHED)
          : (tx_pkt_yumi_i
            ? SEND_RESP
            : SEND_UNCACHED);

      end

      SEND_RESP: begin
        mem_resp_v_o = 1'b1;
        tx_state_n = mem_resp_ready_i
          ? WAIT_DATA_CMD
          : SEND_RESP;

      end

      // should never happen
      default: begin
        tx_state_n = WAIT_DATA_CMD;
      end
    endcase
  end


  // sequential
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      tx_state_r <= WAIT_DATA_CMD;
    end
    else begin
      tx_state_r <= tx_state_n;
      count_r <= count_n;
      mem_data_cmd_r <= mem_data_cmd_n;
    end
  end

endmodule

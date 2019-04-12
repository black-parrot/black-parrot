/**
 *  Name:
 *    bp_me_cce_to_manycore_link_rx.v
 *
 *  Description:
 *    RX module in manycore bridge.
 */

`include "bsg_manycore_packet.vh"

module bp_me_cce_to_manycore_link_rx
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
    , localparam lg_num_flits_lp=`BSG_SAFE_CLOG2(num_flits_lp)

    , localparam x_cord_offset_lp = (link_byte_offset_width_lp+link_addr_width_p)
    , localparam y_cord_offset_lp = (x_cord_offset_lp+x_cord_width_p)

    , localparam packet_width_lp=
      `bsg_manycore_packet_width(link_addr_width_p,link_data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)

    , localparam mem_cmd_width_lp=
      `bp_cce_mem_cmd_width(paddr_width_p,num_lce_p,lce_assoc_p)

    , localparam mem_data_resp_width_lp=
      `bp_mem_cce_data_resp_width(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
  )
  (
    input clk_i
    , input reset_i

    // cce side
    , input [mem_cmd_width_lp-1:0] mem_cmd_i
    , input mem_cmd_v_i
    , output logic mem_cmd_yumi_o
    
    , output logic [mem_data_resp_width_lp-1:0] mem_data_resp_o
    , output logic mem_data_resp_v_o
    , input  mem_data_resp_ready_i

    // manycore side
    , output logic [packet_width_lp-1:0] rx_pkt_o
    , output logic rx_pkt_v_o
    , input rx_pkt_yumi_i

    , input [link_data_width_p-1:0] returned_data_i
    , output logic returned_yumi_o
    , input returned_v_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );

  // manycore_packet struct
  //
  `declare_bsg_manycore_packet_s(link_addr_width_p,link_data_width_p,
    x_cord_width_p,y_cord_width_p,load_id_width_p);
  
  bsg_manycore_packet_s rx_pkt;

  assign rx_pkt_o = rx_pkt;

  // bp_mem struct
  //
  `declare_bp_me_if(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p);
  
  bp_cce_mem_cmd_s mem_cmd;
  bp_mem_cce_data_resp_s mem_data_resp;

  assign mem_cmd = mem_cmd_i;
  assign mem_data_resp_o = mem_data_resp;


  // sipo
  //
  logic sipo_ready_lo;
  logic [$clog2(num_flits_lp+1)-1:0] sipo_yumi_cnt_li;
  logic [num_flits_lp-1:0][link_data_width_p-1:0] sipo_data_lo;
  logic [num_flits_lp-1:0] sipo_valid_lo;

  bsg_serial_in_parallel_out #(
    .width_p(link_data_width_p)
    ,.els_p(num_flits_lp)
  ) sipo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.valid_i(returned_v_i)
    ,.data_i(returned_data_i)
    ,.ready_o(sipo_ready_lo)

    ,.valid_o(sipo_valid_lo)
    ,.data_o(sipo_data_lo)
    ,.yumi_cnt_i(sipo_yumi_cnt_li)
  );
  
  assign returned_yumi_o = returned_v_i & sipo_ready_lo;


  // FSM logic
  //
  typedef enum logic [2:0] {
    WAIT_CMD
    ,SEND_READ_BLOCK
    ,WAIT_READ_BLOCK
    ,SEND_UNCACHED
    ,WAIT_UNCACHED
  } rx_state_e;

  rx_state_e rx_state_r, rx_state_n;
  bp_cce_mem_cmd_s mem_cmd_r, mem_cmd_n;
  logic [lg_num_flits_lp-1:0] count_r, count_n;

 
  always_comb begin
    
    rx_state_n = rx_state_r;
    mem_cmd_n = mem_cmd_r;
    count_n = count_r;

    sipo_yumi_cnt_li = '0;

    mem_cmd_yumi_o = 1'b0;

    mem_data_resp.msg_type = mem_cmd_r.msg_type;
    mem_data_resp.addr = mem_cmd_r.addr;
    mem_data_resp.payload = mem_cmd_r.payload;
    mem_data_resp.non_cacheable = mem_cmd_r.non_cacheable;
    mem_data_resp.nc_size = mem_cmd_r.nc_size;
    mem_data_resp.data = sipo_data_lo;
    mem_data_resp_v_o = 1'b0;

    rx_pkt_v_o = 1'b0;
    rx_pkt.op = `ePacketOp_remote_load;
    rx_pkt.op_ex = {link_mask_width_lp{1'b1}};
    rx_pkt.payload = '0;
    rx_pkt.src_y_cord = my_y_i;
    rx_pkt.src_x_cord = my_x_i;
    rx_pkt.y_cord = '0;
    rx_pkt.x_cord = '0;
    
    case (rx_state_r)
      WAIT_CMD: begin
        if (mem_cmd_v_i) begin
          mem_cmd_yumi_o = 1'b1;
          mem_cmd_n = mem_cmd;
          count_n = '0;
          rx_state_n = mem_cmd.non_cacheable
            ? SEND_UNCACHED
            : SEND_READ_BLOCK;
        end
      end
    
      SEND_READ_BLOCK: begin
        rx_pkt_v_o = 1'b1;
        rx_pkt.y_cord = mem_cmd_r.addr[y_cord_offset_lp+:y_cord_width_p];
        rx_pkt.x_cord = mem_cmd_r.addr[x_cord_offset_lp+:x_cord_width_p];
        rx_pkt.addr = {
          mem_cmd_r.addr[link_byte_offset_width_lp+lg_num_flits_lp+:link_addr_width_p-lg_num_flits_lp],
          count_r
        };
        
        count_n = rx_pkt_yumi_i
          ? count_r + 1
          : count_r;
        rx_state_n = rx_pkt_yumi_i & (count_r == num_flits_lp-1)
          ? WAIT_READ_BLOCK
          : SEND_READ_BLOCK;
      end
    
      WAIT_READ_BLOCK: begin
        mem_data_resp.data = sipo_data_lo; 
        mem_data_resp_v_o = &sipo_valid_lo;
        sipo_yumi_cnt_li = (&sipo_valid_lo) & mem_data_resp_ready_i
          ? ($clog2(num_flits_lp+1))'(num_flits_lp)
          : '0;
        rx_state_n = (&sipo_valid_lo) & mem_data_resp_ready_i
          ? WAIT_CMD
          : WAIT_READ_BLOCK;
      end

      SEND_UNCACHED: begin
        rx_pkt_v_o = 1'b1;
        rx_pkt.y_cord = mem_cmd_r.addr[y_cord_offset_lp+:y_cord_width_p];
        rx_pkt.x_cord = mem_cmd_r.addr[x_cord_offset_lp+:x_cord_width_p];
        rx_pkt.addr = (mem_cmd_r.nc_size == e_lce_nc_req_8)
          ? {mem_cmd_r.addr[link_byte_offset_width_lp+1+:link_addr_width_p-1], count_r[0]}
          : mem_cmd_r.addr[link_byte_offset_width_lp+:link_addr_width_p];
       
        count_n = rx_pkt_yumi_i
          ? count_r + 1
          : count_r;

        rx_state_n = (mem_cmd_r.nc_size == e_lce_nc_req_8) 
          ? ((rx_pkt_yumi_i & (count_r == 1))
            ? WAIT_UNCACHED
            : SEND_UNCACHED)
          : (rx_pkt_yumi_i
            ? WAIT_UNCACHED
            : SEND_UNCACHED);
      end

      WAIT_UNCACHED: begin
        mem_data_resp.data[block_size_in_bits_p-1:(2*link_data_width_p)] = '0;
        if (mem_cmd_r.nc_size == e_lce_nc_req_8) begin
          mem_data_resp.data[0+:(2*link_data_width_p)] = sipo_data_lo[1:0];
          mem_data_resp_v_o = (&sipo_valid_lo[1:0]);
          sipo_yumi_cnt_li = (&sipo_valid_lo[1:0]) & mem_data_resp_ready_i
            ? ($clog2(num_flits_lp+1))'(2)
            : '0;
          rx_state_n = (&sipo_valid_lo[1:0]) & mem_data_resp_ready_i
            ? WAIT_CMD
            : WAIT_UNCACHED;
        end
        else begin
          mem_data_resp.data[0+:(2*link_data_width_p)] = {2{sipo_data_lo[0]}};
          mem_data_resp_v_o = sipo_valid_lo[0];
          sipo_yumi_cnt_li = sipo_valid_lo[0] & mem_data_resp_ready_i
            ? ($clog2(num_flits_lp+1))'(1)
            : '0;
          rx_state_n = sipo_valid_lo[0] & mem_data_resp_ready_i
            ? WAIT_CMD
            : WAIT_UNCACHED;
        end
      end

      // should never happen.
      default: begin
        rx_state_n = WAIT_CMD;
      end

    endcase
  end


  // sequential logic
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      rx_state_r <= WAIT_CMD;
    end
    else begin
      rx_state_r <= rx_state_n;
      count_r <= count_n;
      mem_cmd_r <= mem_cmd_n;
    end
  end

endmodule 

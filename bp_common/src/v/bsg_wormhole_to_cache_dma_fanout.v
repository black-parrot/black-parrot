/**
 *    bsg_wormhole_to_cache_dma.v
 *
 *    This module converts a bsg_cache_dma wormhole link to an array of bsg_cache_dma interfaces.
 *    It can then be connected to other endpoints such as bsg_cache_to_axi or bsg_cache_to_test_dram.
 *
 *    Caution: large fanouts may struggle with timing
 */


`include "bsg_noc_links.vh"


module bsg_wormhole_to_cache_dma_fanout
  import bsg_cache_pkg::*;
  #(parameter num_dma_p="inv"
    , parameter dma_addr_width_p="inv" // cache addr width (in bytes)
    , parameter dma_burst_len_p="inv" // num of data beats in dma transfer

    // flit width must match the cache dma width.
    , parameter wh_flit_width_p="inv"
    , parameter wh_cid_width_p="inv"
    , parameter wh_len_width_p="inv"
    , parameter wh_cord_width_p="inv"

    // FIFO parameters
    , parameter lg_num_dma_lp=`BSG_SAFE_CLOG2(num_dma_p)
    , parameter count_width_lp=`BSG_SAFE_CLOG2(dma_burst_len_p)

    , parameter wh_ready_and_link_sif_width_lp=`bsg_ready_and_link_sif_width(wh_flit_width_p)
    , parameter wh_then_ready_link_sif_width_lp=`bsg_then_ready_link_sif_width(wh_flit_width_p)
    , parameter dma_pkt_width_lp=`bsg_cache_dma_pkt_width(dma_addr_width_p)
    , parameter dma_data_width_p=wh_flit_width_p
  )
  (
    input clk_i
    , input reset_i


    // Incoming wormhole link is valid->ready, while outgoing is standard ready-valid-and
    // While one can functionally connect a valid->ready consumer to a ready-valid-and producer,
    //   it may be desirable for timing or congestion to buffer input flits
    , input [wh_ready_and_link_sif_width_lp-1:0] wh_link_sif_i
    , input [lg_num_dma_lp-1:0] wh_dma_id_i
    , output logic [wh_then_ready_link_sif_width_lp-1:0] wh_link_sif_o

    // cache DMA
    , output logic [num_dma_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
    , output logic [num_dma_p-1:0] dma_pkt_v_o
    , input [num_dma_p-1:0] dma_pkt_yumi_i

    , input [num_dma_p-1:0][dma_data_width_p-1:0] dma_data_i
    , input [num_dma_p-1:0] dma_data_v_i
    , output logic [num_dma_p-1:0] dma_data_ready_and_o

    , output logic [num_dma_p-1:0][dma_data_width_p-1:0] dma_data_o
    , output logic [num_dma_p-1:0] dma_data_v_o
    , input [num_dma_p-1:0] dma_data_yumi_i
  );


  // structs
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p,wh_ready_and_link_sif_s);
  `declare_bsg_then_ready_link_sif_s(wh_flit_width_p,wh_then_ready_link_sif_s);
  `declare_bsg_cache_dma_pkt_s(dma_addr_width_p);
  `declare_bsg_cache_wh_header_flit_s(wh_flit_width_p,wh_cord_width_p,wh_len_width_p,wh_cid_width_p);


  // cast wormhole links
  wh_ready_and_link_sif_s wh_link_sif_in;
  wh_then_ready_link_sif_s wh_link_sif_out;
  assign wh_link_sif_in = wh_link_sif_i;
  assign wh_link_sif_o = wh_link_sif_out;

  // DMA pkt going out
  bsg_cache_dma_pkt_s dma_pkt_out;
  assign dma_pkt_o = {num_dma_p{dma_pkt_out}};

  // header flits coming in and going out
  bsg_cache_wh_header_flit_s header_flit_in, header_flit_out;
  assign header_flit_in = wh_link_sif_in.data;

  // cid, src_cord table
  logic [num_dma_p-1:0][wh_cid_width_p-1:0] src_cid_r;
  logic [num_dma_p-1:0][wh_cord_width_p-1:0] src_cord_r;
  logic [wh_cid_width_p-1:0] src_cid_n;
  logic [wh_cord_width_p-1:0] src_cord_n;
  logic [lg_num_dma_lp-1:0] table_w_addr;
  logic table_we;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      src_cid_r <= '0;
      src_cord_r <= '0;
    end
    else begin
      if (table_we) begin
        src_cid_r[table_w_addr] <= src_cid_n;
        src_cord_r[table_w_addr] <= src_cord_n;
      end
    end
  end



  // send FSM
  // receives wh packets and cache dma pkts.
  typedef enum logic [1:0] {
    SEND_RESET,
    SEND_READY,
    SEND_DMA_PKT,
    SEND_EVICT_DATA
  } send_state_e;

  send_state_e send_state_r, send_state_n;
  logic write_not_read_r, write_not_read_n;
  logic [lg_num_dma_lp-1:0] send_cache_id_r, send_cache_id_n;

  logic send_clear_li;
  logic send_up_li;
  logic [count_width_lp-1:0] send_count_lo;
  bsg_counter_clear_up #(
    .max_val_p(dma_burst_len_p-1)
    ,.init_val_p(0)
  ) send_count (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(send_clear_li)
    ,.up_i(send_up_li)
    ,.count_o(send_count_lo)
  );

  always_comb begin
    send_state_n = send_state_r;
    write_not_read_n = write_not_read_r;
    send_cache_id_n = send_cache_id_r;
    table_we = 1'b0;
    table_w_addr = '0;
    src_cord_n = '0;
    src_cid_n = '0;

    wh_link_sif_out.then_ready_rev = 1'b0;

    send_clear_li = 1'b0;
    send_up_li = 1'b0;
    dma_pkt_v_o = '0;
    dma_pkt_out = '0;

    dma_data_v_o = '0;
    dma_data_o = '0;

    case (send_state_r)
      // coming out of reset
      SEND_RESET: begin
        send_state_n = SEND_READY;
      end

      // wait for a header flit.
      // store the write_not_read, src_cord.
      // save the cid in a table.
      SEND_READY: begin
        if (wh_link_sif_in.v) begin
          wh_link_sif_out.then_ready_rev = 1'b1;
          write_not_read_n = header_flit_in.write_not_read;
          src_cord_n = header_flit_in.src_cord;
          src_cid_n = header_flit_in.src_cid;
          table_w_addr = wh_dma_id_i;
          table_we = 1'b1;
          send_cache_id_n = wh_dma_id_i;
          send_state_n = SEND_DMA_PKT;
        end
      end

      // take the addr flit and send out the dma pkt.
      // For read, return to SEND_READY.
      // For write, move to SEND_EVICT_DATA to pass the evict data.
      SEND_DMA_PKT: begin
        dma_pkt_v_o[send_cache_id_r] = wh_link_sif_in.v;
        dma_pkt_out.write_not_read = write_not_read_r;
        dma_pkt_out.addr = dma_addr_width_p'(wh_link_sif_in.data);

        wh_link_sif_out.then_ready_rev = dma_pkt_yumi_i[send_cache_id_r];
        send_state_n = wh_link_sif_out.then_ready_rev
          ? (write_not_read_r ? SEND_EVICT_DATA : SEND_READY)
          : SEND_DMA_PKT;
      end

      // once all evict data has been passed along return to SEND_READY
      SEND_EVICT_DATA: begin
        dma_data_v_o[send_cache_id_r] = wh_link_sif_in.v;
        dma_data_o[send_cache_id_r] = wh_link_sif_in.data;
        if (dma_data_yumi_i[send_cache_id_r]) begin
          wh_link_sif_out.then_ready_rev = 1'b1;
          send_up_li = send_count_lo != dma_burst_len_p-1;
          send_clear_li = send_count_lo == dma_burst_len_p-1;
          send_state_n = send_clear_li
            ? SEND_READY
            : SEND_EVICT_DATA;
        end
      end

    endcase

  end



  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      send_state_r <= SEND_RESET;
      write_not_read_r <= 1'b0;
      send_cache_id_r <= '0;
    end
    else begin
      send_state_r <= send_state_n;
      write_not_read_r <= write_not_read_n;
      send_cache_id_r <= send_cache_id_n;
    end
  end



  // receiver FSM
  // receives dma_data_i and send them to the vcaches using wh link.
  typedef enum logic [1:0] {
    RECV_RESET,
    RECV_READY,
    RECV_HEADER,
    RECV_FILL_DATA
  } recv_state_e;

  recv_state_e recv_state_r, recv_state_n;
  logic [lg_num_dma_lp-1:0] recv_cache_id_r, recv_cache_id_n;


  logic rr_v_lo;
  logic rr_yumi_li;
  logic [lg_num_dma_lp-1:0] rr_addr_lo;
  logic [num_dma_p-1:0] rr_grants_lo;
  bsg_arb_round_robin #(
    .width_p(num_dma_p)
  ) rr0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.reqs_i(dma_data_v_i)
    ,.grants_o(rr_grants_lo)
    ,.yumi_i(rr_yumi_li)
  );
  assign rr_v_lo = |dma_data_v_i;
  bsg_encode_one_hot #(
    .width_p(num_dma_p)
  ) eoh (
    .i(rr_grants_lo)
    ,.addr_o(rr_addr_lo)
    ,.v_o()
  );


  logic recv_clear_li;
  logic recv_up_li;
  logic [count_width_lp-1:0] recv_count_lo;
  bsg_counter_clear_up #(
    .max_val_p(dma_burst_len_p-1)
    ,.init_val_p(0)
  ) recv_count (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(recv_clear_li)
    ,.up_i(recv_up_li)
    ,.count_o(recv_count_lo)
  );




  always_comb begin

    wh_link_sif_out.v = 1'b0;
    wh_link_sif_out.data = '0;

    rr_yumi_li = 1'b0;

    recv_state_n = recv_state_r;
    recv_cache_id_n = recv_cache_id_r;

    recv_clear_li = 1'b0;
    recv_up_li = 1'b0;

    header_flit_out.unused = '0;
    header_flit_out.write_not_read = 1'b0; // doesn't matter
    header_flit_out.src_cord = '0; // doesn't matter
    header_flit_out.src_cid = '0; // doesn't matter
    header_flit_out.len = dma_burst_len_p;
    header_flit_out.cord = src_cord_r[recv_cache_id_r];
    header_flit_out.cid = src_cid_r[recv_cache_id_r];

    dma_data_ready_and_o = '0;

    case (recv_state_r)

      // coming out of reset
      RECV_RESET: begin
        recv_state_n = RECV_READY;
      end

      // wait for one of dma_data_v_i to be 1.
      // save the cache id.
      RECV_READY: begin
        if (rr_v_lo) begin
          rr_yumi_li = 1'b1;
          recv_cache_id_n = rr_addr_lo;
          recv_state_n = RECV_HEADER;
        end
      end

      // send out header to dest vcache
      RECV_HEADER: begin
        wh_link_sif_out.v = 1'b1;
        wh_link_sif_out.data = header_flit_out;
        if (wh_link_sif_in.ready_and_rev) begin
          recv_state_n = RECV_FILL_DATA;
        end
      end

      // send the data flits to the vcache.
      // once it's done, go back to RECV_READY.
      RECV_FILL_DATA: begin
        wh_link_sif_out.v = dma_data_v_i[recv_cache_id_r];
        wh_link_sif_out.data = dma_data_i[recv_cache_id_r];
        dma_data_ready_and_o[recv_cache_id_r] = wh_link_sif_in.ready_and_rev;
        if (dma_data_ready_and_o[recv_cache_id_r] & dma_data_v_i[recv_cache_id_r]) begin
          recv_clear_li = (recv_count_lo == dma_burst_len_p-1);
          recv_up_li = (recv_count_lo != dma_burst_len_p-1);
          recv_state_n = recv_clear_li
            ? RECV_READY
            : RECV_FILL_DATA;
        end
      end

    endcase
  end


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      recv_state_r <= RECV_RESET;
      recv_cache_id_r <= '0;
    end
    else begin
      recv_state_r <= recv_state_n;
      recv_cache_id_r <= recv_cache_id_n;
    end
  end

  //synopsys translate_off
  if (wh_flit_width_p != dma_data_width_p)
    $error("WH flit width must be equal to DMA data width");
  if (wh_flit_width_p < dma_addr_width_p)
    $error("WH flit width must be larger than address width");
  if (wh_len_width_p < `BSG_WIDTH(dma_burst_len_p+1))
    $error("WH len width %d must be large enough to hold the dma transfer size %d", wh_len_width_p, `BSG_WIDTH(dma_burst_len_p+1));
  //synopsys translate_on

endmodule

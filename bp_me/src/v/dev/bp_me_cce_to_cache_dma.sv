
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_cache.vh"

module bp_me_cce_to_cache_dma
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam cache_dma_pkt_width_lp=`bsg_cache_dma_pkt_width(daddr_width_p, dma_mask_width_p)
   )
  (input                                                   clk_i
   , input                                                 reset_i

   // BedRock Stream interface
   , input [mem_fwd_header_width_lp-1:0]                   mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]                      mem_fwd_data_i
   , input                                                 mem_fwd_v_i
   , output logic                                          mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]            mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]               mem_rev_data_o
   , output logic                                          mem_rev_v_o
   , input                                                 mem_rev_ready_and_i

   // cache DMA
   ,output logic [cache_dma_pkt_width_lp-1:0]              dma_pkt_o
   ,output logic                                           dma_pkt_v_o
   ,input                                                  dma_pkt_yumi_i

   ,input [l2_fill_width_p-1:0]                            dma_data_i
   ,input                                                  dma_data_v_i
   ,output logic                                           dma_data_ready_o

   ,output logic [l2_fill_width_p-1:0]                     dma_data_o
   ,output logic                                           dma_data_v_o
   ,input                                                  dma_data_yumi_i
   );

  localparam dma_burst_len_lp = (bedrock_block_width_p / l2_fill_width_p);
  localparam lg_dma_burst_len_lp = `BSG_SAFE_CLOG2(dma_burst_len_lp);
  localparam bytemask_width_lp = (bedrock_block_width_p >> 3);
  localparam lg_bytemask_width_lp = `BSG_SAFE_CLOG2(bytemask_width_lp);
  localparam l2_fill_in_bytes_lp = (l2_fill_width_p >> 3);
  localparam l2_fill_offset_width_lp = `BSG_SAFE_CLOG2(l2_fill_in_bytes_lp);
  localparam lg_l2_fill_in_bytes_lp = $clog2(l2_fill_in_bytes_lp);
  localparam bedrock_fill_offset_width_lp = `BSG_SAFE_CLOG2(bedrock_fill_width_p >> 3);

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bsg_cache_dma_pkt_s(daddr_width_p, dma_mask_width_p);

  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bsg_cache_dma_pkt_s, dma_pkt);

  // Command
  bp_bedrock_mem_fwd_header_s fsm_fwd_header_lo;
  logic [l2_fill_width_p-1:0] fsm_fwd_data_lo;
  logic fsm_fwd_v_lo, fsm_fwd_yumi_li;
  logic [paddr_width_p-1:0] fsm_fwd_addr_lo;
  logic fsm_fwd_new_lo, fsm_fwd_critical_lo, fsm_fwd_last_lo;
  wire wr_cmd = fsm_fwd_v_lo & fsm_fwd_header_lo.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr};
  wire rd_cmd = fsm_fwd_v_lo & fsm_fwd_header_lo.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd};
  wire csr_cmd = fsm_fwd_v_lo & (fsm_fwd_header_lo.addr < dram_base_addr_gp);

  wire [bedrock_fill_width_p-1:0] mem_fwd_data_shifted_li = mem_fwd_data_i << {mem_fwd_header_cast_i.addr[0+:bedrock_fill_offset_width_lp], 3'b0};

  bp_me_stream_pump_in
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(l2_fill_width_p)
     ,.block_width_p(l2_block_width_p)
     ,.payload_width_p(mem_fwd_payload_width_lp)
     ,.msg_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp)
     )
   fwd_pump_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(mem_fwd_header_i)
     ,.msg_data_i(mem_fwd_data_shifted_li)
     ,.msg_v_i(mem_fwd_v_i)
     ,.msg_ready_and_o(mem_fwd_ready_and_o)

     ,.fsm_header_o(fsm_fwd_header_lo)
     ,.fsm_data_o(fsm_fwd_data_lo)
     ,.fsm_v_o(fsm_fwd_v_lo)
     ,.fsm_yumi_i(fsm_fwd_yumi_li)
     ,.fsm_addr_o(fsm_fwd_addr_lo)
     ,.fsm_new_o(fsm_fwd_new_lo)
     ,.fsm_critical_o(fsm_fwd_critical_lo)
     ,.fsm_last_o(fsm_fwd_last_lo)
     );

  bp_bedrock_mem_rev_header_s fsm_rev_header_li;
  logic fifo_v_li, fifo_ready_lo, fifo_v_lo, fifo_yumi_li;
  assign fifo_v_li = fsm_fwd_yumi_li & fsm_fwd_new_lo;
  bsg_fifo_1r1w_small
   #(.width_p(mem_fwd_header_width_lp), .els_p(l2_outstanding_reqs_p))
   stream_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(fifo_v_li)
     ,.data_i(fsm_fwd_header_lo)
     ,.ready_o(fifo_ready_lo)

     ,.v_o(fifo_v_lo)
     ,.data_o(fsm_rev_header_li)
     ,.yumi_i(fifo_yumi_li)
     );

  localparam mux_els_lp = lg_bytemask_width_lp + 1;
  localparam lg_mux_els_lp = `BSG_SAFE_CLOG2(mux_els_lp);

  logic [mux_els_lp-1:0][bytemask_width_lp-1:0] dma_mask_mux_li;
  logic [bytemask_width_lp-1:0] dma_mask_lo;

  for (genvar i = 0; i < mux_els_lp; i++)
    begin : dma_sel
      localparam slice_width_lp = (2**i);
      localparam num_slices_lp = (bytemask_width_lp/slice_width_lp);
      localparam lg_num_slices_lp = `BSG_SAFE_CLOG2(num_slices_lp);

      if (i == mux_els_lp-1)
        begin: max_size
          assign dma_mask_mux_li[i] = {bytemask_width_lp{1'b1}};
        end
      else
        begin: non_max_size
          wire [lg_num_slices_lp-1:0] slice_index = fsm_fwd_header_lo.addr[i+:lg_num_slices_lp];
          wire [num_slices_lp-1:0] decoded_slice_index = (1'b1 << slice_index);

          bsg_expand_bitmask
           #(.in_width_p(num_slices_lp)
             ,.expand_p(slice_width_lp))
           mask_expand
            (.i(decoded_slice_index)
            ,.o(dma_mask_mux_li[i])
          );
        end
    end

  wire [lg_mux_els_lp-1:0] dma_mask_sel_li = (fsm_fwd_header_lo.size > lg_bytemask_width_lp)
                                             ? lg_mux_els_lp'(mux_els_lp-1)
                                             : fsm_fwd_header_lo.size[0+:lg_mux_els_lp];

  bsg_mux
   #(.width_p(bytemask_width_lp)
   ,.els_p(mux_els_lp))
   dma_mask_mux
    (.data_i(dma_mask_mux_li)
    ,.sel_i(dma_mask_sel_li)
    ,.data_o(dma_mask_lo)
    );

  logic [lg_dma_burst_len_lp-1:0] cmd_burst_cnt_n, cmd_burst_cnt_r;
  logic [l2_fill_in_bytes_lp-1:0] dma_mask_word_selected_lo;
  bsg_mux
   #(.width_p(l2_fill_in_bytes_lp)
   ,.els_p(dma_burst_len_lp))
   dma_mask_word_sel_mux
    (.data_i(dma_mask_lo)
    ,.sel_i(cmd_burst_cnt_r)
    ,.data_o(dma_mask_word_selected_lo)
    );

  logic wr_pkt_sent_n, wr_pkt_sent_r;

  always_comb begin
    dma_pkt_v_o = 1'b0;
    dma_data_v_o = 1'b0;
    fsm_fwd_yumi_li = 1'b0;

    dma_pkt_cast_o.write_not_read = wr_cmd;
    dma_pkt_cast_o.mask = dma_mask_lo;
    dma_pkt_cast_o.addr = fsm_fwd_header_lo.addr & ~((1 << lg_bytemask_width_lp) - 1);

    dma_data_o = fsm_fwd_data_lo;

    cmd_burst_cnt_n = cmd_burst_cnt_r;
    wr_pkt_sent_n = wr_pkt_sent_r;

    if(csr_cmd) begin
      fsm_fwd_yumi_li = fsm_fwd_v_lo & fifo_ready_lo;
    end
    else if(wr_cmd) begin
      dma_pkt_v_o = fsm_fwd_v_lo & fsm_fwd_new_lo & ~wr_pkt_sent_r & fifo_ready_lo;
      dma_data_v_o = fsm_fwd_v_lo & wr_pkt_sent_r;
      fsm_fwd_yumi_li = dma_data_yumi_i & (fsm_fwd_last_lo ? (cmd_burst_cnt_r == dma_burst_len_lp - 1) : (|dma_mask_word_selected_lo));

      cmd_burst_cnt_n = dma_data_yumi_i ? (cmd_burst_cnt_r + 1'b1) : cmd_burst_cnt_r;
      wr_pkt_sent_n = dma_pkt_yumi_i ? 1'b1 : ((fsm_fwd_yumi_li & fsm_fwd_last_lo) ? 1'b0 : wr_pkt_sent_r);
    end
    else if(rd_cmd) begin
      dma_pkt_v_o = fsm_fwd_v_lo & fsm_fwd_new_lo & fifo_ready_lo;
      fsm_fwd_yumi_li = dma_pkt_yumi_i;
    end
  end

  // Response
  logic [l2_fill_width_p-1:0] fsm_rev_data_li;
  logic fsm_rev_v_li, fsm_rev_ready_and_lo;
  logic [paddr_width_p-1:0] fsm_rev_addr_lo;
  logic fsm_rev_new_lo, fsm_rev_critical_lo, fsm_rev_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(l2_fill_width_p)
     ,.block_width_p(l2_block_width_p)
     ,.payload_width_p(mem_rev_payload_width_lp)
     ,.msg_stream_mask_p(mem_rev_stream_mask_gp)
     ,.fsm_stream_mask_p(mem_fwd_stream_mask_gp)
     )
   rev_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(mem_rev_header_o)
     ,.msg_data_o(mem_rev_data_o)
     ,.msg_v_o(mem_rev_v_o)
     ,.msg_ready_and_i(mem_rev_ready_and_i)

     ,.fsm_header_i(fsm_rev_header_li)
     ,.fsm_data_i(fsm_rev_data_li)
     ,.fsm_v_i(fsm_rev_v_li)
     ,.fsm_ready_and_o(fsm_rev_ready_and_lo)
     ,.fsm_addr_o(fsm_rev_addr_lo)
     ,.fsm_new_o(fsm_rev_new_lo)
     ,.fsm_critical_o(fsm_rev_critical_lo)
     ,.fsm_last_o(fsm_rev_last_lo)
     );

  logic [`BSG_WIDTH(l2_fill_offset_width_lp)-1:0] fsm_rev_data_size_li;
  logic [l2_fill_offset_width_lp-1:0] fsm_rev_data_sel_li;
  assign fsm_rev_data_size_li = `BSG_MIN(fsm_rev_header_li.size, `BSG_WIDTH(l2_fill_offset_width_lp)'(l2_fill_offset_width_lp));
  assign fsm_rev_data_sel_li = fsm_rev_header_li.addr[0+:l2_fill_offset_width_lp] & ({l2_fill_offset_width_lp{1'b1}} << fsm_rev_header_li.size);


  bsg_bus_pack
   #(.in_width_p(l2_fill_width_p))
   fsm_rev_data_bus_pack
    (.data_i(dma_data_i)
    ,.sel_i(fsm_rev_data_sel_li)
    ,.size_i(fsm_rev_data_size_li)
    ,.data_o(fsm_rev_data_li)
    );

  wire [`BSG_SAFE_CLOG2(lg_dma_burst_len_lp):0] stream_size = (fsm_rev_header_li.size > lg_l2_fill_in_bytes_lp)
                                                                ? (fsm_rev_header_li.size - lg_l2_fill_in_bytes_lp)
                                                                : '0;
  wire [lg_dma_burst_len_lp-1:0] stream_cnt = (1 << stream_size) - 1'b1;
  wire [lg_dma_burst_len_lp-1:0] first_cnt = fsm_rev_header_li.addr[l2_fill_offset_width_lp+:lg_dma_burst_len_lp]
                                             & ({lg_dma_burst_len_lp{1'b1}} << stream_size);
  wire [lg_dma_burst_len_lp-1:0] last_cnt = first_cnt + stream_cnt;


  wire wr_resp = fifo_v_lo & fsm_rev_header_li.msg_type inside {e_bedrock_mem_uc_wr, e_bedrock_mem_wr};
  wire rd_resp = fifo_v_lo & fsm_rev_header_li.msg_type inside {e_bedrock_mem_uc_rd, e_bedrock_mem_rd};
  wire csr_resp = fifo_v_lo & (fsm_rev_header_li.addr < dram_base_addr_gp);

  logic [lg_dma_burst_len_lp-1:0] resp_burst_cnt_n, resp_burst_cnt_r;
  always_comb begin
    dma_data_ready_o = 1'b0;

    fsm_rev_v_li = 1'b0;
    fifo_yumi_li = 1'b0;

    resp_burst_cnt_n = resp_burst_cnt_r;

    if(rd_resp) begin
      dma_data_ready_o = fifo_v_lo & fsm_rev_ready_and_lo;

      fsm_rev_v_li = dma_data_ready_o & dma_data_v_i & (resp_burst_cnt_r >= first_cnt) & (resp_burst_cnt_r <= last_cnt);
      fifo_yumi_li = dma_data_ready_o & dma_data_v_i & (resp_burst_cnt_r == dma_burst_len_lp - 1);

      resp_burst_cnt_n = (dma_data_ready_o & dma_data_v_i) ? (resp_burst_cnt_r + 1'b1) : resp_burst_cnt_r;
    end
    else if(wr_resp | csr_resp) begin
      fsm_rev_v_li = fifo_v_lo;
      fifo_yumi_li = fsm_rev_v_li & fsm_rev_ready_and_lo;
    end
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      cmd_burst_cnt_r <= '0;
      resp_burst_cnt_r <= '0;
      wr_pkt_sent_r <= 1'b0;
    end
    else begin
      cmd_burst_cnt_r <= cmd_burst_cnt_n;
      resp_burst_cnt_r <= resp_burst_cnt_n;
      wr_pkt_sent_r <= wr_pkt_sent_n;
    end
  end

  if (l2_block_width_p != bedrock_block_width_p)
    $error("L2 and Bedrock block widths must be equal in L2-bypass mode");

endmodule

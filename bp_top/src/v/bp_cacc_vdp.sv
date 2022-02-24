
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

module bp_cacc_vdp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
    `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, acache_sets_p, acache_assoc_p, dword_width_gp, acache_block_width_p, acache_fill_width_p, cache)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
    )
   (input                                         clk_i
    , input                                       reset_i

    , input [lce_id_width_p-1:0]                  lce_id_i

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    , output logic [lce_req_header_width_lp-1:0]  lce_req_header_o
    , output logic                                lce_req_header_v_o
    , input                                       lce_req_header_ready_and_i
    , output logic                                lce_req_has_data_o
    , output logic [acache_fill_width_p-1:0]      lce_req_data_o
    , output logic                                lce_req_data_v_o
    , input                                       lce_req_data_ready_and_i
    , output logic                                lce_req_last_o

    , input [lce_cmd_header_width_lp-1:0]         lce_cmd_header_i
    , input                                       lce_cmd_header_v_i
    , output logic                                lce_cmd_header_ready_and_o
    , input                                       lce_cmd_has_data_i
    , input [acache_fill_width_p-1:0]             lce_cmd_data_i
    , input                                       lce_cmd_data_v_i
    , output logic                                lce_cmd_data_ready_and_o
    , input                                       lce_cmd_last_i

    , input [lce_fill_header_width_lp-1:0]        lce_fill_header_i
    , input                                       lce_fill_header_v_i
    , output logic                                lce_fill_header_ready_and_o
    , input                                       lce_fill_has_data_i
    , input [acache_fill_width_p-1:0]             lce_fill_data_i
    , input                                       lce_fill_data_v_i
    , output logic                                lce_fill_data_ready_and_o
    , input                                       lce_fill_last_i

    , output logic [lce_fill_header_width_lp-1:0] lce_fill_header_o
    , output logic                                lce_fill_header_v_o
    , input                                       lce_fill_header_ready_and_i
    , output logic                                lce_fill_has_data_o
    , output logic [acache_fill_width_p-1:0]      lce_fill_data_o
    , output logic                                lce_fill_data_v_o
    , input                                       lce_fill_data_ready_and_i
    , output logic                                lce_fill_last_o

    , output logic [lce_resp_header_width_lp-1:0] lce_resp_header_o
    , output logic                                lce_resp_header_v_o
    , input                                       lce_resp_header_ready_and_i
    , output logic                                lce_resp_has_data_o
    , output logic [acache_fill_width_p-1:0]      lce_resp_data_o
    , output logic                                lce_resp_data_v_o
    , input                                       lce_resp_data_ready_and_i
    , output logic                                lce_resp_last_o

    // BedRock Stream
    // may only support single beat messages
    , input [mem_header_width_lp-1:0]             io_cmd_header_i
    , input [acache_fill_width_p-1:0]             io_cmd_data_i
    , input                                       io_cmd_v_i
    , input                                       io_cmd_last_i
    , output logic                                io_cmd_ready_and_o

    , output logic [mem_header_width_lp-1:0]      io_resp_header_o
    , output logic [acache_fill_width_p-1:0]      io_resp_data_o
    , output logic                                io_resp_v_o
    , output logic                                io_resp_last_o
    , input                                       io_resp_ready_and_i
    );

  `declare_bp_be_dcache_pkt_s(vaddr_width_p);
  bp_be_dcache_pkt_s        dcache_pkt;
  logic                     dcache_ready, dcache_v;
  logic [dpath_width_gp-1:0] dcache_data;
  logic [ptag_width_p-1:0]  dcache_ptag;
  logic                     dcache_uncached;
  logic                     dcache_dram;
  logic                     dcache_pkt_v;

  `declare_bp_cfg_bus_s(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i.dcache_id = lce_id_i;
  assign cfg_bus_cast_i.dcache_mode = e_lce_mode_normal;

  logic cache_req_v_o, cache_req_yumi_i, cache_req_busy_i, cache_req_metadata_v_o,
  data_mem_pkt_v_i, data_mem_pkt_yumi_o,
  tag_mem_pkt_v_i, tag_mem_pkt_yumi_o,
  stat_mem_pkt_v_i, stat_mem_pkt_yumi_o,
  cache_req_complete_lo, cache_req_critical_tag_lo, cache_req_critical_data_lo,
  cache_req_credits_full_lo, cache_req_credits_empty_lo;

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, acache_sets_p, acache_assoc_p, dword_width_gp, acache_block_width_p, acache_fill_width_p, cache);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  bp_cache_req_s cache_req_cast_o;
  bp_cache_data_mem_pkt_s data_mem_pkt_i;
  logic [acache_block_width_p-1:0] data_mem_o;
  bp_cache_tag_mem_pkt_s tag_mem_pkt_i;
  logic [cache_tag_info_width_lp-1:0] tag_mem_o;
  bp_cache_stat_mem_pkt_s stat_mem_pkt_i;
  logic [cache_stat_info_width_lp-1:0] stat_mem_o;
  bp_cache_req_metadata_s cache_req_metadata_o;

  bp_pma
   #(.bp_params_p(bp_params_p))
   pma
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.ptag_v_i(dcache_pkt_v)
     ,.ptag_i(dcache_ptag)
     ,.uncached_mode_i('0)
     ,.nonspec_mode_i('0)

     ,.uncached_o(dcache_uncached)
     ,.nonidem_o()
     ,.dram_o(dcache_dram)
     );

  // TODO: Actually use the late signal, but we don't really care about performance
  //   for the purposes of this demo
  logic late_v;
  bp_be_dcache
   #(.bp_params_p(bp_params_p)
     ,.sets_p(acache_sets_p)
     ,.assoc_p(acache_assoc_p)
     ,.block_width_p(acache_block_width_p)
     ,.fill_width_p(acache_fill_width_p)
     )
   acache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cfg_bus_i(cfg_bus_cast_i)

     ,.dcache_pkt_i(dcache_pkt)
     ,.v_i(dcache_pkt_v)
     ,.ready_o(dcache_ready)
     ,.poison_req_i(1'b0)

     ,.ptag_v_i(1'b1)
     ,.ptag_i(dcache_ptag)
     ,.ptag_uncached_i(dcache_uncached)
     ,.ptag_dram_i(dcache_dram)
     ,.poison_tl_i(1'b0)

     ,.early_hit_v_o(dcache_v)
     ,.early_miss_v_o()
     ,.early_fencei_o()
     ,.early_data_o(dcache_data)
     ,.early_fflags_o()
     ,.final_data_o()
     ,.final_v_o()

     ,.late_rd_addr_o()
     ,.late_float_o()
     ,.late_data_o()
     ,.late_v_o(late_v)
     ,.late_yumi_i(late_v)

     // D$-LCE Interface
     ,.cache_req_complete_i(cache_req_complete_lo)
     ,.cache_req_critical_tag_i(cache_req_critical_tag_lo)
     ,.cache_req_critical_data_i(cache_req_critical_data_lo)
     ,.cache_req_o(cache_req_cast_o)
     ,.cache_req_v_o(cache_req_v_o)
     ,.cache_req_yumi_i(cache_req_yumi_i)
     ,.cache_req_busy_i(cache_req_busy_i)
     ,.cache_req_metadata_o(cache_req_metadata_o)
     ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
     ,.cache_req_credits_full_i(cache_req_credits_full_lo)
     ,.cache_req_credits_empty_i(cache_req_credits_empty_lo)

     ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
     ,.data_mem_pkt_i(data_mem_pkt_i)
     ,.data_mem_o(data_mem_o)
     ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)
     ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
     ,.tag_mem_pkt_i(tag_mem_pkt_i)
     ,.tag_mem_o(tag_mem_o)
     ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)
     ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
     ,.stat_mem_pkt_i(stat_mem_pkt_i)
     ,.stat_mem_o(stat_mem_o)
     ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
     );


  bp_lce
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(acache_assoc_p)
     ,.sets_p(acache_sets_p)
     ,.block_width_p(acache_block_width_p)
     ,.fill_width_p(acache_fill_width_p)
     ,.timeout_max_limit_p(4)
     ,.credits_p(coh_noc_max_credits_p)
     ,.req_invert_clk_p(1)
     ,.data_mem_invert_clk_p(1)
     ,.tag_mem_invert_clk_p(1)
     )
   lce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(cfg_bus_cast_i.dcache_id)
     ,.lce_mode_i(cfg_bus_cast_i.dcache_mode)

     ,.cache_req_i(cache_req_cast_o)
     ,.cache_req_v_i(cache_req_v_o)
     ,.cache_req_yumi_o(cache_req_yumi_i)
     ,.cache_req_busy_o(cache_req_busy_i)
     ,.cache_req_metadata_i(cache_req_metadata_o)
     ,.cache_req_metadata_v_i(cache_req_metadata_v_o)
     ,.cache_req_critical_tag_o(cache_req_critical_tag_lo)
     ,.cache_req_critical_data_o(cache_req_critical_data_lo)
     ,.cache_req_complete_o(cache_req_complete_lo)
     ,.cache_req_credits_full_o(cache_req_credits_full_lo)
     ,.cache_req_credits_empty_o(cache_req_credits_empty_lo)

     ,.data_mem_pkt_o(data_mem_pkt_i)
     ,.data_mem_pkt_v_o(data_mem_pkt_v_i)
     ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_o)
     ,.data_mem_i(data_mem_o)

     ,.tag_mem_pkt_o(tag_mem_pkt_i)
     ,.tag_mem_pkt_v_o(tag_mem_pkt_v_i)
     ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_o)
     ,.tag_mem_i(tag_mem_o)

     ,.stat_mem_pkt_v_o(stat_mem_pkt_v_i)
     ,.stat_mem_pkt_o(stat_mem_pkt_i)
     ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_o)
     ,.stat_mem_i(stat_mem_o)

     // LCE-CCE Interface
     ,.*
     );

  // CCE-IO interface is used for uncached requests-read/write memory mapped CSR
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_resp_header);

  assign io_cmd_ready_and_o = 1'b1;

  logic [63:0] csr_data, start_cmd, input_a_ptr, input_b_ptr, input_len,
               res_status, res_ptr, res_len, operation, dot_product_res;
  logic [63:0] vector_a [0:7];
  logic [63:0] vector_b [0:7];
  logic [2:0] len_a_cnt, len_b_cnt;
  logic load, second_operand, done;
  logic [paddr_width_p-1:0]  resp_addr;

  //chnage the names
  logic [63:0] product_res [0:7];
  logic [63:0] sum_l1 [0:3];
  logic [63:0] sum_l2 [0:1];
  logic [63:0] dot_product_temp;

  bp_bedrock_mem_payload_s      resp_payload;
  bp_bedrock_msg_size_e         resp_size;
  bp_bedrock_mem_type_e         resp_msg;
  bp_local_addr_s               local_addr_li;

  assign local_addr_li = io_cmd_header_cast_i.addr;
  assign io_resp_header_cast_o = '{msg_type       : resp_msg
                                   ,subop         : e_bedrock_store
                                   ,addr          : resp_addr
                                   ,payload       : resp_payload
                                   ,size          : resp_size
                                   };
  assign io_resp_data_o = csr_data;


  logic [vaddr_width_p-1:0] v_addr;
  assign v_addr = load ? (second_operand ? (input_b_ptr+len_b_cnt*8)
                                         : (input_a_ptr+len_a_cnt*8))
                       : res_ptr;


  typedef enum logic [3:0]{
    RESET
    , WAIT_START
    , WAIT_FETCH
    , FETCH
    , WAIT_DCACHE_C1
    , WAIT_DCACHE_C2
    , CHECK_VEC1_LEN
    , FETCH_VEC2
    , CHECK_VEC2_LEN
    , WB_RESULT
    , DONE
  } state_e;
  state_e state_r, state_n;

  always_ff @(posedge clk_i) begin
    io_resp_v_o  <= io_cmd_v_i;
    io_resp_last_o <= io_cmd_last_i;
    vector_a[len_a_cnt] <= (dcache_v & load & ~second_operand) ? dcache_data : vector_a[len_a_cnt];
    len_a_cnt <= (dcache_v & load & ~second_operand) ? len_a_cnt + 1'b1 : len_a_cnt;
    vector_b[len_b_cnt]  <= (dcache_v & load & second_operand) ? dcache_data : vector_b[len_b_cnt];
    len_b_cnt <= (dcache_v & load & second_operand) ? len_b_cnt + 1'b1 : len_b_cnt;

    if(reset_i)
      state_r <= RESET;
    else
      state_r <= state_n;

    if (reset_i || done) begin
      start_cmd     <= '0;
      input_a_ptr   <= '0;
      input_b_ptr   <= '0;
      input_len     <= '0;
      res_ptr       <= '0;
      res_len       <= '0;
      operation     <= '0;
      len_a_cnt     <= '0;
      len_b_cnt     <= '0;
      vector_a      <= '{default:64'd0};
      vector_b      <= '{default:64'd0};
    end
    if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_wr))
    begin
      resp_size    <= io_cmd_header_cast_i.size;
      resp_payload <= io_cmd_header_cast_i.payload;
      resp_addr    <= io_cmd_header_cast_i.addr;
      resp_msg     <= bp_bedrock_mem_type_e'(io_cmd_header_cast_i.msg_type);
      unique
      case (local_addr_li.addr)
        inputa_ptr_csr_idx_gp : input_a_ptr <= io_cmd_data_i;
        inputb_ptr_csr_idx_gp : input_b_ptr <= io_cmd_data_i;
        input_len_csr_idx_gp  : input_len  <= io_cmd_data_i;
        start_cmd_csr_idx_gp  : start_cmd  <= io_cmd_data_i;
        res_ptr_csr_idx_gp    : res_ptr    <= io_cmd_data_i;
        res_len_csr_idx_gp    : res_len    <= io_cmd_data_i;
        operation_csr_idx_gp  : operation  <= io_cmd_data_i;
        default : begin end
      endcase
    end
    else if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_rd))
    begin
      resp_size    <= io_cmd_header_cast_i.size;
      resp_payload <= io_cmd_header_cast_i.payload;
      resp_addr    <= io_cmd_header_cast_i.addr;
      resp_msg     <= bp_bedrock_mem_type_e'(io_cmd_header_cast_i.msg_type);
      unique
      case (local_addr_li.addr)
        inputa_ptr_csr_idx_gp : csr_data <= input_a_ptr;
        inputb_ptr_csr_idx_gp : csr_data <= input_b_ptr;
        input_len_csr_idx_gp  : csr_data <= input_len;
        start_cmd_csr_idx_gp  : csr_data <= start_cmd;
        res_status_csr_idx_gp : csr_data <= res_status;
        res_ptr_csr_idx_gp    : csr_data <= res_ptr;
        res_len_csr_idx_gp    : csr_data <= res_len;
        operation_csr_idx_gp  : csr_data <= operation;
        default : begin end
      endcase
    end
  end


  always_comb begin
    state_n = state_r;
    case (state_r)
      RESET: begin
        state_n = reset_i ? RESET : WAIT_START;
        res_status = '0;
        dcache_ptag = '0;
        dcache_pkt = '0;
        dcache_pkt_v = '0;
        load = 0;
        second_operand = 0;
        done = 0;
      end
      WAIT_START: begin
        state_n = start_cmd ? WAIT_FETCH : WAIT_START;
        res_status = '1;
        dcache_ptag = '0;
        dcache_pkt = '0;
        dcache_pkt_v = '0;
        load = 1;
        second_operand= 0;
        done = 0;
      end
      WAIT_FETCH: begin
        state_n = dcache_ready ? FETCH : WAIT_FETCH;
        res_status = '0;
        dcache_ptag = '0;
        dcache_pkt = '0;
        dcache_pkt_v = '0;
        done = 0;
      end
      FETCH: begin
        state_n = WAIT_DCACHE_C1;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr[vaddr_width_p-1-:vtag_width_p]};
        dcache_pkt.opcode = load ? e_dcache_op_ld : e_dcache_op_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.vaddr = v_addr;
        dcache_pkt.rd_addr = '0;
        res_status = '0;
        dcache_pkt_v = '1;
        done = 0;
      end
      WAIT_DCACHE_C1: begin
        state_n = dcache_v ? (load ? (second_operand ? CHECK_VEC2_LEN : CHECK_VEC1_LEN) : DONE) : WAIT_DCACHE_C2;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr[vaddr_width_p-1-:vtag_width_p]};
        dcache_pkt.opcode = load ? e_dcache_op_ld : e_dcache_op_sd;
        dcache_pkt.vaddr = v_addr;
        dcache_pkt.rd_addr = '0;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt_v = '0;
        done = 0;
      end
      WAIT_DCACHE_C2: begin
        //if load: load both input vectors
        //if store: go to DONE after store
        state_n = ~(lce_cmd_header_v_i | lce_fill_header_v_i) ? WAIT_DCACHE_C2 : WAIT_FETCH;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr[vaddr_width_p-1-:vtag_width_p]};
        dcache_pkt.opcode = load ? e_dcache_op_ld : e_dcache_op_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.vaddr = v_addr;
        dcache_pkt.rd_addr = '0;
        dcache_pkt_v = '0;
        done = 0;
      end
      CHECK_VEC1_LEN: begin
        state_n = (len_a_cnt == input_len) ? FETCH_VEC2 : WAIT_FETCH;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr[vaddr_width_p-1-:vtag_width_p]};
        dcache_pkt.opcode = load ? e_dcache_op_ld : e_dcache_op_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.vaddr = v_addr;
        dcache_pkt.rd_addr = '0;
        dcache_pkt_v = '0;
        done = 0;
      end
      FETCH_VEC2: begin
        state_n = WAIT_FETCH;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr[vaddr_width_p-1-:vtag_width_p]};
        dcache_pkt.opcode = load ? e_dcache_op_ld : e_dcache_op_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.vaddr = v_addr;
        dcache_pkt.rd_addr = '0;
        dcache_pkt_v = '0;
        second_operand= 1;
        done = 0;
      end
      CHECK_VEC2_LEN: begin
        state_n= (len_b_cnt == input_len) ? WB_RESULT : WAIT_FETCH;
        res_status = '0;
        dcache_ptag = {(ptag_width_p-vtag_width_p)'(0), v_addr[vaddr_width_p-1-:vtag_width_p]};
        dcache_pkt.opcode = load ? e_dcache_op_ld : e_dcache_op_sd;
        dcache_pkt.data = load ? '0 : dot_product_res;
        dcache_pkt.vaddr = v_addr;
        dcache_pkt.rd_addr = '0;
        dcache_pkt_v = '0;
        second_operand= 1;
        done = 0;
        dot_product_res = dot_product_temp;
      end
      WB_RESULT: begin
        state_n = WAIT_FETCH;
        load = 0;
        dcache_ptag = '0;
        dcache_pkt = '0;
        dcache_pkt_v = '0;
        res_status = 0;
        second_operand= 0;
        done = 0;
      end
      DONE: begin
        state_n = cache_req_credits_empty_lo ? RESET : DONE;
        res_status = cache_req_credits_empty_lo ? 1 : 0;
        dcache_ptag = '0;
        dcache_pkt = '0;
        dcache_pkt_v = '0;
        load = 0;
        second_operand= 0;
        done = 1;
      end
    endcase
   end // always_comb


  //dot_product unit
  for (genvar i=0; i<8; i++)
  begin : product
    assign product_res[i]= vector_a[i] * vector_b[i];
  end

  for (genvar i=0; i<4; i++)
  begin : sum_level_1
    assign sum_l1[i]= product_res[2*i] + product_res[2*i+1];
  end

  for (genvar i=0; i<2; i++)
  begin : sum_level_2
    assign sum_l2[i]= sum_l1[2*i] + sum_l1[2*i+1];
  end

   assign dot_product_temp = sum_l2[0] + sum_l2[1];

endmodule

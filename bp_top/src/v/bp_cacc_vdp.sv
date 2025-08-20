
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

module bp_cacc_vdp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
    `declare_bp_be_dcache_engine_if_widths(paddr_width_p, acache_tag_width_p, acache_sets_p, acache_assoc_p, dword_width_gp, acache_block_width_p, acache_fill_width_p, acache_req_id_width_p)

    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
    )
   (input                                         clk_i
    , input                                       reset_i

    , input [lce_id_width_p-1:0]                  lce_id_i

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    , output logic [lce_req_header_width_lp-1:0]  lce_req_header_o
    , output logic [acache_fill_width_p-1:0]      lce_req_data_o
    , output logic                                lce_req_v_o
    , input                                       lce_req_ready_and_i

    , input [lce_cmd_header_width_lp-1:0]         lce_cmd_header_i
    , input [acache_fill_width_p-1:0]             lce_cmd_data_i
    , input                                       lce_cmd_v_i
    , output logic                                lce_cmd_ready_and_o

    , input [lce_fill_header_width_lp-1:0]        lce_fill_header_i
    , input [acache_fill_width_p-1:0]             lce_fill_data_i
    , input                                       lce_fill_v_i
    , output logic                                lce_fill_ready_and_o

    , output logic [lce_fill_header_width_lp-1:0] lce_fill_header_o
    , output logic [acache_fill_width_p-1:0]      lce_fill_data_o
    , output logic                                lce_fill_v_o
    , input                                       lce_fill_ready_and_i

    , output logic [lce_resp_header_width_lp-1:0] lce_resp_header_o
    , output logic [acache_fill_width_p-1:0]      lce_resp_data_o
    , output logic                                lce_resp_v_o
    , input                                       lce_resp_ready_and_i

    // BedRock Stream
    // may only support single beat messages
    , input [mem_fwd_header_width_lp-1:0]         mem_fwd_header_i
    , input [acache_fill_width_p-1:0]             mem_fwd_data_i
    , input                                       mem_fwd_v_i
    , output logic                                mem_fwd_ready_and_o

    , output logic [mem_rev_header_width_lp-1:0]  mem_rev_header_o
    , output logic [acache_fill_width_p-1:0]      mem_rev_data_o
    , output logic                                mem_rev_v_o
    , input                                       mem_rev_ready_and_i
    );

  // CCE-IO interface is used for uncached requests-read/write memory mapped CSR
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `declare_bp_be_dcache_pkt_s(vaddr_width_p);

  localparam reg_els_lp = 1;

  logic r_v_li, w_v_li;
  logic [paddr_width_p-1:0] addr_lo;
  logic [reg_els_lp-1:0][dword_width_gp-1:0] data_li;
  logic [dword_width_gp-1:0] data_lo;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.els_p(reg_els_lp)
     ,.reg_addr_width_p(paddr_width_p)
     ,.base_addr_p({64'b????????????????})
     )
   register
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.r_v_o(r_v_li)
     ,.w_v_o(w_v_li)
     ,.addr_o(addr_lo)
     ,.size_o()
     ,.data_o(data_lo)
     ,.data_i(data_li)

     ,.*
     );

  bp_local_addr_s local_addr_lo;
  bp_global_addr_s global_addr_lo;
  assign global_addr_lo = addr_lo;
  assign local_addr_lo = addr_lo;

  bp_be_dcache_pkt_s acache_pkt_li;
  logic acache_busy_lo, acache_v_li;
  logic [dword_width_gp-1:0] acache_data_lo;
  logic acache_v_lo;

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i.dcache_id = lce_id_i;
  assign cfg_bus_cast_i.dcache_mode = e_lce_mode_normal;

  `declare_bp_be_dcache_engine_if(paddr_width_p, acache_tag_width_p, acache_sets_p, acache_assoc_p, dword_width_gp, acache_block_width_p, acache_fill_width_p, acache_req_id_width_p);
  bp_be_dcache_req_s acache_req_lo;
  logic acache_req_v_lo, acache_req_yumi_li, acache_req_lock_li;
  bp_be_dcache_req_metadata_s acache_req_metadata_lo;
  logic acache_req_metadata_v_lo;
  logic [acache_req_id_width_p-1:0] acache_req_id_lo;
  logic acache_req_last_lo, acache_req_critical_lo;
  logic acache_req_credits_full_lo, acache_req_credits_empty_lo;
  bp_be_dcache_data_mem_pkt_s acache_data_mem_pkt_li;
  logic acache_data_mem_pkt_v_li, acache_data_mem_pkt_yumi_lo;
  logic [acache_block_width_p-1:0] acache_data_mem_lo;
  bp_be_dcache_tag_mem_pkt_s acache_tag_mem_pkt_li;
  logic acache_tag_mem_pkt_v_li, acache_tag_mem_pkt_yumi_lo;
  bp_be_dcache_tag_info_s acache_tag_mem_lo;
  bp_be_dcache_stat_mem_pkt_s acache_stat_mem_pkt_li;
  logic acache_stat_mem_pkt_v_li, acache_stat_mem_pkt_yumi_lo;
  bp_be_dcache_stat_info_s acache_stat_mem_lo;

  logic [ptag_width_p-1:0] acache_ptag_li;
  logic [dword_width_gp-1:0] acache_st_data_r;

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

     ,.dcache_pkt_i(acache_pkt_li)
     ,.v_i(acache_v_li)
     ,.busy_o(acache_busy_lo)
     ,.flush_i(1'b0)
     ,.ordered_o()

     ,.ptag_v_i(1'b1)
     ,.ptag_i(acache_ptag_li)
     ,.ptag_uncached_i(1'b0)
     ,.ptag_dram_i(1'b1)
     ,.st_data_i(acache_st_data_r)

     ,.v_o(acache_v_lo)
     ,.data_o(acache_data_lo)
     ,.rd_addr_o()
     ,.int_o()
     ,.float_o()
     ,.ptw_o()
     ,.ret_o()
     ,.late_o()
     ,.tag_o()
     ,.unsigned_o()

     // D$-LCE Interface
     ,.cache_req_o(acache_req_lo)
     ,.cache_req_v_o(acache_req_v_lo)
     ,.cache_req_yumi_i(acache_req_yumi_li)
     ,.cache_req_lock_i(acache_req_lock_li)
     ,.cache_req_metadata_o(acache_req_metadata_lo)
     ,.cache_req_metadata_v_o(acache_req_metadata_v_lo)
     ,.cache_req_credits_full_i(acache_req_credits_full_lo)
     ,.cache_req_credits_empty_i(acache_req_credits_empty_lo)
     ,.cache_req_id_i(acache_req_id_lo)
     ,.cache_req_critical_i(acache_req_critical_lo)
     ,.cache_req_last_i(acache_req_last_lo)

     ,.data_mem_pkt_v_i(acache_data_mem_pkt_v_li)
     ,.data_mem_pkt_i(acache_data_mem_pkt_li)
     ,.data_mem_pkt_yumi_o(acache_data_mem_pkt_yumi_lo)
     ,.data_mem_o(acache_data_mem_lo)

     ,.tag_mem_pkt_v_i(acache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_i(acache_tag_mem_pkt_li)
     ,.tag_mem_pkt_yumi_o(acache_tag_mem_pkt_yumi_lo)
     ,.tag_mem_o(acache_tag_mem_lo)

     ,.stat_mem_pkt_v_i(acache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_i(acache_stat_mem_pkt_li)
     ,.stat_mem_pkt_yumi_o(acache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_o(acache_stat_mem_lo)
     );


  bp_lce
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(acache_assoc_p)
     ,.sets_p(acache_sets_p)
     ,.block_width_p(acache_block_width_p)
     ,.fill_width_p(acache_fill_width_p)
     ,.data_width_p(acache_data_width_p)
     ,.tag_width_p(acache_tag_width_p)
     ,.id_width_p(acache_req_id_width_p)
     ,.timeout_max_limit_p(4)
     ,.credits_p(coh_noc_max_credits_p)
     )
   lce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(cfg_bus_cast_i.dcache_id)
     ,.did_i(cfg_bus_cast_i.did)
     ,.lce_mode_i(cfg_bus_cast_i.dcache_mode)

     ,.cache_req_i(acache_req_lo)
     ,.cache_req_v_i(acache_req_v_lo)
     ,.cache_req_yumi_o(acache_req_yumi_li)
     ,.cache_req_lock_o(acache_req_lock_li)
     ,.cache_req_metadata_i(acache_req_metadata_lo)
     ,.cache_req_metadata_v_i(acache_req_metadata_v_lo)
     ,.cache_req_id_o(acache_req_id_lo)
     ,.cache_req_critical_o(acache_req_critical_lo)
     ,.cache_req_last_o(acache_req_last_lo)
     ,.cache_req_credits_full_o(acache_req_credits_full_lo)
     ,.cache_req_credits_empty_o(acache_req_credits_empty_lo)

     ,.data_mem_pkt_o(acache_data_mem_pkt_li)
     ,.data_mem_pkt_v_o(acache_data_mem_pkt_v_li)
     ,.data_mem_pkt_yumi_i(acache_data_mem_pkt_yumi_lo)
     ,.data_mem_i(acache_data_mem_lo)

     ,.tag_mem_pkt_o(acache_tag_mem_pkt_li)
     ,.tag_mem_pkt_v_o(acache_tag_mem_pkt_v_li)
     ,.tag_mem_pkt_yumi_i(acache_tag_mem_pkt_yumi_lo)
     ,.tag_mem_i(acache_tag_mem_lo)

     ,.stat_mem_pkt_v_o(acache_stat_mem_pkt_v_li)
     ,.stat_mem_pkt_o(acache_stat_mem_pkt_li)
     ,.stat_mem_pkt_yumi_i(acache_stat_mem_pkt_yumi_lo)
     ,.stat_mem_i(acache_stat_mem_lo)

     // LCE-CCE Interface
     ,.*
     );

  logic [63:0] start_cmd, input_a_ptr, input_b_ptr, input_len,
               res_ptr, res_len, operation, dot_product_res;
  logic [63:0] vector_a [0:7];
  logic [63:0] vector_b [0:7];
  logic [63:0] vdp_result;
  logic [2:0] len_a_cnt, len_b_cnt;
  logic load, second_operand;

  enum logic [3:0]
  {
    e_reset
    ,e_wait_start
    ,e_wait_fetch
    ,e_fetch_vec1
    ,e_wait_dcache_c1
    ,e_wait_dcache_c2
    ,e_check_vec1_len
    ,e_fetch_vec2
    ,e_check_vec2_len
    ,e_wb_result
    ,e_done
  } state_n, state_r;

  wire done = (state_r inside {e_done});
  wire res_status = (state_r inside {e_wait_start});

  always_ff @(posedge clk_i)
    begin
      if (reset_i || done)
        begin
          len_a_cnt     <= '0;
          len_b_cnt     <= '0;
        end
      else if (acache_v_lo & load & ~second_operand)
        begin
          vector_a[len_a_cnt] <= acache_data_lo;
          len_a_cnt <= len_a_cnt + 1'b1;
        end
      else if (acache_v_lo & load & second_operand)
        begin
          vector_b[len_b_cnt] <= acache_data_lo;
          len_b_cnt <= len_b_cnt + 1'b1;
        end
    end

  wire csr_w_v_li = w_v_li && (global_addr_lo.hio == 0);
  wire csr_r_v_li = r_v_li && (global_addr_lo.hio == 0);

  always_ff @(posedge clk_i)
    begin
      if (reset_i)
        begin
          input_a_ptr <= '0;
          input_b_ptr <= '0;
          input_len   <= '0;
          start_cmd   <= '0;
          res_ptr     <= '0;
          res_len     <= '0;
          operation   <= '0;
        end
      else if (csr_w_v_li)
        unique casez (local_addr_lo.addr)
          inputa_ptr_csr_idx_gp : input_a_ptr <= data_lo;
          inputb_ptr_csr_idx_gp : input_b_ptr <= data_lo;
          input_len_csr_idx_gp  : input_len   <= data_lo;
          start_cmd_csr_idx_gp  : start_cmd   <= data_lo;
          res_ptr_csr_idx_gp    : res_ptr     <= data_lo;
          res_len_csr_idx_gp    : res_len     <= data_lo;
          operation_csr_idx_gp  : operation   <= data_lo;
          default : begin end
        endcase

      if (state_r == e_done)
        start_cmd <= '0;
    end

  logic input_a_ptr_r_v_r, input_b_ptr_r_v_r, input_len_r_v_r, operation_r_v_r;
  logic start_cmd_r_v_r, res_status_r_v_r, res_ptr_r_v_r, res_len_r_v_r;
  always_ff @(posedge clk_i)
    begin
      input_a_ptr_r_v_r <= csr_r_v_li && (local_addr_lo.addr == inputa_ptr_csr_idx_gp);
      input_b_ptr_r_v_r <= csr_r_v_li && (local_addr_lo.addr == inputb_ptr_csr_idx_gp);
      input_len_r_v_r   <= csr_r_v_li && (local_addr_lo.addr == input_len_csr_idx_gp);
      start_cmd_r_v_r   <= csr_r_v_li && (local_addr_lo.addr == start_cmd_csr_idx_gp);
      res_status_r_v_r  <= csr_r_v_li && (local_addr_lo.addr == res_status_csr_idx_gp);
      res_ptr_r_v_r     <= csr_r_v_li && (local_addr_lo.addr == res_ptr_csr_idx_gp);
      res_len_r_v_r     <= csr_r_v_li && (local_addr_lo.addr == res_len_csr_idx_gp);
      operation_r_v_r   <= csr_r_v_li && (local_addr_lo.addr == operation_csr_idx_gp);
    end

  logic [dword_width_gp-1:0] csr_data_lo;
  always_comb
    unique casez (local_addr_lo.addr)
      inputa_ptr_csr_idx_gp : csr_data_lo = input_a_ptr;
      inputb_ptr_csr_idx_gp : csr_data_lo = input_b_ptr;
      input_len_csr_idx_gp  : csr_data_lo = input_len;
      start_cmd_csr_idx_gp  : csr_data_lo = start_cmd;
      res_status_csr_idx_gp : csr_data_lo = res_status;
      res_ptr_csr_idx_gp    : csr_data_lo = res_ptr;
      res_len_csr_idx_gp    : csr_data_lo = res_len;
      //operation_csr_idx_gp  : csr_data_lo = operation;
      default: csr_data_lo = operation;
    endcase

  assign data_li = csr_data_lo;

  wire [vaddr_width_p-1:0] vaddr = load ? second_operand
                                           ? (input_b_ptr+len_b_cnt*8)
                                           : (input_a_ptr+len_a_cnt*8)
                                         : res_ptr;
  assign acache_pkt_li = '{opcode: load ? e_dcache_op_ld : e_dcache_op_sd
                           ,offset: vaddr[0+:page_offset_width_gp]
                           ,default: '0
                           };

  always_ff @(posedge clk_i) begin
    acache_ptag_li <= vaddr[page_offset_width_gp+:ptag_width_p];
    acache_st_data_r <= dot_product_res;
  end

  always_comb
    begin
      load = 0;
      second_operand = 0;
      acache_v_li = 0;
      dot_product_res = '0;

      state_n = state_r;
      case (state_r)
        e_reset: begin
          state_n = reset_i ? e_reset : e_wait_start;
        end
        e_wait_start: begin
          load = 1;
          state_n = start_cmd ? e_wait_fetch : e_wait_start;
        end
        e_wait_fetch: begin
          state_n = !acache_busy_lo ? e_fetch_vec1 : e_wait_fetch;
        end
        e_fetch_vec1: begin
          acache_v_li = '1;
          state_n = e_wait_dcache_c1;
        end
        e_wait_dcache_c1: begin
          state_n = acache_v_lo ? (load ? (second_operand ? e_check_vec2_len : e_check_vec1_len) : e_done) : e_wait_dcache_c2;
        end
        e_wait_dcache_c2: begin
          //if load: load both input vectors
          //if store: go to e_done after store
          state_n = ~(lce_cmd_v_i | lce_fill_v_i) ? e_wait_dcache_c2 : e_wait_fetch;
        end
        e_check_vec1_len: begin
          state_n = (len_a_cnt == input_len) ? e_fetch_vec2 : e_wait_fetch;
        end
        e_fetch_vec2: begin
          second_operand = 1;
          state_n = e_wait_fetch;
        end
        e_check_vec2_len: begin
          second_operand = 1;
          dot_product_res = vdp_result;
          state_n = (len_b_cnt == input_len) ? e_wb_result : e_wait_fetch;
        end
        e_wb_result: begin
          state_n = e_wait_fetch;
        end
        e_done: begin
          state_n = acache_req_credits_empty_lo ? e_reset : e_done;
        end
      endcase
    end

  // dot_product unit
  logic [63:0] product_res [0:7];
  logic [63:0] sum_l1 [0:3];
  logic [63:0] sum_l2 [0:1];
  for (genvar i = 0; i < 8; i++) assign product_res[i] = vector_a[i] * vector_b[i];
  for (genvar i = 0; i < 4; i++) assign sum_l1[i] = product_res[2*i] + product_res[2*i+1];
  for (genvar i = 0; i < 2; i++) assign sum_l2[i] = sum_l1[2*i] + sum_l1[2*i+1];
  assign vdp_result = (sum_l2[0] + sum_l2[1]);

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if(reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

endmodule


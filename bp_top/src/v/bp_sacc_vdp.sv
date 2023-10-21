`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_sacc_vdp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [lce_id_width_p-1:0]                 lce_id_i

   , input [mem_fwd_header_width_lp-1:0]        mem_fwd_header_i
   , input [acache_fill_width_p-1:0]            mem_fwd_data_i
   , input                                      mem_fwd_v_i
   , output logic                               mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0] mem_rev_header_o
   , output logic [acache_fill_width_p-1:0]     mem_rev_data_o
   , output logic                               mem_rev_v_o
   , input                                      mem_rev_ready_and_i
   );

  // CCE-IO interface is used for uncached requests-read/write memory mapped CSR
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  logic r_v_li, w_v_li;
  logic [paddr_width_p-1:0] addr_lo;
  logic [dword_width_gp-1:0] data_li, data_lo;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.els_p(1)
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

  logic [63:0] start_cmd, input_a_ptr, input_b_ptr, input_len;
  logic [63:0] res_ptr, res_len, operation, spm_data_lo, vdp_result;
  logic [7:0][63:0] vector_a;
  logic [7:0][63:0] vector_b;
  logic [2:0] len_a_cnt, len_b_cnt;
  logic second_operand;

  enum logic [3:0]
  {
    e_wait
    ,e_fetch_vec1
    ,e_wb_vec1
    ,e_fetch_vec2
    ,e_wb_vec2
    ,e_wb_result
   } state_n, state_r;

  wire is_done = (state_r inside {e_wait});

  logic spm_internal_r_v_li, spm_internal_w_v_li;
  logic [paddr_width_p-1:0] spm_internal_addr;

  logic vector_w_v_li;

  always_ff @(posedge clk_i)
    begin
      if (reset_i || is_done)
        begin
          len_a_cnt <= '0;
          len_b_cnt <= '0;
          vector_a <= '0;
          vector_b <= '0;
        end
      else if (vector_w_v_li & ~second_operand)
        begin
          vector_a[len_a_cnt] <= spm_data_lo;
          len_a_cnt <= len_a_cnt + 1'b1;
        end
      else if (vector_w_v_li & second_operand)
        begin
          vector_b[len_b_cnt] <= spm_data_lo;
          len_b_cnt <= len_b_cnt + 1'b1;
        end
    end

  wire csr_w_v_li = w_v_li && (global_addr_lo.hio == 0);
  wire csr_r_v_li = r_v_li && (global_addr_lo.hio == 0);

  wire spm_external_w_v_li = w_v_li && (global_addr_lo.hio == 1);
  wire spm_external_r_v_li = r_v_li && (global_addr_lo.hio == 1);
  wire [paddr_width_p-1:0] spm_external_addr = addr_lo;

  // SPM
  wire [paddr_width_p-1:0] spm_selected_addr =
    (spm_external_r_v_li | spm_external_w_v_li) ? spm_external_addr : spm_internal_addr;
  wire [`BSG_SAFE_CLOG2(20)-1:0] spm_addr_li = spm_selected_addr >> 3;
  wire [63:0] spm_data_li = spm_external_w_v_li ? data_lo : vdp_result;
  bsg_mem_1rw_sync
    #(.width_p(64), .els_p(20))
    accel_spm
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(spm_data_li)
      ,.addr_i(spm_addr_li)
      ,.v_i(spm_internal_r_v_li | spm_external_r_v_li | spm_internal_w_v_li | spm_external_w_v_li)
      ,.w_i(spm_internal_w_v_li | spm_external_w_v_li)
      ,.data_o(spm_data_lo)
      );

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

      if (state_r == e_fetch_vec1)
        start_cmd <= '0;
    end

  logic [dword_width_gp-1:0] csr_data_lo;
  always_comb
    unique casez (local_addr_lo.addr)
      inputa_ptr_csr_idx_gp : csr_data_lo = input_a_ptr;
      inputb_ptr_csr_idx_gp : csr_data_lo = input_b_ptr;
      input_len_csr_idx_gp  : csr_data_lo = input_len;
      start_cmd_csr_idx_gp  : csr_data_lo = start_cmd;
      res_status_csr_idx_gp : csr_data_lo = is_done;
      res_ptr_csr_idx_gp    : csr_data_lo = res_ptr;
      res_len_csr_idx_gp    : csr_data_lo = res_len;
      //operation_csr_idx_gp:
      default: csr_data_lo = operation;
    endcase

  logic spm_r_v_r;
  always_ff @(posedge clk_i)
    begin
      spm_r_v_r <= spm_external_r_v_li | spm_internal_r_v_li;
    end
  assign data_li = spm_r_v_r ? spm_data_lo : csr_data_lo;

  always_comb
    begin
      spm_internal_w_v_li = '0;
      spm_internal_r_v_li = '0;
      spm_internal_addr = '0;

      vector_w_v_li = '0;

      second_operand = '0;

      state_n = state_r;

      case (state_r)
        e_wait:
          begin
            state_n = start_cmd ? e_fetch_vec1 : state_r;
          end
        e_fetch_vec1:
          begin
            spm_internal_r_v_li = '1;
            spm_internal_addr = (input_a_ptr+len_a_cnt*8);
            state_n = e_wb_vec1;
          end
        e_wb_vec1:
          begin
            vector_w_v_li = 1'b1;
            state_n = (len_a_cnt == input_len-1) ? e_fetch_vec2 : e_fetch_vec1;
          end
        e_fetch_vec2:
          begin
            second_operand = 1'b1;
            spm_internal_r_v_li = '1;
            spm_internal_addr = (input_b_ptr+len_b_cnt*8);
            state_n = e_wb_vec2;
          end
        e_wb_vec2:
          begin
            vector_w_v_li = 1'b1;
            second_operand = 1'b1;
            state_n = (len_b_cnt == input_len-1) ? e_wb_result : e_fetch_vec2;
          end
        e_wb_result:
          begin
            spm_internal_w_v_li = '1;
            spm_internal_addr = res_ptr;
            state_n = e_wait;
          end
      endcase
    end

  // dot_product unit
  logic [7:0][63:0] product_res;
  logic [3:0][63:0] sum_l1;
  logic [1:0][63:0] sum_l2;
  for (genvar i = 0; i < 8; i++) assign product_res[i] = vector_a[i] * vector_b[i];
  for (genvar i = 0; i < 4; i++) assign sum_l1[i] = product_res[2*i] + product_res[2*i+1];
  for (genvar i = 0; i < 2; i++) assign sum_l2[i] = sum_l1[2*i] + sum_l1[2*i+1];
  assign vdp_result = (sum_l2[0] + sum_l2[1]);

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_wait;
    else
      state_r <= state_n;

endmodule


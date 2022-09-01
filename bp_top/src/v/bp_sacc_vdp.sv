`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_sacc_vdp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [lce_id_width_p-1:0]                 lce_id_i

   , input [mem_fwd_header_width_lp-1:0]        io_fwd_header_i
   , input [acache_fill_width_p-1:0]            io_fwd_data_i
   , input                                      io_fwd_v_i
   , input                                      io_fwd_last_i
   , output logic                               io_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0] io_rev_header_o
   , output logic [acache_fill_width_p-1:0]     io_rev_data_o
   , output logic                               io_rev_v_o
   , output logic                               io_rev_last_o
   , input                                      io_rev_ready_and_i
   );

  //synopsys translate_off
  always_ff @(negedge clk_i) begin
    assert(~io_fwd_v_i | (io_fwd_v_i & io_fwd_last_i))
      else $error("sacc_vdp only supports single beat IO commands");
  end
  //synopsys translate_on

  // CCE-IO interface is used for uncached requests-read/write memory mapped CSR
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, io_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, io_rev_header);

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

     ,.mem_fwd_header_i(io_fwd_header_cast_i)
     ,.mem_fwd_data_i(io_fwd_data_i)
     ,.mem_fwd_v_i(io_fwd_v_i)
     ,.mem_fwd_ready_and_o(io_fwd_ready_and_o)
     ,.mem_fwd_last_i(io_fwd_last_i)

     ,.mem_rev_header_o(io_rev_header_cast_o)
     ,.mem_rev_data_o(io_rev_data_o)
     ,.mem_rev_v_o(io_rev_v_o)
     ,.mem_rev_ready_and_i(io_rev_ready_and_i)
     ,.mem_rev_last_o(io_rev_last_o)

     ,.r_v_o(r_v_li)
     ,.w_v_o(w_v_li)
     ,.addr_o(addr_lo)
     ,.size_o()
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );

  bp_local_addr_s local_addr_lo;
  bp_global_addr_s global_addr_lo;
  assign global_addr_lo = addr_lo;
  assign local_addr_lo = addr_lo;

  logic [63:0] start_cmd, input_a_ptr, input_b_ptr, input_len;
  logic [63:0] res_ptr, res_len, operation, spm_data_lo, vdp_result;
  logic [63:0] vector_a [0:7];
  logic [63:0] vector_b [0:7];
  logic [2:0] len_a_cnt, len_b_cnt;
  logic load, second_operand;
  logic spm_internal_r_v_r;

  enum logic [3:0] 
  {
    e_reset
    ,e_wait_start
    ,e_wait_fetch
    ,e_fetch_vec1
    ,e_check_vec1_len
    ,e_fetch_vec2
    ,e_check_vec2_len
    ,e_wb_result
    ,e_done
   } state_n, state_r;

  wire done = (state_r == e_done);
  wire res_status = (state_r inside {e_reset, e_wait_start, e_wait_fetch});

  always_ff @(posedge clk_i)
    begin
      if (reset_i || done)
        begin
          len_a_cnt <= '0;
          len_b_cnt <= '0;
        end
      else if (spm_internal_r_v_r & load & ~second_operand)
        begin
          vector_a[len_a_cnt] <= spm_data_lo;
          len_a_cnt <= len_a_cnt + 1'b1;
        end
      else if (spm_internal_r_v_r & load & second_operand)
        begin
          vector_b[len_b_cnt] <= spm_data_lo;
          len_b_cnt <= len_b_cnt + 1'b1;
        end
    end

  wire csr_w_v_li = w_v_li && (global_addr_lo.hio == 0);
  wire csr_r_v_li = r_v_li && (global_addr_lo.hio == 0);

  logic spm_internal_r_v_li, spm_internal_w_v_li;
  wire spm_external_w_v_li = w_v_li && (global_addr_lo.hio == 1);
  wire spm_external_r_v_li = r_v_li && (global_addr_lo.hio == 1);

  // SPM
  wire [paddr_width_p-1:0] spm_external_addr = addr_lo;
  wire [paddr_width_p-1:0] spm_internal_addr = load
                                               ? second_operand
                                                 ? (input_b_ptr+len_b_cnt*8)
                                                 : (input_a_ptr+len_a_cnt*8)
                                               : res_ptr;
  wire [paddr_width_p-1:0] spm_selected_addr =
    (spm_external_r_v_li | spm_external_w_v_li) ? spm_external_addr : spm_internal_addr;
  wire [`BSG_SAFE_CLOG2(20)-1:0] spm_addr_li = spm_selected_addr >> 3;
  wire [63:0] spm_data_li = spm_external_w_v_li ? io_fwd_data_i : vdp_result;
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
          inputa_ptr_csr_idx_gp : input_a_ptr <= io_fwd_data_i;
          inputb_ptr_csr_idx_gp : input_b_ptr <= io_fwd_data_i;
          input_len_csr_idx_gp  : input_len   <= io_fwd_data_i;
          start_cmd_csr_idx_gp  : start_cmd   <= io_fwd_data_i;
          res_ptr_csr_idx_gp    : res_ptr     <= io_fwd_data_i;
          res_len_csr_idx_gp    : res_len     <= io_fwd_data_i;
          operation_csr_idx_gp  : operation   <= io_fwd_data_i;
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

  logic spm_r_v_r;
  always_ff @(posedge clk_i)
    begin
      spm_internal_r_v_r <= spm_internal_r_v_li;
      spm_r_v_r <= spm_external_r_v_li | spm_internal_r_v_li;
    end
  assign data_li = spm_r_v_r ? spm_data_lo : csr_data_lo;

  always_comb
    begin
      spm_internal_w_v_li = '0;
      spm_internal_r_v_li = '0;

      load = 0;
      second_operand = 0;

      state_n = state_r;

      case (state_r)
        e_reset:
          begin
            load = 1;
            state_n = reset_i ? e_reset : e_wait_start;
          end
        e_wait_start:
          begin
            load = 1;
            state_n = start_cmd ? e_fetch_vec1 : e_wait_start;
          end
        e_fetch_vec1:
          begin
            spm_internal_r_v_li = '1;
            state_n = load ? (second_operand ? e_check_vec2_len : e_check_vec1_len) : e_done;
          end
        e_check_vec1_len:
          begin
            state_n = (len_a_cnt == input_len-1) ? e_fetch_vec2 : e_fetch_vec1;
          end
        e_fetch_vec2:
          begin
            second_operand = 1;
            state_n = e_fetch_vec1;
          end
        e_check_vec2_len:
          begin
            second_operand = 1;
            state_n = (len_b_cnt == input_len-1) ? e_wb_result : e_fetch_vec1;
          end
        e_wb_result:
          begin
            spm_internal_w_v_li = '1;
            state_n = e_done;
          end
        e_done:
          begin
            state_n = e_reset;
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


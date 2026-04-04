`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_sacc_scratchpad
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
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
  `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);

  function automatic logic [dword_width_gp-1:0]
    amo_data_result
     (input bp_bedrock_wr_subop_e subop_i
      , input logic [dword_width_gp-1:0] old_data_i
      , input logic [dword_width_gp-1:0] operand_i
      );
    logic signed [dword_width_gp-1:0] old_signed, op_signed;
    begin
      old_signed = old_data_i;
      op_signed = operand_i;
      unique case (subop_i)
        e_bedrock_amoswap: amo_data_result = operand_i;
        e_bedrock_amoadd : amo_data_result = old_data_i + operand_i;
        e_bedrock_amoxor : amo_data_result = old_data_i ^ operand_i;
        e_bedrock_amoand : amo_data_result = old_data_i & operand_i;
        e_bedrock_amoor  : amo_data_result = old_data_i | operand_i;
        e_bedrock_amomin : amo_data_result = (old_signed < op_signed) ? old_data_i : operand_i;
        e_bedrock_amomax : amo_data_result = (old_signed > op_signed) ? old_data_i : operand_i;
        e_bedrock_amominu: amo_data_result = (old_data_i < operand_i) ? old_data_i : operand_i;
        e_bedrock_amomaxu: amo_data_result = (old_data_i > operand_i) ? old_data_i : operand_i;
        default          : amo_data_result = old_data_i;
      endcase
    end
  endfunction

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [acache_fill_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_yumi_li;
  // Buffer one request and bridge ready->yumi handshake for local control.
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_mem_fwd_header_s)+acache_fill_width_p))
   fwd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({mem_fwd_data_i, mem_fwd_header_cast_i})
     ,.v_i(mem_fwd_v_i)
     ,.ready_and_o(mem_fwd_ready_and_o)

     ,.data_o({mem_fwd_data_li, mem_fwd_header_li})
     ,.v_o(mem_fwd_v_li)
     ,.yumi_i(mem_fwd_yumi_li)
     );

  bp_global_addr_s req_global_addr_lo;
  assign req_global_addr_lo = mem_fwd_header_li.addr;

  wire req_is_wr = (mem_fwd_header_li.msg_type == e_bedrock_mem_wr);
  wire req_is_rd = (mem_fwd_header_li.msg_type == e_bedrock_mem_rd);
  wire req_is_amo = (mem_fwd_header_li.msg_type == e_bedrock_mem_amo);
  wire req_is_spm = (req_global_addr_lo.hio == 1'b1);
  wire req_is_csr = (mem_fwd_header_li.addr inside {accel_wr_cnt_csr_idx_gp});
  logic [dword_width_gp-1:0] req_data;
  if (acache_fill_width_p >= dword_width_gp)
    begin : req_data_wide
      assign req_data = mem_fwd_data_li[0+:dword_width_gp];
    end
  else if (acache_fill_width_p > 0)
    begin : req_data_narrow
      assign req_data = {{(dword_width_gp-acache_fill_width_p){1'b0}}, mem_fwd_data_li};
    end
  else
    begin : req_data_none
      assign req_data = '0;
    end

  logic [dword_width_gp-1:0] pend_data_r;
  logic [paddr_width_p-1:0] pend_addr_r;
  bp_bedrock_wr_subop_e pend_subop_r;
  bp_bedrock_mem_fwd_header_s pend_header_r;
  logic pend_is_amo_r, pend_is_rd_r, pend_is_spm_r, pend_is_csr_r;

  typedef enum logic [0:0] {e_idle, e_wait_spm_read} state_e;
  state_e state_r;

  logic mem_rev_v_r;
  logic [dword_width_gp-1:0] mem_rev_data_r;
  bp_bedrock_mem_rev_header_s mem_rev_header_r;
  assign mem_rev_v_o = mem_rev_v_r;
  assign mem_rev_header_cast_o = mem_rev_header_r;

  // Pack 64b internal response data onto the outgoing Bedrock fill bus width.
  if (acache_fill_width_p > 0)
    begin : rev_data_pack
      localparam sel_width_lp = `BSG_SAFE_CLOG2(dword_width_gp>>3);
      localparam size_width_lp = `BSG_SAFE_CLOG2(sel_width_lp);
      bsg_bus_pack
       #(.in_width_p(dword_width_gp), .out_width_p(acache_fill_width_p))
       rev_bus_pack
        (.data_i(mem_rev_data_r)
         ,.sel_i('0)
         ,.size_i(mem_rev_header_cast_o.size[0+:size_width_lp])
         ,.data_o(mem_rev_data_o)
         );
    end
  else
    begin : rev_data_zero
      assign mem_rev_data_o = '0;
    end

  logic [paddr_width_p-1:0] spm_req_addr_li;
  logic [dword_width_gp-1:0] spm_req_data_li;
  logic spm_req_v_li, spm_req_w_li;

  logic [dword_width_gp-1:0] spm_data_lo;
  logic [`BSG_SAFE_CLOG2(20)-1:0] spm_addr_li;
  logic [9:0] spm_write_cnt;
  bsg_counter_clear_up
   #(.max_val_p(2**10-1), .init_val_p(0))
   write_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(spm_req_v_li & spm_req_w_li)
     ,.count_o(spm_write_cnt)
     );
  wire [dword_width_gp-1:0] csr_data_lo = spm_write_cnt;

  assign spm_addr_li = spm_req_addr_li >> 3;
  bsg_mem_1rw_sync
    #(.width_p(64), .els_p(20))
    accel_spm
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(spm_req_data_li)
      ,.addr_i(spm_addr_li)
      ,.v_i(spm_req_v_li)
      ,.w_i(spm_req_w_li)
      ,.data_o(spm_data_lo)
      );

  logic lr_v_r;
  logic [paddr_width_p-1:0] lr_addr_r;

  // SC succeeds only if there is a valid reservation for the same address.
  wire sc_success = lr_v_r & (lr_addr_r == pend_addr_r);
  wire [dword_width_gp-1:0] amo_new_data = amo_data_result(pend_subop_r, spm_data_lo, pend_data_r);
  wire [dword_width_gp-1:0] sc_resp_data = {{(dword_width_gp-1){1'b0}}, ~sc_success};

  // Sequential state: holds pending request context and output-valid until handshake.
  always_ff @(posedge clk_i)
    begin
      if (reset_i)
        begin
          state_r <= e_idle;
          mem_rev_v_r <= 1'b0;
          mem_rev_data_r <= '0;
          mem_rev_header_r <= '0;
          pend_data_r <= '0;
          pend_addr_r <= '0;
          pend_subop_r <= e_bedrock_store;
          pend_header_r <= '0;
          pend_is_amo_r <= 1'b0;
          pend_is_rd_r <= 1'b0;
          pend_is_spm_r <= 1'b0;
          pend_is_csr_r <= 1'b0;
          lr_v_r <= 1'b0;
          lr_addr_r <= '0;
        end
      else
        begin
          // Drop response valid after downstream consumes it.
          if (mem_rev_v_r & mem_rev_ready_and_i)
            mem_rev_v_r <= 1'b0;

          unique case (state_r)
            e_idle:
              if (mem_fwd_v_li & ~mem_rev_v_r)
                begin
                  // SPM reads/AMOs need a synchronous memory read before response.
                  if (req_is_spm & (req_is_rd | req_is_amo))
                    begin
                      pend_header_r <= mem_fwd_header_li;
                      pend_data_r <= req_data;
                      pend_addr_r <= mem_fwd_header_li.addr;
                      pend_subop_r <= mem_fwd_header_li.subop;
                      pend_is_amo_r <= req_is_amo;
                      pend_is_rd_r <= req_is_rd;
                      pend_is_spm_r <= req_is_spm;
                      pend_is_csr_r <= req_is_csr;
                      state_r <= e_wait_spm_read;
                    end
                  else
                    begin
                      // CSR/direct path can respond immediately without SPM read latency.
                      mem_rev_header_r <= mem_fwd_header_li;
                      if (req_is_csr)
                        mem_rev_data_r <= csr_data_lo;
                      else
                        mem_rev_data_r <= '0;
                      mem_rev_v_r <= 1'b1;

                      if (req_is_amo & (mem_fwd_header_li.subop == e_bedrock_amolr))
                        begin
                          lr_v_r <= 1'b1;
                          lr_addr_r <= mem_fwd_header_li.addr;
                        end
                      else if (req_is_wr | req_is_amo)
                        lr_v_r <= 1'b0;
                    end
                end

            e_wait_spm_read:
              if (~mem_rev_v_r)
                begin
                  // Return the old value for read/AMO after SPM data is available.
                  mem_rev_header_r <= pend_header_r;
                  mem_rev_data_r <= spm_data_lo;
                  mem_rev_v_r <= 1'b1;

                  if (pend_is_amo_r)
                    begin
                      if (pend_subop_r == e_bedrock_amolr)
                        begin
                          lr_v_r <= 1'b1;
                          lr_addr_r <= pend_addr_r;
                        end
                      else if (pend_subop_r == e_bedrock_amosc)
                        lr_v_r <= 1'b0;
                      else
                        lr_v_r <= 1'b0;

                      if (pend_subop_r == e_bedrock_amosc)
                        mem_rev_data_r <= sc_resp_data;
                    end

                  state_r <= e_idle;
                end
          endcase
        end
    end

  // Combinational control: derive RAM request pulses from current state/request type.
  always_comb
    begin
      mem_fwd_yumi_li = 1'b0;
      spm_req_v_li = 1'b0;
      spm_req_w_li = 1'b0;
      spm_req_data_li = '0;
      spm_req_addr_li = '0;

      unique case (state_r)
        e_idle:
          if (mem_fwd_v_li & ~mem_rev_v_r)
            begin
              mem_fwd_yumi_li = 1'b1;
              if (req_is_spm & (req_is_rd | req_is_amo))
                begin
                  spm_req_v_li = 1'b1;
                  spm_req_w_li = 1'b0;
                  spm_req_addr_li = mem_fwd_header_li.addr;
                end
              else if (req_is_spm & req_is_wr)
                begin
                  spm_req_v_li = 1'b1;
                  spm_req_w_li = 1'b1;
                  spm_req_addr_li = mem_fwd_header_li.addr;
                  spm_req_data_li = req_data;
                end
            end

        e_wait_spm_read:
          if (~mem_rev_v_r & pend_is_amo_r)
            begin
              // For SC, write back only on successful reservation check.
              if (pend_subop_r == e_bedrock_amosc)
                begin
                  if (sc_success)
                    begin
                      spm_req_v_li = 1'b1;
                      spm_req_w_li = 1'b1;
                      spm_req_addr_li = pend_addr_r;
                      spm_req_data_li = pend_data_r;
                    end
                end
              else if (pend_subop_r != e_bedrock_amolr)
                begin
                  spm_req_v_li = 1'b1;
                  spm_req_w_li = 1'b1;
                  spm_req_addr_li = pend_addr_r;
                  spm_req_data_li = amo_new_data;
                end
            end
      endcase
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_sacc_scratchpad)


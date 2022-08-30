`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_sacc_scratchpad
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   , localparam cfg_bus_width_lp= `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [lce_id_width_p-1:0]                 lce_id_i

   , input [mem_header_width_lp-1:0]            io_cmd_header_i
   , input [acache_fill_width_p-1:0]            io_cmd_data_i
   , input                                      io_cmd_v_i
   , input                                      io_cmd_last_i
   , output logic                               io_cmd_ready_and_o

   , output logic [mem_header_width_lp-1:0]     io_resp_header_o
   , output logic [acache_fill_width_p-1:0]     io_resp_data_o
   , output logic                               io_resp_v_o
   , output logic                               io_resp_last_o
   , input                                      io_resp_ready_and_i
   );

  //synopsys translate_off
  always_ff @(negedge clk_i) begin
    assert(~io_cmd_v_i | (io_cmd_v_i & io_cmd_last_i))
      else $error("sacc_vdp only supports single beat IO commands");
  end
  //synopsys translate_on

  // CCE-IO interface is used for uncached requests-read/write memory mapped CSR
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `bp_cast_i(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_resp_header);

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

     ,.mem_cmd_header_i(io_cmd_header_cast_i)
     ,.mem_cmd_data_i(io_cmd_data_i)
     ,.mem_cmd_v_i(io_cmd_v_i)
     ,.mem_cmd_ready_and_o(io_cmd_ready_and_o)
     ,.mem_cmd_last_i(io_cmd_last_i)

     ,.mem_resp_header_o(io_resp_header_cast_o)
     ,.mem_resp_data_o(io_resp_data_o)
     ,.mem_resp_v_o(io_resp_v_o)
     ,.mem_resp_ready_and_i(io_resp_ready_and_i)
     ,.mem_resp_last_o(io_resp_last_o)

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
 
  wire csr_w_v_li = w_v_li && (addr_lo inside {accel_wr_cnt_csr_idx_gp});
  wire csr_r_v_li = r_v_li && (addr_lo inside {accel_wr_cnt_csr_idx_gp});
  wire [dword_width_gp-1:0] csr_data_li = data_lo;

  wire spm_w_v_li = w_v_li && (global_addr_lo.hio == 1);
  wire spm_r_v_li = r_v_li && (global_addr_lo.hio == 1);
  wire [dword_width_gp-1:0] spm_data_li = data_lo;

  logic [dword_width_gp-1:0] spm_data_lo;
  logic [`BSG_SAFE_CLOG2(20)-1:0] spm_addr_li;
  logic [9:0] spm_write_cnt;
  bsg_counter_clear_up
   #(.max_val_p(2**10-1), .init_val_p(0))
   write_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(spm_w_v_li)
     ,.count_o(spm_write_cnt)
     );
  wire [dword_width_gp-1:0] csr_data_lo = spm_write_cnt;

  assign spm_addr_li = addr_lo >> 3;
  bsg_mem_1rw_sync
    #(.width_p(64), .els_p(20))
    accel_spm
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(spm_data_li)
      ,.addr_i(spm_addr_li)
      ,.v_i(spm_r_v_li | spm_w_v_li)
      ,.w_i(spm_w_v_li)
      ,.data_o(spm_data_lo)
      );

  logic spm_r_v_r;
  always_ff @(posedge clk_i)
    spm_r_v_r <= spm_r_v_li;

  assign data_li = spm_r_v_r ? spm_data_lo : csr_data_lo;

endmodule

`BSG_ABSTRACT_MODULE(bp_sacc_scratchpad)


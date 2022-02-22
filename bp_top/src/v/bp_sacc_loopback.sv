`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_sacc_loopback
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   , localparam cfg_bus_width_lp= `bp_cfg_bus_width(hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
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

  // CCE-IO interface is used for uncached requests-read/write memory mapped CSR
  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);
  `bp_cast_i(bp_bedrock_mem_header_s, io_cmd_header);
  `bp_cast_o(bp_bedrock_mem_header_s, io_resp_header);

  assign io_cmd_ready_and_o = 1'b1;

  logic [63:0] spm_data_lo, spm_data_li, csr_data, spm_write_cnt;
  logic [paddr_width_p-1:0]  resp_addr;

  logic [vaddr_width_p-1:0] spm_addr;
  logic spm_read_v_li, spm_write_v_li, spm_v_lo, resp_v_lo;

  bp_bedrock_mem_payload_s  resp_payload;
  bp_bedrock_msg_size_e         resp_size;
  bp_bedrock_mem_type_e         resp_msg;
  bp_local_addr_s           local_addr_li;
  bp_global_addr_s          global_addr_li;

  assign global_addr_li = io_cmd_header_cast_i.addr;
  assign local_addr_li = io_cmd_header_cast_i.addr;

  assign io_resp_header_cast_o = '{msg_type       : resp_msg
                                   ,addr          : resp_addr
                                   ,payload       : resp_payload
                                   ,subop         : e_bedrock_store
                                   ,size          : resp_size
                                   };
  assign io_resp_data_o = spm_v_lo ? spm_data_lo : csr_data;

  assign io_resp_v_o = spm_v_lo | resp_v_lo;
  assign io_resp_last_o = io_resp_v_o;
  always_ff @(posedge clk_i) begin
    spm_v_lo <= spm_read_v_li;

    if (reset_i) begin
      spm_v_lo <= '0;
      resp_v_lo <= 0;
      spm_read_v_li  <= '0;
      spm_write_v_li <= '0;
      spm_write_cnt  <= '0;
    end
    else if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_rd) & (global_addr_li.hio == '0))
    begin
      resp_size    <= io_cmd_header_cast_i.size;
      resp_payload <= io_cmd_header_cast_i.payload;
      resp_addr    <= io_cmd_header_cast_i.addr;
      resp_msg     <= bp_bedrock_mem_type_e'(io_cmd_header_cast_i.msg_type);
      spm_read_v_li  <= '0;
      spm_write_v_li <= '0;
      resp_v_lo <= 1;
      unique
      case (local_addr_li.addr)
        accel_wr_cnt_csr_idx_gp : csr_data <= spm_write_cnt;
        default : begin end
      endcase
    end
    else if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_wr) & (global_addr_li.hio == 1))
    begin
      resp_size    <= io_cmd_header_cast_i.size;
      resp_payload <= io_cmd_header_cast_i.payload;
      resp_addr    <= io_cmd_header_cast_i.addr;
      resp_msg     <= bp_bedrock_mem_type_e'(io_cmd_header_cast_i.msg_type);
      spm_write_v_li <= '1;
      spm_write_cnt  <= spm_write_cnt + 1;
      spm_read_v_li  <= '0;
      resp_v_lo <= 1;
      spm_data_li  <= io_cmd_data_i;
      spm_addr <= io_cmd_header_cast_i.addr;
    end
    else if (io_cmd_v_i & (io_cmd_header_cast_i.msg_type == e_bedrock_mem_uc_rd) & (global_addr_li.hio == 1))
    begin
      resp_size    <= io_cmd_header_cast_i.size;
      resp_payload <= io_cmd_header_cast_i.payload;
      resp_addr    <= io_cmd_header_cast_i.addr;
      resp_msg     <= bp_bedrock_mem_type_e'(io_cmd_header_cast_i.msg_type);
      spm_read_v_li  <= '1;
      spm_write_v_li <= '0;
      resp_v_lo <= 0;
      spm_addr <= io_cmd_header_cast_i.addr;
    end
    else
    begin
      spm_write_v_li <= '0;
      spm_read_v_li  <= '0;
      resp_v_lo <= 0;
      end
  end


  //SPM
  wire [`BSG_SAFE_CLOG2(20)-1:0] spm_addr_li = spm_addr >> 3;
  bsg_mem_1rw_sync
    #(.width_p(64), .els_p(20))
    accel_spm
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.data_i(spm_data_li)
      ,.addr_i(spm_addr_li)
      ,.v_i(spm_read_v_li | spm_write_v_li)
      ,.w_i(spm_write_v_li)
      ,.data_o(spm_data_lo)
      );

endmodule


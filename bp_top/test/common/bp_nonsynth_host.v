
module bp_nonsynth_host
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input clk_i
   , input reset_i

   , input [cce_mem_msg_width_lp-1:0]              io_cmd_i
   , input                                         io_cmd_v_i
   , output logic                                  io_cmd_ready_o

   , output logic [cce_mem_msg_width_lp-1:0]       io_resp_o
   , output logic                                  io_resp_v_o
   , input                                         io_resp_yumi_i

   , output [num_core_p-1:0]                       program_finish_o
   );

import "DPI-C" context function void start();
import "DPI-C" context function int scan();
import "DPI-C" context function void pop();

logic [63:0] ch;
initial begin
  start();
end

always_ff @(posedge clk_i) begin
  ch = scan();
end

`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

// HOST I/O mappings
//localparam host_dev_base_addr_gp     = 32'h03??_????;

// Host I/O mappings (arbitrarily decided for now)
//   Overall host controls 32'h0300_0000-32'h03FF_FFFF

localparam getchar_base_addr_gp = paddr_width_p'(64'h0010_0000);
localparam putchar_base_addr_gp = paddr_width_p'(64'h0010_1000);
localparam finish_base_addr_gp  = paddr_width_p'(64'h0010_2???);

bp_cce_mem_msg_s  io_cmd_cast_i;

assign io_cmd_cast_i = io_cmd_i;

localparam lg_num_core_lp = `BSG_SAFE_CLOG2(num_core_p);

logic putchar_data_cmd_v;
logic getchar_data_cmd_v;
logic finish_data_cmd_v;

always_comb
  begin
    putchar_data_cmd_v = 1'b0;
    getchar_data_cmd_v = 1'b0;
    finish_data_cmd_v = 1'b0;

    unique
    casez (io_cmd_cast_i.header.addr)
      putchar_base_addr_gp: putchar_data_cmd_v = io_cmd_v_i; 
      getchar_base_addr_gp: getchar_data_cmd_v = io_cmd_v_i;
      finish_base_addr_gp: finish_data_cmd_v = io_cmd_v_i;
      default: begin end
    endcase
  end

logic [num_core_p-1:0] finish_w_v_li;

// Memory-mapped I/O is 64 bit aligned
localparam byte_offset_width_lp = 3;
wire [lg_num_core_lp-1:0] io_cmd_core_enc =
  io_cmd_cast_i.header.addr[byte_offset_width_lp+:lg_num_core_lp];

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 finish_data_cmd_decoder
  (.v_i(finish_data_cmd_v)
   ,.i(io_cmd_core_enc)

   ,.o(finish_w_v_li)
   );

logic [num_core_p-1:0] finish_r;
bsg_dff_reset
 #(.width_p(num_core_p))
 finish_accumulator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(finish_r | finish_w_v_li)
   ,.data_o(finish_r)
   );

logic all_finished_r;
bsg_dff_reset
 #(.width_p(1))
 all_finished_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(&finish_r)
   ,.data_o(all_finished_r)
   );

assign program_finish_o = finish_r;
logic [2:0] domain_id;
assign domain_id = io_cmd_cast_i.header.addr[paddr_width_p-1-:3];

always_ff @(negedge clk_i)
  begin
    if (putchar_data_cmd_v & io_cmd_v_i) begin
      $write("%c", io_cmd_cast_i.data[0+:8]);
      $fflush(32'h8000_0001);
    end
    if (getchar_data_cmd_v & io_cmd_v_i)
      pop();

    if (io_cmd_v_i & (domain_id != '0))
      $display("Warning: Accesing domain: %0h", domain_id);
    for (integer i = 0; i < num_core_p; i++)
      begin
        // PASS when returned value in finish packet is zero
        if (finish_w_v_li[i] & io_cmd_v_i &
          (io_cmd_cast_i.data[0+:8] == 8'(0)))
          $display("[CORE%0x FSH] PASS", i);
        // FAIL when returned value in finish packet is non-zero
        if (finish_w_v_li[i] & io_cmd_v_i &
          (io_cmd_cast_i.data[0+:8] != 8'(0)))
          $display("[CORE%0x FSH] FAIL", i);
      end

    if (all_finished_r)
      begin
        $display("All cores finished! Terminating...");
        $finish();
      end
  end

bp_cce_mem_msg_s io_resp_lo, core_io_resp_lo, domain_io_resp_lo;
assign io_resp_lo = (domain_id != '0) ? domain_io_resp_lo : core_io_resp_lo;
bsg_two_fifo
 #(.width_p($bits(bp_cce_mem_msg_s)))
 io_resp_buffer
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(io_resp_lo)
   ,.v_i(io_cmd_v_i)
   ,.ready_o(io_cmd_ready_o)

   ,.data_o(io_resp_o)
   ,.v_o(io_resp_v_o)
   ,.yumi_i(io_resp_yumi_i)
   );

assign core_io_resp_lo =
  '{header: '{msg_type : io_cmd_cast_i.header.msg_type
              ,addr    : io_cmd_cast_i.header.addr
              ,payload : io_cmd_cast_i.header.payload
              ,size    : io_cmd_cast_i.header.size
              }
    ,data : ch
    };

assign domain_io_resp_lo =
  '{header: '{msg_type              : io_cmd_cast_i.header.msg_type
              ,addr                 : io_cmd_cast_i.header.addr
              ,payload: '{state        : io_cmd_cast_i.header.payload.state
                         ,way_id       : io_cmd_cast_i.header.payload.way_id
                         ,prefetch     : io_cmd_cast_i.header.payload.prefetch
                         ,uncached     : io_cmd_cast_i.header.payload.uncached
                         ,speculative  : io_cmd_cast_i.header.payload.speculative
                         ,lce_id       : lce_id_width_p'(3)
                         }
              ,size                 : io_cmd_cast_i.header.size
              }
    ,data : '0
    };

endmodule


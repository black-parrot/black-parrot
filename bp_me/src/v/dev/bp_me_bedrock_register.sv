
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

//
// This module is used to interface a BP Stream interface to a general-purpose
//   register read/write interface. The data is stored externally so that
//   control/status registers can be controlled by this interface while
//   retaining special semantics. Registers are assumed to be synchronous
//   read/write which is compatible (although suboptimal) for asynchronous
//   registers.
module bp_me_bedrock_register
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)

   // The width of the registers. Currently, must all be the same.
   , parameter reg_width_p = dword_width_gp
   // The address width of the registers. For addresses less than paddr_width_p,
   //   the upper bits of the paddr are ignored for matching purposes
   , parameter reg_addr_width_p = paddr_width_p
   // The number of registers to control
   , parameter els_p = 1

   // We would like to use unpacked here, but Verilator 4.202 does not support it
   // Unsupported tristate construct: INITITEM
   //// An unpacked array of integer register base addresses
   ////   e.g. localparam integer base_addr_lp [1:0] = '{0xf00bad, 0x00cafe}
   //// Can also accept pattern matches such as 0x8???
   //, parameter integer base_addr_p [els_p-1:0] = '{0}
   , parameter [els_p-1:0][reg_addr_width_p-1:0] base_addr_p = '0

   , localparam lg_reg_width_lp = `BSG_WIDTH(`BSG_SAFE_CLOG2(reg_width_p/8))
   )
  (input                                            clk_i
   , input                                          reset_i

   // Network-side BP-Stream interface
   , input [xce_mem_msg_header_width_lp-1:0]        mem_cmd_header_i
   , input [dword_width_gp-1:0]                     mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , output logic                                   mem_cmd_ready_and_o
   , input                                          mem_cmd_last_i

   , output logic [xce_mem_msg_header_width_lp-1:0] mem_resp_header_o
   , output logic [dword_width_gp-1:0]              mem_resp_data_o
   , output logic                                   mem_resp_v_o
   , input                                          mem_resp_ready_and_i
   , output logic                                   mem_resp_last_o


   // Synchronous register read/write interface.
   // Actually 1rw, but expose both ports to prevent unnecessary and gates
   // Assume latch last read behavior at registers, and do not have
   //   unnecessary read/writes. This could be parameterizable, but requires
   //   a read register in this module to do and maintain helpfulness
   , output logic [els_p-1:0]                       r_v_o
   , output logic [els_p-1:0]                       w_v_o
   , output logic [reg_addr_width_p-1:0]            addr_o
   , output logic [lg_reg_width_lp-1:0]             size_o
   , output logic [reg_width_p-1:0]                 data_o
   , input [els_p-1:0][reg_width_p-1:0]             data_i
   );

  wire unused = &{mem_cmd_last_i};

  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);

  bp_bedrock_xce_mem_msg_header_s mem_cmd_header_li;
  logic [dword_width_gp-1:0] mem_cmd_data_li;
  logic mem_cmd_v_li, mem_cmd_yumi_li;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_xce_mem_msg_s)))
   cmd_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.data_i({mem_cmd_data_i, mem_cmd_header_i})
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_and_o)
  
     ,.data_o({mem_cmd_data_li, mem_cmd_header_li})
     ,.v_o(mem_cmd_v_li)
     ,.yumi_i(mem_cmd_yumi_li)
     );

  logic v_r;
  wire wr_not_rd  = (mem_cmd_header_li.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr});
  wire rd_not_wr  = (mem_cmd_header_li.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr});
  wire v_n = mem_cmd_v_li & ~v_r;
  logic [els_p-1:0] r_v_r;
  bsg_dff_reset_set_clear
   #(.width_p(1+els_p), .clear_over_set_p(1))
   v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     // We also track reads which don't match to prevent deadlock
     ,.set_i({v_n, r_v_o})
     ,.clear_i({(els_p+1){mem_cmd_yumi_li}})
     ,.data_o({v_r, r_v_r})
     );

  logic [reg_width_p-1:0] rdata_lo;
  bsg_mux_one_hot
   #(.width_p(reg_width_p), .els_p(els_p))
   rmux_oh
    (.data_i(data_i)
     ,.sel_one_hot_i(r_v_r)
     ,.data_o(rdata_lo)
     );

  for (genvar i = 0; i < els_p; i++)
    begin : dec
      wire addr_match = mem_cmd_v_li & (mem_cmd_header_li.addr[0+:reg_addr_width_p] inside {base_addr_p[i]});
      assign r_v_o[i] = ~v_r & addr_match & ~wr_not_rd;
      assign w_v_o[i] = ~v_r & addr_match &  wr_not_rd;
    end
      assign addr_o = (mem_cmd_header_li.addr);
      assign size_o = (mem_cmd_header_li.size);
      assign data_o = (mem_cmd_data_li);

  assign mem_resp_header_o = mem_cmd_header_li;
  assign mem_resp_data_o = rdata_lo;
  assign mem_resp_v_o = v_r;
  assign mem_resp_last_o = mem_resp_v_o;
  assign mem_cmd_yumi_li = mem_resp_ready_and_i & mem_resp_v_o;

  //synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      assert (~mem_cmd_v_li | (v_r | ~wr_not_rd | |w_v_o) | (v_r | ~rd_not_wr | |r_v_o))
        else $error("Command to non-existent register: %x", addr_o);
    end
  //synopsys translate_on

endmodule


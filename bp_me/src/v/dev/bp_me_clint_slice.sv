
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_clint_slice
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)
   )
  (input                                                clk_i
   , input                                              reset_i

   , input [xce_mem_msg_header_width_lp-1:0]            mem_cmd_header_i
   , input [dword_width_gp-1:0]                         mem_cmd_data_i
   , input                                              mem_cmd_v_i
   , output logic                                       mem_cmd_ready_and_o
   , input                                              mem_cmd_last_i

   , output logic [xce_mem_msg_header_width_lp-1:0]     mem_resp_header_o
   , output logic [dword_width_gp-1:0]                  mem_resp_data_o
   , output logic                                       mem_resp_v_o
   , input                                              mem_resp_ready_and_i
   , output logic                                       mem_resp_last_o

   // Local interrupts
   , output logic                                       software_irq_o
   , output logic                                       timer_irq_o
   , output logic                                       external_irq_o
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);
  `declare_bp_memory_map(paddr_width_p, daddr_width_p);

  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [3:0][dword_width_gp-1:0] data_li;
  logic plic_w_v_li, mtime_w_v_li, mtimecmp_w_v_li, mipi_w_v_li;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.els_p(4)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.base_addr_p({plic_reg_addr_gp, mtime_reg_match_addr_gp, mtimecmp_reg_match_addr_gp, mipi_reg_match_addr_gp})
     )
   register
    (.*
     // We ignore reads because these are all asynchronous registers
     ,.r_v_o()
     ,.w_v_o({plic_w_v_li, mtime_w_v_li, mtimecmp_w_v_li, mipi_w_v_li})
     ,.addr_o(addr_lo)
     ,.size_o()
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );

  // TODO: Should be actual RTC, or at least programmable
  localparam ds_width_lp = 5;
  localparam [ds_width_lp-1:0] ds_ratio_li = 8;
  logic mtime_inc_li;
  bsg_strobe
   #(.width_p(ds_width_lp))
   bsg_rtc_strobe
    (.clk_i(clk_i)
     ,.reset_r_i(reset_i)
     ,.init_val_r_i(ds_ratio_li)
     ,.strobe_r_o(mtime_inc_li)
     );
  logic [dword_width_gp-1:0] mtime_r;
  wire [dword_width_gp-1:0] mtime_n = data_lo;
  bsg_counter_set_en
   #(.max_val_p(0) // max_val_p is unused but must be set
     ,.lg_max_val_lp(dword_width_gp) // Use lg_max_val_lp because of 64-bit parameter restriction
     ,.reset_val_p(0)
     )
   mtime_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.set_i(mtime_w_v_li)
     ,.en_i(mtime_inc_li)
     ,.val_i(mtime_n)
     ,.count_o(mtime_r)
     );

  logic [dword_width_gp-1:0] mtimecmp_r;
  wire [dword_width_gp-1:0] mtimecmp_n = data_lo;
  bsg_dff_reset_en
   #(.width_p(dword_width_gp))
   mtimecmp_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(mtimecmp_w_v_li)
     ,.data_i(mtimecmp_n)
     ,.data_o(mtimecmp_r)
     );
  assign timer_irq_o = (mtime_r >= mtimecmp_r);

  logic mipi_r;
  wire mipi_n = data_lo[0];
  bsg_dff_reset_en
   #(.width_p(1))
   mipi_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(mipi_w_v_li)

     ,.data_i(mipi_n)
     ,.data_o(mipi_r)
     );
  assign software_irq_o = mipi_r;

  logic plic_r;
  wire plic_n = data_lo[0];
  bsg_dff_reset_en
   #(.width_p(1))
   plic_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(plic_w_v_li)

     ,.data_i(plic_n)
     ,.data_o(plic_r)
     );
  assign external_irq_o = plic_r;

  assign data_li[0] = mipi_r;
  assign data_li[1] = mtimecmp_r;
  assign data_li[2] = mtime_r;
  assign data_li[3] = plic_r;

endmodule


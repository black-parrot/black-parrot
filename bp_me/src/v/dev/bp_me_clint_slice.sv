/**
 *
 * Name:
 *   bp_me_clint_slice.sv
 *
 * Description:
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_clint_slice
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                                clk_i
   , input                                              rt_clk_i
   , input                                              reset_i

   , input [core_id_width_p-1:0]                        id_i

   , input [mem_header_width_lp-1:0]                    mem_cmd_header_i
   , input [dword_width_gp-1:0]                         mem_cmd_data_i
   , input                                              mem_cmd_v_i
   , output logic                                       mem_cmd_ready_and_o
   , input                                              mem_cmd_last_i

   , output logic [mem_header_width_lp-1:0]             mem_resp_header_o
   , output logic [dword_width_gp-1:0]                  mem_resp_data_o
   , output logic                                       mem_resp_v_o
   , input                                              mem_resp_ready_and_i
   , output logic                                       mem_resp_last_o

   // Local interrupts
   , output logic                                       software_irq_o
   , output logic                                       timer_irq_o
   , output logic                                       m_external_irq_o
   , output logic                                       s_external_irq_o
   );

  if (dword_width_gp != 64) $error("BedRock interface data width must be 64-bits");

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, caddr_width_p);

  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [3:0][dword_width_gp-1:0] data_li;
  logic plic_w_v_li;
  logic mtime_w_v_li, mtimecmp_w_v_li, mipi_w_v_li;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.els_p(4)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.base_addr_p({plic_reg_match_addr_gp, mtime_reg_addr_gp,
            mtimecmp_reg_match_addr_gp, mipi_reg_match_addr_gp})
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

  logic [dword_width_gp-1:0] mtime_gray_r;
  bsg_async_ptr_gray
   #(.lg_size_p(dword_width_gp), .use_async_reset_p(1))
   mtime_gray
    (.w_clk_i(rt_clk_i)
     ,.w_reset_i(reset_i) // async to rtc
     ,.w_inc_i(1'b1) // TODO: Enable / disable increment?
     ,.r_clk_i(clk_i)
     ,.w_ptr_binary_r_o()
     ,.w_ptr_gray_r_o()
     ,.w_ptr_gray_r_rsync_o(mtime_gray_r)
     );
  // Cannot write the RTC. If needed, raise an issue
  wire unused = mtime_w_v_li;

  logic [dword_width_gp-1:0] mtime_r;
  bsg_gray_to_binary
   #(.width_p(dword_width_gp))
   g2b
    (.gray_i(mtime_gray_r)
     ,.binary_o(mtime_r)
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

  // This scheme can be used for N PLIC bits, which may be required in
  //   a distributed PLIC scheme. However, for now we only support
  //   M and S mode external interrupts. This code doesn't work for
  //   only a single PLIC bit.
  localparam plic_els_lp = 2;
  localparam lg_plic_els_lp = `BSG_SAFE_CLOG2(plic_els_lp);
  logic [plic_els_lp-1:0] plic_n, plic_r;
  wire [lg_plic_els_lp-1:0] plic_addr_li = addr_lo[2+:lg_plic_els_lp];

  always_comb
    begin
      plic_n = plic_r;
      plic_n[plic_addr_li] = data_lo[0];
    end

  bsg_dff_reset_en
   #(.width_p(plic_els_lp))
   plic_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(plic_w_v_li)
     ,.data_i(plic_n)
     ,.data_o(plic_r)
     );
  wire plic_lo = plic_r[plic_addr_li];

  assign m_external_irq_o = plic_r[0];
  assign s_external_irq_o = plic_r[1];

  assign data_li[0] = mipi_r;
  assign data_li[1] = mtimecmp_r;
  assign data_li[2] = mtime_r;
  assign data_li[3] = plic_lo;

endmodule


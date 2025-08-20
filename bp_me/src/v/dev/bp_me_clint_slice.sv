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
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
   )
  (input                                                clk_i
   , input                                              rt_clk_i
   , input                                              reset_i

   , input [cfg_bus_width_lp-1:0]                       cfg_bus_i

   , input [mem_fwd_header_width_lp-1:0]                mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]                   mem_fwd_data_i
   , input                                              mem_fwd_v_i
   , output logic                                       mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]         mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]            mem_rev_data_o
   , output logic                                       mem_rev_v_o
   , input                                              mem_rev_ready_and_i

   // Local interrupts
   , output logic                                       debug_irq_o
   , output logic                                       software_irq_o
   , output logic                                       timer_irq_o
   , output logic                                       m_external_irq_o
   , output logic                                       s_external_irq_o
   );

  if (dword_width_gp != 64) $error("BedRock interface data width must be 64-bits");

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bp_memory_map(paddr_width_p, caddr_width_p);
  `bp_cast_i(bp_cfg_bus_s, cfg_bus);

  localparam reg_els_lp = 6;

  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [reg_els_lp-1:0][dword_width_gp-1:0] data_li;
  logic debug_w_v_li;
  logic plic_w_v_li;
  logic mtime_w_v_li, mtimesel_w_v_li, mtimecmp_w_v_li, mipi_w_v_li;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.reg_data_width_p(dword_width_gp)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.els_p(reg_els_lp)
     ,.base_addr_p({debug_reg_match_addr_gp, plic_reg_match_addr_gp, mtime_reg_addr_gp, mtimesel_reg_match_addr_gp, mtimecmp_reg_match_addr_gp, mipi_reg_match_addr_gp})
     )
   clints_register
    (.*
     // We ignore reads because these are all asynchronous registers
     ,.r_v_o()
     ,.w_v_o({debug_w_v_li, plic_w_v_li, mtime_w_v_li, mtimesel_w_v_li, mtimecmp_w_v_li, mipi_w_v_li})
     ,.addr_o(addr_lo)
     ,.size_o()
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );

  logic [1:0] mtimesel_r;
  wire [1:0] mtimesel_n = data_lo;
  bsg_dff_reset_en
   #(.width_p(2))
   mtimesel_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.en_i(mtimesel_w_v_li)
     ,.data_i(mtimesel_n)
     ,.data_o(mtimesel_r)
     );

  // 8:1 downsample
  logic clk_ds_lo;
  bsg_counter_clock_downsample
   #(.width_p(3))
   ds
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.val_i(3'b111)
     ,.clk_r_o(clk_ds_lo)
     );

  logic rt_clk_lo;
  bsg_mux
   #(.width_p(1), .els_p(4), .harden_p(1))
   rtc_mux
    (.data_i({1'b0, rt_clk_i, clk_ds_lo, clk_i})
     ,.sel_i(mtimesel_r)
     ,.data_o(rt_clk_lo)
     );

  logic [dword_width_gp-1:0] mtime_gray_r;
  bsg_async_ptr_gray
   #(.lg_size_p(dword_width_gp))
   mtime_gray
    (.w_clk_i(rt_clk_lo)
     ,.w_reset_i(reset_i)
     ,.w_inc_i(1'b1) // Can enable / disable through mtimesel
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
  wire [lg_plic_els_lp-1:0] plic_addr_li = addr_lo[3+:lg_plic_els_lp];

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

  logic debug_r;
  wire debug_n = data_lo[0];
  bsg_dff_reset_en
   #(.width_p(1))
   debug_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(debug_w_v_li)
     ,.data_i(debug_n)
     ,.data_o(debug_r)
     );
  assign debug_irq_o = debug_r;

  assign data_li[0] = mipi_r;
  assign data_li[1] = mtimecmp_r;
  assign data_li[2] = mtimesel_r;
  assign data_li[3] = mtime_r;
  assign data_li[4] = plic_lo;
  assign data_li[5] = debug_r;

endmodule


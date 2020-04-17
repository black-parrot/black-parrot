
module bp_clint_slice
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   // TODO: Should I be a global param?
   , localparam clint_max_outstanding_p = 2
   )
  (input                                                clk_i
   , input                                              reset_i

   , input [cce_mem_msg_width_lp-1:0]                   mem_cmd_i
   , input                                              mem_cmd_v_i
   , output                                             mem_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]                  mem_resp_o
   , output                                             mem_resp_v_o
   , input                                              mem_resp_yumi_i

   // Local interrupts
   , output                                             software_irq_o
   , output                                             timer_irq_o
   , output                                             external_irq_o
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

bp_cce_mem_msg_s mem_cmd_li, mem_cmd_lo;
assign mem_cmd_li = mem_cmd_i;

logic small_fifo_v_lo, small_fifo_yumi_li;
bsg_fifo_1r1w_small
 #(.width_p($bits(bp_cce_mem_msg_s)), .els_p(clint_max_outstanding_p))
 small_fifo
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(mem_cmd_li)
   ,.v_i(mem_cmd_v_i)
   ,.ready_o(mem_cmd_ready_o)

   ,.data_o(mem_cmd_lo)
   ,.v_o(small_fifo_v_lo)
   ,.yumi_i(small_fifo_yumi_li)
   );

logic mipi_cmd_v;
logic mtimecmp_cmd_v;
logic mtime_cmd_v;
logic plic_cmd_v;
logic wr_not_rd;

bp_local_addr_s local_addr;
assign local_addr = mem_cmd_li.header.addr;

always_comb
  begin
    mtime_cmd_v    = 1'b0;
    mtimecmp_cmd_v = 1'b0;
    mipi_cmd_v     = 1'b0;
    plic_cmd_v     = 1'b0;

    wr_not_rd = mem_cmd_li.header.msg_type inside {e_cce_mem_wb, e_cce_mem_uc_wr};

    unique 
    casez ({local_addr.dev, local_addr.addr})
      mtime_reg_addr_gp        : mtime_cmd_v    = mem_cmd_v_i;
      mtimecmp_reg_base_addr_gp: mtimecmp_cmd_v = mem_cmd_v_i;
      mipi_reg_base_addr_gp    : mipi_cmd_v     = mem_cmd_v_i;
      plic_reg_base_addr_gp    : plic_cmd_v     = mem_cmd_v_i;
      default: begin end
    endcase
  end

logic [dword_width_p-1:0] mtime_r, mtime_val_li, mtimecmp_n, mtimecmp_r;
logic                     mipi_n, mipi_r;
logic                     plic_n, plic_r;

// TODO: Should be actual RTC
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
assign mtime_val_li = mem_cmd_li.data[0+:dword_width_p];
wire mtime_w_v_li = wr_not_rd & mtime_cmd_v;
bsg_counter_set_en
 #(.lg_max_val_lp(dword_width_p)
   ,.reset_val_p(0)
   )
 mtime_counter
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.set_i(mtime_w_v_li)
   ,.en_i(mtime_inc_li)
   ,.val_i(mtime_val_li)
   ,.count_o(mtime_r)
   );

assign mtimecmp_n = mem_cmd_li.data[0+:dword_width_p];
wire mtimecmp_w_v_li = wr_not_rd & mtimecmp_cmd_v;
bsg_dff_reset_en
 #(.width_p(dword_width_p))
 mtimecmp_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.en_i(mtimecmp_w_v_li)
   ,.data_i(mtimecmp_n)
   ,.data_o(mtimecmp_r)
   );
assign timer_irq_o = (mtime_r >= mtimecmp_r);

assign mipi_n = mem_cmd_li.data[0];
wire mipi_w_v_li = wr_not_rd & mipi_cmd_v;
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

assign plic_n = mem_cmd_li.data[0];
wire plic_w_v_li = wr_not_rd & plic_cmd_v;
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

wire [dword_width_p-1:0] rdata_lo = plic_cmd_v 
                                    ? dword_width_p'(plic_r)
                                    : mipi_cmd_v 
                                      ? dword_width_p'(mipi_r)
                                      : mtimecmp_cmd_v 
                                        ? dword_width_p'(mtimecmp_r)
                                        : mtime_r;

bp_cce_mem_msg_s mem_resp_lo;
assign mem_resp_lo =
  '{header : '{
    msg_type       : mem_cmd_lo.header.msg_type
    ,addr          : mem_cmd_lo.header.addr
    ,payload       : mem_cmd_lo.header.payload
    ,size          : mem_cmd_lo.header.size
    }
    ,data          : cce_block_width_p'(rdata_lo)
    };
assign mem_resp_o = mem_resp_lo;
assign mem_resp_v_o = small_fifo_v_lo;
assign small_fifo_yumi_li = mem_resp_yumi_i;

endmodule


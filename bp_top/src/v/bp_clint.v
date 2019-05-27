
module bp_clint
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   // Arbitrary default, should be set based on PD constraints
   , parameter irq_pipe_depth_p = 4
   )
  (input                                           clk_i
   , input                                         reset_i

   , input                                         rtc_i

   // BP side
   , input [cce_mem_cmd_width_lp-1:0]              mem_cmd_i
   , input                                         mem_cmd_v_i
   , output logic                                  mem_cmd_yumi_o

   , input [cce_mem_data_cmd_width_lp-1:0]         mem_data_cmd_i
   , input                                         mem_data_cmd_v_i
   , output logic                                  mem_data_cmd_yumi_o

   , output [mem_cce_resp_width_lp-1:0]            mem_resp_o
   , output                                        mem_resp_v_o
   , input                                         mem_resp_ready_i

   , output logic [mem_cce_data_resp_width_lp-1:0] mem_data_resp_o
   , output logic                                  mem_data_resp_v_o
   , input                                         mem_data_resp_ready_i

   // Local interrupts
   , output [num_core_p-1:0]                       soft_irq_o
   , output [num_core_p-1:0]                       timer_irq_o
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);

bp_cce_mem_cmd_s       mem_cmd_cast_i;
bp_cce_mem_data_cmd_s  mem_data_cmd_cast_i;
bp_mem_cce_resp_s      mem_resp_cast_o;
bp_mem_cce_data_resp_s mem_data_resp_cast_o;

assign mem_cmd_cast_i       = mem_cmd_i;
assign mem_data_cmd_cast_i  = mem_data_cmd_i;
assign mem_data_resp_o      = mem_data_resp_cast_o;
assign mem_resp_o           = mem_resp_cast_o;

logic [num_core_p-1:0] mtime_cmd_v_li   , mtime_data_cmd_v_li;
logic [num_core_p-1:0] mtimecmp_cmd_v_li, mtimecmp_data_cmd_v_li;
logic [num_core_p-1:0] msoftint_cmd_v_li, msoftint_data_cmd_v_li;

always_comb 
  begin
    for (integer i = 0; i < num_core_p; i++)
      begin
        mtime_cmd_v_li   [i] = 
          mem_cmd_v_i[i] & (mem_cmd_cast_i[i].addr == bp_mmio_mtime_addr_gp);
        mtimecmp_cmd_v_li[i] = 
          mem_cmd_v_i[i] & (mem_cmd_cast_i[i].addr == bp_mmio_mtimecmp_base_addr_gp + 8*i);
        msoftint_cmd_v_li[i] = 
          mem_cmd_v_i[i] & (mem_cmd_cast_i[i].addr == bp_mmio_msoftint_base_addr_gp + 8*i);

        mtime_data_cmd_v_li   [i] = 
          mem_data_cmd_v_i[i] & (mem_data_cmd_cast_i[i].addr == bp_mmio_mtime_addr_gp);
        mtimecmp_data_cmd_v_li[i] = 
          mem_data_cmd_v_i[i] & (mem_data_cmd_cast_i[i].addr == bp_mmio_mtimecmp_base_addr_gp + 8*i);
        msoftint_data_cmd_v_li[i] = 
          mem_data_cmd_v_i[i] & (mem_data_cmd_cast_i[i].addr == bp_mmio_msoftint_base_addr_gp + 8*i);
      end
  end

logic [dword_width_p-1:0] mtime_n, mtime_r;
assign mtime_n = mtime_r + dword_width_p'(1);
  bsg_dff_reset_en
   #(.width_p(dword_width_p))
   mtime_reg
    (.clk_i(rtc_i)
     ,.reset_i(reset_i)
     ,.en_i(1'b1) // Always increment RTC, writes are ignored to avoid arbitration and for inter-core security

     ,.data_i(mtime_n)
     ,.data_o(mtime_r)
     );

logic [num_core_p-1:0][dword_width_p-1:0] mtimecmp_n, mtimecmp_r;
logic [num_core_p-1:0]                    mtimecmp_w_v_li;

logic [num_core_p-1:0]                    msoftint_n, msoftint_r;
logic [num_core_p-1:0]                    msoftint_w_v_li;

for (genvar i = 0; i < num_core_p; i++)
  begin : rof1
    assign mtimecmp_n     [i] = mem_data_cmd_cast_i.data[0+:dword_width_p];
    assign mtimecmp_w_v_li[i] = mtimecmp_data_cmd_v_li[i]; 
    bsg_dff_reset_en
     #(.width_p(dword_width_p))
     mtimecmp_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.en_i(mtimecmp_w_v_li[i])
       ,.data_i(mtimecmp_n[i])
       ,.data_o(mtimecmp_r[i])
       );

    bsg_dff_chain
     #(.width_p(dword_width_p)
       ,.num_stages_p(irq_pipe_depth_p)
       )
     timer_irq_pipe
      (.clk_i(clk_i)

       ,.data_i((mtimecmp_r[i] >= mtime_r))
       ,.data_o(timer_irq_o[i])
       );

    assign msoftint_n     [i] = mem_data_cmd_cast_i[i].data[0];
    assign msoftint_w_v_li[i] = msoftint_data_cmd_v_li[i];
    bsg_dff_reset_en
     #(.width_p(1))
     msoftint_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.en_i(msoftint_w_v_li[i])
       ,.data_i(msoftint_n[i])
       ,.data_o(msoftint_r[i])
       );

    bsg_dff_chain
     #(.width_p(1)
       ,.num_stages_p(irq_pipe_depth_p)
       )
     soft_irq_pipe
      (.clk_i(clk_i)

       ,.data_i(msoftint_r[i])
       ,.data_o(soft_irq_o[i])
       );
  end // rof1

// Always accept incoming commands and data commands
assign mem_data_resp_v_o = mem_cmd_v_i;
assign mem_cmd_yumi_o    = mem_cmd_v_i;

assign mem_resp_v_o        = mem_data_cmd_v_i;
assign mem_data_cmd_yumi_o = mem_data_cmd_v_i;

always_comb
  begin
    // The memory-mapped version of CLINT registers should be write-only. Maybe
    //   we should just disconnect this port.  But we do this for now...
    mem_data_resp_cast_o.msg_type      = mem_cmd_cast_i.msg_type;
    mem_data_resp_cast_o.addr          = mem_cmd_cast_i.addr;
    mem_data_resp_cast_o.payload       = mem_cmd_cast_i.payload;
    mem_data_resp_cast_o.non_cacheable = mem_cmd_cast_i.non_cacheable;
    mem_data_resp_cast_o.nc_size       = mem_cmd_cast_i.nc_size;
    mem_data_resp_cast_o.data          = '0;


    // This is just an ack
    mem_resp_cast_o.msg_type           = mem_data_cmd_cast_i.msg_type;
    mem_resp_cast_o.addr               = mem_data_cmd_cast_i.addr;
    mem_resp_cast_o.payload            = mem_data_cmd_cast_i.payload;
    mem_resp_cast_o.non_cacheable      = mem_data_cmd_cast_i.non_cacheable;
    mem_resp_cast_o.nc_size            = mem_data_cmd_cast_i.nc_size;
  end

endmodule : bp_clint


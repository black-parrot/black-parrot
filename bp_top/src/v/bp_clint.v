


module bp_clint
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter num_cce_p = "inv"
   , parameter paddr_width_p = "inv"
   , parameter num_lce_p = "inv"
   , parameter block_size_in_bits_p = "inv"
   , parameter lce_assoc_p = "inv"

   , parameter dword_width_p = 64

   , localparam mem_resp_width_lp=
      `bp_mem_cce_resp_width(paddr_width_p,num_lce_p,lce_assoc_p)
   , localparam mem_data_resp_width_lp=
      `bp_mem_cce_data_resp_width(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
   , localparam mem_cmd_width_lp=
      `bp_cce_mem_cmd_width(paddr_width_p,num_lce_p,lce_assoc_p)
   , localparam mem_data_cmd_width_lp=
      `bp_cce_mem_data_cmd_width(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p)
   )
  (input clk_i
   , input reset_i

   , input rtc_i

    // BP side
    , input [num_cce_p-1:0][mem_cmd_width_lp-1:0] mem_cmd_i
    , input [num_cce_p-1:0] mem_cmd_v_i
    , output logic [num_cce_p-1:0]  mem_cmd_yumi_o

    , input [num_cce_p-1:0][mem_data_cmd_width_lp-1:0] mem_data_cmd_i
    , input [num_cce_p-1:0] mem_data_cmd_v_i
    , output logic [num_cce_p-1:0] mem_data_cmd_yumi_o

    , output logic [num_cce_p-1:0][mem_resp_width_lp-1:0] mem_resp_o
    , output logic [num_cce_p-1:0] mem_resp_v_o
    , input [num_cce_p-1:0] mem_resp_ready_i

    , output logic [num_cce_p-1:0][mem_data_resp_width_lp-1:0] mem_data_resp_o
    , output logic [num_cce_p-1:0] mem_data_resp_v_o
    , input  [num_cce_p-1:0] mem_data_resp_ready_i

    // Main memory connection
    , output logic [num_cce_p-1:0][mem_cmd_width_lp-1:0] mem_cmd_o
    , output logic  [num_cce_p-1:0] mem_cmd_v_o
    , input  [num_cce_p-1:0] mem_cmd_yumi_i

    , output logic [num_cce_p-1:0][mem_data_cmd_width_lp-1:0] mem_data_cmd_o
    , output logic  [num_cce_p-1:0] mem_data_cmd_v_o
    , input  [num_cce_p-1:0] mem_data_cmd_yumi_i

    , input [num_cce_p-1:0][mem_resp_width_lp-1:0] mem_resp_i
    , input  [num_cce_p-1:0] mem_resp_v_i
    , output logic [num_cce_p-1:0] mem_resp_ready_o

    , input [num_cce_p-1:0][mem_data_resp_width_lp-1:0] mem_data_resp_i
    , input  [num_cce_p-1:0] mem_data_resp_v_i
    , output logic [num_cce_p-1:0] mem_data_resp_ready_o

    // Local interrupts
    , output [num_cce_p-1:0] soft_irq_o
    , output [num_cce_p-1:0] timer_irq_o
   );

`declare_bp_me_if(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p);

bp_cce_mem_cmd_s [num_cce_p-1:0] mem_cmd_cast_i;
bp_cce_mem_data_cmd_s [num_cce_p-1:0] mem_data_cmd_cast_i;
bp_mem_cce_resp_s [num_cce_p-1:0] mem_resp_cast_i;
bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp_cast_i;

bp_cce_mem_cmd_s [num_cce_p-1:0] mem_cmd_cast_o;
bp_cce_mem_data_cmd_s [num_cce_p-1:0] mem_data_cmd_cast_o;
bp_mem_cce_resp_s [num_cce_p-1:0] mem_resp_cast_o;
bp_mem_cce_data_resp_s [num_cce_p-1:0] mem_data_resp_cast_o;

logic [num_cce_p-1:0] mtime_cmd_v_li, mtime_data_cmd_v_li;
logic [num_cce_p-1:0] mtimecmp_cmd_v_li, mtimecmp_data_cmd_v_li;
logic [num_cce_p-1:0] msoftint_cmd_v_li, msoftint_data_cmd_v_li;
logic [num_cce_p-1:0] mem_cmd_io_v_li, mem_data_cmd_io_v_li;
logic [num_cce_p-1:0] mem_cmd_io_yumi_lo, mem_data_cmd_io_yumi_lo;
logic [num_cce_p-1:0] mem_cmd_mem_v_li, mem_data_cmd_mem_v_li;

assign mem_cmd_cast_i       = mem_cmd_i;
assign mem_data_cmd_cast_i  = mem_data_cmd_i;

wire unused = &{clk_i, reset_i};

logic [`BSG_SAFE_CLOG2(num_cce_p)-1:0] mem_cmd_arb_tag_lo;
logic [mem_cmd_width_lp-1:0] mem_cmd_arb_lo;
logic mem_cmd_arb_v_lo, mem_cmd_arb_yumi_li;
logic [num_cce_p-1:0] mem_cmd_arb_tgt_dec_lo;
bsg_round_robin_n_to_1
 #(.width_p(mem_cmd_width_lp)
   ,.num_in_p(num_cce_p)
   ,.strict_p(1)
   )
 mem_cmd_io_arb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(/* We only use the valid of this arbiter */)
   ,.v_i(mem_cmd_io_v_li)
   ,.yumi_o(mem_cmd_io_yumi_lo)

   ,.tag_o(mem_cmd_arb_tag_lo)
   ,.data_o(/* We only use the valid of this arbiter */)
   ,.v_o(mem_cmd_arb_v_lo)
   ,.yumi_i(mem_cmd_arb_yumi_li)
   );

logic [num_cce_p-1:0] mem_cmd_arb_tag_dec_lo;
bsg_decode_with_v
 #(.num_out_p(num_cce_p))
 cmd_tag_decoder
  (.i(mem_cmd_arb_tag_lo)
   ,.v_i(mem_cmd_arb_v_lo)
   ,.o(mem_cmd_arb_tag_dec_lo)
   );

logic [`BSG_SAFE_CLOG2(num_cce_p)-1:0] mem_data_cmd_arb_tag_lo;
logic [mem_data_cmd_width_lp-1:0] mem_data_cmd_arb_lo;
logic [num_cce_p-1:0] mem_data_cmd_io_v_i;
logic mem_data_cmd_arb_v_lo, mem_data_cmd_arb_yumi_li;
logic [num_cce_p-1:0] mem_data_cmd_arb_tgt_dec_lo;
bsg_round_robin_n_to_1
 #(.width_p(mem_data_cmd_width_lp)
   ,.num_in_p(num_cce_p)
   ,.strict_p(1)
   )
 mem_data_cmd_io_arb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(/* We only use the valid of this arbiter */)
   ,.v_i(mem_data_cmd_io_v_li)
   ,.yumi_o(mem_data_cmd_io_yumi_lo)

   ,.tag_o(mem_data_cmd_arb_tag_lo)
   ,.data_o(/* We only use the valid of this arbiter */)
   ,.v_o(mem_data_cmd_arb_v_lo)
   ,.yumi_i(mem_data_cmd_arb_yumi_li)
   );

logic [num_cce_p-1:0] mem_data_cmd_arb_tag_dec_lo;
bsg_decode_with_v
 #(.num_out_p(num_cce_p))
 data_cmd_tag_decoder
  (.i(mem_data_cmd_arb_tag_lo)
   ,.v_i(mem_data_cmd_arb_v_lo)
   ,.o(mem_data_cmd_arb_tag_dec_lo)
   );

always_comb 
  begin
    for (integer i = 0; i < num_cce_p; i++)
      begin
        mtime_cmd_v_li[i]    = mem_cmd_v_i[i] & (mem_cmd_cast_i[i].addr == bp_mmio_mtime_addr_gp);
        mtimecmp_cmd_v_li[i] = mem_cmd_v_i[i] & (mem_cmd_cast_i[i].addr == bp_mmio_mtimecmp_base_addr_gp + 8*i);
        msoftint_cmd_v_li[i] = mem_cmd_v_i[i] & (mem_cmd_cast_i[i].addr == bp_mmio_msoftint_base_addr_gp + 8*i);
        mem_cmd_io_v_li[i]   = mtime_cmd_v_li[i] | mtimecmp_cmd_v_li[i] | msoftint_cmd_v_li[i];
        mem_cmd_mem_v_li[i]  = mem_cmd_v_i[i] & ~mem_cmd_io_v_li[i];

        mtime_data_cmd_v_li[i]    = mem_data_cmd_v_i[i] & (mem_data_cmd_cast_i[i].addr == bp_mmio_mtime_addr_gp);
        mtimecmp_data_cmd_v_li[i] = mem_data_cmd_v_i[i] & (mem_data_cmd_cast_i[i].addr == bp_mmio_mtimecmp_base_addr_gp + 8*i);
        msoftint_data_cmd_v_li[i] = mem_data_cmd_v_i[i] & (mem_data_cmd_cast_i[i].addr == bp_mmio_msoftint_base_addr_gp + 8*i);
        mem_data_cmd_io_v_li[i]   = mtime_data_cmd_v_li[i] | mtimecmp_data_cmd_v_li[i] | msoftint_data_cmd_v_li[i];
        mem_data_cmd_mem_v_li[i]  = mem_data_cmd_v_i[i] & ~mem_data_cmd_io_v_li[i];
      end
  end

logic [dword_width_p-1:0] mtime_n, mtime_r;
logic [num_cce_p-1:0][dword_width_p-1:0] mtimecmp_n, mtimecmp_r;
logic [num_cce_p-1:0] mtimecmp_w_v_li;
logic [num_cce_p-1:0] msoftint_n, msoftint_r;
logic [num_cce_p-1:0] msoftint_w_v_li;

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

for (genvar i = 0; i < num_cce_p; i++)
  begin : rof1
    assign mtimecmp_n[i] = mem_data_cmd_cast_i[i].data[0+:dword_width_p];
    assign mtimecmp_w_v_li[i] = mtimecmp_data_cmd_v_li[i] & mem_data_cmd_arb_tag_dec_lo[i];
    bsg_dff_reset_en
     #(.width_p(dword_width_p))
     mtimecmp_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.en_i(mtimecmp_w_v_li[i])
       ,.data_i(mtimecmp_n[i])
       ,.data_o(mtimecmp_r[i])
       );

    assign timer_irq_o[i] = (mtimecmp_r[i] >= mtime_r);

    assign msoftint_n[i] = mem_data_cmd_cast_i[i].data[0];
    assign msoftint_w_v_li[i] = msoftint_data_cmd_v_li[i] & mem_data_cmd_arb_tag_dec_lo[i];
    bsg_dff_reset_en
     #(.width_p(1))
     msoftint_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.en_i(msoftint_w_v_li[i])
       ,.data_i(msoftint_n[i])
       ,.data_o(msoftint_r[i])
       );

    assign soft_irq_o[i] = msoftint_r[i];

  end // rof1

bp_mem_cce_resp_s [num_cce_p-1:0] io_resp_lo;
logic [num_cce_p-1:0] io_resp_v_lo;
bp_mem_cce_data_resp_s [num_cce_p-1:0] io_data_resp_lo;
logic [num_cce_p-1:0] io_data_resp_v_lo;

always_comb
  begin
        mem_cmd_arb_yumi_li = mem_cmd_arb_v_lo & mem_data_resp_ready_i;
        mem_data_cmd_arb_yumi_li = mem_data_cmd_arb_v_lo & mem_resp_ready_i;

        for (integer i = 0; i < num_cce_p; i++)
        begin
        io_resp_lo[i].msg_type           = mem_data_cmd_cast_i[i].msg_type;
        io_resp_lo[i].addr               = mem_data_cmd_cast_i[i].addr;
        io_resp_lo[i].payload            = mem_data_cmd_cast_i[i].payload;
        io_resp_lo[i].non_cacheable      = mem_data_cmd_cast_i[i].non_cacheable;
        io_resp_lo[i].nc_size            = mem_data_cmd_cast_i[i].nc_size;

        io_resp_v_lo[i]                   = mem_data_cmd_arb_tag_dec_lo[i] & mem_resp_ready_i[i];

        io_data_resp_lo[i].msg_type      = mem_cmd_cast_i[i].msg_type;
        io_data_resp_lo[i].addr          = mem_cmd_cast_i[i].addr;
        io_data_resp_lo[i].payload       = mem_cmd_cast_i[i].payload;
        io_data_resp_lo[i].non_cacheable = mem_cmd_cast_i[i].non_cacheable;
        io_data_resp_lo[i].nc_size       = mem_cmd_cast_i[i].nc_size;
        io_data_resp_lo[i].data          = mtime_cmd_v_li[i]
                                           ? mtime_r
                                           : mtimecmp_cmd_v_li[i]
                                             ? mtimecmp_r[i]
                                             : msoftint_r[i];

        io_data_resp_v_lo[i]             = mem_cmd_arb_tag_dec_lo[i] & mem_data_resp_ready_i[i];
      end
  end

for (genvar i = 0; i < num_cce_p; i++)
  begin : rof2
    assign mem_cmd_o[i] = mem_cmd_i[i];
    assign mem_cmd_v_o[i] = mem_cmd_mem_v_li[i];
    assign mem_cmd_yumi_o[i] = mem_cmd_yumi_i[i] | mem_data_cmd_io_yumi_lo[i];

    assign mem_data_cmd_o[i] = mem_data_cmd_i[i];
    assign mem_data_cmd_v_o[i] = mem_data_cmd_mem_v_li[i];
    assign mem_data_cmd_yumi_o[i] = mem_data_cmd_yumi_i[i] | mem_data_cmd_io_yumi_lo[i];

    assign mem_resp_o[i] = mem_resp_v_i[i] ? mem_resp_i[i] : io_resp_lo[i];
    assign mem_resp_v_o[i] = mem_resp_v_i[i] | io_resp_v_lo[i];
    assign mem_resp_ready_o[i] = mem_resp_ready_i[i];
    
    assign mem_data_resp_o[i] = mem_data_resp_v_i[i] ? mem_data_resp_i[i] : io_data_resp_lo[i];
    assign mem_data_resp_v_o[i] = mem_data_resp_v_i[i] | io_data_resp_v_lo[i];
    assign mem_data_resp_ready_o[i] = mem_data_resp_ready_i[i];
  end // rof2

endmodule : bp_clint


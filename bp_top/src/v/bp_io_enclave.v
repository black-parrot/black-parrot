
module bp_io_enclave
 import bp_common_pkg::*;
 #(parameter num_cce_p = "inv"
   , parameter paddr_width_p = "inv"
   , parameter num_lce_p = "inv"
   , parameter block_size_in_bits_p = "inv"
   , parameter lce_assoc_p = "inv"
   , parameter dword_width_p = "inv"

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

   // Real time clock input (currently tied to regular clock)
   , input rtc_i

   // Timer read
   , input logic [num_cce_p-1:0][mem_cmd_width_lp-1:0] mtime_cmd_i
   , input logic [num_cce_p-1:0] mtime_cmd_v_i
   , output logic [num_cce_p-1:0] mtime_cmd_yumi_o

   , input logic [num_cce_p-1:0][mem_data_cmd_width_lp-1:0] mtime_data_cmd_i
   , input logic [num_cce_p-1:0] mtime_data_cmd_v_i
   , output logic [num_cce_p-1:0] mtime_data_cmd_yumi_o

   , output logic [num_cce_p-1:0][mem_resp_width_lp-1:0] mtime_resp_o
   , output logic [num_cce_p-1:0] mtime_resp_v_o
   , input logic [num_cce_p-1:0] mtime_resp_ready_i

   , output logic [num_cce_p-1:0][mem_data_resp_width_lp-1:0] mtime_data_resp_o
   , output logic [num_cce_p-1:0] mtime_data_resp_v_o
   , input logic [num_cce_p-1:0] mtime_data_resp_ready_i

   // Timer compare
   , input logic [num_cce_p-1:0][mem_cmd_width_lp-1:0] mtimecmp_cmd_i
   , input logic [num_cce_p-1:0] mtimecmp_cmd_v_i
   , output logic [num_cce_p-1:0] mtimecmp_cmd_yumi_o

   , input logic [num_cce_p-1:0][mem_data_cmd_width_lp-1:0] mtimecmp_data_cmd_i
   , input logic [num_cce_p-1:0] mtimecmp_data_cmd_v_i
   , output logic [num_cce_p-1:0] mtimecmp_data_cmd_yumi_o

   , output logic [num_cce_p-1:0][mem_resp_width_lp-1:0] mtimecmp_resp_o
   , output logic [num_cce_p-1:0] mtimecmp_resp_v_o
   , input logic [num_cce_p-1:0] mtimecmp_resp_ready_i

   , output logic [num_cce_p-1:0][mem_data_resp_width_lp-1:0] mtimecmp_data_resp_o
   , output logic [num_cce_p-1:0] mtimecmp_data_resp_v_o
   , input logic [num_cce_p-1:0] mtimecmp_data_resp_ready_i

   // Software interrupts
   , input logic [num_cce_p-1:0][mem_cmd_width_lp-1:0] msoftint_cmd_i
   , input logic [num_cce_p-1:0] msoftint_cmd_v_i
   , output logic [num_cce_p-1:0] msoftint_cmd_yumi_o

   , input logic [num_cce_p-1:0][mem_data_cmd_width_lp-1:0] msoftint_data_cmd_i
   , input logic [num_cce_p-1:0] msoftint_data_cmd_v_i
   , output logic [num_cce_p-1:0] msoftint_data_cmd_yumi_o

   , output logic [num_cce_p-1:0][mem_resp_width_lp-1:0] msoftint_resp_o
   , output logic [num_cce_p-1:0] msoftint_resp_v_o
   , input logic [num_cce_p-1:0] msoftint_resp_ready_i

   , output logic [num_cce_p-1:0][mem_data_resp_width_lp-1:0] msoftint_data_resp_o
   , output logic [num_cce_p-1:0] msoftint_data_resp_v_o
   , input logic [num_cce_p-1:0] msoftint_data_resp_ready_i

   // Timer interrupt
   , output [num_cce_p-1:0] timer_int_o
   , output [num_cce_p-1:0] software_int_o
   );

`declare_bp_me_if(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p);

bp_cce_mem_cmd_s                       mtime_cmd_cast_i;
bp_cce_mem_data_cmd_s                  mtime_data_cmd_cast_i;
bp_mem_cce_resp_s                      mtime_resp_cast_o;
bp_mem_cce_data_resp_s                 mtime_data_resp_cast_o;

bp_mem_cce_resp_s [num_cce_p-1:0]      mtimecmp_resp_cast_o;
bp_mem_cce_data_resp_s [num_cce_p-1:0] mtimecmp_data_resp_cast_o;
bp_cce_mem_cmd_s [num_cce_p-1:0]       mtimecmp_cmd_cast_i;
bp_cce_mem_data_cmd_s [num_cce_p-1:0]  mtimecmp_data_cmd_cast_i;

bp_mem_cce_resp_s [num_cce_p-1:0]      msoftint_resp_cast_o;
bp_mem_cce_data_resp_s [num_cce_p-1:0] msoftint_data_resp_cast_o;
bp_cce_mem_cmd_s [num_cce_p-1:0]       msoftint_cmd_cast_i;
bp_cce_mem_data_cmd_s [num_cce_p-1:0]  msoftint_data_cmd_cast_i;

assign mtime_cmd_cast_i         = mtime_cmd_i;
assign mtime_data_cmd_cast_i    = mtime_data_cmd_i;
assign mtime_resp_o             = mtime_resp_cast_o;
assign mtime_data_resp_o        = mtime_data_resp_cast_o;

assign mtimecmp_cmd_cast_i      = mtimecmp_cmd_i;
assign mtimecmp_data_cmd_cast_i = mtimecmp_data_cmd_i;
assign mtimecmp_resp_o          = mtimecmp_resp_cast_o;
assign mtimecmp_data_resp_o     = mtimecmp_data_resp_cast_o;

assign msoftint_cmd_cast_i      = msoftint_cmd_i;
assign msoftint_data_cmd_cast_i = msoftint_data_cmd_i;
assign msoftint_resp_o          = msoftint_resp_cast_o;
assign msoftint_data_resp_o     = msoftint_data_resp_cast_o;

logic [dword_width_p-1:0]                mtime_n, mtime_r;

logic [num_cce_p-1:0][dword_width_p-1:0] mtimecmp_n, mtimecmp_r;
logic [num_cce_p-1:0]                    mtimecmp_w_v_li;

logic [num_cce_p-1:0]                    msoftint_n, msoftint_r;
logic [num_cce_p-1:0]                    msoftint_w_v_li;

assign mtime_n = mtime_data_cmd_v_i & (mtime_data_cmd_cast_i.msg_type == e_lce_req_type_wr)
                 ? mtime_data_cmd_cast_i.data[0+:dword_width_p]
                 : mtime_r + dword_width_p'(1);
  bsg_dff_reset_en
   #(.width_p(dword_width_p))
   mtime_reg
    (.clk_i(rtc_i)
     ,.reset_i(reset_i)
     ,.en_i(1'b1) // Always increment RTC

     ,.data_i(mtime_n)
     ,.data_o(mtime_r)
     );

for (genvar i = 0; i < num_cce_p; i++)
  begin : rof1
    assign mtimecmp_n[i] = mtimecmp_data_cmd_cast_i[i].data[0+:dword_width_p];
    assign mtimecmp_w_v_li[i] = mtimecmp_data_cmd_v_i[i] 
                                & (mtimecmp_data_cmd_cast_i[i].msg_type == e_lce_req_type_wr);

    bsg_dff_reset_en
     #(.width_p(dword_width_p))
     mtimecmp_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(mtimecmp_w_v_li[i])

       ,.data_i(mtimecmp_n[i])
       ,.data_o(mtimecmp_r[i])
       );

    assign timer_int_o[i] = (mtime_r >= mtimecmp_r[i]);

    always_comb
      begin
        mtimecmp_cmd_yumi_o[i]      = mtime_cmd_v_i[i];
        mtimecmp_data_cmd_yumi_o[i] = mtime_data_cmd_v_i[i];

        mtimecmp_resp_cast_o[i].msg_type           = mtimecmp_data_cmd_cast_i[i].msg_type;
        mtimecmp_resp_cast_o[i].addr               = mtimecmp_data_cmd_cast_i[i].addr;
        mtimecmp_resp_cast_o[i].payload            = mtimecmp_data_cmd_cast_i[i].payload;
        mtimecmp_resp_cast_o[i].non_cacheable      = mtimecmp_data_cmd_cast_i[i].non_cacheable;
        mtimecmp_resp_cast_o[i].nc_size            = mtimecmp_data_cmd_cast_i[i].nc_size;
        mtimecmp_resp_v_o[i]                       = mtimecmp_resp_ready_i[i] 
                                                     & mtimecmp_data_cmd_v_i[i];

        mtimecmp_data_resp_cast_o[i].msg_type      = mtimecmp_cmd_cast_i[i].msg_type;
        mtimecmp_data_resp_cast_o[i].addr          = mtimecmp_cmd_cast_i[i].addr;
        mtimecmp_data_resp_cast_o[i].payload       = mtimecmp_cmd_cast_i[i].payload;
        mtimecmp_data_resp_cast_o[i].non_cacheable = mtimecmp_cmd_cast_i[i].non_cacheable;
        mtimecmp_data_resp_cast_o[i].nc_size       = mtimecmp_cmd_cast_i[i].nc_size;
        mtimecmp_data_resp_cast_o[i].data          = mtimecmp_r[i];
        mtimecmp_data_resp_v_o[i]                  = mtimecmp_data_resp_ready_i[i]
                                                     & mtimecmp_cmd_v_i[i];
      end
  end // rof1

for (genvar i = 0; i < num_cce_p; i++)
  begin : rof2
    assign msoftint_n[i] = msoftint_data_cmd_cast_i[i].data[0];
    assign msoftint_w_v_li[i] = msoftint_data_cmd_v_i[i]
                                & (msoftint_data_cmd_cast_i[i].msg_type == e_lce_req_type_wr);

    bsg_dff_reset_en
     #(.width_p(1))
     msoftint_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(msoftint_w_v_li[i])

       ,.data_i(msoftint_n[i])
       ,.data_o(msoftint_r[i])
       );

    assign software_int_o[i] = msoftint_r[i];

    always_comb
      begin
        msoftint_cmd_yumi_o[i]      = mtime_cmd_v_i[i];
        msoftint_data_cmd_yumi_o[i] = mtime_data_cmd_v_i[i];

        msoftint_resp_cast_o[i].msg_type           = msoftint_data_cmd_cast_i[i].msg_type;
        msoftint_resp_cast_o[i].addr               = msoftint_data_cmd_cast_i[i].addr;
        msoftint_resp_cast_o[i].payload            = msoftint_data_cmd_cast_i[i].payload;
        msoftint_resp_cast_o[i].non_cacheable      = msoftint_data_cmd_cast_i[i].non_cacheable;
        msoftint_resp_cast_o[i].nc_size            = msoftint_data_cmd_cast_i[i].nc_size;
        msoftint_resp_v_o[i]                       = msoftint_resp_ready_i[i]
                                                     & msoftint_data_cmd_v_i[i];

        msoftint_data_resp_cast_o[i].msg_type      = msoftint_cmd_cast_i[i].msg_type;
        msoftint_data_resp_cast_o[i].addr          = msoftint_cmd_cast_i[i].addr;
        msoftint_data_resp_cast_o[i].payload       = msoftint_cmd_cast_i[i].payload;
        msoftint_data_resp_cast_o[i].non_cacheable = msoftint_cmd_cast_i[i].non_cacheable;
        msoftint_data_resp_cast_o[i].nc_size       = msoftint_cmd_cast_i[i].nc_size;
        msoftint_data_resp_cast_o[i].data          = msoftint_r[i];
        msoftint_data_resp_v_o[i]                  = msoftint_data_resp_ready_i[i]
                                                     & msoftint_cmd_v_i[i];
      end
  end // rof2

always_comb
  begin
    mtime_cmd_yumi_o      = mtime_cmd_v_i;
    mtime_data_cmd_yumi_o = mtime_data_cmd_v_i;

    mtime_resp_cast_o.msg_type           = mtime_data_cmd_cast_i.msg_type;
    mtime_resp_cast_o.addr               = mtime_data_cmd_cast_i.addr;
    mtime_resp_cast_o.payload            = mtime_data_cmd_cast_i.payload;
    mtime_resp_cast_o.non_cacheable      = mtime_data_cmd_cast_i.non_cacheable;
    mtime_resp_cast_o.nc_size            = mtime_data_cmd_cast_i.nc_size;
    mtime_resp_v_o                       = mtime_resp_ready_i & mtime_data_cmd_v_i;

    mtime_data_resp_cast_o.msg_type      = mtime_cmd_cast_i.msg_type;
    mtime_data_resp_cast_o.addr          = mtime_cmd_cast_i.addr;
    mtime_data_resp_cast_o.payload       = mtime_cmd_cast_i.payload;
    mtime_data_resp_cast_o.non_cacheable = mtime_cmd_cast_i.non_cacheable;
    mtime_data_resp_cast_o.nc_size       = mtime_cmd_cast_i.nc_size;
    mtime_data_resp_cast_o.data          = mtime_r;
    mtime_data_resp_v_o                  = mtime_data_resp_ready_i & mtime_cmd_v_i;
  end

endmodule : bp_io_enclave


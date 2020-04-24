
module bp_clint
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

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                clk_i
   , input                                              reset_i

   // BP side
   , input [mem_noc_cord_width_p-1:0]                   my_cord_i

   , input [mem_noc_ral_link_width_lp-1:0]              cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]             cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]              resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]             resp_link_o

   // Local interrupts
   , output [num_core_p-1:0]                            soft_irq_o
   , output [num_core_p-1:0]                            timer_irq_o
   , output [num_core_p-1:0]                            external_irq_o
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

bp_cce_mem_msg_s mem_cmd_li;
logic mem_cmd_v_li, mem_cmd_yumi_lo;

bp_cce_mem_msg_s mem_resp_lo;
logic mem_resp_v_lo, mem_resp_ready_li;

localparam lg_num_core_lp = `BSG_SAFE_CLOG2(num_core_p);

logic mipi_cmd_v;
logic mtimecmp_cmd_v;
logic mtime_cmd_v;
logic plic_cmd_v;
logic wr_not_rd;

always_comb
  begin
    mipi_cmd_v          = 1'b0;
    mtimecmp_cmd_v      = 1'b0;
    mtime_cmd_v         = 1'b0;
    plic_cmd_v          = 1'b0;

    wr_not_rd = mem_cmd_li.msg_type inside {e_cce_mem_wr, e_cce_mem_uc_wr};

    unique 
    casez (mem_cmd_li.addr)
      mipi_reg_base_addr_gp    : mipi_cmd_v     = mem_cmd_v_li;
      mtimecmp_reg_base_addr_gp: mtimecmp_cmd_v = mem_cmd_v_li;
      mtime_reg_addr_gp        : mtime_cmd_v    = mem_cmd_v_li;
      plic_reg_base_addr_gp    : plic_cmd_v     = mem_cmd_v_li;
      default: begin end
    endcase
  end

logic [num_core_p-1:0] mtimecmp_v_li;
logic [num_core_p-1:0] mipi_v_li;
logic [num_core_p-1:0] plic_v_li;

// Memory-mapped I/O is 64 bit aligned
// Low 8 bits are core id for MMIO addresses
localparam mipi_core_offset_lp = 2;
localparam mtimecmp_core_offset_lp = 3;
wire [lg_num_core_lp-1:0] mipi_cmd_core_enc = 
  mem_cmd_li.addr[mipi_core_offset_lp+:lg_num_core_lp];
wire [lg_num_core_lp-1:0] mtimecmp_cmd_core_enc = 
  mem_cmd_li.addr[mtimecmp_core_offset_lp+:lg_num_core_lp];  

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 mipi_cmd_decoder
  (.v_i(mipi_cmd_v)
   ,.i(mipi_cmd_core_enc)
   
   ,.o(mipi_v_li)
   );

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 mtimecmp_cmd_decoder
  (.v_i(mtimecmp_cmd_v)
   ,.i(mtimecmp_cmd_core_enc)
   
   ,.o(mtimecmp_v_li)
   );

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 plic_cmd_decoder
  (.v_i(plic_cmd_v)
   ,.i(mtimecmp_cmd_core_enc)

   ,.o(plic_v_li)
   );

logic [dword_width_p-1:0] mtime_n, mtime_r;
wire mtime_w_v_li = wr_not_rd & mtime_cmd_v;
assign mtime_n    = mtime_w_v_li 
                    ? mem_cmd_li.data[0+:dword_width_p] 
                    : mtime_r + dword_width_p'(1);
  bsg_dff_reset
   #(.width_p(dword_width_p))
   mtime_reg
    (.clk_i(clk_i) // TODO: Should be a RTC once CDC strategy is decided
     ,.reset_i(reset_i)

     ,.data_i(mtime_n)
     ,.data_o(mtime_r)
     );

logic [num_core_p-1:0][dword_width_p-1:0] mtimecmp_n, mtimecmp_r;
logic [num_core_p-1:0]                    mipi_n, mipi_r;
logic [num_core_p-1:0]                    plic_n, plic_r;

for (genvar i = 0; i < num_core_p; i++)
  begin : rof1
    assign mtimecmp_n[i] = mem_cmd_li.data[0+:dword_width_p];
    wire mtimecmp_w_v_li = wr_not_rd & mtimecmp_v_li[i];
    bsg_dff_reset_en
     #(.width_p(dword_width_p))
     mtimecmp_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)

       ,.en_i(mtimecmp_w_v_li)
       ,.data_i(mtimecmp_n[i])
       ,.data_o(mtimecmp_r[i])
       );
    assign timer_irq_o[i] = (mtime_r >= mtimecmp_r[i]);

    assign mipi_n[i] = mem_cmd_li.data[0];
    wire mipi_w_v_li = wr_not_rd & mipi_v_li[i];
    bsg_dff_reset_en
     #(.width_p(1))
     mipi_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(mipi_w_v_li)

       ,.data_i(mipi_n[i])
       ,.data_o(mipi_r[i])
       );
    assign soft_irq_o[i] = mipi_r[i];

    assign plic_n[i] = mem_cmd_li.data[0];
    wire plic_w_v_li = wr_not_rd & plic_v_li[i];
    bsg_dff_reset_en
     #(.width_p(1))
     plic_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(plic_w_v_li)

       ,.data_i(plic_n[i])
       ,.data_o(plic_r[i])
       );
    assign external_irq_o[i] = plic_r[i];
  end // rof1

logic mipi_lo;
bsg_mux_one_hot
 #(.width_p(1)
   ,.els_p(num_core_p) 
   )
 mipi_mux_one_hot
  (.data_i(mipi_r)
   ,.sel_one_hot_i(mipi_v_li)
   ,.data_o(mipi_lo)
   );

logic [dword_width_p-1:0] mtimecmp_lo;
bsg_mux_one_hot
 #(.width_p(dword_width_p)
   ,.els_p(num_core_p)
   )
 mtimecmp_mux_one_hot
  (.data_i(mtimecmp_r)
   ,.sel_one_hot_i(mtimecmp_v_li)
   ,.data_o(mtimecmp_lo)
   );

logic plic_lo;
bsg_mux_one_hot
 #(.width_p(1)
   ,.els_p(num_core_p)
   )
 plic_mux_one_hot
  (.data_i(plic_r)
   ,.sel_one_hot_i(plic_v_li)
   ,.data_o(plic_lo)
   );

wire [dword_width_p-1:0] rdata_lo = plic_cmd_v 
                                    ? dword_width_p'(plic_lo)
                                    : mipi_cmd_v 
                                      ? dword_width_p'(mipi_lo)
                                      : mtimecmp_cmd_v 
                                        ? dword_width_p'(mtimecmp_lo)
                                        : mtime_r;

assign mem_resp_lo =
  '{msg_type       : mem_cmd_li.msg_type
    ,addr          : mem_cmd_li.addr
    ,payload       : mem_cmd_li.payload
    ,size          : mem_cmd_li.size
    ,data          : cce_block_width_p'(rdata_lo)
    };

// CCE-MEM IF to wormhole link conversion
assign mem_cmd_yumi_lo = mem_cmd_v_li & mem_resp_ready_li;
assign mem_resp_v_lo = mem_cmd_yumi_lo;
bp_me_cce_to_wormhole_link_client
 #(.bp_params_p(bp_params_p))
 client_link
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_o(mem_cmd_li)
   ,.mem_cmd_v_o(mem_cmd_v_li)
   ,.mem_cmd_yumi_i(mem_cmd_yumi_lo)

   ,.mem_resp_i(mem_resp_lo)
   ,.mem_resp_v_i(mem_resp_v_lo)
   ,.mem_resp_ready_o(mem_resp_ready_li)

   ,.my_cord_i(my_cord_i)

   ,.cmd_link_i(cmd_link_i)
   ,.cmd_link_o(cmd_link_o)

   ,.resp_link_i(resp_link_i)
   ,.resp_link_o(resp_link_o)
   );

endmodule


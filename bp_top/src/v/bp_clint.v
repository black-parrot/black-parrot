
/*
 * Note: Should rename to I/O enclave and instantiate CLINT and CFG submodules
 */
module bp_clint
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   // Arbitrary default, should be set based on PD constraints
   , parameter irq_pipe_depth_p = 4
   , parameter cfg_link_pipe_depth_p = 4
   )
  (input                                           clk_i
   , input                                         reset_i

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
   , output [num_core_p-1:0]                       external_irq_o

   // Core config link
   , output                                        cfg_link_w_v_o
   , output [bp_cfg_link_addr_width_gp-1:0]        cfg_link_addr_o
   , output [bp_cfg_link_data_width_gp-1:0]        cfg_link_data_o
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);

// Cast ports
bp_cce_mem_cmd_s       mem_cmd_cast_i;
bp_cce_mem_data_cmd_s  mem_data_cmd_cast_i;
bp_mem_cce_resp_s      mem_resp_cast_o;
bp_mem_cce_data_resp_s mem_data_resp_cast_o;

assign mem_cmd_cast_i       = mem_cmd_i;
assign mem_data_cmd_cast_i  = mem_data_cmd_i;
assign mem_data_resp_o      = mem_data_resp_cast_o;
assign mem_resp_o           = mem_resp_cast_o;

localparam lg_num_core_lp = `BSG_SAFE_CLOG2(num_core_p);

logic cfg_link_data_cmd_v;
logic mipi_cmd_v, mipi_data_cmd_v;
logic mtimecmp_cmd_v, mtimecmp_data_cmd_v;
logic mtime_cmd_v, mtime_data_cmd_v;
logic plic_cmd_v, plic_data_cmd_v;

always_comb
  begin
    mipi_cmd_v          = 1'b0;
    mtimecmp_cmd_v      = 1'b0;
    mtime_cmd_v         = 1'b0;
    plic_cmd_v          = 1'b0;

    unique 
    casez (mem_cmd_cast_i.addr)
      mipi_reg_base_addr_gp    : mipi_cmd_v     = mem_cmd_v_i;
      mtimecmp_reg_base_addr_gp: mtimecmp_cmd_v = mem_cmd_v_i;
      mtime_reg_addr_gp        : mtime_cmd_v    = mem_cmd_v_i;
      plic_reg_base_addr_gp    : plic_cmd_v     = mem_cmd_v_i;
      default: begin end
    endcase

    cfg_link_data_cmd_v = 1'b0;
    mipi_data_cmd_v     = 1'b0;
    mtimecmp_data_cmd_v = 1'b0;
    mtime_data_cmd_v    = 1'b0;
    plic_data_cmd_v     = 1'b0;

    unique 
    casez (mem_data_cmd_cast_i.addr)
      cfg_link_dev_base_addr_gp: cfg_link_data_cmd_v = mem_data_cmd_v_i;
      mipi_reg_base_addr_gp    : mipi_data_cmd_v     = mem_data_cmd_v_i;
      mtimecmp_reg_base_addr_gp: mtimecmp_data_cmd_v = mem_data_cmd_v_i;
      mtime_reg_addr_gp        : mtime_data_cmd_v    = mem_data_cmd_v_i;
      plic_reg_base_addr_gp    : plic_data_cmd_v     = mem_data_cmd_v_i;
      default: begin end
    endcase
  end

logic [num_core_p-1:0] mtimecmp_r_v_li, mtimecmp_w_v_li;
logic [num_core_p-1:0] mipi_r_v_li    , mipi_w_v_li;
logic [num_core_p-1:0] plic_r_v_li    , plic_w_v_li;

// Memory-mapped I/O is 64 bit aligned
localparam byte_offset_width_lp = 3;
wire [lg_num_core_lp-1:0] mem_cmd_core_enc = 
  mem_cmd_cast_i.addr[byte_offset_width_lp+:lg_num_core_lp];
wire [lg_num_core_lp-1:0] mem_data_cmd_core_enc = 
  mem_data_cmd_cast_i.addr[byte_offset_width_lp+:lg_num_core_lp];

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 mipi_cmd_decoder
  (.v_i(mipi_cmd_v)
   ,.i(mem_cmd_core_enc)
   
   ,.o(mipi_r_v_li)
   );

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 mipi_data_cmd_decoder
  (.v_i(mipi_data_cmd_v)
   ,.i(mem_data_cmd_core_enc)

   ,.o(mipi_w_v_li)
   );

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 mtimecmp_cmd_decoder
  (.v_i(mtimecmp_cmd_v)
   ,.i(mem_cmd_core_enc)
   
   ,.o(mtimecmp_r_v_li)
   );

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 mtimecmp_data_cmd_decoder
  (.v_i(mtimecmp_data_cmd_v)
   ,.i(mem_data_cmd_core_enc)

   ,.o(mtimecmp_w_v_li)
   );

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 plic_cmd_decoder
  (.v_i(plic_cmd_v)
   ,.i(mem_cmd_core_enc)

   ,.o(plic_r_v_li)
   );

bsg_decode_with_v
 #(.num_out_p(num_core_p))
 plic_data_cmd_decoder
  (.v_i(plic_data_cmd_v)
   ,.i(mem_data_cmd_core_enc)

   ,.o(plic_w_v_li)
   );

// Could replace with bsg_cycle_counter if it provided a way to sideload a value
logic [dword_width_p-1:0] mtime_n, mtime_r;
wire mtime_w_v_li = mtime_data_cmd_v;
assign mtime_n    = mtime_w_v_li ? mem_data_cmd_cast_i.data : mtime_r + dword_width_p'(1);
  bsg_dff_reset
   #(.width_p(dword_width_p))
   mtime_reg
    (.clk_i(clk_i) // TODO: Should be a RTC once CDC strategy is decided
     ,.reset_i(reset_i)

     ,.data_i(mtime_n)
     ,.data_o(mtime_r)
     );

logic [num_core_p-1:0][dword_width_p-1:0] mtimecmp_n, mtimecmp_r;
logic [num_core_p-1:0]                    mipi_n    , mipi_r;
logic [num_core_p-1:0]                    plic_n    , plic_r;
for (genvar i = 0; i < num_core_p; i++)
  begin : rof1
    assign mtimecmp_n[i] = mem_data_cmd_cast_i.data[0+:dword_width_p];
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
     #(.width_p(1)
       ,.num_stages_p(irq_pipe_depth_p)
       )
     timer_irq_pipe
      (.clk_i(clk_i)

       ,.data_i((mtimecmp_r[i] >= mtime_r))
       ,.data_o(timer_irq_o[i])
       );

    assign mipi_n[i] = mem_data_cmd_cast_i.data[0];
    bsg_dff_reset_en
     #(.width_p(1))
     mipi_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(mipi_w_v_li[i])

       ,.data_i(mipi_n[i])
       ,.data_o(mipi_r[i])
       );

    bsg_dff_chain
     #(.width_p(1)
       ,.num_stages_p(irq_pipe_depth_p)
       )
     soft_irq_pipe
      (.clk_i(clk_i)

       ,.data_i(mipi_r[i])
       ,.data_o(soft_irq_o[i])
       );

    assign plic_n[i] = mem_data_cmd_cast_i.data[0];
    bsg_dff_reset_en
     #(.width_p(1))
     plic_reg
      (.clk_i(clk_i)
       ,.reset_i(reset_i)
       ,.en_i(plic_w_v_li[i])

       ,.data_i(plic_n[i])
       ,.data_o(plic_r[i])
       );

    bsg_dff_chain
     #(.width_p(1)
       ,.num_stages_p(irq_pipe_depth_p)
       )
     external_irq_pipe
      (.clk_i(clk_i)

       ,.data_i(plic_r[i])
       ,.data_o(external_irq_o[i])
       );

  end // rof1

  wire cfg_link_w_v_li = cfg_link_data_cmd_v;
  wire [bp_cfg_link_addr_width_gp-1:0] cfg_link_addr_li = mem_data_cmd_cast_i.addr[0+:bp_cfg_link_addr_width_gp-1];
  wire [bp_cfg_link_data_width_gp-1:0] cfg_link_data_li = mem_data_cmd_cast_i.data[0+:bp_cfg_link_data_width_gp-1];
  bsg_dff_chain
   #(.width_p(1+bp_cfg_link_addr_width_gp+bp_cfg_link_data_width_gp)
     ,.num_stages_p(cfg_link_pipe_depth_p)
     )
   cfg_link_pipe
    (.clk_i(clk_i)

     ,.data_i({cfg_link_w_v_li, cfg_link_addr_li, cfg_link_data_li})
     ,.data_o({cfg_link_w_v_o, cfg_link_addr_o, cfg_link_data_o})
     );

logic mipi_lo;
bsg_mux_one_hot
 #(.width_p(1)
   ,.els_p(num_core_p) 
   )
 mipi_mux_one_hot
  (.data_i(mipi_r)
   ,.sel_one_hot_i(mipi_r_v_li)
   ,.data_o(mipi_lo)
   );

logic [dword_width_p-1:0] mtimecmp_lo;
bsg_mux_one_hot
 #(.width_p(dword_width_p)
   ,.els_p(num_core_p)
   )
 mtimecmp_mux_one_hot
  (.data_i(mtimecmp_r)
   ,.sel_one_hot_i(mtimecmp_r_v_li)
   ,.data_o(mtimecmp_lo)
   );

logic plic_lo;
bsg_mux_one_hot
 #(.width_p(1)
   ,.els_p(num_core_p)
   )
 plic_mux_one_hot
  (.data_i(plic_r)
   ,.sel_one_hot_i(plic_r_v_li)
   ,.data_o(plic_lo)
   );

wire [dword_width_p-1:0] rdata_lo = plic_cmd_v 
                                    ? plic_lo 
                                    : mipi_cmd_v 
                                      ? mipi_lo 
                                      : mtimecmp_cmd_v 
                                        ? mtimecmp_lo 
                                        : mtime_r;
always_comb
  begin
    mem_data_resp_cast_o.msg_type      = mem_cmd_cast_i.msg_type;
    mem_data_resp_cast_o.addr          = mem_cmd_cast_i.addr;
    mem_data_resp_cast_o.payload       = mem_cmd_cast_i.payload;
    mem_data_resp_cast_o.non_cacheable = mem_cmd_cast_i.non_cacheable;
    mem_data_resp_cast_o.nc_size       = mem_cmd_cast_i.nc_size;
    mem_data_resp_cast_o.data          = rdata_lo;

    mem_resp_cast_o.msg_type           = mem_data_cmd_cast_i.msg_type;
    mem_resp_cast_o.addr               = mem_data_cmd_cast_i.addr;
    mem_resp_cast_o.payload            = mem_data_cmd_cast_i.payload;
    mem_resp_cast_o.non_cacheable      = mem_data_cmd_cast_i.non_cacheable;
    mem_resp_cast_o.nc_size            = mem_data_cmd_cast_i.nc_size;
  end

// Always accept incoming commands and data commands if the network is ready
assign mem_data_resp_v_o = mem_cmd_v_i & mem_data_resp_ready_i;
assign mem_cmd_yumi_o    = mem_cmd_v_i & mem_data_resp_ready_i;

assign mem_resp_v_o        = mem_data_cmd_v_i & mem_resp_ready_i;
assign mem_data_cmd_yumi_o = mem_data_cmd_v_i & mem_resp_ready_i;

endmodule : bp_clint


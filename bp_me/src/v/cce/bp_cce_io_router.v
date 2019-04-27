
module bp_cce_io_router
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 #(parameter num_cce_p = "inv"
   , parameter paddr_width_p = "inv"
   , parameter num_lce_p = "inv"
   , parameter block_size_in_bits_p = "inv"
   , parameter lce_assoc_p = "inv"

   , parameter num_io_p = "inv"

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

    // BP side
    , input [mem_cmd_width_lp-1:0] mem_cmd_i
    , input mem_cmd_v_i
    , output logic mem_cmd_yumi_o

    , input [mem_data_cmd_width_lp-1:0] mem_data_cmd_i
    , input mem_data_cmd_v_i
    , output logic mem_data_cmd_yumi_o

    , output logic [mem_resp_width_lp-1:0] mem_resp_o
    , output logic mem_resp_v_o
    , input mem_resp_ready_i

    , output logic [mem_data_resp_width_lp-1:0] mem_data_resp_o
    , output logic mem_data_resp_v_o
    , input  mem_data_resp_ready_i

    // Main memory connection
    , output logic [mem_cmd_width_lp-1:0] mem_cmd_o
    , output logic  mem_cmd_v_o
    , input  mem_cmd_yumi_i

    , output logic [mem_data_cmd_width_lp-1:0] mem_data_cmd_o
    , output logic  mem_data_cmd_v_o
    , input  mem_data_cmd_yumi_i

    , input [mem_resp_width_lp-1:0] mem_resp_i
    , input  mem_resp_v_i
    , output logic mem_resp_ready_o

    , input [mem_data_resp_width_lp-1:0] mem_data_resp_i
    , input  mem_data_resp_v_i
    , output logic mem_data_resp_ready_o

    // I/O device connections
    , output logic [num_io_p-1:0][mem_cmd_width_lp-1:0] io_cmd_o
    , output logic [num_io_p-1:0] io_cmd_v_o
    , input [num_io_p-1:0] io_cmd_yumi_i

    , output logic [num_io_p-1:0][mem_data_cmd_width_lp-1:0] io_data_cmd_o
    , output logic [num_io_p-1:0] io_data_cmd_v_o
    , input [num_io_p-1:0] io_data_cmd_yumi_i

    , input [num_io_p-1:0][mem_resp_width_lp-1:0] io_resp_i
    , input [num_io_p-1:0] io_resp_v_i
    , output logic [num_io_p-1:0] io_resp_ready_o

    , input [num_io_p-1:0][mem_data_resp_width_lp-1:0] io_data_resp_i
    , input [num_io_p-1:0] io_data_resp_v_i
    , output logic [num_io_p-1:0] io_data_resp_ready_o
   );

`declare_bp_me_if(paddr_width_p,block_size_in_bits_p,num_lce_p,lce_assoc_p);

localparam [num_io_p-1:0][paddr_width_p-1:0] io_paddr_p = {bp_mmio_msoftint_addr_gp[num_cce_p-1:0]
                                                           ,bp_mmio_mtimecmp_addr_gp[num_cce_p-1:0]
                                                           ,bp_mmio_mtime_addr_gp
                                                           };

bp_cce_mem_cmd_s mem_cmd;
bp_cce_mem_data_cmd_s mem_data_cmd;
bp_mem_cce_resp_s [num_io_p-1:0] mem_resp;
bp_mem_cce_data_resp_s [num_io_p-1:0] mem_data_resp;

logic [num_io_p-1:0] io_cmd_addr_match, io_data_cmd_addr_match;
logic [num_io_p-1:0] io_resp_addr_match, io_data_resp_addr_match;

bp_mem_cce_resp_s      io_resp_selected_li;
bp_mem_cce_data_resp_s io_data_resp_selected_li;

assign mem_cmd       = mem_cmd_i;
assign mem_data_cmd  = mem_data_cmd_i;
assign mem_resp      = mem_resp_i;
assign mem_data_resp = mem_data_resp_i;

wire unused = &{clk_i, reset_i};
    for (genvar io = 0; io < num_io_p; io++)
      begin : rof1
        assign io_cmd_addr_match[io]       = mem_cmd.non_cacheable 
                                             & (mem_cmd.addr           == io_paddr_p[io]);
        assign io_data_cmd_addr_match[io]  = mem_data_cmd.non_cacheable 
                                             & (mem_data_cmd.addr      == io_paddr_p[io]);
        assign io_resp_addr_match[io]      = mem_resp[io].non_cacheable 
                                             & (mem_resp[io].addr      == io_paddr_p[io]);
        assign io_data_resp_addr_match[io] = mem_data_resp[io].non_cacheable 
                                             & (mem_data_resp[io].addr == io_paddr_p[io]);
      end

bsg_mux_one_hot
 #(.width_p(mem_resp_width_lp)
   ,.els_p(num_io_p)
   )
 io_resp_sel
  (.data_i(io_resp_i)
   ,.sel_one_hot_i(io_resp_addr_match)
   ,.data_o(io_resp_selected_li)
   );

bsg_mux_one_hot
 #(.width_p(mem_data_resp_width_lp)
   ,.els_p(num_io_p)
   )
 io_data_resp_sel
  (.data_i(io_data_resp_i)
   ,.sel_one_hot_i(io_data_resp_addr_match)
   ,.data_o(io_data_resp_selected_li)
   );

wire any_io_cmd_v_li            = |io_cmd_addr_match & mem_cmd_v_i;
wire any_io_data_cmd_v_li       = |io_data_cmd_addr_match & mem_data_cmd_v_i;

wire any_io_resp_v_li           = |(io_resp_addr_match & io_resp_v_i);
wire any_io_data_resp_v_li      = |(io_resp_addr_match & io_data_resp_v_i);

wire any_io_cmd_yumi_li         = |(io_cmd_addr_match & io_cmd_yumi_i);
wire any_io_data_cmd_yumi_li    = |(io_data_cmd_addr_match & io_data_cmd_yumi_i);

always_comb 
  begin
    // BP Side
    mem_cmd_yumi_o        = mem_cmd_yumi_i | any_io_cmd_yumi_li;

    mem_data_cmd_yumi_o   = mem_data_cmd_yumi_i | any_io_data_cmd_yumi_li;

    mem_resp_o            = any_io_resp_v_li ? io_resp_selected_li : mem_resp_i;
    mem_resp_v_o          = any_io_resp_v_li | mem_resp_v_i;

    mem_data_resp_o       = any_io_data_resp_v_li ? io_data_resp_selected_li : mem_data_resp_i;
    mem_data_resp_v_o     = any_io_data_resp_v_li | mem_data_resp_v_i;

    // Memory Side
    mem_cmd_o             = mem_cmd_i;
    mem_cmd_v_o           = mem_cmd_v_i & ~any_io_cmd_v_li;

    mem_data_cmd_o        = mem_data_cmd_i;
    mem_data_cmd_v_o      = mem_data_cmd_v_i & ~any_io_data_cmd_v_li;

    mem_resp_ready_o      = mem_resp_ready_i;

    mem_data_resp_ready_o = mem_data_resp_ready_i;

    // IO side
    io_cmd_o              = mem_cmd_i;
    io_cmd_v_o            = io_cmd_addr_match; 

    io_data_cmd_o         = mem_cmd_i;
    io_data_cmd_v_o       = io_data_cmd_addr_match; 

    io_resp_ready_o       = mem_resp_ready_i;

    io_data_resp_ready_o  = mem_data_resp_ready_i;

  end

endmodule : bp_cce_io_router


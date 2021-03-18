
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_cfg
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)

   // TODO: Should I be a global param
   , localparam cfg_max_outstanding_p = 1
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [xce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                              mem_cmd_v_i
   , output                             mem_cmd_ready_o

   , output [xce_mem_msg_width_lp-1:0]  mem_resp_o
   , output                             mem_resp_v_o
   , input                              mem_resp_yumi_i

   , output [cfg_bus_width_lp-1:0]      cfg_bus_o
   , input [io_noc_did_width_p-1:0]     did_i
   , input [io_noc_did_width_p-1:0]     host_did_i
   , input [coh_noc_cord_width_p-1:0]   cord_i

   // ucode programming interface, synchronous read, direct connection to RAM
   , output                             cce_ucode_v_o
   , output                             cce_ucode_w_o
   , output [cce_pc_width_p-1:0]        cce_ucode_addr_o
   , output [cce_instr_width_gp-1:0]     cce_ucode_data_o
   , input [cce_instr_width_gp-1:0]      cce_ucode_data_i
   );

  `declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);

  bp_cfg_bus_s cfg_bus_cast_o;
  bp_bedrock_xce_mem_msg_s mem_cmd_li, mem_cmd_lo;

  assign cfg_bus_o = cfg_bus_cast_o;
  assign mem_cmd_li = mem_cmd_i;

  logic mem_cmd_v_lo, mem_cmd_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_bedrock_xce_mem_msg_s)), .els_p(cfg_max_outstanding_p))
   small_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_cmd_li)
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_o)

     ,.data_o(mem_cmd_lo)
     ,.v_o(mem_cmd_v_lo)
     ,.yumi_i(mem_cmd_yumi_li)
     );

  logic         freeze_r;
  bp_lce_mode_e icache_mode_r;
  bp_lce_mode_e dcache_mode_r;
  bp_cce_mode_e cce_mode_r;

  wire                        cfg_v_li    = mem_cmd_v_lo;
  wire                        cfg_w_v_li  = cfg_v_li & (mem_cmd_lo.header.msg_type == e_bedrock_mem_uc_wr);
  wire                        cfg_r_v_li  = cfg_v_li & (mem_cmd_lo.header.msg_type == e_bedrock_mem_uc_rd);
  wire [cfg_addr_width_gp-1:0] cfg_addr_li = mem_cmd_lo.header.addr[0+:cfg_addr_width_gp];
  wire [cfg_data_width_gp-1:0] cfg_data_li = mem_cmd_lo.data[0+:cfg_data_width_gp];

  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        freeze_r            <= 1'b1;
        icache_mode_r       <= e_lce_mode_uncached;
        dcache_mode_r       <= e_lce_mode_uncached;
        cce_mode_r          <= e_cce_mode_uncached;
      end
    else if (cfg_w_v_li)
      begin
        unique
        case (cfg_addr_li)
          cfg_reg_freeze_gp      : freeze_r       <= cfg_data_li;
          cfg_reg_icache_mode_gp : icache_mode_r  <= bp_lce_mode_e'(cfg_data_li);
          cfg_reg_dcache_mode_gp : dcache_mode_r  <= bp_lce_mode_e'(cfg_data_li);
          cfg_reg_cce_mode_gp    : cce_mode_r     <= bp_cce_mode_e'(cfg_data_li);
          default : begin end
        endcase
      end

  wire did_r_v_li       = cfg_r_v_li & (cfg_addr_li == cfg_reg_did_gp);
  wire host_did_r_v_li  = cfg_r_v_li & (cfg_addr_li == cfg_reg_host_did_gp);
  wire cord_r_v_li      = cfg_r_v_li & (cfg_addr_li == cfg_reg_cord_gp);
  wire domain_r_v_li    = cfg_r_v_li & (cfg_addr_li == cfg_reg_domain_mask_gp);

  assign cce_ucode_v_o    = (cfg_r_v_li | cfg_w_v_li) & (cfg_addr_li >= 16'h8000);
  assign cce_ucode_w_o    = cfg_w_v_li & (cfg_addr_li >= 16'h8000);
  assign cce_ucode_addr_o = cfg_addr_li[0+:cce_pc_width_p];
  assign cce_ucode_data_o = cfg_data_li[0+:cce_instr_width_gp];

  wire domain_w_v_li = cfg_w_v_li & (cfg_addr_li == cfg_reg_domain_mask_gp);
  wire [domain_width_p-1:0] domain_li = cfg_data_li[domain_width_p-1:0];

  // Enabled DIDs
  logic [domain_width_p-1:0] domain_mask_r;
  bsg_dff_reset_en
   #(.width_p(domain_width_p))
   domain_mask_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(domain_w_v_li)
     ,.data_i(domain_li)
     ,.data_o(domain_mask_r)
     );

  logic [core_id_width_p-1:0] core_id_li;
  logic [cce_id_width_p-1:0]  cce_id_li;
  logic [lce_id_width_p-1:0]  icache_id_li, dcache_id_li;
  bp_me_cord_to_id
   #(.bp_params_p(bp_params_p))
   id_map
    (.cord_i(cord_i)
     ,.core_id_o(core_id_li)
     ,.cce_id_o(cce_id_li)
     ,.lce_id0_o(icache_id_li)
     ,.lce_id1_o(dcache_id_li)
     );

  assign cfg_bus_cast_o = '{freeze: freeze_r
                            ,core_id: core_id_li
                            ,icache_id: icache_id_li
                            ,icache_mode: icache_mode_r
                            ,dcache_id: dcache_id_li
                            ,dcache_mode: dcache_mode_r
                            ,cce_id: cce_id_li
                            ,cce_mode: cce_mode_r
                            ,domain_mask: domain_mask_r
                            };

  logic rdata_v_r;
  bsg_dff_reset
   #(.width_p(1))
   rdata_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_cmd_v_lo)
     ,.data_o(rdata_v_r)
     );

  logic [4:0] read_sel_one_hot_r;
  bsg_dff_reset_en
   #(.width_p(5))
   read_reg_one_hot
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(mem_cmd_v_lo)

     ,.data_i({domain_r_v_li, host_did_r_v_li, did_r_v_li, cord_r_v_li, cce_ucode_v_o})
     ,.data_o(read_sel_one_hot_r)
     );

  logic [dword_width_gp-1:0] read_data;
  bsg_mux_one_hot
   #(.width_p(dword_width_gp), .els_p(5))
   read_mux_one_hot
    (.data_i({dword_width_gp'(domain_mask_r)
              ,dword_width_gp'(host_did_i)
              ,dword_width_gp'(did_i)
              ,dword_width_gp'(cord_i)
              ,dword_width_gp'(cce_ucode_data_i)
              })
     ,.sel_one_hot_i(read_sel_one_hot_r)

     ,.data_o(read_data)
     );

  logic [dword_width_gp-1:0] read_data_r;
  bsg_dff_en_bypass
   #(.width_p(dword_width_gp))
   rdata_reg
    (.clk_i(clk_i)
     ,.en_i(rdata_v_r)

     ,.data_i(read_data)
     ,.data_o(read_data_r)
     );

  bp_bedrock_xce_mem_msg_s mem_resp_lo;
  assign mem_resp_lo = '{header: mem_cmd_lo.header, data: dword_width_gp'(read_data_r)};

  assign mem_resp_o = mem_resp_lo;
  assign mem_resp_v_o = mem_cmd_v_lo & rdata_v_r;
  assign mem_cmd_yumi_li = mem_resp_yumi_i;


endmodule


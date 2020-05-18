
module bp_cfg
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   // TODO: Should I be a global param
   , localparam cfg_max_outstanding_p = 1
   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                              mem_cmd_v_i
   , output                             mem_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]  mem_resp_o
   , output                             mem_resp_v_o
   , input                              mem_resp_yumi_i

   , output [cfg_bus_width_lp-1:0]      cfg_bus_o
   , input [io_noc_did_width_p-1:0]     did_i
   , input [io_noc_did_width_p-1:0]     host_did_i
   , input [coh_noc_cord_width_p-1:0]   cord_i
   , input [dword_width_p-1:0]          irf_data_i
   , input [vaddr_width_p-1:0]          npc_data_i
   , input [dword_width_p-1:0]          csr_data_i
   , input [1:0]                        priv_data_i
   , input [cce_instr_width_p-1:0]      cce_ucode_data_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  
  bp_cfg_bus_s cfg_bus_cast_o;
  bp_cce_mem_msg_s mem_cmd_li, mem_cmd_lo;
  
  assign cfg_bus_o = cfg_bus_cast_o;
  assign mem_cmd_li = mem_cmd_i;

  logic mem_cmd_v_lo, mem_cmd_yumi_li;
  bsg_fifo_1r1w_small
   #(.width_p($bits(bp_cce_mem_msg_s)), .els_p(cfg_max_outstanding_p))
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
wire                        cfg_w_v_li  = cfg_v_li & (mem_cmd_lo.header.msg_type == e_cce_mem_uc_wr);
wire                        cfg_r_v_li  = cfg_v_li & (mem_cmd_lo.header.msg_type == e_cce_mem_uc_rd);
wire [cfg_addr_width_p-1:0] cfg_addr_li = mem_cmd_lo.header.addr[0+:cfg_addr_width_p];
wire [cfg_data_width_p-1:0] cfg_data_li = mem_cmd_lo.data[0+:cfg_data_width_p];

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
        bp_cfg_reg_freeze_gp      : freeze_r       <= cfg_data_li;
        bp_cfg_reg_icache_mode_gp : icache_mode_r  <= bp_lce_mode_e'(cfg_data_li);
        bp_cfg_reg_dcache_mode_gp : dcache_mode_r  <= bp_lce_mode_e'(cfg_data_li);
        bp_cfg_reg_cce_mode_gp    : cce_mode_r     <= bp_cce_mode_e'(cfg_data_li);
        default : begin end
      endcase
    end

wire did_r_v_li       = cfg_r_v_li & (cfg_addr_li == bp_cfg_reg_did_gp);
wire host_did_r_v_li  = cfg_r_v_li & (cfg_addr_li == bp_cfg_reg_host_did_gp);
wire cord_r_v_li      = cfg_r_v_li & (cfg_addr_li == bp_cfg_reg_cord_gp);

wire cce_ucode_w_v_li = cfg_w_v_li & (cfg_addr_li >= 16'h8000);
wire cce_ucode_r_v_li = cfg_r_v_li & (cfg_addr_li >= 16'h8000);
wire [cce_pc_width_p-1:0] cce_ucode_addr_li = cfg_addr_li[0+:cce_pc_width_p];
wire [cce_instr_width_p-1:0] cce_ucode_data_li = cfg_data_li[0+:cce_instr_width_p];

wire npc_w_v_li = cfg_w_v_li & (cfg_addr_li == bp_cfg_reg_npc_gp);
wire npc_r_v_li = cfg_r_v_li & (cfg_addr_li == bp_cfg_reg_npc_gp);
wire [vaddr_width_p-1:0] npc_li = cfg_data_li[0+:vaddr_width_p];

// Need to delay reads by 1 cycle here, to align with other synchronous reads
logic [dword_width_p-1:0] npc_data_r;
always_ff @(posedge clk_i)
  npc_data_r <= csr_data_i;

wire irf_w_v_li = cfg_w_v_li & (cfg_addr_li >= bp_cfg_reg_irf_x0_gp && cfg_addr_li <= bp_cfg_reg_irf_x31_gp);
wire irf_r_v_li = cfg_r_v_li & (cfg_addr_li >= bp_cfg_reg_irf_x0_gp && cfg_addr_li <= bp_cfg_reg_irf_x31_gp);
// TODO: we could get rid of this subtraction with intellignent address map
wire [reg_addr_width_p-1:0] irf_addr_li = (cfg_addr_li - bp_cfg_reg_irf_x0_gp);
wire [dword_width_p-1:0] irf_data_li = cfg_data_li;

wire csr_w_v_li = cfg_w_v_li & (cfg_addr_li >= bp_cfg_reg_csr_begin_gp && cfg_addr_li <= bp_cfg_reg_csr_end_gp);
wire csr_r_v_li = cfg_r_v_li & (cfg_addr_li >= bp_cfg_reg_csr_begin_gp && cfg_addr_li <= bp_cfg_reg_csr_end_gp);
wire [rv64_csr_addr_width_gp-1:0] csr_addr_li = (cfg_addr_li - bp_cfg_reg_csr_begin_gp);
wire [dword_width_p-1:0] csr_data_li = cfg_data_li;

// Need to delay reads by 1 cycle here, to align with other synchronous reads
logic [dword_width_p-1:0] csr_data_r;
always_ff @(posedge clk_i)
  csr_data_r <= csr_data_i;

wire priv_w_v_li = cfg_w_v_li & (cfg_addr_li == bp_cfg_reg_priv_gp);
wire priv_r_v_li = cfg_r_v_li & (cfg_addr_li == bp_cfg_reg_priv_gp);
wire [1:0] priv_data_li = cfg_data_li[1:0];

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
                          ,npc_w_v: npc_w_v_li
                          ,npc_r_v: npc_r_v_li
                          ,npc: npc_li
                          ,dcache_id: dcache_id_li
                          ,dcache_mode: dcache_mode_r
                          ,cce_id: cce_id_li
                          ,cce_mode: cce_mode_r
                          ,cce_ucode_w_v: cce_ucode_w_v_li
                          ,cce_ucode_r_v: cce_ucode_r_v_li
                          ,cce_ucode_addr: cce_ucode_addr_li
                          ,cce_ucode_data: cce_ucode_data_li
                          ,irf_w_v: irf_w_v_li
                          ,irf_r_v: irf_r_v_li
                          ,irf_addr: irf_addr_li
                          ,irf_data: irf_data_li
                          ,csr_w_v: csr_w_v_li
                          ,csr_r_v: csr_r_v_li
                          ,csr_addr: csr_addr_li
                          ,csr_data: csr_data_li
                          ,priv_w_v: priv_w_v_li
                          ,priv_r_v: priv_r_v_li
                          ,priv_data: priv_data_li
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

  logic [7:0] read_sel_one_hot_r;
  bsg_dff_reset_en
   #(.width_p(8))
   read_reg_one_hot
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(mem_cmd_v_lo)

     ,.data_i({irf_r_v_li, npc_r_v_li, csr_r_v_li, priv_r_v_li, host_did_r_v_li, did_r_v_li, cord_r_v_li, cce_ucode_r_v_li})
     ,.data_o(read_sel_one_hot_r)
     );

  logic [dword_width_p-1:0] read_data;
  bsg_mux_one_hot
   #(.width_p(dword_width_p), .els_p(8))
   read_mux_one_hot
    (.data_i({dword_width_p'(irf_data_i)
              ,dword_width_p'(npc_data_r)
              ,dword_width_p'(csr_data_r)
              ,dword_width_p'(priv_data_i)
              ,dword_width_p'(host_did_i)
              ,dword_width_p'(did_i)
              ,dword_width_p'(cord_i)
              ,dword_width_p'(cce_ucode_data_i)
              })
     ,.sel_one_hot_i(read_sel_one_hot_r)

     ,.data_o(read_data)
     );

  logic [dword_width_p-1:0] read_data_r;
  bsg_dff_en_bypass
   #(.width_p(dword_width_p))
   rdata_reg
    (.clk_i(clk_i)
     ,.en_i(rdata_v_r)

     ,.data_i(read_data)
     ,.data_o(read_data_r)
     );

  bp_cce_mem_msg_s mem_resp_lo;
  assign mem_resp_lo = '{header: mem_cmd_lo.header, data: cce_block_width_p'(read_data_r)};

  assign mem_resp_o = mem_resp_lo;
  assign mem_resp_v_o = mem_cmd_v_lo & rdata_v_r;
  assign mem_cmd_yumi_li = mem_resp_yumi_i;
  

endmodule


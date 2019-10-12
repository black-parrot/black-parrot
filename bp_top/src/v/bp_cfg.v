
module bp_cfg
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                              mem_cmd_v_i
   , output                             mem_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]  mem_resp_o
   , output                             mem_resp_v_o
   , input                              mem_resp_ready_i

   , output [cfg_bus_width_lp-1:0]     cfg_bus_o
   , input [dword_width_p-1:0]          irf_data_i
   , input [vaddr_width_p-1:0]          npc_data_i
   , input [dword_width_p-1:0]          csr_data_i
   , input [1:0]                        priv_data_i
   , input [cce_instr_width_p-1:0]      cce_ucode_data_i
   );

`declare_bp_cfg_bus_s(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

bp_cfg_bus_s cfg_bus_cast_o;
bp_cce_mem_msg_s mem_cmd_cast_i, mem_resp_cast_o;

assign cfg_bus_o = cfg_bus_cast_o;
assign mem_cmd_cast_i = mem_cmd_i;
assign mem_resp_o = mem_resp_cast_o;

logic                                   freeze_r;
logic [`BSG_SAFE_CLOG2(num_core_p)-1:0] core_id_r;
logic [`BSG_SAFE_CLOG2(num_lce_p)-1:0]  icache_id_r;
bp_lce_mode_e                           icache_mode_r;
logic                                   npc_w_v_r;
logic                                   npc_r_v_r;
logic [vaddr_width_p-1:0]               npc_r;
logic [`BSG_SAFE_CLOG2(num_lce_p)-1:0]  dcache_id_r;
bp_lce_mode_e                           dcache_mode_r;
logic [`BSG_SAFE_CLOG2(num_cce_p)-1:0]  cce_id_r;
bp_cce_mode_e                           cce_mode_r;
logic [`BSG_SAFE_CLOG2(num_lce_p)-1:0]  num_lce_r;
logic                                   cce_ucode_w_v_r;
logic                                   cce_ucode_r_v_r;
logic [cce_pc_width_p-1:0]              cce_ucode_addr_r;
logic [cce_instr_width_p-1:0]           cce_ucode_data_r;
logic                                   irf_w_v_r;
logic                                   irf_r_v_r;
logic [reg_addr_width_p-1:0]            irf_addr_r;
logic [dword_width_p-1:0]               irf_data_r;

// The config bus reads are synchronous (regfile, ucode ram, etc.). Therefore, we need to 
//   wait a cycle before returning mem_resp. However, if we wait to dequeue until mem_resp_ready is high,
//   it may no longer be true by the time the synchronous read is complete. To avoid having input
//   and output fifos, we simply serialize the requests with a cycle delay. For a config bus, this
//   is a very small overhead.
logic read_ready_r;
bsg_dff_reset
 #(.width_p(1))
 read_ready_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(mem_cmd_v_i & ~mem_resp_v_o)
   ,.data_o(read_ready_r)
   );

assign mem_cmd_yumi_o = mem_cmd_v_i & mem_resp_v_o;

wire                        cfg_v_li    = mem_cmd_v_i;
wire                        cfg_w_v_li  = cfg_v_li & (mem_cmd_cast_i.msg_type.cce_mem_cmd == e_cce_mem_uc_wr);
wire                        cfg_r_v_li  = cfg_v_li & (mem_cmd_cast_i.msg_type.cce_mem_cmd == e_cce_mem_uc_rd);
wire [cfg_addr_width_p-1:0] cfg_addr_li = mem_cmd_cast_i.addr[0+:cfg_addr_width_p];
wire [cfg_data_width_p-1:0] cfg_data_li = mem_cmd_cast_i.data[0+:cfg_data_width_p];

always_ff @(posedge clk_i)
  if (reset_i)
    begin
      freeze_r            <= 1'b1;
      core_id_r           <= '0;
      icache_id_r         <= '0;
      icache_mode_r       <= e_lce_mode_uncached;
      dcache_id_r         <= '0;
      dcache_mode_r       <= e_lce_mode_uncached;
      cce_id_r            <= '0;
      cce_mode_r          <= e_cce_mode_uncached;
      num_lce_r           <= '0;
    end
  else if (cfg_w_v_li)
    begin
      unique 
      case (cfg_addr_li)
        bp_cfg_reg_freeze_gp      : freeze_r       <= cfg_data_li;
        bp_cfg_reg_core_id_gp     : core_id_r      <= cfg_data_li;
        bp_cfg_reg_icache_id_gp   : icache_id_r    <= cfg_data_li;
        bp_cfg_reg_icache_mode_gp : icache_mode_r  <= bp_lce_mode_e'(cfg_data_li);
        bp_cfg_reg_dcache_id_gp   : dcache_id_r    <= cfg_data_li;
        bp_cfg_reg_dcache_mode_gp : dcache_mode_r  <= bp_lce_mode_e'(cfg_data_li);
        bp_cfg_reg_cce_id_gp      : cce_id_r       <= cfg_data_li;
        bp_cfg_reg_cce_mode_gp    : cce_mode_r     <= bp_cce_mode_e'(cfg_data_li);
        bp_cfg_reg_num_lce_gp     : num_lce_r      <= cfg_data_li;
        default : begin end
      endcase
    end

wire cce_ucode_w_v_li = cfg_w_v_li & (cfg_addr_li >= 16'h8000);
wire cce_ucode_r_v_li = cfg_r_v_li & (cfg_addr_li >= 16'h8000);
wire [cce_pc_width_p-1:0] cce_ucode_addr_li = cfg_addr_li[0+:cce_pc_width_p];
wire [cce_instr_width_p-1:0] cce_ucode_data_li = cfg_data_li[0+:cce_instr_width_p];

wire npc_w_v_li = cfg_w_v_li & (cfg_addr_li == bp_cfg_reg_npc_gp);
wire npc_r_v_li = cfg_r_v_li & (cfg_addr_li == bp_cfg_reg_npc_gp);
wire [vaddr_width_p-1:0] npc_li = cfg_data_li;

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
wire [1:0] priv_data_li = cfg_data_li;

assign cfg_bus_cast_o = '{freeze: freeze_r
                           ,core_id: core_id_r
                           ,icache_id: icache_id_r
                           ,icache_mode: icache_mode_r
                           ,npc_w_v: npc_w_v_li
                           ,npc_r_v: npc_r_v_li
                           ,npc: npc_li
                           ,dcache_id: dcache_id_r
                           ,dcache_mode: dcache_mode_r
                           ,cce_id: cce_id_r
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

assign mem_resp_v_o    = mem_resp_ready_i & read_ready_r;
assign mem_resp_cast_o = '{msg_type: mem_cmd_cast_i.msg_type
                           ,addr   : mem_cmd_cast_i.addr
                           ,payload: mem_cmd_cast_i.payload
                           ,size   : mem_cmd_cast_i.size
                           // TODO: Add all mode bits to mux
                           ,data   : irf_r_v_li 
                                     ? irf_data_i 
                                     : npc_r_v_li 
                                       ? npc_data_i
                                       : csr_r_v_li
                                         ? csr_data_r
                                         : priv_r_v_li
                                           ? priv_data_i
                                           : cce_ucode_data_i
                           };

endmodule


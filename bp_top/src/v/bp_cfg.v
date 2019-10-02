
module bp_cfg
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                              mem_cmd_v_i
   , output                             mem_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]  mem_resp_o
   , output                             mem_resp_v_o
   , input                              mem_resp_ready_i

   , output [proc_cfg_width_lp-1:0]     proc_cfg_o
   );

`declare_bp_proc_cfg_s(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

bp_proc_cfg_s proc_cfg_cast_o;
bp_cce_mem_msg_s mem_cmd_cast_i, mem_resp_cast_o;

assign proc_cfg_o = proc_cfg_cast_o;
assign mem_cmd_cast_i = mem_cmd_i;
assign mem_resp_o = mem_resp_cast_o;

logic                                   freeze_r;
logic [`BSG_SAFE_CLOG2(num_core_p)-1:0] core_id_r;
logic [`BSG_SAFE_CLOG2(num_lce_p)-1:0]  icache_id_r;
bp_lce_mode_e                           icache_mode_r;
logic                                   start_pc_w_v_r;
logic [vaddr_width_p-1:0]               start_pc_r;
logic [`BSG_SAFE_CLOG2(num_lce_p)-1:0]  dcache_id_r;
bp_lce_mode_e                           dcache_mode_r;
logic [`BSG_SAFE_CLOG2(num_cce_p)-1:0]  cce_id_r;
bp_cce_mode_e                           cce_mode_r;
logic [`BSG_SAFE_CLOG2(num_lce_p)-1:0]  num_lce_r;
logic                                   cce_ucode_w_v_r;
logic [cce_pc_width_p-1:0]              cce_ucode_addr_r;
logic [cce_instr_width_p-1:0]           cce_ucode_data_r;

assign mem_cmd_yumi_o = mem_cmd_v_i & mem_resp_ready_i;

wire                        cfg_v_li    = mem_cmd_yumi_o;
wire                        cfg_w_v_li  = cfg_v_li & (mem_cmd_cast_i.msg_type.cce_mem_cmd == e_cce_mem_uc_wr);
wire                        cfg_r_v_li  = cfg_v_li & (mem_cmd_cast_i.msg_type.cce_mem_cmd == e_cce_mem_uc_rd);
wire [cfg_addr_width_p-1:0] cfg_addr_li = mem_cmd_cast_i.addr[0+:cfg_addr_width_p];
wire [cfg_data_width_p-1:0] cfg_data_li = mem_cmd_cast_i.data[0+:cfg_data_width_p];

assign mem_resp_v_o    = mem_cmd_yumi_o;
assign mem_resp_cast_o = '{msg_type: mem_cmd_cast_i.msg_type
                           ,addr   : mem_cmd_cast_i.addr
                           ,payload: mem_cmd_cast_i.payload
                           ,size   : mem_cmd_cast_i.size
                           ,data   : '0
                           };

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

always_ff @(posedge clk_i)
  if (reset_i)
    begin
      cce_ucode_w_v_r     <= '0;
      cce_ucode_addr_r    <= '0;
      cce_ucode_data_r    <= '0;
    end
  else if (cfg_addr_li >= 16'h8000)
    begin
      cce_ucode_w_v_r  <= cfg_w_v_li;
      cce_ucode_addr_r <= cfg_addr_li[0+:cce_pc_width_p];
      cce_ucode_data_r <= cfg_data_li[0+:cce_instr_width_p];
    end

always_ff @(posedge clk_i)
  if (reset_i)
    begin
      start_pc_w_v_r <= '0;
      start_pc_r     <= '0;
    end
  else if (cfg_addr_li == bp_cfg_reg_start_pc_gp)
    begin
      start_pc_w_v_r <= cfg_w_v_li;
      start_pc_r     <= cfg_data_li;
    end

assign proc_cfg_cast_o = '{freeze: freeze_r
                           ,core_id: core_id_r
                           ,icache_id: icache_id_r
                           ,icache_mode: icache_mode_r
                           ,start_pc_w_v: start_pc_w_v_r
                           ,start_pc: start_pc_r
                           ,dcache_id: dcache_id_r
                           ,dcache_mode: dcache_mode_r
                           ,cce_id: cce_id_r
                           ,cce_mode: cce_mode_r
                           ,cce_ucode_w_v: cce_ucode_w_v_r
                           ,cce_ucode_r_v: '0
                           ,cce_ucode_addr: cce_ucode_addr_r
                           ,cce_ucode_data: cce_ucode_data_r
                           };

endmodule


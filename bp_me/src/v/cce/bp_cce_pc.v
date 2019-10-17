/**
 *
 * Name:
 *   bp_cce_pc.v
 *
 * Description:
 *   PC register, next PC logic, and instruction memory
 *
 * Configuration Link
 *   The config link is used to fill the instruction RAM, and to set the operating mode of the CCE.
 *   At startup, reset_i and freeze_i will both be high. After reset_i goes low, and while freeze_i
 *   is still high, the CCE waits for the mode register to be written.
 *
 *   config_addr_i specifies which address to read or write from. The address must be large enough
 *   to support 2*inst_ram_els_p addresses, plus the CCE mode register.
 *
 *   cfg_link_addr_width_p is assumed to be 16 bits, and cfg_link_data_width_p to be 32 bits
 *
 *   The msb of cfg_link_addr_width_p is reserved for the bridge link module. Of the address bits
 *   that are sent to the CCE, they are used as follows:
 *
 *   The address arriving on config_addr_i is interpreted as follows (and is 15-bits wide)
 *   14 - 1 if address is for CCE
 *   13 - 1 if address is for CCE instruction RAM, 0 if control register
 *
 *   For instruction RAM addresses (15'b11._...._...._....)
 *   1+:inst_ram_addr_width_lp - address into instruction RAM
 *   0 - specifies if instruction RAM address is for lo (0) or hi (1) 32-bit chunk of instruction
 *
 *   For configuration register addresses (15'b10._...._...._....)
 *   0+:cfg_reg_addr_width_lp - config register address
 *
 *   Current configuration registers:
 *   0 - cce_mode_r : controls the operating mode of the CCE
 *
 */

module bp_cce_pc
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
    `declare_bp_proc_params(bp_params_p)
    // Derived parameters
    , localparam inst_width_lp     = `bp_cce_inst_width
    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p)
  )
  (input                                         clk_i
   , input                                       reset_i

   , input [cfg_bus_width_lp-1:0]                cfg_bus_i
   , output [cce_instr_width_p-1:0]              cfg_cce_ucode_data_o

   // ALU branch result signal
   , input                                       alu_branch_res_i

   // Directory busy signal
   , input                                       dir_busy_i

   // control from decode
   , input                                       pc_stall_i
   , input [cce_pc_width_p-1:0]                  pc_branch_target_i

   // instruction output to decode
   , output logic [inst_width_lp-1:0]            inst_o
   , output logic                                inst_v_o
  );

  `declare_bp_cfg_bus_s(vaddr_width_p, num_core_p, num_cce_p, num_lce_p, cce_pc_width_p, cce_instr_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  typedef enum logic [2:0] {
    RESET
    ,INIT
    ,INIT_END
    ,START_FETCH
    ,FETCH
  } pc_state_e;

  pc_state_e pc_state_r, pc_state_n;

  logic [cce_pc_width_p-1:0] ex_pc_r, ex_pc_n;
  logic inst_v_r, inst_v_n;
  logic ram_v_li, ram_w_li;
  logic [cce_pc_width_p-1:0] ram_addr_li;
  logic [inst_width_lp-1:0] ram_data_li, ram_data_lo;

  bsg_mem_1rw_sync
    #(.width_p(inst_width_lp)
      ,.els_p(num_cce_instr_ram_els_p)
      )
    cce_inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i((cfg_bus_cast_i.cce_ucode_w_v | cfg_bus_cast_i.cce_ucode_r_v) | ram_v_li)
      ,.data_i(cfg_bus_cast_i.cce_ucode_w_v ? cfg_bus_cast_i.cce_ucode_data : ram_data_li)
      ,.addr_i((cfg_bus_cast_i.cce_ucode_w_v | cfg_bus_cast_i.cce_ucode_r_v) ? cfg_bus_cast_i.cce_ucode_addr : ram_addr_li)
      ,.w_i(cfg_bus_cast_i.cce_ucode_w_v | ram_w_li)
      ,.data_o(ram_data_lo)
      );
  assign cfg_cce_ucode_data_o = ram_data_lo;

  //synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pc_state_r <= RESET;

      ex_pc_r <= '0;
      inst_v_r <= '0;
    end else begin
      pc_state_r <= pc_state_n;

      ex_pc_r <= ex_pc_n;
      inst_v_r <= inst_v_n;
    end
  end

  assign inst_v_o = (dir_busy_i) ? 1'b0 : inst_v_r;
  assign inst_o = (inst_v_o) ? ram_data_lo : '0;

  always_comb begin
    // defaults
    pc_state_n = pc_state_r;
    ex_pc_n = '0;
    inst_v_n = '0;

    ram_v_li    = '0;
    ram_w_li    = '0;
    ram_addr_li = '0;
    ram_data_li = '0;

    case (pc_state_r)
      RESET: begin
        pc_state_n = INIT;
      end
      INIT: begin
        // If mode is uncached, the CCE operates in uncached mode
        // and this module stays in the INIT state and does not fetch microcode
        pc_state_n = (cfg_bus_cast_i.cce_mode == e_cce_mode_normal) ? INIT_END : INIT;
      end
      INIT_END: begin
        // This state gives an extra cycle for the RAM to finish the last write command that
        // was sent on the config link, if it needs it.
        pc_state_n = FETCH;
        ex_pc_n = '0;
        inst_v_n = 1'b1;
        ram_v_li = 1'b1;
        ram_addr_li = ex_pc_n;
      end
      FETCH: begin
        // Always continue fetching instructions
        pc_state_n = FETCH;
        ram_v_li = 1'b1;

        // The next instruction is always valid once this state is reached. Stalls replay
        // the current instruction, and branches have a 0 cycle redirect.
        inst_v_n = 1'b1;

        // The PC stalls and the current instruction is presented in the next cycle if
        // the decoder stalls execution, the directory is finishing a read, or the invalidtion
        // instruction is still executing.
        if (pc_stall_i | dir_busy_i) begin
          // when stalling, hold executing pc and ram addr registers constant
          ex_pc_n = ex_pc_r;
          // feed the currently executing pc as input to instruction ram
          ram_addr_li = ex_pc_n;

        // A branch is signaled by the ALU branch result. The PC is redirected to the branch
        // target, which is executed next cycle. The second instruction will be the one after
        // the branch target.
        end else if (alu_branch_res_i) begin
          // when branching, the instruction executed next is the branch target
          ex_pc_n = pc_branch_target_i;
          // if branching, use the branch target from the current instruction
          ram_addr_li = pc_branch_target_i;

        // If no stall or branch occurs, the next instruction executed is the one indicated
        // by the RAM address register, and the second instruction is the next one in sequential
        // order.
        end else begin
          // normal execution, the instruction that will be executed is the one that will
          // be fetched in sequential order
          ex_pc_n = ex_pc_r + 'd1;
          // the next instruction to fetch follows sequentially
          ram_addr_li = ex_pc_n;
        end
      end
      default: begin
        pc_state_n = RESET;
      end
    endcase


  end
endmodule


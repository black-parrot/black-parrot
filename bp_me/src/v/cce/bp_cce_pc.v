/**
 *
 * Name:
 *   bp_cce_pc.v
 *
 * Description:
 *   PC register, next PC logic, and instruction memory
 *
 */

module bp_cce_pc
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter inst_ram_els_p             = "inv"

    // Default parameters
    , parameter harden_p                 = 0

    // Derived parameters
    , localparam inst_width_lp           = `bp_cce_inst_width
    , localparam inst_ram_addr_width_lp  = `BSG_SAFE_CLOG2(inst_ram_els_p)
  )
  (input                                         clk_i
   , input                                       reset_i

   // ALU branch result signal
   , input                                       alu_branch_res_i

   // control from decode
   , input                                       pc_stall_i
   , input [inst_ram_addr_width_lp-1:0]          pc_branch_target_i

   // instruction output to decode
   , output logic [inst_width_lp-1:0]            inst_o
   , output logic                                inst_v_o

   // CCE Instruction boot ROM
   , output logic [inst_ram_addr_width_lp-1:0]   boot_rom_addr_o
   , input [inst_width_lp-1:0]                   boot_rom_data_i
  );

  logic [inst_ram_addr_width_lp-1:0] boot_rom_addr_r, boot_rom_addr_r_n;

  logic [inst_ram_addr_width_lp-1:0] ex_pc_r, ex_pc_r_n;
  logic inst_v_r, inst_v_r_n;

  logic ram_v_r, ram_v_r_n;
  logic ram_w_r, ram_w_r_n;
  logic [inst_ram_addr_width_lp-1:0] ram_addr_i, ram_addr_r, ram_addr_r_n;
  logic [inst_width_lp-1:0] ram_data_i_r, ram_data_o, ram_data_i_r_n;

  bsg_mem_1rw_sync
    #(.width_p(inst_width_lp)
      ,.els_p(inst_ram_els_p)
      )
    cce_inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(ram_v_r)
      ,.data_i(ram_data_i_r)
      ,.addr_i(ram_addr_i)
      ,.w_i(ram_w_r)
      ,.data_o(ram_data_o)
      );

  typedef enum logic [1:0] {
    BOOT
    ,BOOT_END
    ,FETCH_START
    ,FETCH
  } pc_state_e;

  pc_state_e pc_state, pc_state_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pc_state <= BOOT;

      ram_v_r <= '0;
      ram_w_r <= '0;
      ram_addr_r <= '0;
      ram_data_i_r <= '0;

      boot_rom_addr_r <= '0;

      ex_pc_r <= '0;
      inst_v_r <= '0;

    end else begin
      pc_state <= pc_state_n;

      ram_v_r <= ram_v_r_n;
      ram_w_r <= ram_w_r_n;
      ram_addr_r <= ram_addr_r_n;
      ram_data_i_r <= ram_data_i_r_n;

      boot_rom_addr_r <= boot_rom_addr_r_n;

      ex_pc_r <= ex_pc_r_n;
      inst_v_r <= inst_v_r_n;

    end
  end

  always_comb begin
    // outputs always come from registers or the instruction RAM
    boot_rom_addr_o = boot_rom_addr_r;
    inst_v_o = inst_v_r;
    inst_o = ram_data_o;

    // by default, regardless of the pc_state, send the instruction ram the registered value
    ram_addr_i = ram_addr_r;

    // next values for registers

    // defaults
    ram_w_r_n = '0;
    ram_data_i_r_n = '0;
    boot_rom_addr_r_n = '0;

    case (pc_state)
      BOOT: begin
        pc_state_n = (boot_rom_addr_r == (inst_ram_addr_width_lp)'(inst_ram_els_p-1))
          ? BOOT_END
          : BOOT;

        ram_v_r_n = 1'b1;
        ram_w_r_n = 1'b1;
        ram_addr_r_n = boot_rom_addr_r;
        ram_data_i_r_n = boot_rom_data_i;

        ex_pc_r_n = '0;
        inst_v_r_n = '0;

        boot_rom_addr_r_n = boot_rom_addr_r + 'd1;

      end
      BOOT_END: begin
        // At the end of this cycle, the RAM will write the last instruction from the boot ROM
        // into its memory array. The following cycle, PC will be setup to start fetching from
        // address 0

        // setup to fetch first instruction
        // at end of cycle 1, RAM controls are captured into registers
        // at end of cycle 2, RAM captures the registers
        // in cycle 3, the instruction is produced and executed
        pc_state_n = FETCH_START;

        // setup input registers for instruction RAM
        // fetch address 0
        ram_v_r_n = 1'b1;
        ram_addr_r_n = '0;

        ex_pc_r_n = '0;
        inst_v_r_n = '0;

      end
      FETCH_START: begin
        // setup the registers for the first instruction
        pc_state_n = FETCH;

        ram_v_r_n = 1'b1;
        ram_addr_r_n = ram_addr_r + 'd1;

        // at the end of this cycle, inputs to the instruction RAM will be latched into the
        // registers that feed the RAM inputs

        // Thus, next cycle, no instruction will be valid
        ex_pc_r_n = '0;
        inst_v_r_n = '0;

      end
      FETCH: begin
        // Always continue fetching instructions
        pc_state_n = FETCH;
        // next instruction is always valid once in steady state
        inst_v_r_n = 1'b1;

        // Always fetch an instruction
        ram_v_r_n = 1'b1;
        // setup RAM address register and register tracking PC of instruction being executed
        // also, determine input address for RAM depending on stall and branch in execution
        if (pc_stall_i) begin
          // when stalling, hold executing pc and ram addr registers constant
          ex_pc_r_n = ex_pc_r;
          ram_addr_r_n = ram_addr_r;
          // feed the currently executing pc as input to instruction ram
          ram_addr_i = ex_pc_r;
        end else if (alu_branch_res_i) begin
          // when branching, the instruction executed next is the branch target
          ex_pc_r_n = pc_branch_target_i;
          // the following instruction to fetch is after the branch target
          ram_addr_r_n = pc_branch_target_i + 'd1;
          // if branching, use the branch target from the current instruction
          ram_addr_i = pc_branch_target_i;
        end else begin
          // normal execution, the instruction that will be executed is the one that will
          // be fetched in sequential order
          ex_pc_r_n = ram_addr_r;
          // the next instruction to fetch follows sequentially
          ram_addr_r_n = ram_addr_r + 'd1;
          // normally, use the address register (i.e., sequential execution)
          ram_addr_i = ram_addr_r;
        end

      end
      default: begin
        pc_state_n = BOOT;
        ram_v_r_n = '0;
        ram_w_r_n = '0;
        ram_addr_r_n = '0;
        ram_data_i_r_n = '0;
        ex_pc_r_n = '0;
        inst_v_r_n = '0;
        boot_rom_addr_r_n = '0;
      end
    endcase
  end

endmodule

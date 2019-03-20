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

  logic [inst_ram_addr_width_lp-1:0] boot_rom_addr_r;

  logic [inst_ram_addr_width_lp-1:0] ex_pc_r;
  logic inst_v_r;

  logic ram_v_i, ram_w_i;
  logic ram_v_r, ram_w_r;
  logic [inst_ram_addr_width_lp-1:0] ram_addr_i, ram_addr_r;
  logic [inst_width_lp-1:0] ram_data_i, ram_data_o, ram_data_i_r;

  bsg_mem_1rw_sync
    #(.width_p(inst_width_lp)
      ,.els_p(inst_ram_els_p)
      )
    cce_inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(ram_v_i)
      ,.data_i(ram_data_i)
      ,.addr_i(ram_addr_i)
      ,.w_i(ram_w_i)
      ,.data_o(ram_data_o)
      );

  typedef enum logic [1:0] {
    BOOT
    ,BOOT_END
    ,FETCH
  } pc_state_e;

  pc_state_e pc_state;

  always_comb begin
    boot_rom_addr_o = '0;
    ram_v_i = '0;
    ram_w_i = '0;
    ram_addr_i = '0;
    ram_data_i = '0;
    inst_o = '0;
    inst_v_o = '0;

    if (reset_i) begin
      boot_rom_addr_o = '0;
      ram_v_i = '0;
      ram_w_i = '0;
      ram_addr_i = '0;
      ram_data_i = '0;
      inst_o = '0;
      inst_v_o = '0;

    end else if (pc_state == BOOT) begin
      boot_rom_addr_o = boot_rom_addr_r;
      ram_v_i = ram_v_r;
      ram_w_i = ram_w_r;
      ram_addr_i = ram_addr_r;
      ram_data_i = ram_data_i_r;
      inst_o = '0;
      inst_v_o = '0;

    end else if (pc_state == BOOT_END) begin
      boot_rom_addr_o = boot_rom_addr_r;
      ram_v_i = ram_v_r;
      ram_w_i = ram_w_r;
      ram_addr_i = ram_addr_r;
      ram_data_i = ram_data_i_r;
      inst_o = '0;
      inst_v_o = '0;

    end else if (pc_state == FETCH) begin
      boot_rom_addr_o = '0;
      ram_w_i = '0;
      ram_data_i = '0;
      ram_v_i = ram_v_r;
      // PC is always fetching, every cycle, so instruction to output is directly from the
      // RAM and it is always valid
      inst_o = ram_data_o;
      inst_v_o = inst_v_r;

      // determine input address for RAM depending on stall and branch in execution
      if (pc_stall_i) begin
        // when current instruction is stalling, select the current instruction PC
        ram_addr_i = ex_pc_r;
      end else if (alu_branch_res_i) begin
        // if branching, use the branch target from the current instruction
        ram_addr_i = pc_branch_target_i;
      end else begin
        // normally, use the address register (i.e., sequential execution)
        ram_addr_i = ram_addr_r;
      end


    end else begin
      boot_rom_addr_o = '0;
      ram_v_i = '0;
      ram_w_i = '0;
      ram_addr_i = '0;
      ram_data_i = '0;
      inst_o = '0;
      inst_v_o = '0;

    end
  end


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
      // Defaults for registers
      pc_state <= BOOT;
      ram_v_r <= '0;
      ram_w_r <= '0;
      ram_addr_r <= '0;
      ram_data_i_r <= '0;
      boot_rom_addr_r <= '0;

      ex_pc_r <= '0;
      inst_v_r <= '0;

      case (pc_state)
        BOOT: begin
          ram_v_r <= 1'b1;
          ram_w_r <= 1'b1;
          ram_addr_r <= boot_rom_addr_r;
          ram_data_i_r <= boot_rom_data_i;

          pc_state <= (boot_rom_addr_r == (inst_ram_addr_width_lp)'(inst_ram_els_p-1))
            ? BOOT_END
            : BOOT;

          boot_rom_addr_r <= boot_rom_addr_r + 'd1;

        end
        BOOT_END: begin
          // At the end of this cycle, the RAM will write the last instruction from the boot ROM
          // into its memory array. The following cycle, PC will start fetching with instruction
          // at address 0

          // setup to fetch first instruction
          ram_v_r <= 1'b1;
          ram_addr_r <= '0;
          pc_state <= FETCH;
        end
        FETCH: begin
          inst_v_r <= 1'b1;

          // at end of cycle 1, RAM controls are captured into registers
          // at end of cycle 2, RAM captures the control registers
          // in cycle 3, the instruction is produced and executed

          // Always fetch an instruction
          ram_v_r <= 1'b1;
          // setup RAM address register and register tracking PC of instruction being executed
          if (pc_stall_i) begin
            ex_pc_r <= ex_pc_r;
            ram_addr_r <= ram_addr_r;
          end else if (alu_branch_res_i) begin
            // when branching, the instruction executed next is the branch target
            ex_pc_r <= pc_branch_target_i;
            // the following instruction to fetch is after the branch target
            ram_addr_r <= pc_branch_target_i + 'd1;
          end else begin
            // normal execution, the instruction that will be executed is the one that will
            // be fetched in sequential order
            ex_pc_r <= ram_addr_r;
            // the next instruction to fetch follows sequentially
            ram_addr_r <= ram_addr_r + 'd1;
          end

          // Always continue fetching instructions
          pc_state <= FETCH;

        end
        default: begin
          pc_state <= BOOT;
          ram_v_r <= '0;
          ram_w_r <= '0;
          ram_addr_r <= '0;
          ram_data_i_r <= '0;
          boot_rom_addr_r <= '0;
    
          ex_pc_r <= '0;
          inst_v_r <= '0;

        end
      endcase
    end
  end
endmodule

/**
 *
 * Name:
 *   bp_cce_inst_ram.sv
 *
 * Description:
 *   Fetch PC register, next PC logic, and instruction memory
 *
 *   Fetch chooses between three PC's. By default, fetching uses the predicted PC from pre-decode.
 *   If there is a stall, the current PC is re-fetched. If a mispredict is detected in EX stage,
 *   fetch is re-directed to the correct PC as computed by EX.
 *
 *   The configuration bus can read or write the ucode RAM while CCE is in INIT state
 *   (uncached mode). A config read or write during normal execution results in undefined behavior.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_inst_ram
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    // Derived parameters
    , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)
  )
  (input                                         clk_i
   , input                                       reset_i

   // Configuration Interface
   , input [cfg_bus_width_lp-1:0]                cfg_bus_i

   // ucode programming interface, synchronous read, direct connection to RAM
   , input                                       ucode_v_i
   , input                                       ucode_w_i
   , input [cce_pc_width_p-1:0]                  ucode_addr_i
   , input [cce_instr_width_gp-1:0]              ucode_data_i
   , output logic [cce_instr_width_gp-1:0]       ucode_data_o

   , input [cce_pc_width_p-1:0]                  predicted_fetch_pc_i
   , input [cce_pc_width_p-1:0]                  branch_resolution_pc_i

   , input                                       stall_i
   , input                                       mispredict_i

   , output logic [cce_pc_width_p-1:0]           fetch_pc_o
   , output bp_cce_inst_s                        inst_o
   , output logic                                inst_v_o
  );

  // parameter checks
  if ($bits(bp_cce_inst_s) != cce_instr_width_gp)
    $error("Param cce_instr_width_gp does not match width of bp_cce_inst_s");

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  bp_cfg_bus_s cfg_bus_cast_i;
  assign cfg_bus_cast_i = cfg_bus_i;

  // Fetch PC Register
  // This register has the same value as the instruction RAM's internal address register
  logic [cce_pc_width_p-1:0] fetch_pc_r, fetch_pc_n;
  assign fetch_pc_o = fetch_pc_r;
  logic inst_v_r, inst_v_n;
  assign inst_v_o = inst_v_r;

  logic ram_v_li;
  bsg_mem_1rw_sync
    #(.width_p(cce_instr_width_gp)
      ,.els_p(num_cce_instr_ram_els_p)
      ,.latch_last_read_p(1)
      )
    inst_ram
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(ucode_v_i | ram_v_li)
      ,.data_i(ucode_data_i)
      ,.addr_i(ucode_v_i ? ucode_addr_i : fetch_pc_n)
      ,.w_i(ucode_w_i)
      ,.data_o(inst_o)
      );

  // Configuration Bus Microcode Data output
  assign ucode_data_o = inst_o;


  typedef enum logic [1:0] {
    RESET
    ,INIT
    ,INIT_END
    ,FETCH
  } fetch_state_e;

  fetch_state_e fetch_state_r, fetch_state_n;

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      fetch_state_r <= RESET;
      fetch_pc_r <= '0;
      inst_v_r <= '0;
    end else begin
      fetch_state_r <= fetch_state_n;
      fetch_pc_r <= fetch_pc_n;
      inst_v_r <= inst_v_n;
    end
  end

  always_comb begin
    fetch_state_n = fetch_state_r;
    fetch_pc_n = '0;
    inst_v_n = '0;

    ram_v_li    = '0;

    case (fetch_state_r)
      RESET: begin
        fetch_state_n = INIT;
      end
      INIT: begin
        // If mode is uncached, the CCE operates in uncached mode
        // and this module stays in the INIT state and does not fetch microcode
        fetch_state_n = (cfg_bus_cast_i.cce_mode == e_cce_mode_normal) ? INIT_END : INIT;
      end
      INIT_END: begin
        // This state gives an extra cycle for the RAM to finish the last write command that
        // was sent on the config link, if it needs it.
        fetch_state_n = FETCH;
        fetch_pc_n = '0;
        ram_v_li = 1'b1;
        // first instruction will be valid
        inst_v_n = 1'b1;
      end
      FETCH: begin
        // fetch as long as current instruction in execute stage is not stalling
        // RAM will hold last read
        ram_v_li = ~stall_i;

        // Select the next instruction to fetch
        // If the currently executing instruction is stalling, re-fetch the same instruction as
        // last cycle. If there is no stall, but a mispredict use the the PC computed from EX stage
        // in branch resolution logic. Otherwise, fetch the predicted fetch PC from the pre-decoder.
        fetch_pc_n = stall_i
          ? fetch_pc_r
          : mispredict_i
            ? branch_resolution_pc_i
            : predicted_fetch_pc_i;

        // From the point of view of the Fetch stage, the next instruction fetched is always
        // valid. It might be an incorrect fetch due to a mispredict, but the output of the
        // instruction RAM will be a valid instruction.
        inst_v_n = 1'b1;

      end
      default: begin
        fetch_state_n = RESET;
      end
    endcase


  end
endmodule


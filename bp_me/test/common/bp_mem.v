/**
 * bp_mem.v
 *
 */

module bp_mem
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter block_size_in_bytes_p="inv"
    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8
    ,parameter lce_sets_p="inv"

    ,parameter mem_els_p="inv"
    ,parameter boot_rom_width_p="inv"
    ,parameter boot_rom_els_p="inv"
    ,parameter lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)

    ,parameter bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,parameter bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
    ,parameter bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,parameter bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)

    ,parameter mem_addr_width_lp=`BSG_SAFE_CLOG2(mem_els_p)
    ,parameter block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    ,parameter byte_width_lp=8
  )
  (
    input clk_i
    ,input reset_i

    // CCE-MEM Interface
    // CCE to Mem, Mem is demanding and uses vaild->ready (valid-yumi)
    ,input logic [bp_cce_mem_cmd_width_lp-1:0] mem_cmd_i
    ,input logic mem_cmd_v_i
    ,output logic mem_cmd_yumi_o

    ,input logic [bp_cce_mem_data_cmd_width_lp-1:0] mem_data_cmd_i
    ,input logic mem_data_cmd_v_i
    ,output logic mem_data_cmd_yumi_o

    // Mem to CCE, Mem is demanding and uses ready->valid
    ,output logic [bp_mem_cce_resp_width_lp-1:0] mem_resp_o
    ,output logic mem_resp_v_o
    ,input logic mem_resp_ready_i

    ,output logic [bp_mem_cce_data_resp_width_lp-1:0] mem_data_resp_o
    ,output logic mem_data_resp_v_o
    ,input logic mem_data_resp_ready_i

    ,output logic [lg_boot_rom_els_lp-1:0] boot_rom_addr_o
    ,input logic [boot_rom_width_p-1:0]   boot_rom_data_i
  );

  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);

  bp_cce_mem_cmd_s mem_cmd_s_r, mem_cmd_i_s;
  bp_cce_mem_data_cmd_s mem_data_cmd_s_r, mem_data_cmd_i_s;
  bp_mem_cce_resp_s mem_resp_s_o;
  bp_mem_cce_data_resp_s mem_data_resp_s_o;

  logic [lg_boot_rom_els_lp-1:0] boot_count;

  // memory signals
  logic [mem_addr_width_lp-1:0] mem_addr_i, rd_addr, wr_addr;
  logic mem_v_i, mem_w_i;
  logic [block_size_in_bits_lp-1:0] mem_data_i, mem_data_o;

  bsg_mem_1rw_sync
    #(.width_p(block_size_in_bits_lp)
      ,.els_p(mem_els_p)
    ) mem
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.v_i(mem_v_i)
     ,.data_i(mem_data_i)
     ,.addr_i(mem_addr_i)
     ,.w_i(mem_w_i)
     ,.data_o(mem_data_o)
    );

  always_comb begin
    mem_resp_o = mem_resp_s_o;
    mem_data_resp_o = mem_data_resp_s_o;
    mem_cmd_i_s = mem_cmd_i;
    mem_data_cmd_i_s = mem_data_cmd_i;

    rd_addr = mem_addr_width_lp'(mem_cmd_i_s.addr >> block_offset_bits_lp);
    wr_addr = mem_addr_width_lp'(mem_data_cmd_i_s.addr >> block_offset_bits_lp);
  end

  typedef enum logic [2:0] {
    RESET
    ,READY
    ,RD_CMD
    ,RD_MEM
    ,RD_DATA_CMD
  } mem_state_e;

  mem_state_e mem_st;

  //logic [block_size_in_bits_lp-1:0] cnt;

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      mem_v_i <= '0;
      mem_w_i <= '0;
      mem_addr_i <= '0;
      mem_data_i <= '0;

      mem_st <= RESET;
      boot_count <= '0;
      boot_rom_addr_o <= '0;
      //cnt <= '0;

      // outputs
      mem_resp_v_o <= '0;
      mem_data_resp_v_o <= '0;
      mem_resp_s_o <= '0;
      mem_data_resp_s_o <= '0;

      // inputs
      mem_data_cmd_s_r <= '0;
      mem_data_cmd_yumi_o <= '0;
      mem_cmd_s_r <= '0;
      mem_cmd_yumi_o <= '0;

    end
    else begin
      mem_v_i <= '0;
      mem_w_i <= '0;
      mem_addr_i <= '0;
      mem_data_i <= '0;

      mem_resp_s_o <= '0;
      mem_resp_v_o <= '0;
      mem_data_resp_s_o <= '0;
      mem_data_resp_v_o <= '0;

      case (mem_st)
        /* Boot RAM from ROM */
        RESET: begin
          mem_v_i <= 1'b1;
          mem_w_i <= 1'b1;
          mem_addr_i <= boot_rom_addr_o;
          mem_data_i <= boot_rom_data_i;
          //cnt <= cnt + 'd1;

          mem_st <= (boot_count == boot_rom_els_p-1)
            ? READY
            : RESET; 

          boot_rom_addr_o <= boot_rom_addr_o + 'd1;
          boot_count <= boot_count + 'd1;

        end
        READY: begin
          // mem data command - need to write data to memory
          if (mem_data_cmd_v_i && mem_resp_ready_i) begin
            mem_data_cmd_yumi_o <= 1'b1;
            mem_data_cmd_s_r <= mem_data_cmd_i;
            mem_st <= RD_DATA_CMD;

            // do the write to memory ram
            mem_v_i <= 1'b1;
            mem_w_i <= 1'b1;
            mem_addr_i <= wr_addr;
            assert(wr_addr < mem_els_p) else $error("Mem write address too high");
            mem_data_i <= mem_data_cmd_i_s.data;

          // mem command - need to read data from memory
          end else if (mem_cmd_v_i && mem_data_resp_ready_i) begin
            mem_cmd_yumi_o <= 1'b1;
            mem_cmd_s_r <= mem_cmd_i;
            mem_st <= RD_MEM;

            // register the inputs for the memory, memory will consume them next cycle
            mem_v_i <= 1'b1;
            mem_addr_i <= rd_addr;
            assert(rd_addr < mem_els_p) else $error("Mem read address too high");

          end
        end
        RD_MEM: begin
          // read from memory, data will be available next cycle
          mem_cmd_yumi_o <= '0;
          mem_st <= RD_CMD;
        end
        RD_CMD: begin
          mem_st <= READY;

          mem_data_resp_s_o.msg_type <= mem_cmd_s_r.msg_type;
          mem_data_resp_s_o.payload.lce_id <= mem_cmd_s_r.payload.lce_id;
          mem_data_resp_s_o.payload.way_id <= mem_cmd_s_r.payload.way_id;
          mem_data_resp_s_o.addr <= mem_cmd_s_r.addr;
          mem_data_resp_s_o.data <= mem_data_o;

          // pull valid high
          mem_data_resp_v_o <= 1'b1;
        end
        RD_DATA_CMD: begin
          mem_data_cmd_yumi_o <= '0;
          mem_st <= READY;

          mem_resp_s_o.msg_type <= mem_data_cmd_s_r.msg_type;
          mem_resp_s_o.payload.lce_id <= mem_data_cmd_s_r.payload.lce_id;
          mem_resp_s_o.payload.way_id <= mem_data_cmd_s_r.payload.way_id;
          mem_resp_s_o.payload.req_addr <= mem_data_cmd_s_r.payload.req_addr;
          mem_resp_s_o.payload.tr_lce_id <= mem_data_cmd_s_r.payload.tr_lce_id;
          mem_resp_s_o.payload.tr_way_id <= mem_data_cmd_s_r.payload.tr_way_id;
          mem_resp_s_o.payload.transfer <= mem_data_cmd_s_r.payload.transfer;
          mem_resp_s_o.payload.replacement <= mem_data_cmd_s_r.payload.replacement;

          // pull valid high
          mem_resp_v_o <= 1'b1;
        end
        default: begin
          mem_st <= RESET;
        end
      endcase
    end
  end

endmodule


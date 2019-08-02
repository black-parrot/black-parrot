/**
 * bp_mem_dramsim2.v
 *
 */

module bp_mem_dramsim2
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter mem_id_p="inv"
    ,parameter clock_period_in_ps_p="inv"
    ,parameter prog_name_p="inv"
    ,parameter dram_cfg_p="inv"
    ,parameter dram_sys_cfg_p="inv"
    ,parameter dram_capacity_p="inv"

    ,parameter num_lce_p="inv"
    ,parameter num_cce_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter block_size_in_bytes_p="inv"
    ,parameter block_size_in_bits_lp=block_size_in_bytes_p*8
    ,parameter lce_sets_p="inv"

    ,parameter lce_req_data_width_p="inv"

    `declare_bp_me_if_widths(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)

    ,localparam word_select_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p/8)
    ,localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    ,localparam byte_width_lp=8
    ,localparam byte_offset_bits_lp=`BSG_SAFE_CLOG2(lce_req_data_width_p/8)
  )
  (
    input clk_i
    ,input reset_i

    // CCE-MEM Interface
    // CCE to Mem, Mem is demanding and uses vaild->ready (valid-yumi)
    ,input logic [cce_mem_cmd_width_lp-1:0] mem_cmd_i
    ,input logic mem_cmd_v_i
    ,output logic mem_cmd_yumi_o

    // Mem to CCE, Mem is demanding and uses ready->valid
    ,output logic [mem_cce_resp_width_lp-1:0] mem_resp_o
    ,output logic mem_resp_v_o
    ,input logic mem_resp_ready_i
  );

  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);

  bp_cce_mem_cmd_s mem_cmd_s_r, mem_cmd_i_s;
  bp_mem_cce_resp_s mem_resp_s_o;

  assign mem_resp_o = mem_resp_s_o;
  assign mem_cmd_i_s = mem_cmd_i;

  // memory signals
  logic [paddr_width_p-1:0] block_rd_addr, wr_addr;
  assign block_rd_addr = {mem_cmd_i_s.addr[paddr_width_p-1:block_offset_bits_lp], block_offset_bits_lp'(0)};
  // send full address on writes, let c++ code modify as needed based on cached or uncached
  assign wr_addr = mem_cmd_i_s.addr;

  // signals for dramsim2
  logic [511:0] dramsim_data;
  logic dramsim_valid;
  logic [511:0] dramsim_data_n;
  logic read_accepted, write_accepted;

  // Uncached access read and write selection
  logic [lce_req_data_width_p-1:0] nc_data;

  // get the 64-bit word for reads
  // address: [tag, set index, block offset] = [tag, word select, byte select]
  int word_select;
  assign word_select = mem_cmd_s_r.addr[byte_offset_bits_lp+:word_select_bits_lp];

  int byte_select;
  assign byte_select = mem_cmd_s_r.addr[0+:byte_offset_bits_lp];

  assign nc_data = dramsim_data[(word_select*lce_req_data_width_p)+:lce_req_data_width_p];

  int wr_size;

  typedef enum logic [2:0] {
    RESET
    ,READY
    ,RD_CMD
    ,RD_DATA_CMD
  } mem_state_e;

  mem_state_e mem_st;

  logic mem_wr_cmd, mem_rd_cmd;
  logic mem_uc_cmd;

  assign mem_rd_cmd = (mem_cmd_i_s.msg_type == e_cce_mem_rd) | (mem_cmd_i_s.msg_type == e_cce_mem_wr)
                      | (mem_cmd_i_s.msg_type == e_cce_mem_uc_rd);
  assign mem_wr_cmd = (mem_cmd_i_s.msg_type == e_cce_mem_wb) | (mem_cmd_i_s.msg_type == e_cce_mem_uc_wr);
  assign mem_uc_cmd = (mem_cmd_i_s.msg_type == e_cce_mem_uc_rd) | (mem_cmd_i_s.msg_type == e_cce_mem_uc_wr);

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      mem_st <= RESET;

      // outputs
      mem_resp_v_o <= '0;
      mem_resp_s_o <= '0;

      // inputs
      mem_cmd_s_r <= '0;
      mem_cmd_yumi_o <= '0;
    end
    else begin
      mem_resp_s_o <= '0;
      mem_resp_v_o <= '0;
      
      mem_cmd_yumi_o <= '0;

      read_accepted = '0;
      write_accepted = '0;

      case (mem_st)
        RESET: begin
          mem_st <= READY;
        end
        READY: begin
          // mem data command - need to write data to memory
          if (mem_cmd_v_i & mem_wr_cmd) begin
            // do the write to memory ram if available
            write_accepted = '0;
            // uncached write, send correct size
            if (mem_uc_cmd) begin

              wr_size = 
                (mem_cmd_i_s.size == e_mem_size_1)
                ? 1
                : (mem_cmd_i_s.size == e_mem_size_2)
                  ? 2
                  : (mem_cmd_i_s.size == e_mem_size_4)
                    ? 4
                    : 8;

              write_accepted = mem_write_req(wr_addr, mem_cmd_i_s.data, wr_size);
            end else begin
              // cached access, size == 0 tells c++ code to write full cache block
              write_accepted = mem_write_req(wr_addr, mem_cmd_i_s.data, 0);
            end

            mem_cmd_yumi_o <= write_accepted;
            mem_cmd_s_r    <= mem_cmd_i;
            mem_st         <= write_accepted ? RD_DATA_CMD : READY;
          end else if (mem_cmd_v_i & mem_rd_cmd) begin
            // do the read from memory ram if available
            read_accepted = mem_read_req(block_rd_addr);

            mem_cmd_yumi_o <= read_accepted;
            mem_cmd_s_r    <= mem_cmd_i;
            mem_st         <= read_accepted ? RD_CMD : READY;
          end
        end
        RD_CMD: begin
          if(mem_resp_ready_i) begin
            mem_st <= dramsim_valid ? READY : RD_CMD;
  
            mem_resp_s_o.msg_type <= mem_cmd_s_r.msg_type;
            mem_resp_s_o.payload <= mem_cmd_s_r.payload;
            mem_resp_s_o.addr <= mem_cmd_s_r.addr;
            // uncached load
            if (mem_cmd_s_r.msg_type == e_cce_mem_uc_rd) begin
              mem_resp_s_o.data <= {(block_size_in_bits_lp-lce_req_data_width_p)'('0),nc_data};
            // cached read/write request
            end else begin
              mem_resp_s_o.data <= dramsim_data;
            end
            mem_resp_s_o.size <= mem_cmd_s_r.size;
  
            // pull valid high
            mem_resp_v_o <= dramsim_valid;
          end
        end
        RD_DATA_CMD: begin
          if(mem_resp_ready_i) begin
            mem_st <= dramsim_valid ? READY : RD_DATA_CMD;
  
            mem_resp_s_o.msg_type <= mem_cmd_s_r.msg_type;
            mem_resp_s_o.addr <= mem_cmd_s_r.addr;
            mem_resp_s_o.payload <= mem_cmd_s_r.payload;
            mem_resp_s_o.size <= mem_cmd_s_r.size;
            mem_resp_s_o.data <= '0;
  
            // pull valid high
            mem_resp_v_o <= dramsim_valid;
          end
        end
        default: begin
          mem_st <= RESET;
        end
      endcase
    end
  end

import "DPI-C" function void init(input longint clock_period
                                  , input string prog_name
                                  , input string dram_cfg_name
                                  , input string system_cfg_name
                                  , input longint dram_capacity
                                  , input longint dram_req_width
                                  , input longint block_offset_bits
                                  );
import "DPI-C" context function bit tick();

import "DPI-C" context function bit mem_read_req(input longint addr);
import "DPI-C" context function bit mem_write_req(input longint addr
                                                  , input bit [block_size_in_bits_lp-1:0] data
                                                  , input int reqSize = 0
                                                  );

export "DPI-C" function read_resp;
export "DPI-C" function write_resp;

function void read_resp(input bit [block_size_in_bits_lp-1:0] data);
  dramsim_data_n  = data;
endfunction

function void write_resp();

endfunction

initial 
  begin
    init(clock_period_in_ps_p, prog_name_p, dram_cfg_p, dram_sys_cfg_p, dram_capacity_p, block_size_in_bits_lp, block_offset_bits_lp);
  end

// TODO: This is horrifying verilog / DPI glue. Should fix for best practices
always_ff @(posedge clk_i)
  begin
    if (mem_st == RD_CMD || mem_st == RD_DATA_CMD)
      begin
        dramsim_valid <= dramsim_valid == '0 ? tick() : dramsim_valid;
        dramsim_data <= dramsim_data_n;
      end
    else
      dramsim_valid <= tick();
  end

endmodule

/**
 * bp_mem_dramsim2.v
 *
 */

module bp_mem_dramsim2
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
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

    ,localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)


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
  );

  `declare_bp_me_if(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p);

  bp_cce_mem_cmd_s mem_cmd_s_r, mem_cmd_i_s;
  bp_cce_mem_data_cmd_s mem_data_cmd_s_r, mem_data_cmd_i_s;
  bp_mem_cce_resp_s mem_resp_s_o;
  bp_mem_cce_data_resp_s mem_data_resp_s_o;

  assign mem_resp_o = mem_resp_s_o;
  assign mem_data_resp_o = mem_data_resp_s_o;
  assign mem_cmd_i_s = mem_cmd_i;
  assign mem_data_cmd_i_s = mem_data_cmd_i;

  // memory signals
  logic [paddr_width_p-1:0] block_rd_addr, block_wr_addr;
  assign block_rd_addr = {mem_cmd_i_s.addr[paddr_width_p-1:block_offset_bits_lp], block_offset_bits_lp'(0)};
  assign block_wr_addr = {mem_data_cmd_i_s.addr[paddr_width_p-1:block_offset_bits_lp], block_offset_bits_lp'(0)};

  // signals for dramsim2
  logic [511:0] dramsim_data;
  logic dramsim_valid;
  logic [511:0] dramsim_data_n;
  logic read_accepted, write_accepted;

  // Uncached access read and write selection
  logic [lce_req_data_width_p-1:0] mem_nc_data, nc_data;

  // get the 64-bit word for reads
  // address: [tag, set index, block offset] = [tag, word select, byte select]
  int word_select;
  assign word_select = mem_cmd_s_r.addr[byte_offset_bits_lp+:word_select_bits_lp];

  int byte_select;
  assign byte_select = mem_cmd_s_r.addr[0+:byte_offset_bits_lp];

  assign mem_nc_data = dramsim_data[(word_select*lce_req_data_width_p)+:lce_req_data_width_p];

  assign nc_data = (mem_cmd_s_r.nc_size == e_lce_nc_req_1)
    ? {56'('0),mem_nc_data[(byte_select*8)+:8]}
    : (mem_cmd_s_r.nc_size == e_lce_nc_req_2)
      ? {48'('0),mem_nc_data[(byte_select*8)+:16]}
      : (mem_cmd_s_r.nc_size == e_lce_nc_req_4)
        ? {32'('0),mem_nc_data[(byte_select*8)+:32]}
        : mem_nc_data;

  // write shift - only set for non-cacheable writes
  int wr_word_select;
  assign wr_word_select = mem_data_cmd_i_s.addr[byte_offset_bits_lp+:word_select_bits_lp];

  int wr_byte_select;
  assign wr_byte_select = mem_data_cmd_i_s.addr[0+:byte_offset_bits_lp];

  int wr_shift;
  assign wr_shift = ((wr_word_select*lce_req_data_width_p) + (wr_byte_select*8));

  logic [block_size_in_bits_lp-1:0] wr_mask;
  assign wr_mask = (mem_data_cmd_i_s.nc_size == e_lce_nc_req_1)
    ? {(block_size_in_bits_lp-8)'('0),8'('1)} << wr_shift
    : (mem_data_cmd_i_s.nc_size == e_lce_nc_req_2)
      ? {(block_size_in_bits_lp-16)'('0),16'('1)} << wr_shift
      : (mem_data_cmd_i_s.nc_size == e_lce_nc_req_4)
        ? {(block_size_in_bits_lp-32)'('0),32'('1)} << wr_shift
        : {(block_size_in_bits_lp-64)'('0),64'('1)} << wr_shift;


  typedef enum logic [2:0] {
    RESET
    ,READY
    ,RD_CMD
    ,RD_DATA_CMD
  } mem_state_e;

  mem_state_e mem_st;

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      mem_st <= RESET;

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
      mem_resp_s_o <= '0;
      mem_resp_v_o <= '0;
      mem_data_resp_s_o <= '0;
      mem_data_resp_v_o <= '0;

      read_accepted = '0;
      write_accepted = '0;

      case (mem_st)
        RESET: begin
          mem_st <= READY;
        end
        READY: begin
          // mem data command - need to write data to memory
          if (mem_data_cmd_v_i && mem_resp_ready_i) begin
            // do the write to memory ram if available
            write_accepted = '0;
            if (mem_data_cmd_i_s.non_cacheable) begin
              // TODO: uncached writes
              write_accepted = '0;
            end else begin
              write_accepted = mem_write_req(block_wr_addr, mem_data_cmd_i_s.data);
            end

            mem_data_cmd_yumi_o <= write_accepted;
            mem_data_cmd_s_r    <= mem_data_cmd_i;
            mem_st              <= write_accepted ? RD_DATA_CMD : READY;
          end else if (mem_cmd_v_i && mem_data_resp_ready_i) begin
            // do the read from memory ram if available
            read_accepted = mem_read_req(block_rd_addr);

            mem_cmd_yumi_o <= read_accepted;
            mem_cmd_s_r    <= mem_cmd_i;
            mem_st         <= read_accepted ? RD_CMD : READY;
          end
        end
        RD_CMD: begin
          mem_cmd_yumi_o <= '0;
          mem_st <= dramsim_valid ? READY : RD_CMD;

          mem_data_resp_s_o.msg_type <= mem_cmd_s_r.msg_type;
          mem_data_resp_s_o.payload.lce_id <= mem_cmd_s_r.payload.lce_id;
          mem_data_resp_s_o.payload.way_id <= mem_cmd_s_r.payload.way_id;
          mem_data_resp_s_o.addr <= mem_cmd_s_r.addr;
          if (mem_cmd_s_r.non_cacheable) begin
            mem_data_resp_s_o.data <= {(block_size_in_bits_lp-lce_req_data_width_p)'('0),nc_data};
          end else begin
            mem_data_resp_s_o.data <= dramsim_data;
          end
          mem_data_resp_s_o.non_cacheable <= mem_cmd_s_r.non_cacheable;
          mem_data_resp_s_o.nc_size <= mem_cmd_s_r.nc_size;

          // pull valid high
          mem_data_resp_v_o <= dramsim_valid;
        end
        RD_DATA_CMD: begin
          mem_data_cmd_yumi_o <= '0;
          mem_st <= dramsim_valid ? READY : RD_DATA_CMD;

          mem_resp_s_o.msg_type <= mem_data_cmd_s_r.msg_type;
          mem_resp_s_o.addr <= mem_data_cmd_s_r.addr;
          mem_resp_s_o.payload.lce_id <= mem_data_cmd_s_r.payload.lce_id;
          mem_resp_s_o.payload.way_id <= mem_data_cmd_s_r.payload.way_id;
          mem_resp_s_o.payload.req_addr <= mem_data_cmd_s_r.payload.req_addr;
          mem_resp_s_o.payload.tr_lce_id <= mem_data_cmd_s_r.payload.tr_lce_id;
          mem_resp_s_o.payload.tr_way_id <= mem_data_cmd_s_r.payload.tr_way_id;
          mem_resp_s_o.payload.transfer <= mem_data_cmd_s_r.payload.transfer;
          mem_resp_s_o.payload.replacement <= mem_data_cmd_s_r.payload.replacement;
          mem_resp_s_o.non_cacheable <= mem_data_cmd_s_r.non_cacheable;
          mem_resp_s_o.nc_size <= mem_data_cmd_s_r.nc_size;

          // pull valid high
          mem_resp_v_o <= dramsim_valid;
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
    init(clock_period_in_ps_p, prog_name_p, dram_cfg_p, dram_sys_cfg_p, dram_capacity_p, block_size_in_bits_lp); 
  end

always_ff @(posedge clk_i)
  begin
    dramsim_valid <= tick(); 
    dramsim_data  <= dramsim_data_n;
  end

endmodule

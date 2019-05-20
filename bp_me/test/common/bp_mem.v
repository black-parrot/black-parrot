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

    ,parameter lce_req_data_width_p="inv"

    ,parameter mem_els_p="inv"
    ,parameter boot_rom_width_p="inv"
    ,parameter boot_rom_els_p="inv"
    ,parameter lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)

    ,localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p, num_lce_p, lce_assoc_p)
    ,localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p, block_size_in_bits_lp, num_lce_p, lce_assoc_p)

    ,localparam mem_addr_width_lp=`BSG_SAFE_CLOG2(mem_els_p)
    ,localparam block_offset_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p)
    ,localparam byte_width_lp=8
    ,localparam byte_offset_bits_lp=`BSG_SAFE_CLOG2(lce_req_data_width_p/8)
    ,localparam word_select_bits_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p/8)
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
  logic [block_size_in_bits_lp-1:0] mem_data_i, mem_data_o, mem_mask_i;
  logic [lce_req_data_width_p-1:0] mem_nc_data, nc_data;

  bsg_mem_1rw_sync_mask_write_bit
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
     ,.w_mask_i(mem_mask_i)
    );


  assign mem_resp_o = mem_resp_s_o;
  assign mem_data_resp_o = mem_data_resp_s_o;
  assign mem_cmd_i_s = mem_cmd_i;
  assign mem_data_cmd_i_s = mem_data_cmd_i;

  assign rd_addr = mem_addr_width_lp'(mem_cmd_i_s.addr >> block_offset_bits_lp);
  assign wr_addr = mem_addr_width_lp'(mem_data_cmd_i_s.addr >> block_offset_bits_lp);

  // get the 64-bit word for reads
  // address: [tag, set index, block offset] = [tag, word select, byte select]
  int word_select;
  assign word_select = mem_cmd_s_r.addr[byte_offset_bits_lp+:word_select_bits_lp];

  int byte_select;
  assign byte_select = mem_cmd_s_r.addr[0+:byte_offset_bits_lp];

  assign mem_nc_data = mem_data_o[(word_select*lce_req_data_width_p)+:lce_req_data_width_p];

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
    ,RD_MEM
    ,RD_DATA_CMD
  } mem_state_e;

  mem_state_e mem_st;

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      mem_v_i <= '0;
      mem_w_i <= '0;
      mem_addr_i <= '0;
      mem_data_i <= '0;
      mem_mask_i <= '0;

      mem_st <= RESET;
      boot_count <= '0;
      boot_rom_addr_o <= '0;

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
      mem_mask_i <= '0;

      mem_resp_s_o <= '0;
      mem_resp_v_o <= '0;
      mem_data_resp_s_o <= '0;
      mem_data_resp_v_o <= '0;

      case (mem_st)
        /* Boot RAM from ROM */
        RESET: begin
          mem_v_i <= 1'b1;
          mem_w_i <= 1'b1;
          mem_mask_i <= '1;
          mem_addr_i <= boot_rom_addr_o;
          mem_data_i <= boot_rom_data_i;

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
            mem_data_i <= (mem_data_cmd_i_s.non_cacheable == e_lce_req_cacheable)
                          ? mem_data_cmd_i_s.data
                          : (mem_data_cmd_i_s.data << wr_shift);
            mem_mask_i <= (mem_data_cmd_i_s.non_cacheable == e_lce_req_cacheable)
                          ? '1
                          : wr_mask;

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
          if (mem_cmd_s_r.non_cacheable) begin
            mem_data_resp_s_o.data <= {(block_size_in_bits_lp-lce_req_data_width_p)'('0),nc_data};
          end else begin
            mem_data_resp_s_o.data <= mem_data_o;
          end
          mem_data_resp_s_o.non_cacheable <= mem_cmd_s_r.non_cacheable;
          mem_data_resp_s_o.nc_size <= mem_cmd_s_r.nc_size;

          // pull valid high
          mem_data_resp_v_o <= 1'b1;
        end
        RD_DATA_CMD: begin
          mem_data_cmd_yumi_o <= '0;
          mem_st <= READY;

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
          mem_resp_v_o <= 1'b1;
        end
        default: begin
          mem_st <= RESET;
        end
      endcase
    end
  end

endmodule


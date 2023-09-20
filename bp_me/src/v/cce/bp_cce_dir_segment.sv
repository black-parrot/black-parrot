/**
 *
 * Name:
 *   bp_cce_dir_segment.sv
 *
 * Description:
 *   A directory segment stores the coherence state and tags for a set of cache blocks tracked
 *   by the CCE. Each segment tracks coherence info for a single type of LCE in the system.
 *   Different LCE types include data caches, instruction caches, and accelerator caches.
 *
 *   The physical directory SRAM is a synchronous read 1RW memory.
 *
 *   All write operations take 1 cycle, but read operations take multiple cycles. The busy_o
 *   signal will be asserted until the read operation is completed.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_dir_segment
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter `BSG_INV_PARAM(tag_sets_p)              // number of tag sets tracked by this directory
    , parameter `BSG_INV_PARAM(num_lce_p)             // number of LCEs tracked in this directory
    // parameters of cache type being tracked
    , parameter `BSG_INV_PARAM(sets_p)                // number of cache sets
    , parameter `BSG_INV_PARAM(assoc_p)               // associativity of each set
    , parameter `BSG_INV_PARAM(paddr_width_p)         // physical address width
    , parameter `BSG_INV_PARAM(tag_width_p)           // tag width of cacheable memory
    , parameter `BSG_INV_PARAM(block_size_in_bytes_p) // size of cache blocks in bytes

    , parameter `BSG_INV_PARAM(num_cce_p)             // number of CCEs that blocks are banked across

    // This is set as a constant based on prior physical design work showing 2 tag sets
    // per row gives good PPA, assuming 64-set, 8-way associative LCEs.
    // For even numbers of LCEs, all rows are fully utilized
    // For odd numbers of LCEs, last row for a way group will only have 1 tag set in use
    // Warning: changing this to another value will likely break the directory implementation
    , localparam tag_sets_per_row_lp       = 2

    // Derived parameters
    , localparam lg_tag_sets_per_row_lp    = `BSG_SAFE_CLOG2(tag_sets_per_row_lp)
    , localparam lg_tag_sets_lp            = `BSG_SAFE_CLOG2(tag_sets_p)
    , localparam lg_num_lce_lp             = `BSG_SAFE_CLOG2(num_lce_p)

    , localparam lg_sets_lp                = `BSG_SAFE_CLOG2(sets_p)
    , localparam lg_assoc_lp               = `BSG_SAFE_CLOG2(assoc_p)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_p)
    , localparam lg_num_cce_lp             = `BSG_SAFE_CLOG2(num_cce_p)

    // For VIPT L1 caches, should be equivalent to page_offset_width
    , localparam tag_offset_lp             = (lg_sets_lp+lg_block_size_in_bytes_lp)

    , localparam hash_index_width_lp      = $clog2((2**lg_sets_lp+num_cce_p-1)/num_cce_p)

    // Directory information width
    , localparam entry_width_lp           = (tag_width_p+$bits(bp_coh_states_e))
    , localparam tag_set_width_lp         = (entry_width_lp*assoc_p)
    , localparam row_width_lp             = (tag_set_width_lp*tag_sets_per_row_lp)

    // Number of rows to hold one set from all LCEs
    // Note: If there is an odd number of LCEs managed by this directory segment, the
    // last row per set will only utilize one of the 2 entries.
    // if num_lce_p == 1, rows_per_set_lp = CDIV(1,2) = ceil(1/2) = 1
    , localparam rows_per_set_lp          = `BSG_CDIV(num_lce_p, tag_sets_per_row_lp)
    , localparam lg_rows_per_set_lp       = `BSG_SAFE_CLOG2(rows_per_set_lp)

    // Total number of rows in the directory RAM
    , localparam rows_lp                  = (rows_per_set_lp*tag_sets_p)
    , localparam lg_rows_lp               = `BSG_SAFE_CLOG2(rows_lp)

    // Is the last directory row for each set fully utilized?
    , localparam last_row_full_lp         = ((num_lce_p % tag_sets_per_row_lp) == 0)

    , localparam counter_max_lp           = (rows_lp+1)
    , localparam counter_width_lp         = `BSG_SAFE_CLOG2(counter_max_lp)

  )
  (input                                                          clk_i
   , input                                                        reset_i

   // input address, fed to bsg_hash_bank
   , input [paddr_width_p-1:0]                                    addr_i
   // bypass signal to use low bits of raw address instead of hashed address
   , input                                                        addr_bypass_i

   , input [lg_num_lce_lp-1:0]                                    lce_i
   , input [lg_assoc_lp-1:0]                                      way_i
   , input [lg_assoc_lp-1:0]                                      lru_way_i
   , input bp_coh_states_e                                        coh_state_i
   , input bp_cce_inst_opd_gpr_e                                  addr_dst_gpr_i

   , input bp_cce_inst_minor_dir_op_e                             cmd_i
   , input                                                        r_v_i
   , input                                                        r_lru_v_i
   , input                                                        w_v_i

   , output logic                                                 busy_o

   , output logic                                                 sharers_v_o
   , output logic [num_lce_p-1:0]                                 sharers_hits_o
   , output logic [num_lce_p-1:0][lg_assoc_lp-1:0]                sharers_ways_o
   , output bp_coh_states_e [num_lce_p-1:0]                       sharers_coh_states_o

   , output logic                                                 lru_v_o
   , output bp_coh_states_e                                       lru_coh_state_o
   , output logic [paddr_width_p-1:0]                             lru_addr_o

   , output logic                                                 addr_v_o
   , output logic [paddr_width_p-1:0]                             addr_o
   , output bp_cce_inst_opd_gpr_e                                 addr_dst_gpr_o
  );

  // parameter checks
  // If value of tag_sets_per_row_lp changes (is no longer 2) the directory logic
  // needs to be re-written.
  if (tag_sets_per_row_lp != 2)
    $error("Unsupported configuration: number of sets per row must equal 2");
  if (sets_p <= 1)
    $error("Number of cache sets must be greater than 1; direct-mapped caches not supported");
  if (tag_sets_p < 1)
    $error("Number of tag sets must be at least 1");

  // input address hashing
  logic [lg_num_cce_lp-1:0] cce_id_lo;
  logic [hash_index_width_lp-1:0] set_id_lo;
  // NOTE: reverse the address to use the low order bits for striping cache blocks across CCEs
  wire [lg_sets_lp-1:0] hash_addr_rev = { <<{addr_i[lg_block_size_in_bytes_lp+:lg_sets_lp]}};

  bsg_hash_bank
    #(.banks_p(num_cce_p) // number of CCE's to spread way groups over
      ,.width_p(lg_sets_lp) // width of address input
      )
    addr_to_cce_id
     (.i(hash_addr_rev)
      ,.bank_o(cce_id_lo)
      ,.index_o(set_id_lo)
      );

  // Bypass hashing if input wants to use raw address input
  logic [lg_rows_lp-1:0] set_id;
  assign set_id = addr_bypass_i ? {'0, addr_i[0+:lg_tag_sets_lp]} : {'0, set_id_lo};

  // address offset table
  logic [rows_per_set_lp-1:0][lg_rows_lp-1:0] addr_offset_table;
  genvar i;
  generate
    for (i = 0; i < rows_per_set_lp; i++) begin
      assign addr_offset_table[i] = lg_rows_lp'(i * tag_sets_p);
    end
  endgenerate
  logic [lg_rows_per_set_lp-1:0] addr_lce;
  if (rows_per_set_lp > 1) begin
    // lookup: lce_i[1+:], assuming tag_sets_per_row_lp == 2
    assign addr_lce = lce_i[1+:lg_rows_per_set_lp];
  end else begin
    assign addr_lce = '0;
  end
  wire [lg_rows_lp-1:0] addr_offset = addr_offset_table[addr_lce];

  // directory address for single entry operations
  wire [lg_rows_lp-1:0] entry_row_addr = addr_offset + set_id;

  // Struct for directory entries
  `declare_bp_cce_dir_entry_s(tag_width_p);

  // Directory signals
  // read / write valid signals
  logic dir_ram_w_v;
  logic dir_ram_v;
  // address input and address register
  logic [lg_rows_lp-1:0] dir_ram_addr;
  logic [lg_rows_lp-1:0] dir_ram_addr_r, dir_ram_addr_n;
  // write mask and data in
  dir_entry_s [tag_sets_per_row_lp-1:0][assoc_p-1:0] dir_ram_w_mask, dir_ram_w_data;
  // data out
  dir_entry_s [tag_sets_per_row_lp-1:0][assoc_p-1:0] dir_row_entries;

  // Counter
  logic cnt_clr, cnt_inc;
  logic [counter_width_lp-1:0] cnt;

  // State machine
  typedef enum logic [2:0] {
    RESET
    ,INIT
    ,READY
    ,READ_FULL
    ,READ_ENTRY
  } dir_state_e;

  dir_state_e state_r, state_n;

  // Registers
  logic [lg_num_lce_lp-1:0]       lce_r, lce_n;
  logic [lg_assoc_lp-1:0]         way_r, way_n;
  logic [lg_assoc_lp-1:0]         lru_way_r, lru_way_n;
  logic [paddr_width_p-1:0]       addr_r, addr_n;
  wire [tag_width_p-1:0] addr_r_tag = addr_r[tag_offset_lp +: tag_width_p];
  logic [tag_sets_per_row_lp-1:0] dir_data_o_v_r, dir_data_o_v_n;
  bp_cce_inst_opd_gpr_e           addr_dst_gpr_r, addr_dst_gpr_n;
  // this registers is set when a rdw operation occurs and this segment must output the LRU
  // information for the read because the requesting LCE is tracked by this segment.
  logic                           r_lru_v_r, r_lru_v_n;

  assign addr_dst_gpr_o = addr_dst_gpr_r;

  // Sharers registers
  logic                                             sharers_v_r, sharers_v_n;
  logic [num_lce_p-1:0]                             sharers_hits_r, sharers_hits_n;
  logic [num_lce_p-1:0][lg_assoc_lp-1:0]            sharers_ways_r, sharers_ways_n;
  bp_coh_states_e [num_lce_p-1:0]                   sharers_coh_states_r, sharers_coh_states_n;

  assign sharers_v_o = sharers_v_r;
  assign sharers_hits_o = sharers_hits_r;
  assign sharers_ways_o = sharers_ways_r;
  assign sharers_coh_states_o = sharers_coh_states_r;

  logic [tag_sets_per_row_lp-1:0]                                 sharers_hits;
  logic [tag_sets_per_row_lp-1:0][lg_assoc_lp-1:0]                sharers_ways;
  bp_coh_states_e [tag_sets_per_row_lp-1:0]                       sharers_coh_states;

  // synopsys sync_set_reset reset_i
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= RESET;
      lce_r <= '0;
      way_r <= '0;
      lru_way_r <= '0;
      addr_r <= '0;
      dir_data_o_v_r <= '0;
      dir_ram_addr_r <= '0;

      addr_dst_gpr_r <= e_opd_r0;

      r_lru_v_r <= '0;

      sharers_v_r <= '0;
      sharers_hits_r <= '0;
      sharers_ways_r <= '0;
      sharers_coh_states_r <= e_COH_I;

    end else begin
      state_r <= state_n;
      lce_r <= lce_n;
      way_r <= way_n;
      lru_way_r <= lru_way_n;
      addr_r <= addr_n;
      dir_data_o_v_r <= dir_data_o_v_n;
      dir_ram_addr_r <= dir_ram_addr_n;

      addr_dst_gpr_r <= addr_dst_gpr_n;

      r_lru_v_r <= r_lru_v_n;

      sharers_v_r <= sharers_v_n;
      sharers_hits_r <= sharers_hits_n;
      sharers_ways_r <= sharers_ways_n;
      sharers_coh_states_r <= sharers_coh_states_n;

    end
  end

  // Directory State Machine logic
  always_comb begin
    // state - hold by default
    state_n = state_r;

    // counter inputs
    cnt_clr = 1'b0;
    cnt_inc = 1'b0;

    // directory inputs
    dir_ram_w_mask = '0;
    dir_ram_w_data = '0;
    dir_ram_v = '0;
    dir_ram_w_v = '0;
    dir_ram_addr = '0;

    lce_n = lce_r;
    way_n = way_r;
    lru_way_n = lru_way_r;
    addr_n = addr_r;
    dir_data_o_v_n = '0;
    dir_ram_addr_n = dir_ram_addr_r;

    addr_dst_gpr_n = addr_dst_gpr_r;

    r_lru_v_n = r_lru_v_r;

    sharers_v_n = sharers_v_r;
    sharers_hits_n = sharers_hits_r;
    sharers_ways_n = sharers_ways_r;
    sharers_coh_states_n = sharers_coh_states_r;

    // outputs
    busy_o = '0;
    addr_v_o = '0;
    addr_o = '0;

    case (state_r)
      RESET: begin
        state_n = INIT;
        cnt_clr = 1'b1;
      end
      INIT: begin
        // clear every row in directory after reset
        dir_ram_v = 1'b1;
        dir_ram_w_v = 1'b1;
        dir_ram_addr = cnt[0+:lg_rows_lp];
        dir_ram_w_mask = '1;
        dir_ram_w_data = '0;
        cnt_clr = (cnt == counter_width_lp'(rows_lp-1));
        state_n = cnt_clr ? READY : INIT;
        cnt_inc = ~cnt_clr;
        // directory is busy and cannot accept commands
        busy_o = 1'b1;
      end
      READY: begin

        if (r_v_i) begin

          // reset the sharers vectors for the new read; new values will be prepared for writing
          // starting in the next cycle, when the first read data is valid
          sharers_v_n = '0;
          sharers_hits_n = '0;
          sharers_ways_n = '0;
          sharers_coh_states_n = e_COH_I;

          // capture inputs into registers
          lce_n     = lce_i;
          way_n     = way_i;
          lru_way_n = lru_way_i;
          addr_n     = addr_i;

          addr_dst_gpr_n = addr_dst_gpr_i;

          r_lru_v_n = 1'b0;

          // ensure counter is reset to 0
          cnt_clr = 1'b1;

          // setup the read
          dir_ram_v = 1'b1;
          dir_ram_addr_n = '0;

          // initiate directory read of first row of way group
          // first row will be valid on output of directory next cycle (in READ)
          if (cmd_i == e_rdw_op) begin
            state_n = READ_FULL;

            // setup directory ram inputs
            dir_ram_addr = set_id;

            // next address to read from directory
            dir_ram_addr_n = dir_ram_addr + lg_rows_lp'(tag_sets_p);

            // next cycle, the data coming out of the RAM will be valid
            dir_data_o_v_n =
              (num_lce_p < tag_sets_per_row_lp)
              ? {'0, {num_lce_p{1'b1}}}
              : '1;

            r_lru_v_n = r_lru_v_i;

          // read entry
          end else if (cmd_i == e_rde_op) begin
            state_n = READ_ENTRY;

            // entry read does not use LRU way, override register next value to 0
            lru_way_n = '0;

            // The address to read depends on how many rows per way group there are.
            // If there is only one row per wg, then the input way group is the address.
            // If there is more than one row per wg, then the input way group is the high bits
            // and the rd_wg_row_select is the low bits since RDE op takes only one read (read a
            // single entry from a single tag set)
            dir_ram_addr = entry_row_addr;

          end

        // directory write
        end else if (w_v_i) begin
          r_lru_v_n = 1'b0;

          // mark sharers info as invalid after a write, since it is possible the write
          // changes data in the way-group that generated the sharers vectors
          sharers_v_n = '0;

          addr_n = '0;
          addr_dst_gpr_n = e_opd_r0;

          state_n = READY;
          dir_ram_v = 1'b1;
          dir_ram_w_v = 1'b1;

          dir_ram_addr = entry_row_addr;
          dir_ram_addr_n = entry_row_addr;

          if (cmd_i == e_clr_op) begin
            dir_ram_w_data = '0;
            dir_ram_w_mask = '1;
          end else if (cmd_i == e_wde_op) begin
            dir_ram_w_mask[lce_i[0]][way_i] = '1;
            dir_ram_w_data[lce_i[0]][way_i].tag = addr_i[tag_offset_lp+:tag_width_p];
            dir_ram_w_data[lce_i[0]][way_i].state = coh_state_i;
          end else if (cmd_i == e_wds_op) begin
            dir_ram_w_mask[lce_i[0]][way_i].state = bp_coh_states_e'('1);
            dir_ram_w_data[lce_i[0]][way_i].state = coh_state_i;
          end
        end

      end
      READ_FULL: begin
        // directory is busy
        busy_o = 1'b1;

        // cnt should be shifted based on LOG2(tag_sets_per_row_lp)
        // would require tag_sets_per_row_lp to be a power of two
        for(int j = 0; j < tag_sets_per_row_lp; j++) begin
          sharers_hits_n[(cnt << 1) + j] = sharers_hits[j];
          sharers_ways_n[(cnt << 1) + j] = sharers_ways[j];
          sharers_coh_states_n[(cnt << 1) + j] = sharers_coh_states[j];
        end

        // do another read if required (num_lce_p > 2 and rows_per_set_lp >= 2)
        if (cnt < counter_width_lp'(rows_per_set_lp-1)) begin
          dir_ram_v = 1'b1;
          dir_ram_addr = dir_ram_addr_r;
          dir_ram_addr_n = dir_ram_addr_r + lg_rows_lp'(tag_sets_p);
          dir_data_o_v_n = (cnt == counter_width_lp'(rows_per_set_lp-2))
                           ? (last_row_full_lp)
                             ? '1
                             : 2'b01
                           : '1;
        end else begin
          state_n = READY;
          cnt_clr = 1'b1;
          // sharers will be valid next cycle
          sharers_v_n = 1'b1;
        end
        cnt_inc = ~cnt_clr;
      end
      READ_ENTRY: begin
        busy_o = 1'b1;
        sharers_hits_n[0] = (addr_r_tag == dir_row_entries[lce_r[0]][way_r].tag)
                            & |dir_row_entries[lce_r[0]][way_r].state;
        sharers_ways_n[0] = way_r;
        sharers_coh_states_n[0] = dir_row_entries[lce_r[0]][way_r].state;
        sharers_v_n = 1'b1;
        // output the tag in the entry so it can be stored in a register
        addr_v_o = 1'b1;
        addr_o = {dir_row_entries[lce_r[0]][way_r].tag, tag_offset_lp'(0)};
        addr_n = {dir_row_entries[lce_r[0]][way_r].tag, tag_offset_lp'(0)};
        state_n = READY;
      end
      default: begin
        state_n = RESET;
      end
    endcase
  end

  // Instantiated modules

  // Reads are synchronous, with the address latched in the current cycle, and data available next
  // Writes take 1 cycle
  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(row_width_lp)
      ,.els_p(rows_lp)
      )
    directory
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.w_i(dir_ram_w_v)
      ,.w_mask_i(dir_ram_w_mask)
      ,.addr_i(dir_ram_addr)
      ,.data_i(dir_ram_w_data)
      ,.v_i(dir_ram_v)
      ,.data_o(dir_row_entries)
      );

  // counter
  bsg_counter_clear_up
    #(.max_val_p(counter_max_lp)
      ,.init_val_p(0)
     )
    counter
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.clear_i(cnt_clr)
      ,.up_i(cnt_inc)
      ,.count_o(cnt)
      );

  // combinational logic to determine hit, way, and state for current directory row output
  bp_cce_dir_tag_checker
    #(.tag_sets_per_row_p(tag_sets_per_row_lp)
      ,.row_width_p(row_width_lp)
      ,.assoc_p(assoc_p)
      ,.tag_width_p(tag_width_p)
     )
    tag_checker
     (.row_i(dir_row_entries)
      ,.row_v_i(dir_data_o_v_r)
      ,.tag_i(addr_r_tag)
      ,.sharers_hits_o(sharers_hits)
      ,.sharers_ways_o(sharers_ways)
      ,.sharers_coh_states_o(sharers_coh_states)
     );

  logic lru_v_lo;
  logic [tag_width_p-1:0] lru_tag_lo;
  bp_cce_dir_lru_extract
    #(.tag_sets_per_row_p(tag_sets_per_row_lp)
      ,.rows_per_set_p(rows_per_set_lp)
      ,.row_width_p(row_width_lp)
      ,.assoc_p(assoc_p)
      ,.num_lce_p(num_lce_p)
      ,.tag_width_p(tag_width_p)
     )
    lru_extract
     (.row_i(dir_row_entries)
      ,.row_v_i(dir_data_o_v_r)
      ,.row_num_i(cnt[0+:lg_rows_per_set_lp])
      ,.lce_i(lce_r)
      ,.lru_way_i(lru_way_r)
      ,.lru_v_o(lru_v_lo)
      ,.lru_coh_state_o(lru_coh_state_o)
      ,.lru_tag_o(lru_tag_lo)
     );
  wire [lg_sets_lp-1:0] lru_set = addr_r[lg_block_size_in_bytes_lp +: lg_sets_lp];
  assign lru_addr_o = {lru_tag_lo, lru_set, lg_block_size_in_bytes_lp'(0)};
  assign lru_v_o = lru_v_lo & r_lru_v_r;

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_dir_segment)

/**
 *
 * Name:
 *   bp_cce_dir.v
 *
 * Description:
 *   The directory stores the coherence state and tags for all cache blocks tracked by
 *   a CCE. The directory supports a small set of operations such as reading a way-group or entry,
 *   and writing an entry's coherence state and tag.
 *
 *   The directory is a synchronous read 1RW memory.
 *
 *   All writes take 1 cycle. RDW operations take multiple cycles. RDW reads out the way-group and
 *   performs tag comparisons and coherence state extraction, which are output in the sharers
 *   vectors. The RDW operation also produces information about the LRU way provided by the
 *   requesting LCE.
 *
 *   RDE is currently not supported.
 *
 */

module bp_cce_dir
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter sets_p                      = "inv" // number of LCE sets tracked by this directory
    , parameter lce_assoc_p               = "inv" // associativity of each set
    , parameter num_lce_p                 = "inv" // number of LCEs
    , parameter tag_width_p               = "inv" // address tag width

    // Default parameters

    // For even numbers of LCEs, all rows are fully utilized
    // For odd numbers of LCEs, last row for a way group will only have 1 tag set in use
    // TODO: this is set as a constant based on prior physical design work showing 2 tag sets
    // per row gives good PPA, assuming 64-set, 8-way associative LCEs
    , parameter tag_sets_per_row_lp       = 2

    // Derived parameters

    // Directory information widths
    , localparam entry_width_lp           = (tag_width_p+$bits(bp_coh_states_e))
    , localparam tag_set_width_lp         = (entry_width_lp*lce_assoc_p)
    , localparam row_width_lp             = (tag_set_width_lp*tag_sets_per_row_lp)

    // Number of rows to hold one set from all LCEs
    // TODO: this wastes space if there is an odd number of LCEs in the system
    // since tag_sets_per_row_lp is hard-coded to 2.
    , localparam rows_per_set_lp          = (num_lce_p == 1) ? 1
                                            :((num_lce_p % tag_sets_per_row_lp) == 0)
                                              ? (num_lce_p / tag_sets_per_row_lp)
                                              : ((num_lce_p / tag_sets_per_row_lp) + 1)

    // Total number of rows in the directory RAM
    , localparam rows_lp                  = (rows_per_set_lp*sets_p)

    // Is the last directory row for each set fully utilized?
    // yes (1) for even number of LCEs, no (0) for odd number of LCEs
    , localparam last_row_full_lp         = ((num_lce_p % 2) == 0)

    , localparam counter_max_lp           = (rows_lp+1)

    // Derived parameters - widths
    , localparam lg_sets_lp               = `BSG_SAFE_CLOG2(sets_p)
    , localparam lg_num_lce_lp            = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp          = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam lg_tag_sets_per_row_lp   = `BSG_SAFE_CLOG2(tag_sets_per_row_lp)
    , localparam lg_rows_per_set_lp       = `BSG_SAFE_CLOG2(rows_per_set_lp)
    , localparam lg_rows_lp               = `BSG_SAFE_CLOG2(rows_lp)

    , localparam addr_offset_shift_lp     = 1
  )
  (input                                                          clk_i
   , input                                                        reset_i

   , input [lg_sets_lp-1:0]                                       set_i
   , input [lg_num_lce_lp-1:0]                                    lce_i
   , input [lg_lce_assoc_lp-1:0]                                  way_i
   , input [lg_lce_assoc_lp-1:0]                                  lru_way_i
   , input [`bp_cce_inst_minor_op_width-1:0]                      r_cmd_i
   , input                                                        r_v_i

   , input [tag_width_p-1:0]                                      tag_i
   , input [$bits(bp_coh_states_e)-1:0]                           coh_state_i
   , input [`bp_cce_inst_minor_op_width-1:0]                      w_cmd_i
   , input                                                        w_v_i
   // TODO: this is used by FSM CCE, but not ucode CCE currently
   , input                                                        w_clr_row_i

   , output logic                                                 busy_o

   , output logic                                                 sharers_v_o
   , output logic [num_lce_p-1:0]                                 sharers_hits_o
   , output logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0]            sharers_ways_o
   , output logic [num_lce_p-1:0][$bits(bp_coh_states_e)-1:0]     sharers_coh_states_o

   , output logic                                                 lru_v_o
   , output logic                                                 lru_cached_excl_o
   , output logic [tag_width_p-1:0]                               lru_tag_o

   , output logic [tag_width_p-1:0]                               tag_o
  );

  initial begin
    assert(tag_sets_per_row_lp == 2) else
      $error("Unsupported configuration: number of sets per row must equal 2");
  end

  // address offset table
  // bits is O(rows_per_set), computation should all be static since it is generate/params
  // lookup: lce_i[1+:], assuming tag_sets_per_row_lp == 2
  logic [rows_per_set_lp-1:0][lg_rows_lp-1:0] addr_offset_table;
  genvar i;
  generate
    for (i = 0; i < rows_per_set_lp; i++) begin
      assign addr_offset_table[i] = (i * sets_p);
    end
  endgenerate
  wire [lg_num_lce_lp-1:0] addr_lce = (lce_i >> addr_offset_shift_lp);
  wire [lg_rows_lp-1:0] addr_offset = addr_offset_table[addr_lce[0+:lg_rows_per_set_lp]];

  // directory address for single entry operations
  wire [lg_rows_lp-1:0] entry_row_addr = addr_offset + set_i;

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
  dir_entry_s [tag_sets_per_row_lp-1:0][lce_assoc_p-1:0] dir_ram_w_mask, dir_ram_w_data;
  // data out
  dir_entry_s [tag_sets_per_row_lp-1:0][lce_assoc_p-1:0] dir_row_entries;

  // Counter
  logic cnt_clr, cnt_inc;
  logic [`BSG_SAFE_CLOG2(counter_max_lp+1)-1:0] cnt;

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
  logic [lg_sets_lp-1:0]          set_r, set_n;
  logic [lg_num_lce_lp-1:0]       lce_r, lce_n;
  logic [lg_lce_assoc_lp-1:0]     way_r, way_n;
  logic [lg_lce_assoc_lp-1:0]     lru_way_r, lru_way_n;
  logic [tag_width_p-1:0]         tag_r, tag_n;
  logic [tag_sets_per_row_lp-1:0] dir_data_o_v_r, dir_data_o_v_n;


  // Sharers registers
  logic                                             sharers_v_r, sharers_v_n;
  logic [num_lce_p-1:0]                             sharers_hits_r, sharers_hits_n;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0]        sharers_ways_r, sharers_ways_n;
  logic [num_lce_p-1:0][$bits(bp_coh_states_e)-1:0] sharers_coh_states_r, sharers_coh_states_n;

  assign sharers_v_o = sharers_v_r;
  assign sharers_hits_o = sharers_hits_r;
  assign sharers_ways_o = sharers_ways_r;
  assign sharers_coh_states_o = sharers_coh_states_r;

  logic [tag_sets_per_row_lp-1:0]                                 sharers_hits;
  logic [tag_sets_per_row_lp-1:0][lg_lce_assoc_lp-1:0]            sharers_ways;
  logic [tag_sets_per_row_lp-1:0][$bits(bp_coh_states_e)-1:0]     sharers_coh_states;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= RESET;
      set_r <= '0;
      lce_r <= '0;
      way_r <= '0;
      lru_way_r <= '0;
      tag_r <= '0;
      dir_data_o_v_r <= '0;
      dir_ram_addr_r <= '0;

      sharers_v_r <= '0;
      sharers_hits_r <= '0;
      sharers_ways_r <= '0;
      sharers_coh_states_r <= '0;

    end else begin
      state_r <= state_n;
      set_r <= set_n;
      lce_r <= lce_n;
      way_r <= way_n;
      lru_way_r <= lru_way_n;
      tag_r <= tag_n;
      dir_data_o_v_r <= dir_data_o_v_n;
      dir_ram_addr_r <= dir_ram_addr_n;

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

    // registers
    set_n = set_r;
    lce_n = lce_r;
    way_n = way_r;
    lru_way_n = lru_way_r;
    tag_n = tag_r;
    dir_data_o_v_n = '0;
    dir_ram_addr_n = dir_ram_addr_r;

    sharers_v_n = sharers_v_r;
    sharers_hits_n = sharers_hits_r;
    sharers_ways_n = sharers_ways_r;
    sharers_coh_states_n = sharers_coh_states_r;

    // outputs
    busy_o = '0;
    tag_o = tag_r;

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
        state_n = (cnt == (rows_lp-1)) ? READY : INIT;
        cnt_clr = (state_n == READY);
        cnt_inc = ~cnt_clr;
        // directory is busy and cannot accept commands
        busy_o = 1'b1;
      end
      READY: begin

        // initiate directory read of first row of way group
        // first row will be valid on output of directory next cycle (in READ)
        if (r_v_i & (r_cmd_i == e_rdw_op)) begin
          state_n = READ_FULL;

          // ensure counter is reset to 0
          cnt_clr = 1'b1;

          // capture inputs into registers
          set_n     = set_i;
          lce_n     = lce_i;
          way_n     = way_i;
          lru_way_n = lru_way_i;
          tag_n     = tag_i;

          // setup directory ram inputs
          dir_ram_v = 1'b1;
          dir_ram_addr[0+:lg_sets_lp] = set_i;

          // next address to read from directory
          dir_ram_addr_n = dir_ram_addr + sets_p;

          // next cycle, the data coming out of the RAM will be valid
          dir_data_o_v_n = (num_lce_p == 1) ? 2'b01 : 2'b11;

          // reset the sharers vectors for the new read; new values will be prepared for writing
          // starting in the next cycle, when the first read data is valid
          sharers_v_n = '0;
          sharers_hits_n = '0;
          sharers_ways_n = '0;
          sharers_coh_states_n = '0;

        // read entry
        end else if (r_v_i & (r_cmd_i == e_rde_op)) begin
          state_n = READ_ENTRY;

          // capture inputs into registers
          set_n = set_i;
          lce_n = lce_i;
          way_n = way_i;

          // entry read does not use LRU or input tag
          lru_way_n = '0;
          tag_n = '0;

          // setup the read
          dir_ram_v = 1'b1;

          // The address to read depends on how many rows per way group there are.
          // If there is only one row per wg, then the input way group is the address.
          // If there is more than one row per wg, then the input way group is the high bits
          // and the rd_wg_row_select is the low bits since RDE op takes only one read (read a
          // single entry from a single tag set)
          dir_ram_addr = entry_row_addr;

          // reset the sharers vectors for the new read; new values will be prepared for writing
          // starting in the next cycle, when the first read data is valid
          sharers_v_n = '0;
          sharers_hits_n = '0;
          sharers_ways_n = '0;
          sharers_coh_states_n = '0;

        // directory write
        end else if (w_v_i & ((w_cmd_i == e_wde_op) | (w_cmd_i == e_wds_op))) begin
          // mark sharers info as invalid after a write, since it is possible the write
          // changes data in the way-group that generated the sharers vectors
          sharers_v_n = '0;

          tag_n = '0;

          state_n = READY;
          dir_ram_v = 1'b1;
          dir_ram_w_v = 1'b1;

          dir_ram_addr = entry_row_addr;

          if (w_clr_row_i) begin
            dir_ram_w_data = '0;
            dir_ram_w_mask = '1;
          end else if (w_cmd_i == e_wde_op) begin
            dir_ram_w_mask[lce_i[0]][way_i] = '1;
            dir_ram_w_data[lce_i[0]][way_i].tag = tag_i;
            dir_ram_w_data[lce_i[0]][way_i].state = bp_coh_states_e'(coh_state_i);
          end else if (w_cmd_i == e_wds_op) begin
            dir_ram_w_mask[lce_i[0]][way_i].state = {$bits(bp_coh_states_e){1'b1}};
            dir_ram_w_data[lce_i[0]][way_i].state = bp_coh_states_e'(coh_state_i);
          end
        end

      end
      READ_FULL: begin
        // WARNING: if value of tag_sets_per_row_lp changes (is no longer 2), this logic will break!

        // directory is busy
        busy_o = 1'b1;

        for(int i = 0; i < tag_sets_per_row_lp; i++) begin
          sharers_hits_n[(cnt << 1) + i] = sharers_hits[i];
          sharers_ways_n[(cnt << 1) + i] = sharers_ways[i];
          sharers_coh_states_n[(cnt << 1) + i] = sharers_coh_states[i];
        end

        // do another read if required (num_lce_p > 2 and rows_per_set_lp >= 2)
        if (cnt < (rows_per_set_lp-1)) begin
          dir_ram_v = 1'b1;
          dir_ram_addr = dir_ram_addr_r;
          dir_ram_addr_n = dir_ram_addr_r + sets_p;
          dir_data_o_v_n = (cnt == (rows_per_set_lp-2))
                           ? (last_row_full_lp)
                             ? 2'b11
                             : 2'b01
                           : 2'b11;
        end else begin
          state_n = READY;
          cnt_clr = 1'b1;
          // sharers will be valid next cycle
          sharers_v_n = 1'b1;
        end
        cnt_inc = ~cnt_clr;
      end
      READ_ENTRY: begin
        // WARNING: if value of tag_sets_per_row_lp changes (is no longer 2), this logic will break!
        busy_o = 1'b1;
        sharers_hits_n[0] = 1'b1;
        sharers_ways_n[0] = way_r;
        sharers_coh_states_n[0] = dir_row_entries[lce_r[0]][way_r].state;
        sharers_v_n = 1'b1;
        // output the tag in the entry, and store it to the register
        // override output of tag_r with the tag from the directory read
        tag_o = dir_row_entries[lce_r[0]][way_r].tag;
        tag_n = dir_row_entries[lce_r[0]][way_r].tag;
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
      ,.lce_assoc_p(lce_assoc_p)
      ,.tag_width_p(tag_width_p)
     )
    tag_checker
     (.row_i(dir_row_entries)
      ,.row_v_i(dir_data_o_v_r)
      ,.tag_i(tag_r)
      ,.sharers_hits_o(sharers_hits)
      ,.sharers_ways_o(sharers_ways)
      ,.sharers_coh_states_o(sharers_coh_states)
     );

  bp_cce_dir_lru_extract
    #(.tag_sets_per_row_p(tag_sets_per_row_lp)
      ,.rows_per_set_p(rows_per_set_lp)
      ,.row_width_p(row_width_lp)
      ,.lce_assoc_p(lce_assoc_p)
      ,.num_lce_p(num_lce_p)
      ,.tag_width_p(tag_width_p)
     )
    lru_extract
     (.row_i(dir_row_entries)
      ,.row_v_i(dir_data_o_v_r)
      ,.row_num_i(cnt[0+:lg_rows_per_set_lp])
      ,.lce_i(lce_r)
      ,.lru_way_i(lru_way_r)
      ,.lru_v_o(lru_v_o)
      ,.lru_cached_excl_o(lru_cached_excl_o)
      ,.lru_tag_o(lru_tag_o)
     );

endmodule

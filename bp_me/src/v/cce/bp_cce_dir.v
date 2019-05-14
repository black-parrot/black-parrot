/**
 *
 * Name:
 *   bp_cce_dir.v
 *
 * Description:
 *   The directory stores the coherence state and tags for all cache blocks tracked by
 *   a CCE. The directory supports a small set of operations such as reading and writing
 *   pending bits for a way-group, reading a way-group or entry, and writing an entry's
 *   coherence state and tag.
 *
 *   The way-group memory in the directory is a synchronous read 1RW memories.
 *   The pending bits are stored in flops and may be read asynchronously.
 *
 *   All writes take 1 cycle
 *   RDW and RDE instructions present valid data in the next cycle (synchronous reads)
 *   RDP presents valid data in same cycle (asynchronous reads)
 *
 */

module bp_cce_dir
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_way_groups_p            = "inv"
    , parameter num_lce_p                 = "inv"
    , parameter num_cce_p                 = "inv"
    , parameter lce_assoc_p               = "inv"
    , parameter tag_width_p               = "inv"

    // Derived parameters
    , localparam lg_num_way_groups_lp     = `BSG_SAFE_CLOG2(num_way_groups_p)
    , localparam lg_num_lce_lp            = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp          = `BSG_SAFE_CLOG2(lce_assoc_p)
    // Directory information widths
    , localparam entry_width_lp           = (tag_width_p+`bp_cce_coh_bits)
    , localparam tag_set_width_lp         = (entry_width_lp*lce_assoc_p)
    // Directory physical organization
    , localparam dir_tag_sets_per_row_lp  = (num_lce_p/num_cce_p)
    , localparam lg_dir_tag_sets_per_row_lp = `BSG_SAFE_CLOG2(dir_tag_sets_per_row_lp)
    , localparam dir_rows_per_wg_lp       = (num_lce_p / dir_tag_sets_per_row_lp)
    , localparam lg_dir_rows_per_wg_lp    = `BSG_SAFE_CLOG2(dir_rows_per_wg_lp)
    , localparam dir_row_width_lp         = (tag_set_width_lp*dir_tag_sets_per_row_lp)
    , localparam dir_rows_lp              = (dir_rows_per_wg_lp*num_way_groups_p)
    , localparam lg_dir_rows_lp           = `BSG_SAFE_CLOG2(dir_rows_lp)

    // number of entry (tag+state) per directory row
    , localparam dir_entry_per_row_lp     = (dir_tag_sets_per_row_lp*lce_assoc_p)
  )
  (input                                                          clk_i
   , input                                                        reset_i

   , input [lg_num_way_groups_lp-1:0]                             way_group_i
   , input [lg_num_lce_lp-1:0]                                    lce_i
   , input [lg_lce_assoc_lp-1:0]                                  way_i
   , input [lg_lce_assoc_lp-1:0]                                  lru_way_i
   , input [`bp_cce_inst_minor_op_width-1:0]                      r_cmd_i
   , input                                                        r_v_i

   , input [tag_width_p-1:0]                                      tag_i
   , input [`bp_cce_coh_bits-1:0]                                 coh_state_i
   , input                                                        pending_i
   , input [`bp_cce_inst_minor_op_width-1:0]                      w_cmd_i
   , input                                                        w_v_i

   , output logic                                                 pending_o
   , output logic                                                 pending_v_o

   , output logic                                                 busy_o

   , output logic                                                 sharers_v_o
   , output logic [num_lce_p-1:0]                                 sharers_hits_o
   , output logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0]            sharers_ways_o
   , output logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0]           sharers_coh_states_o

   , output logic                                                 lru_v_o
   , output logic                                                 lru_cached_excl_o
   , output logic [tag_width_p-1:0]                               lru_tag_o

  );

  // pending bits
  logic [num_way_groups_p-1:0] pending_bits_r, pending_bits_n;
  logic pending_w_v, pending_r_v;
  assign pending_w_v = w_v_i & (w_cmd_i == e_wdp_op);
  assign pending_r_v = r_v_i & (r_cmd_i == e_rdp_op);

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      pending_bits_r <= '0;
    end else begin
      pending_bits_r <= pending_bits_n;
    end
  end

  always_comb begin
    if (reset_i) begin
      pending_bits_n = '0;
    end else begin
      pending_bits_n = pending_bits_r;
      if (pending_w_v) begin
        pending_bits_n[way_group_i] = pending_i;
      end
    end
  end

  assign pending_o = pending_bits_r[way_group_i];
  assign pending_v_o = pending_r_v;

  // Directory
  typedef struct packed {
    logic [tag_width_p-1:0]      tag;
    logic [`bp_cce_coh_bits-1:0] state;
  } entry_s;

  // read / write valid signals
  logic dir_ram_w_v, dir_ram_r_v;
  logic dir_ram_v;
  // read / write address
  logic [lg_dir_rows_lp-1:0] dir_ram_addr;
  // write mask and data in
  logic [dir_row_width_lp-1:0] dir_ram_w_mask;
  logic [dir_row_width_lp-1:0] dir_ram_w_data;
  // data out
  entry_s [dir_entry_per_row_lp-1:0] dir_row_lo;
  entry_s [dir_tag_sets_per_row_lp-1:0][lce_assoc_p-1:0] dir_row_entries;
  assign dir_row_entries = dir_row_lo;

  logic [lg_dir_tag_sets_per_row_lp-1:0] tag_set_select;

  typedef enum logic [2:0] {
    RESET
    ,READY
    ,READ
    ,FINISH_READ
  } dir_state_e;

  dir_state_e dir_state, dir_state_n;

  logic [lg_dir_rows_per_wg_lp:0] dir_rd_cnt_r, dir_rd_cnt_n;
  logic [lg_num_way_groups_lp-1:0]  way_group_r, way_group_n;
  logic [lg_num_lce_lp-1:0]         lce_r, lce_n;
  logic [lg_lce_assoc_lp-1:0]       way_r, way_n;
  logic [lg_lce_assoc_lp-1:0]       lru_way_r, lru_way_n;
  logic [tag_width_p-1:0]           tag_r, tag_n;
  logic dir_rd_v_r, dir_rd_v_n;

  logic [num_lce_p-1:0]                                 sharers_hits_r, sharers_hits_n;
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0]            sharers_ways_r, sharers_ways_n;
  logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0]           sharers_coh_states_r, sharers_coh_states_n;

  assign sharers_hits_o = sharers_hits_r;
  assign sharers_ways_o = sharers_ways_r;
  assign sharers_coh_states_o = sharers_coh_states_r;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      dir_state <= RESET;
      dir_rd_cnt_r <= '0;
      way_group_r <= '0;
      lce_r <= '0;
      way_r <= '0;
      lru_way_r <= '0;
      tag_r <= '0;
      dir_rd_v_r <= '0;

      sharers_hits_r <= '0;
      sharers_ways_r <= '0;
      sharers_coh_states_r <= '0;

    end else begin
      dir_state <= dir_state_n;
      dir_rd_cnt_r <= dir_rd_cnt_n;
      way_group_r <= way_group_n;
      lce_r <= lce_n;
      way_r <= way_n;
      lru_way_r <= lru_way_n;
      tag_r <= tag_n;
      dir_rd_v_r <= dir_rd_v_n;

      sharers_hits_r <= sharers_hits_n;
      sharers_ways_r <= sharers_ways_n;
      sharers_coh_states_r <= sharers_coh_states_n;

    end
  end

  // combinational logic to determine hit, way, and state for current directory row output

  logic [dir_tag_sets_per_row_lp-1:0][lce_assoc_p-1:0]                row_hits;
  logic [dir_tag_sets_per_row_lp-1:0]                                 sharers_hits;
  logic [dir_tag_sets_per_row_lp-1:0][lg_lce_assoc_lp-1:0]            sharers_ways;
  logic [dir_tag_sets_per_row_lp-1:0][`bp_cce_coh_bits-1:0]           sharers_coh_states;

  for (genvar i = 0; i < dir_tag_sets_per_row_lp; i++) begin : row_hits_tag_set
    for (genvar j = 0; j < lce_assoc_p; j++) begin : row_hits_way
      // hit if matching tag and state is valid (any bit set in state)
      assign row_hits[i][j] =
        (dir_rd_v_r)
        ? (dir_row_entries[i][j].tag == tag_r) & |(dir_row_entries[i][j].state)
        : '0;
    end
  end

  for (genvar i = 0; i < dir_tag_sets_per_row_lp; i++) begin : sharers_ways_gen
    bsg_encode_one_hot
      #(.width_p(lce_assoc_p)
        )
      row_hits_to_way_ids_and_v
       (.i(row_hits[i])
        ,.addr_o(sharers_ways[i])
        ,.v_o(sharers_hits[i])
        );
  end

  for (genvar i = 0; i < dir_tag_sets_per_row_lp; i++) begin : sharers_states_gen
    assign sharers_coh_states[i] = (sharers_hits[i])
                                   ? dir_row_entries[i][sharers_ways[i]].state
                                   : '0;
  end

  logic [`bp_cce_coh_bits-1:0] lru_coh_state;
  assign lru_coh_state = (dir_rd_v_r)
                         ? dir_row_entries[lce_r[0+:lg_dir_tag_sets_per_row_lp]][lru_way_r].state
                         : '0;
  assign lru_cached_excl_o = ((lru_coh_state == e_MESI_M) || (lru_coh_state == e_MESI_E));
  assign lru_tag_o = (dir_rd_v_r)
                     ? dir_row_entries[lce_r[0+:lg_dir_tag_sets_per_row_lp]][lru_way_r].tag
                     : '0;
  int lce_rd_cnt;
  assign lce_rd_cnt = (num_lce_p == 1) ? lce_r : (lce_r >> lg_dir_tag_sets_per_row_lp);
  assign lru_v_o = (dir_rd_v_r)
                   && (lce_rd_cnt == dir_rd_cnt_r);

  // Directory State Machine logic
  always_comb begin
    if (reset_i) begin
      dir_state_n = RESET;
      dir_rd_cnt_n = '0;
      dir_ram_w_mask = '0;
      dir_ram_w_data = '0;
      dir_ram_v = '0;
      dir_ram_r_v = '0;
      dir_ram_w_v = '0;
      way_group_n = '0;
      lce_n = '0;
      way_n = '0;
      lru_way_n = '0;
      tag_n = '0;
      dir_rd_v_n = '0;

      busy_o = '0;
      sharers_v_o = '0;

      sharers_hits_n = '0;
      sharers_ways_n = '0;
      sharers_coh_states_n = '0;

      tag_set_select = '0;

    end else begin
      // hold state by default
      dir_state_n = dir_state;
      dir_rd_cnt_n = '0;
      dir_ram_w_mask = '0;
      dir_ram_w_data = '0;
      dir_ram_v = '0;
      dir_ram_r_v = '0;
      dir_ram_w_v = '0;
      way_group_n = way_group_r;
      lce_n = lce_r;
      way_n = way_r;
      lru_way_n = lru_way_r;
      tag_n = tag_r;
      dir_rd_v_n = '0;

      busy_o = '0;
      sharers_v_o = '0;

      sharers_hits_n = sharers_hits_r;
      sharers_ways_n = sharers_ways_r;
      sharers_coh_states_n = sharers_coh_states_r;

      tag_set_select = '0;

      case (dir_state)
        RESET: begin
          dir_state_n = (reset_i) ? RESET : READY;
        end
        READY: begin
          dir_state_n = READY;
          // TODO: RDE not supported at the moment

          // initiate directory read of first row of way group
          // first row will be valid on output of directory next cycle (in READ)
          if (r_v_i & (r_cmd_i == e_rdw_op)) begin
            dir_state_n = READ;
            way_group_n = way_group_i;
            lce_n = lce_i;
            way_n = way_i;
            lru_way_n = lru_way_i;
            tag_n = tag_i;
            dir_ram_r_v = 1'b1;
            dir_ram_v = 1'b1;
            dir_ram_addr = (num_lce_p == 1) ? way_group_i : {way_group_i, dir_rd_cnt_r};
            dir_rd_cnt_n = '0;
            dir_rd_v_n = 1'b1;

            // reset the sharers vectors for the new read
            sharers_hits_n = '0;
            sharers_ways_n = '0;
            sharers_coh_states_n = '0;

            busy_o = 1'b1;

          // directory write
          end else if (w_v_i & ((w_cmd_i == e_wde_op) | (w_cmd_i == e_wds_op))) begin
            dir_state_n = READY;
            dir_ram_v = 1'b1;
            dir_ram_w_v = 1'b1;

            tag_set_select = (num_lce_p == 1) ? '0 : lce_i[0+:lg_dir_tag_sets_per_row_lp];
            dir_ram_addr = (num_lce_p == 1) ? way_group_i : {way_group_i, tag_set_select};

            if (w_cmd_i == e_wde_op) begin
              dir_ram_w_mask = {{(dir_row_width_lp-entry_width_lp){1'b0}},{entry_width_lp{1'b1}}}
                              << (tag_set_select*tag_set_width_lp + way_i*entry_width_lp);
            end else if (w_cmd_i == e_wds_op) begin
              dir_ram_w_mask = {{(dir_row_width_lp-`bp_cce_coh_bits){1'b0}},{`bp_cce_coh_bits{1'b1}}}
                              << (tag_set_select*tag_set_width_lp + way_i*entry_width_lp);
            end else begin
              dir_ram_w_mask = '0;
            end

            dir_ram_w_data = {{(dir_row_width_lp-entry_width_lp){1'b0}},{tag_i, coh_state_i}}
                             << (tag_set_select*tag_set_width_lp + way_i*entry_width_lp);
          end
        end
        READ: begin

          // capture the output of the read
          sharers_hits_n[dir_rd_cnt_r+:dir_tag_sets_per_row_lp] = sharers_hits;
          sharers_ways_n[(dir_rd_cnt_r*lg_lce_assoc_lp)+:(dir_tag_sets_per_row_lp*lg_lce_assoc_lp)] = sharers_ways;
          sharers_coh_states_n[(dir_rd_cnt_r*`bp_cce_coh_bits)+:(dir_tag_sets_per_row_lp*`bp_cce_coh_bits)] = sharers_coh_states;

          dir_rd_cnt_n = dir_rd_cnt_r + 'd1;

          // do another read if required
          // This only happens if there is more than 1 LCE, so dir_ram_addr doesn't need to check
          // whether there is only 1 LCE, as it does in the READY state
          if (dir_rd_cnt_r < (dir_rows_per_wg_lp-1)) begin
            dir_ram_r_v = 1'b1;
            dir_ram_v = 1'b1;
            dir_ram_addr = {way_group_r, dir_rd_cnt_r};
            dir_rd_v_n = 1'b1;
            dir_state_n = READ;
          end else begin
            dir_state_n = FINISH_READ;
          end

          // signal that directory is busy, PC should stall
          busy_o = 1'b1;
        end
        FINISH_READ: begin
          // output the sharers vectors registers
          sharers_v_o = 1'b1;
          // and give the register file a cycle to capture the outputs
          busy_o = 1'b1;

          // go back to READY state
          dir_state_n = READY;

        end
        default: begin
          dir_state_n = RESET;
        end
      endcase
    end
  end

  // Reads are synchronous, with the address latched in the current cycle, and data available next
  // Writes take 1 cycle
  bsg_mem_1rw_sync_mask_write_bit
    #(.width_p(dir_row_width_lp)
      ,.els_p(dir_rows_lp)
      )
    directory
     (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.w_i(dir_ram_w_v)
      ,.w_mask_i(dir_ram_w_mask)
      ,.addr_i(dir_ram_addr)
      ,.data_i(dir_ram_w_data)
      ,.v_i(dir_ram_v)
      ,.data_o(dir_row_lo)
      );

endmodule

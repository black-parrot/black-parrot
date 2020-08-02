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
 *   The directory is partitioned into directory segments, where each segment tracks the
 *   coherence for a single type of LCE (I$, D$, A$, etc.).
 */

module bp_cce_dir
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam block_size_in_bytes_lp = (cce_block_width_p/8)
    , localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp)

    // I$ ID to LCE ID mapping
    // I$ and D$ LCE ID's are [0, (2*num_core_p)-1]
    // A$ LCE ID's start at (2*num_core_p)
    , localparam acc_lce_id_offset_lp = (num_core_p*2)

    // minimal number of sets across all LCE types
    , localparam lce_min_sets_lp = `BSG_MIN(dcache_sets_p,
                                            `BSG_MIN(icache_sets_p, acache_sets_p))

  )
  (input                                                          clk_i
   , input                                                        reset_i

   , input [paddr_width_p-1:0]                                    addr_i
   , input                                                        addr_bypass_i

   , input [lce_id_width_p-1:0]                                   lce_i
   , input [lce_assoc_width_p-1:0]                                way_i
   , input [lce_assoc_width_p-1:0]                                lru_way_i
   , input bp_coh_states_e                                        coh_state_i
   , input bp_cce_inst_opd_gpr_e                                  addr_dst_gpr_i

   , input bp_cce_inst_minor_dir_op_e                             cmd_i
   , input                                                        r_v_i
   , input                                                        w_v_i

   , output logic                                                 busy_o

   , output logic                                                 sharers_v_o
   , output logic [num_lce_p-1:0]                                 sharers_hits_o
   , output logic [num_lce_p-1:0][lce_assoc_width_p-1:0]          sharers_ways_o
   , output bp_coh_states_e [num_lce_p-1:0]                       sharers_coh_states_o

   , output logic                                                 lru_v_o
   , output bp_coh_states_e                                       lru_coh_state_o
   , output logic [paddr_width_p-1:0]                             lru_addr_o

   , output logic                                                 addr_v_o
   , output logic [paddr_width_p-1:0]                             addr_o
   , output bp_cce_inst_opd_gpr_e                                 addr_dst_gpr_o
  );


  wire lce_is_icache = (~lce_i[0] && (lce_i < acc_lce_id_offset_lp));
  wire lce_is_dcache = (lce_i[0] && (lce_i < acc_lce_id_offset_lp));
  wire lce_is_acache = (lce_i >= acc_lce_id_offset_lp);

  // I$ directory segment

  // I$ segment parameters
  localparam icache_dir_sets_lp = `BSG_CDIV(icache_sets_p, num_cce_p);
  localparam lg_icache_assoc_lp = `BSG_SAFE_CLOG2(icache_assoc_p);
  localparam icache_lce_id_width_lp = `BSG_SAFE_CLOG2(num_core_p);
  localparam lg_icache_sets_lp = `BSG_SAFE_CLOG2(icache_sets_p);

  wire [icache_lce_id_width_lp-1:0] icache_lce_id = lce_i[1+:icache_lce_id_width_lp];

  // I$ segment signals
  wire icache_r_v = r_v_i & ((cmd_i == e_rdw_op)
                             | ((cmd_i == e_rde_op) && lce_is_icache));
  wire icache_w_v = w_v_i & lce_is_icache;

  logic                                                 icache_sharers_v;
  logic [num_core_p-1:0]                                icache_sharers_hits;
  logic [num_core_p-1:0][lg_icache_assoc_lp-1:0]        icache_sharers_ways;
  bp_coh_states_e [num_core_p-1:0]                      icache_sharers_coh_states;

  logic icache_busy, icache_lru_v, icache_addr_v;
  logic [paddr_width_p-1:0] icache_lru_addr_lo, icache_addr_lo;
  bp_cce_inst_opd_gpr_e icache_addr_dst_gpr_lo;
  bp_coh_states_e icache_lru_coh_state_lo;

  bp_cce_dir_segment
    #(.tag_sets_p(icache_dir_sets_lp)
      ,.num_lce_p(num_core_p)
      ,.sets_p(icache_sets_p)
      ,.assoc_p(icache_assoc_p)
      ,.paddr_width_p(paddr_width_p)
      ,.num_cce_p(num_cce_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      )
    icache_dir_segment
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.addr_i(addr_i)
      ,.addr_bypass_i(addr_bypass_i)
      ,.lce_i(icache_lce_id)
      ,.way_i(way_i[0+:lg_icache_assoc_lp])
      ,.lru_way_i(lru_way_i[0+:lg_icache_assoc_lp])
      ,.coh_state_i(coh_state_i)
      ,.addr_dst_gpr_i(addr_dst_gpr_i)
      ,.cmd_i(cmd_i)
      ,.r_v_i(icache_r_v)
      ,.r_lru_v_i(lce_is_icache)
      ,.w_v_i(icache_w_v)
      ,.busy_o(icache_busy)
      ,.sharers_v_o(icache_sharers_v)
      ,.sharers_hits_o(icache_sharers_hits)
      ,.sharers_ways_o(icache_sharers_ways)
      ,.sharers_coh_states_o(icache_sharers_coh_states)
      ,.lru_v_o(icache_lru_v)
      ,.lru_coh_state_o(icache_lru_coh_state_lo)
      ,.lru_addr_o(icache_lru_addr_lo)
      ,.addr_v_o(icache_addr_v)
      ,.addr_o(icache_addr_lo)
      ,.addr_dst_gpr_o(icache_addr_dst_gpr_lo)
      );

  // D$ directory segment

  // D$ segment parameters
  localparam dcache_dir_sets_lp = `BSG_CDIV(dcache_sets_p, num_cce_p);
  localparam lg_dcache_assoc_lp = `BSG_SAFE_CLOG2(dcache_assoc_p);
  localparam dcache_lce_id_width_lp = `BSG_SAFE_CLOG2(num_core_p);
  localparam lg_dcache_sets_lp = `BSG_SAFE_CLOG2(dcache_sets_p);

  // D$ segment signals
  logic                                                 dcache_sharers_v;
  logic [num_core_p-1:0]                                dcache_sharers_hits;
  logic [num_core_p-1:0][lg_dcache_assoc_lp-1:0]        dcache_sharers_ways;
  bp_coh_states_e [num_core_p-1:0]                      dcache_sharers_coh_states;

  logic dcache_busy, dcache_lru_v, dcache_addr_v;
  logic [paddr_width_p-1:0] dcache_lru_addr_lo, dcache_addr_lo;
  bp_cce_inst_opd_gpr_e dcache_addr_dst_gpr_lo;
  bp_coh_states_e dcache_lru_coh_state_lo;

  if (num_lce_p > 1) begin : dcache

    wire [dcache_lce_id_width_lp-1:0] dcache_lce_id = lce_i[1+:dcache_lce_id_width_lp];

    wire dcache_r_v = r_v_i & ((cmd_i == e_rdw_op)
                               | ((cmd_i == e_rde_op) && lce_is_dcache));
    wire dcache_w_v = w_v_i & lce_is_dcache;

    bp_cce_dir_segment
      #(.tag_sets_p(dcache_dir_sets_lp)
        ,.num_lce_p(num_core_p)
        ,.sets_p(dcache_sets_p)
        ,.assoc_p(dcache_assoc_p)
        ,.paddr_width_p(paddr_width_p)
        ,.num_cce_p(num_cce_p)
        ,.block_size_in_bytes_p(block_size_in_bytes_lp)
        )
      dcache_dir_segment
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.addr_i(addr_i)
        ,.addr_bypass_i(addr_bypass_i)
        ,.lce_i(dcache_lce_id)
        ,.way_i(way_i[0+:lg_dcache_assoc_lp])
        ,.lru_way_i(lru_way_i[0+:lg_dcache_assoc_lp])
        ,.coh_state_i(coh_state_i)
        ,.addr_dst_gpr_i(addr_dst_gpr_i)
        ,.cmd_i(cmd_i)
        ,.r_v_i(dcache_r_v)
        ,.r_lru_v_i(lce_is_dcache)
        ,.w_v_i(dcache_w_v)
        ,.busy_o(dcache_busy)
        ,.sharers_v_o(dcache_sharers_v)
        ,.sharers_hits_o(dcache_sharers_hits)
        ,.sharers_ways_o(dcache_sharers_ways)
        ,.sharers_coh_states_o(dcache_sharers_coh_states)
        ,.lru_v_o(dcache_lru_v)
        ,.lru_coh_state_o(dcache_lru_coh_state_lo)
        ,.lru_addr_o(dcache_lru_addr_lo)
        ,.addr_v_o(dcache_addr_v)
        ,.addr_o(dcache_addr_lo)
        ,.addr_dst_gpr_o(dcache_addr_dst_gpr_lo)
        );
  end else begin
    // No dcache in system (i.e., half_core_cfg), assign all outputs from dcache segment to 0.
    // (and hope the tool optimizes them away)
    always_comb begin
      dcache_busy = '0;
      dcache_sharers_v = 1'b1;
      dcache_sharers_hits = '0;
      dcache_sharers_ways = '0;
      dcache_sharers_coh_states = e_COH_I;
      dcache_lru_v = '0;
      dcache_lru_coh_state_lo = e_COH_I;
      dcache_lru_addr_lo = '0;
      dcache_addr_v = '0;
      dcache_addr_lo = '0;
      dcache_addr_dst_gpr_lo = e_opd_r0;
    end
  end

  // A$ directory segment

  // A$ segment parameters
  localparam acache_dir_sets_lp = `BSG_CDIV(acache_sets_p, num_cce_p);
  localparam lg_acache_assoc_lp = `BSG_SAFE_CLOG2(acache_assoc_p);
  localparam acache_lce_id_width_lp = `BSG_SAFE_CLOG2(num_cacc_p);
  localparam lg_acache_sets_lp = `BSG_SAFE_CLOG2(acache_sets_p);
  // local param that is set to 1 if there are 0 CACC's, so the acache_sharers vectors
  // are sized properly when there are no accelerators. This is only used to size the vectors
  // as 1 element vectors when there are no accelerators present.
  localparam num_cacc_lp = (num_cacc_p == 0) ? 1 : num_cacc_p;

  logic                                                   acache_sharers_v;
  logic [num_cacc_lp-1:0]                                 acache_sharers_hits;
  logic [num_cacc_lp-1:0][lg_acache_assoc_lp-1:0]         acache_sharers_ways;
  bp_coh_states_e [num_cacc_lp-1:0]                       acache_sharers_coh_states;

  logic acache_busy, acache_lru_v, acache_addr_v;
  logic [paddr_width_p-1:0] acache_lru_addr_lo, acache_addr_lo;
  bp_cce_inst_opd_gpr_e acache_addr_dst_gpr_lo;
  bp_coh_states_e acache_lru_coh_state_lo;

  if (num_cacc_p > 0) begin : acache
    // A$ segment signals
    wire [acache_lce_id_width_lp-1:0] acache_lce_id =
      acache_lce_id_width_lp'(lce_i - acc_lce_id_offset_lp);

    wire acache_r_v = r_v_i & ((cmd_i == e_rdw_op)
                               | ((cmd_i == e_rde_op) && lce_is_acache));
    wire acache_w_v = w_v_i & lce_is_acache;

    // Accelerator LCEs exist, instantiate a directory segmenet to track them
    bp_cce_dir_segment
      #(.tag_sets_p(acache_dir_sets_lp)
        ,.num_lce_p(num_cacc_p)
        ,.sets_p(acache_sets_p)
        ,.assoc_p(acache_assoc_p)
        ,.paddr_width_p(paddr_width_p)
        ,.num_cce_p(num_cce_p)
        ,.block_size_in_bytes_p(block_size_in_bytes_lp)
        )
      acache_dir_segment
       (.clk_i(clk_i)
        ,.reset_i(reset_i)
        ,.addr_i(addr_i)
        ,.addr_bypass_i(addr_bypass_i)
        ,.lce_i(acache_lce_id)
        ,.way_i(way_i[0+:lg_acache_assoc_lp])
        ,.lru_way_i(lru_way_i[0+:lg_acache_assoc_lp])
        ,.coh_state_i(coh_state_i)
        ,.addr_dst_gpr_i(addr_dst_gpr_i)
        ,.cmd_i(cmd_i)
        ,.r_v_i(acache_r_v)
        ,.r_lru_v_i(lce_is_acache)
        ,.w_v_i(acache_w_v)
        ,.busy_o(acache_busy)
        ,.sharers_v_o(acache_sharers_v)
        ,.sharers_hits_o(acache_sharers_hits)
        ,.sharers_ways_o(acache_sharers_ways)
        ,.sharers_coh_states_o(acache_sharers_coh_states)
        ,.lru_v_o(acache_lru_v)
        ,.lru_coh_state_o(acache_lru_coh_state_lo)
        ,.lru_addr_o(acache_lru_addr_lo)
        ,.addr_v_o(acache_addr_v)
        ,.addr_o(acache_addr_lo)
        ,.addr_dst_gpr_o(acache_addr_dst_gpr_lo)
        );

  end else begin
    // No accelerators in system, assign all outputs from acache segment to 0.
    // (and hope the tool optimizes them away)
    always_comb begin
      acache_busy = '0;
      acache_sharers_v = 1'b1;
      acache_sharers_hits = '0;
      acache_sharers_ways = '0;
      acache_sharers_coh_states = e_COH_I;
      acache_lru_v = '0;
      acache_lru_coh_state_lo = e_COH_I;
      acache_lru_addr_lo = '0;
      acache_addr_v = '0;
      acache_addr_lo = '0;
      acache_addr_dst_gpr_lo = e_opd_r0;
    end
  end

  // Output combination
  assign busy_o = icache_busy | dcache_busy | acache_busy;
  assign sharers_v_o = icache_sharers_v & dcache_sharers_v & acache_sharers_v;
  always_comb begin
    sharers_hits_o = '0;
    sharers_ways_o = '0;
    sharers_coh_states_o = {((2*num_core_p)+num_cacc_p){e_COH_I}};
    for (int i = 0; i < num_core_p; i++) begin
      sharers_hits_o[(2*i)]         = icache_sharers_hits[i];
      sharers_ways_o[(2*i)][0+:lg_icache_assoc_lp] = icache_sharers_ways[i];
      sharers_coh_states_o[(2*i)]   = icache_sharers_coh_states[i];
      sharers_hits_o[(2*i)+1]       = dcache_sharers_hits[i];
      sharers_ways_o[(2*i)+1][0+:lg_dcache_assoc_lp] = dcache_sharers_ways[i];
      sharers_coh_states_o[(2*i)+1] = dcache_sharers_coh_states[i];
    end
    for (int i = 0; i < num_cacc_p; i++) begin
      sharers_hits_o[i+(2*num_core_p)] = acache_sharers_hits[i];
      sharers_ways_o[i+(2*num_core_p)][0+:lg_acache_assoc_lp] = acache_sharers_ways[i];
      sharers_coh_states_o[i+(2*num_core_p)] = acache_sharers_coh_states[i];
    end
  end

  assign lru_v_o = icache_lru_v | dcache_lru_v | acache_lru_v;
  assign lru_addr_o = icache_lru_v
                      ? icache_lru_addr_lo
                      : dcache_lru_v
                        ? dcache_lru_addr_lo
                        : acache_lru_v
                          ? acache_lru_addr_lo
                          : '0;
  assign lru_coh_state_o = icache_lru_v
                      ? icache_lru_coh_state_lo
                      : dcache_lru_v
                        ? dcache_lru_coh_state_lo
                        : acache_lru_v
                          ? acache_lru_coh_state_lo
                          : e_COH_I;

  assign addr_v_o = icache_addr_v | dcache_addr_v | acache_addr_v;
  assign addr_o = icache_addr_v
                  ? icache_addr_lo
                  : dcache_addr_v
                    ? dcache_addr_lo
                    : acache_addr_v
                      ? acache_addr_lo
                      : '0;
  assign addr_dst_gpr_o = icache_addr_v
                          ? icache_addr_dst_gpr_lo
                          : dcache_addr_v
                            ? dcache_addr_dst_gpr_lo
                            : acache_addr_v
                              ? acache_addr_dst_gpr_lo
                              : e_opd_r0;

  // Nonsynth assertions
  //synopsys translate_off
  initial begin
    // Number of CCEs must be at least as large as the minimal number of sets in any of the
    // LCE types (dcache, icache, acache). This ensures that every tag set is wholly stored
    // in a *single* CCE (equivalently, tag sets are not split across LCEs).
    // LCEs and CCEs use the set index bits from the physical address to map address to CCE.
    assert(lce_min_sets_lp >= num_cce_p)
      else $error("Number of CCEs must be at least as large as the minimal number of LCE sets");
  end

  always_ff @(negedge clk_i) begin
    if (~reset_i) begin
      assert($countones({icache_lru_v, dcache_lru_v, acache_lru_v}) <= 1)
        else $error("Multiple directory segments attempting to output LRU information in same cycle");
      assert($countones({icache_addr_v, dcache_addr_v, acache_addr_v}) <= 1)
        else $error("Multiple directory segments attempting to output addr information in same cycle");
    end
  end
  //synopsys translate_on

endmodule

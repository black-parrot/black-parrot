/**
 *
 * Name:
 *   bp_cce_gad.v
 *
 * Description:
 *
 */

module bp_cce_gad
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_way_groups_p         = "inv"
    , parameter num_lce_p              = "inv"
    , parameter lce_assoc_p            = "inv"
    , parameter tag_width_p            = "inv"

    // Derived parameters
    , localparam lg_num_way_groups_lp  = `BSG_SAFE_CLOG2(num_way_groups_p)
    , localparam lg_num_lce_lp         = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp       = `BSG_SAFE_CLOG2(lce_assoc_p)
    , localparam entry_width_lp        = (tag_width_p+`bp_cce_coh_bits)
    , localparam tag_set_width_lp      = (entry_width_lp*lce_assoc_p)
    , localparam way_group_width_lp    = (tag_set_width_lp*num_lce_p)
  )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [way_group_width_lp-1:0]                        way_group_i
   , input [lg_num_lce_lp-1:0]                             req_lce_i
   , input [tag_width_p-1:0]                               req_tag_i
   , input [lg_lce_assoc_lp-1:0]                           lru_way_i
   , input                                                 req_type_flag_i
   , input                                                 lru_dirty_flag_i

   // high if the current op is a GAD op
   , input                                                 gad_v_i

   , output logic [lg_lce_assoc_lp-1:0]                    req_addr_way_o
   , output logic [`bp_cce_coh_bits-1:0]                   coh_state_o

   , output logic [tag_width_p-1:0]                        lru_tag_o

   , output logic                                          transfer_flag_o
   , output logic [lg_num_lce_lp-1:0]                      transfer_lce_o
   , output logic [lg_lce_assoc_lp-1:0]                    transfer_way_o
   , output logic                                          replacement_flag_o
   , output logic                                          upgrade_flag_o
   , output logic                                          invalidate_flag_o
   , output logic                                          exclusive_flag_o
   , output logic                                          cached_flag_o

   , output logic [num_lce_p-1:0]                          sharers_hits_o
   , output logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0]     sharers_ways_o
   , output logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0]    sharers_coh_states_o
  );

  // one hot decoding of request LCE ID
  logic [num_lce_p-1:0] lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p)
     )
     lce_id_to_one_hot
     (.i(req_lce_i)
      ,.o(lce_id_one_hot)
     );

  // vector of tag sets, Assoc*(Tag + Coh State) per LCE
  logic [num_lce_p-1:0][lce_assoc_p-1:0][entry_width_lp-1:0] tag_sets;
  assign tag_sets = way_group_i;

  // Tag from LRU way in requesting LCE's tag set
  assign lru_tag_o = tag_sets[req_lce_i][lru_way_i][`bp_cce_coh_bits +: tag_width_p];

  // Coherence State of LRU way in target set of LCE
  logic [`bp_cce_coh_bits-1:0] lru_coh_state;
  assign lru_coh_state = tag_sets[req_lce_i][lru_way_i][0 +: `bp_cce_coh_bits];
  logic lru_cached_excl;
  assign lru_cached_excl = ((lru_coh_state == e_MESI_E) || (lru_coh_state == e_MESI_M));

  // Information for determining if the target cache block is cached, where it is cached, and
  // in what state it is cached in each LCE

  // Cache hit per way per LCE
  logic [num_lce_p-1:0][lce_assoc_p-1:0] lce_way_hits;
  genvar x, y;
  for (x = 0; x < num_lce_p; x=x+1) begin : lce_way_hits_gen_lce
    for (y = 0; y < lce_assoc_p; y=y+1) begin : lce_way_hits_gen
      // hit= req_tag_i == way_tag && way_coh_state != Invalid
      // Invalid state == '0, so any bit being set in the coherence state means block is valid
      assign lce_way_hits[x][y] = (tag_sets[x][y][`bp_cce_coh_bits +: tag_width_p] == req_tag_i)
        & |(tag_sets[x][y][0 +: `bp_cce_coh_bits]);
    end
  end

  // Cache hit per LCE
  logic [num_lce_p-1:0] lce_cached;
  assign sharers_hits_o = lce_cached;

  // Way per LCE that target block is found in
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] lce_cached_way;
  assign sharers_ways_o = lce_cached_way;

  // Coherence state of block per LCE, if cached
  logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0] lce_cached_states;
  assign sharers_coh_states_o = lce_cached_states;

  // Cache hit in E or M per LCE
  logic [num_lce_p-1:0] lce_cached_excl;

  logic [num_lce_p-1:0][lce_assoc_p-1:0] lce_way_hits_li;
  assign lce_way_hits_li = (gad_v_i) ? lce_way_hits : '0;
  genvar i;
  for (i = 0; i < num_lce_p; i=i+1) begin : lce_cached_way_gen
    bsg_encode_one_hot
      #(.width_p(lce_assoc_p)
        )
      lce_way_hits_to_way_ids_and_v
       (.i(lce_way_hits_li[i])
        ,.addr_o(lce_cached_way[i])
        ,.v_o(lce_cached[i])
        );
  end

  for (i = 0; i < num_lce_p; i=i+1) begin : lce_cached_states_gen
    assign lce_cached_states[i] = (lce_cached[i])
                                  ? tag_sets[i][lce_cached_way[i]][0 +: `bp_cce_coh_bits]
                                  : '0;
  end

  for (i = 0; i < num_lce_p; i=i+1) begin : lce_cached_excl_gen
    assign lce_cached_excl[i] = lce_cached[i] & ((lce_cached_states[i] == e_MESI_E)
                                                 || (lce_cached_states[i] == e_MESI_M));
  end

  // hit in requesting LCE
  // compute hit - OR reduction of hit bits for the requesting LCE
  logic req_lce_cached;
  assign req_lce_cached = lce_cached[req_lce_i];
  logic req_lce_cached_excl;
  assign req_lce_cached_excl = lce_cached_excl[req_lce_i];

  logic other_lce_cached;
  assign other_lce_cached = |(lce_cached & ~lce_id_one_hot);
  logic other_lce_cached_excl;
  assign other_lce_cached_excl = |(lce_cached_excl & ~lce_id_one_hot);

  assign req_addr_way_o = req_lce_cached
    ? lce_cached_way[req_lce_i]
    : '0;
  assign coh_state_o = req_lce_cached
    ? tag_sets[req_lce_i][req_addr_way_o][0 +: `bp_cce_coh_bits]
    : '0;

  // request type
  logic req_wr, req_rd;
  assign req_wr = (req_type_flag_i == e_lce_req_type_wr);
  assign req_rd = ~req_wr;

  // Flag outputs
  /*
   * Excusive Flag: cached in other LCE in E or M
   * Upgrade Flag: cached in reqLce in S and write request
   * Transfer Flag: cached in other LCE in E or M (same as transfer at the moment)
   * Invalidate Flag: cached exclusively in other LCEs if read request else
                      cached in any valid state in other LCEs if write request
   * Replacement Flag: reqLce's lru way is valid and dirty, and not an upgrade
   * Cached Flag: cached in any valid state in any LCE other than requesting LCE
   */

  assign cached_flag_o = other_lce_cached;
  assign exclusive_flag_o = other_lce_cached_excl;
  assign transfer_flag_o = exclusive_flag_o;
  assign upgrade_flag_o = (req_wr) ? (req_lce_cached & ~req_lce_cached_excl) : 1'b0;
  assign replacement_flag_o = (~upgrade_flag_o & lru_cached_excl & lru_dirty_flag_i);

  // TODO: future version of CCE will not necessarily invalidate the transfer LCE, but
  // for now, if the request results in a transfer, we invalidate the other LCE
  assign invalidate_flag_o = (req_rd) ? other_lce_cached_excl : other_lce_cached;
  
  // Transfer stuff
  // transfer LCE
  logic [num_lce_p-1:0] transfer_lce_one_hot;
  logic [lg_num_lce_lp-1:0] transfer_lce_lo;
  logic transfer_lce_v;

  //assign transfer_lce_one_hot = ~lce_id_one_hot & lce_cached;
  assign transfer_lce_one_hot = (gad_v_i & transfer_flag_o) ? lce_cached : '0;
  bsg_encode_one_hot
    #(.width_p(num_lce_p)
      )
    lce_cached_to_lce_id
     (.i(transfer_lce_one_hot)
      ,.addr_o(transfer_lce_lo)
      ,.v_o(transfer_lce_v)
      );

  assign transfer_lce_o = (gad_v_i & transfer_flag_o & transfer_lce_v)
                          ? transfer_lce_lo : '0;
  assign transfer_way_o = (gad_v_i & transfer_flag_o & transfer_lce_v)
                          ? lce_cached_way[transfer_lce_lo] : '0;


  // Debugging
  always @(negedge clk_i) begin
    if (~reset_i & gad_v_i) begin
    /*
$info("@%0T LCE[%0d] addr[%H] req[%b] lruWay[%3H] lruDirty[%b]\n\
\thit[%b] way[%0d] coh_st[%0H]\n\
\ttf[%b] ef[%b] rf[%b] uf[%b] if[%b]\n\
\ttr_lce[%0d] tr_way[%0d]\n\
\tlce_id_oh[%b]"
            , $time
            , req_lce_i
            , req_tag_i
            , req_type_flag_i
            , lru_way_i
            , lru_dirty_flag_i
            , req_lce_cached
            , req_addr_way_o
            , coh_state_o
            , transfer_flag_o
            , exclusive_flag_o
            , replacement_flag_o
            , upgrade_flag_o
            , invalidate_flag_o
            , transfer_lce_o
            , transfer_way_o
            , lce_id_one_hot
            );
      */
      if (transfer_flag_o) begin
        assert(transfer_lce_v) else $error("Transfer LCE not valid, but hit detected");
      end
      if (replacement_flag_o) begin
        assert(!upgrade_flag_o) else $error("upgrade flag set on replacement");
      end
      if (transfer_flag_o) begin
        assert(!req_lce_cached) else $error("hit detected on transfer");
        if (req_lce_cached) begin
          $info("lce_way_htis: %b\nlce_cached: %b\nlce_cached_excl: %b\nlce_cached_way: %b", lce_way_hits, lce_cached, lce_cached_excl, lce_cached_way);
        end
        assert(!upgrade_flag_o) else $error("upgrade flag set on transfer");
      end
      if (exclusive_flag_o) begin
        assert(!req_lce_cached) else $error("hit detected with exclusive flag set");
      end
      if (upgrade_flag_o) begin
        assert(!exclusive_flag_o) else $error("exclusive flag set on upgrade");
      end
      for (integer i = 0; i < num_lce_p; i=i+1) begin
        if (lce_cached_excl[i]) begin
          assert(lce_cached[i]) else $error("lce[%0d] cached_excl but not cached", i);
          if (!lce_cached[i]) begin
            $info("lce_way_htis: %b\nlce_cached: %b\nlce_cached_excl: %b\nlce_cached_way: %b", lce_way_hits, lce_cached, lce_cached_excl, lce_cached_way);
          end
        end
      end
    end
  end

endmodule

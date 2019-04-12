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
  (input                                                  clk_i
   , input                                                reset_i
   , input                                                freeze_i

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

   , output logic [num_lce_p-1:0]                          sharers_hits_o
   , output logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0]     sharers_ways_o
   , output logic [num_lce_p-1:0][`bp_cce_coh_bits-1:0]    sharers_coh_states_o
  );

  logic hit;
  logic [`bp_cce_coh_bits-1:0] lru_coh_state;

  logic [num_lce_p-1:0] sharers_cached, inv_hits, excl_bits;

  // vector of tag sets, Assoc*(Tag + Coh State) per LCE
  logic [num_lce_p-1:0][lce_assoc_p-1:0][entry_width_lp-1:0] tag_sets;

  // vector of hit bits, Assoc*(1 bit) per LCE
  logic [num_lce_p-1:0][lce_assoc_p-1:0] tag_set_hits;
  // vector of way IDs recording which way per tag set the req_addr was found in
  logic [num_lce_p-1:0][lg_lce_assoc_lp-1:0] tag_set_hit_ways;
  // valid bit per tag set indicating req_addr was found in that LCE's tag set
  logic [num_lce_p-1:0] tag_set_hit_v;

  logic [num_lce_p-1:0] transfer_lce_one_hot;
  logic [lg_num_lce_lp-1:0] transfer_lce_n;
  logic transfer_lce_v;

  // one hot decoding of request LCE ID
  logic [num_lce_p-1:0] lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p)
     )
     lce_id_to_one_hot
     (.i(req_lce_i)
      ,.o(lce_id_one_hot)
     );

  assign tag_sets = way_group_i;

  int x, y;
  always_comb
  begin
    // determine if there is a hit in each way per tag set
    // hit occurs if req_addr == way_addr && way_coh_state != Invalid
    for (x = 0; x < num_lce_p; x=x+1) begin
      for (y = 0; y < lce_assoc_p; y=y+1) begin
        tag_set_hits[x][y] = (tag_sets[x][y][`bp_cce_coh_bits +: tag_width_p] == req_tag_i)
          & |(tag_sets[x][y][0 +: `bp_cce_coh_bits]);
      end
    end
  end

  // combinational logic to encode one-hot hit vector per LCE tag set into a valid bit and way ID
  genvar i;
  generate
    for (i = 0; i < num_lce_p; i=i+1) begin : hit_vec_to_way_id_gen
      bsg_encode_one_hot
        #(.width_p(lce_assoc_p)
          )
        tag_set_hits_to_way_id
         (.i(tag_set_hits[i])
          ,.addr_o(tag_set_hit_ways[i])
          ,.v_o(tag_set_hit_v[i])
          );
    end
  endgenerate

  int z;
  always_comb begin
    sharers_hits_o = tag_set_hit_v;
    sharers_ways_o = tag_set_hit_ways;

    for (z = 0; z < num_lce_p; z=z+1) begin
      sharers_coh_states_o[z] = tag_sets[z][tag_set_hit_ways[z]][0 +: `bp_cce_coh_bits];
    end

    // compute hit - OR reduction of hit bits for the requesting LCE
    hit = |tag_set_hits[req_lce_i];

    if (hit) begin

      req_addr_way_o = tag_set_hit_ways[req_lce_i];
      coh_state_o = tag_sets[req_lce_i][req_addr_way_o][0 +: `bp_cce_coh_bits];

    end else begin

      req_addr_way_o = '0;
      coh_state_o = '0;

    end

    // Regardless of a hit occuring, the lru_tag and lru_coh_state are gathered
    lru_tag_o = tag_sets[req_lce_i][lru_way_i][`bp_cce_coh_bits +: tag_width_p];
    lru_coh_state = tag_sets[req_lce_i][lru_way_i][0 +: `bp_cce_coh_bits];

  end

  // Flag outputs
  int n;
  always_comb
  begin
    // exclusive_flag - cached exclusively in a LCE other than requesting LCE
    for (n = 0; n < num_lce_p; n=n+1) begin
      excl_bits[n] = sharers_coh_states_o[n][1] & sharers_hits_o[n];
    end
    exclusive_flag_o = |(excl_bits & ~lce_id_one_hot);

    // upgrade flag - hit in reqLce, request is a write, and coh state is Shared
    upgrade_flag_o = hit & (req_type_flag_i == e_lce_req_type_wr) & (coh_state_o == e_MESI_S);

    // transfer flag
    // transfer does not occur on upgrade
    // transfer happens if an LCE other than requestor has block in an Exclusive state
    transfer_flag_o = exclusive_flag_o; // & ~hit & ~upgrade_flag_o

    // invalidate_flag
    for (n = 0; n < num_lce_p; n=n+1) begin
      sharers_cached[n] = |sharers_coh_states_o[n];
    end
    inv_hits = sharers_hits_o & ~lce_id_one_hot;
    // TODO: future version of CCE will not necessarily invalidate the transfer LCE, but
    // for now, if the request results in a transfer, we invalidate the other LCE
    invalidate_flag_o = (req_type_flag_i & |(inv_hits & sharers_cached)) | transfer_flag_o;

    // replacement flag
    // replacement does not occur on upgrade
    // replacement occurs when the LRU way is in E or M and dirty, but is not needed
    // if the LRU way is in S (and therefore, lruDirty should also be false)
    // NOTE: it is possible that prior to the current request, the LRU block was invalidated, and
    // thus, we only do replacement if the block is still in E or M state
    replacement_flag_o = ((lru_coh_state == e_MESI_E) || (lru_coh_state == e_MESI_M))
                         & lru_dirty_flag_i;
  end

  assign transfer_lce_one_hot = ~lce_id_one_hot & sharers_hits_o;
  bsg_encode_one_hot
    #(.width_p(num_lce_p)
      )
    tag_set_hits_to_way_id
     (.i(transfer_lce_one_hot)
      ,.addr_o(transfer_lce_n)
      ,.v_o(transfer_lce_v)
      );

  always_comb
  begin
    if (gad_v_i & transfer_flag_o) begin
      // transfer lce
      transfer_lce_o = transfer_lce_n;
      transfer_way_o = sharers_ways_o[transfer_lce_o];
    end else begin
      transfer_lce_o = '0;
      transfer_way_o = '0;
    end
  end

  always @(negedge clk_i) begin
    if (~reset_i) begin
      if (gad_v_i & transfer_flag_o) begin
        assert(transfer_lce_v) else $error("Transfer LCE not valid, but hit detected");
      end
      if (gad_v_i & replacement_flag_o) begin
        assert(!upgrade_flag_o) else $error("upgrade flag set on replacement");
      end
      if (gad_v_i & transfer_flag_o) begin
        assert(!hit) else $error("hit detected on transfer");
        assert(!upgrade_flag_o) else $error("upgrade flag set on transfer");
      end
      if (gad_v_i & exclusive_flag_o) begin
        assert(!hit) else $error("hit detected with exclusive flag set");
      end
    end
  end

endmodule

/**
 *
 * Name:
 *   bp_cce_gad.v
 *
 * Description:
 *   The GAD (Generate Auxiliary Directory Information) module computes the values of a number of
 *   control flags used by the CCE, based on the information stored in a way-group in the
 *   coherence directory. The directory information is consolidated as it is read out of the
 *   directory RAM into a few vectors that indicate for each LCE if there is a hit for the target
 *   address, which way in the LCE the hit occurred in, and the coherence state of that entry.
 *
 */

module bp_cce_gad
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_lce_p              = "inv"
    , parameter lce_assoc_p            = "inv"

    // Derived parameters
    , localparam lg_num_lce_lp         = `BSG_SAFE_CLOG2(num_lce_p)
    , localparam lg_lce_assoc_lp       = `BSG_SAFE_CLOG2(lce_assoc_p)
  )
  (input                                                   clk_i
   , input                                                 reset_i

   // high if the current op is a GAD op
   , input                                                 gad_v_i

   , input                                                 sharers_v_i
   , input [num_lce_p-1:0]                                 sharers_hits_i
   , input [num_lce_p-1:0][lg_lce_assoc_lp-1:0]            sharers_ways_i
   , input [num_lce_p-1:0][`bp_coh_bits-1:0]               sharers_coh_states_i

   , input [lg_num_lce_lp-1:0]                             req_lce_i
   , input                                                 req_type_flag_i
   , input                                                 lru_dirty_flag_i
   , input                                                 lru_cached_excl_flag_i

   , output logic [lg_lce_assoc_lp-1:0]                    req_addr_way_o

   , output logic                                          transfer_flag_o
   , output logic [lg_num_lce_lp-1:0]                      transfer_lce_o
   , output logic [lg_lce_assoc_lp-1:0]                    transfer_way_o
   , output logic                                          replacement_flag_o
   , output logic                                          upgrade_flag_o
   , output logic                                          invalidate_flag_o
   , output logic                                          cached_flag_o
   , output logic                                          cached_exclusive_flag_o
   , output logic                                          cached_owned_flag_o
   , output logic                                          cached_dirty_flag_o
  );

  // Suppress unused signal warnings
  wire unused = &{clk_i, reset_i};

  // one hot decoding of request LCE ID
  logic [num_lce_p-1:0] lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p)
     )
     lce_id_to_one_hot
     (.i(req_lce_i)
      ,.o(lce_id_one_hot)
     );

  // Cache hit per LCE
  logic [num_lce_p-1:0] lce_cached;
  assign lce_cached = sharers_hits_i;

  // Cache hit in E or M per LCE
  logic [num_lce_p-1:0] lce_cached_excl;
  logic [num_lce_p-1:0] lce_cached_owned;
  logic [num_lce_p-1:0] lce_cached_dirty;
  for (genvar i = 0; i < num_lce_p; i=i+1) begin : lce_cached_excl_gen
    assign lce_cached_excl[i] = lce_cached[i] & ~sharers_coh_states_i[i][`bp_coh_shared_bit];
    assign lce_cached_owned[i] = lce_cached[i] & sharers_coh_states_i[i][`bp_coh_owned_bit];
    assign lce_cached_dirty[i] = lce_cached[i] & sharers_coh_states_i[i][`bp_coh_dirty_bit];
  end

  // hit in requesting LCE
  logic req_lce_cached;
  assign req_lce_cached = lce_cached[req_lce_i];
  // read-only permissions in requesting LCE
  logic req_lce_ro;
  assign req_lce_ro = req_lce_cached & sharers_coh_states_i[req_lce_i][`bp_coh_shared_bit];

  assign req_addr_way_o = req_lce_cached
    ? sharers_ways_i[req_lce_i]
    : '0;

  // request type
  logic req_wr, req_rd;
  assign req_wr = (req_type_flag_i == e_lce_req_type_wr);
  assign req_rd = ~req_wr;

  // Flag outputs
  assign cached_flag_o = |(lce_cached & ~lce_id_one_hot);
  assign cached_exclusive_flag_o = |(lce_cached_excl & ~lce_id_one_hot);
  assign cached_owned_flag_o = |(lce_cached_owned & ~lce_id_one_hot);
  assign cached_dirty_flag_o = |(lce_cached_dirty & ~lce_id_one_hot);

  // If the block has an owner, we can do an LCE to LCE transfer
  assign transfer_flag_o = cached_owned_flag_o;
  // Upgrade from read-only to read-write
  assign upgrade_flag_o = (req_wr & req_lce_cached & req_lce_ro);
  // Replace the LRU block if not doing an upgrade and the lru block is actually dirty
  assign replacement_flag_o = (~upgrade_flag_o & lru_cached_excl_flag_i & lru_dirty_flag_i);

  // for now, if the request results in a transfer, we invalidate the other LCEA
  // this works for MESI, MSI, MI/EI, but needs adjustment if adding O or F states in MOESIF
  assign invalidate_flag_o = (req_rd) ? cached_exclusive_flag_o : cached_flag_o;
  
  // Transfer stuff
  // transfer LCE
  logic [num_lce_p-1:0] transfer_lce_one_hot;
  logic [lg_num_lce_lp-1:0] transfer_lce_lo;
  logic transfer_lce_v;

  assign transfer_lce_one_hot = (gad_v_i & transfer_flag_o) ? (lce_cached & ~lce_id_one_hot) : '0;
  bsg_encode_one_hot
    #(.width_p(num_lce_p)
      ,.lo_to_hi_p(1)
      )
    lce_cached_to_lce_id
     (.i(transfer_lce_one_hot)
      ,.addr_o(transfer_lce_lo)
      ,.v_o(transfer_lce_v)
      );

  assign transfer_lce_o = (gad_v_i & transfer_flag_o & transfer_lce_v)
                          ? transfer_lce_lo : '0;
  assign transfer_way_o = (gad_v_i & transfer_flag_o & transfer_lce_v)
                          ? sharers_ways_i[transfer_lce_lo] : '0;

endmodule

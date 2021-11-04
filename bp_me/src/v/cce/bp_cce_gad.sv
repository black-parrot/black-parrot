/**
 *
 * Name:
 *   bp_cce_gad.sv
 *
 * Description:
 *   The GAD (Generate Auxiliary Directory Information) module computes the values of a number of
 *   control flags used by the CCE, based on the information stored in a way-group in the
 *   coherence directory. The directory information is consolidated as it is read out of the
 *   directory RAM into a few vectors that indicate for each LCE if there is a hit for the target
 *   address, which way in the LCE the hit occurred in, and the coherence state of that entry.
 *
 *
 *   This block supports any valid subset of MOESIF.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_gad
  import bp_common_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    // Derived parameters
    , localparam lg_num_lce_lp         = `BSG_SAFE_CLOG2(num_lce_p)
  )
  (input                                                   clk_i
   , input                                                 reset_i

   // high if the current op is a GAD op
   , input                                                 gad_v_i

   // from Directory
   , input                                                 sharers_v_i
   , input [num_lce_p-1:0]                                 sharers_hits_i
   , input [num_lce_p-1:0][lce_assoc_width_p-1:0]          sharers_ways_i
   , input bp_coh_states_e [num_lce_p-1:0]                 sharers_coh_states_i

   // from MSHR - request details
   , input [lce_id_width_p-1:0]                            req_lce_i
   , input                                                 req_type_flag_i
   , input bp_coh_states_e                                 lru_coh_state_i
   , input                                                 atomic_req_flag_i
   , input                                                 uncached_req_flag_i

   // Outputs
   , output logic [lce_assoc_width_p-1:0]                  req_addr_way_o

   , output logic [lce_id_width_p-1:0]                     owner_lce_o
   , output logic [lce_assoc_width_p-1:0]                  owner_way_o
   , output bp_coh_states_e                                owner_coh_state_o

   , output logic                                          replacement_flag_o
   , output logic                                          upgrade_flag_o
   , output logic                                          cached_shared_flag_o
   , output logic                                          cached_exclusive_flag_o
   , output logic                                          cached_modified_flag_o
   , output logic                                          cached_owned_flag_o
   , output logic                                          cached_forward_flag_o
  );

  // Suppress unused signal warnings
  wire unused = &{clk_i, reset_i, sharers_v_i};

  wire [lg_num_lce_lp-1:0] req_lce_id = req_lce_i[0+:lg_num_lce_lp];

  // one hot decoding of request LCE ID
  logic [num_lce_p-1:0] lce_id_one_hot;
  bsg_decode
    #(.num_out_p(num_lce_p)
     )
     lce_id_to_one_hot
     (.i(req_lce_id)
      ,.o(lce_id_one_hot)
     );

  // Cache hit per LCE
  logic [num_lce_p-1:0] lce_cached;
  assign lce_cached = sharers_hits_i;

  logic [num_lce_p-1:0] lce_cached_S;
  logic [num_lce_p-1:0] lce_cached_E;
  logic [num_lce_p-1:0] lce_cached_M;
  logic [num_lce_p-1:0] lce_cached_O;
  logic [num_lce_p-1:0] lce_cached_F;
  for (genvar i = 0; i < num_lce_p; i=i+1) begin : lce_cached_flags
    assign lce_cached_S[i] = lce_cached[i] & (sharers_coh_states_i[i] == e_COH_S);
    assign lce_cached_E[i] = lce_cached[i] & (sharers_coh_states_i[i] == e_COH_E);
    assign lce_cached_M[i] = lce_cached[i] & (sharers_coh_states_i[i] == e_COH_M);
    assign lce_cached_O[i] = lce_cached[i] & (sharers_coh_states_i[i] == e_COH_O);
    assign lce_cached_F[i] = lce_cached[i] & (sharers_coh_states_i[i] == e_COH_F);
  end

  // Block cached in some state in LCE other than requestor
  assign cached_shared_flag_o = |(lce_cached_S & ~lce_id_one_hot);
  assign cached_exclusive_flag_o = |(lce_cached_E & ~lce_id_one_hot);
  assign cached_modified_flag_o = |(lce_cached_M & ~lce_id_one_hot);
  assign cached_owned_flag_o = |(lce_cached_O & ~lce_id_one_hot);
  assign cached_forward_flag_o = |(lce_cached_F & ~lce_id_one_hot);

  // hit in requesting LCE
  logic req_lce_cached;
  assign req_lce_cached = lce_cached[req_lce_id] & (req_lce_id < num_lce_p);
  // read-only permissions in requesting LCE (block in S, F, or O)
  logic req_lce_ro;
  assign req_lce_ro = req_lce_cached & ((sharers_coh_states_i[req_lce_id] == e_COH_S)
                                        | (sharers_coh_states_i[req_lce_id] == e_COH_F)
                                        | (sharers_coh_states_i[req_lce_id] == e_COH_O));

  assign req_addr_way_o = req_lce_cached
    ? sharers_ways_i[req_lce_id]
    : '0;

  // Flag outputs

  // Upgrade from read-only to read-write
  // Requesting LCE has block cached in read-only state and request is a store-miss
  // Only for cached access
  assign upgrade_flag_o = req_type_flag_i & req_lce_ro & ~uncached_req_flag_i;

  // Replace the LRU block if not doing an upgrade and the lru block might be dirty
  // also set replacement flag when the block is cached (in any state) by the requesting
  // LCE and the request is an atomic operation or an uncached operation.
  assign replacement_flag_o = (uncached_req_flag_i | atomic_req_flag_i)
                              ? req_lce_cached
                              : (~upgrade_flag_o & ((lru_coh_state_i == e_COH_E)
                                                    | (lru_coh_state_i == e_COH_M)
                                                    | (lru_coh_state_i == e_COH_O))
                                );

  // Owner LCE
  logic [num_lce_p-1:0] owner_lce_one_hot;
  // output owner even if it is same as requestor
  // Owner will be in one of states: E, M, O, or F; and only one LCE may be in those states
  // It is an error if more than one LCE is in one of these states (or the two LCE's are in some
  // pair of these states) for a given cache block.
  assign owner_lce_one_hot = (gad_v_i)
                             ? (lce_cached_E | lce_cached_M | lce_cached_O | lce_cached_F)
                             : '0;

  logic [lg_num_lce_lp-1:0] owner_lce_lo;
  logic owner_lce_v;
  bsg_encode_one_hot
    #(.width_p(num_lce_p)
      ,.lo_to_hi_p(1)
      )
    lce_cached_to_lce_id
     (.i(owner_lce_one_hot)
      ,.addr_o(owner_lce_lo)
      ,.v_o(owner_lce_v)
      );

  assign owner_lce_o = (gad_v_i & owner_lce_v)
                       ? {'0, owner_lce_lo} : '0;
  assign owner_way_o = (gad_v_i & owner_lce_v)
                       ? sharers_ways_i[owner_lce_lo] : '0;
  assign owner_coh_state_o = (gad_v_i & owner_lce_v)
                             ? sharers_coh_states_i[owner_lce_lo] : e_COH_I;

endmodule

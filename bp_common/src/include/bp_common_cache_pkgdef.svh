
`ifndef BP_COMMON_CACHE_PKGDEF_SVH
`define BP_COMMON_CACHE_PKGDEF_SVH

  /////////////////////////////////////////////////////
  // bsg_cache operations                            //
  /////////////////////////////////////////////////////
  // TAGST   // st; address = way, index; data = tag //
  // TAGFL   // st; address = way, index; data = X   //
  // TAGLV   // ld; address = way, index; data = X   //
  // TAGLA   // ld; address = way, index; data = X   //
  /////////////////////////////////////////////////////
  // AFL     // st; address = address   ; data = X   //
  // AFLINV  // st; address = address   ; data = X   //
  // AINV    // st; address = address   ; data = X   //
  // ALOCK   // st; address = address   ; data = X   //
  // AUNLOCK // st; address = address   ; data = X   //

  localparam cache_base_addr_gp    = (dev_id_width_gp+dev_addr_width_gp)'('h0400_0000);

  // This could be more efficiently matched to actual L2 architecture
  typedef struct packed
  {
    logic [2:0] bank;
    logic [2:0] way;
    logic [7:0] index;
    logic [5:0] addr;
  }  bp_me_l2_csr_addr_s;

  // bedrock addr[15:12]                 -> cache bank
  // bedrock data[X : 3]                 -> cache addr[X : 3]
  // bedrock data[3 : 0]                 -> cache data (used for lock op)
  //                                                              0000_0000_0000_00aa_a000
  localparam cache_afl_match_addr_gp     = (dev_addr_width_gp)'('b0000_0000_0000_0000_0000);
  localparam cache_aflinv_match_addr_gp  = (dev_addr_width_gp)'('b0000_0000_0000_0000_1000);
  localparam cache_ainv_match_addr_gp    = (dev_addr_width_gp)'('b0000_0000_0000_0001_0000);
  localparam cache_alock_match_addr_gp   = (dev_addr_width_gp)'('b0000_0000_0000_0001_1000);

  // bedrock addr[15:12]                 -> cache bank
  // bedrock addr[11: 6] -> way, index   -> cache addr[addr:block_offset]
  // bedrock data        -> tag          -> cache data
  //                                                              bbbw_wwii_iiii_iioa_a000
  localparam cache_tagfl_match_addr_gp   = (dev_addr_width_gp)'('b????_????_????_??10_0000);
  localparam cache_taglv_match_addr_gp   = (dev_addr_width_gp)'('b????_????_????_??10_1000);
  localparam cache_tagla_match_addr_gp   = (dev_addr_width_gp)'('b????_????_????_??11_0000);
  localparam cache_tagst_match_addr_gp   = (dev_addr_width_gp)'('b????_????_????_??11_1000);

  localparam cache_tagop_match_addr_gp   = (dev_addr_width_gp)'('b????_????_????_??1?_????);
  localparam cache_addrop_match_addr_gp  = (dev_addr_width_gp)'('b????_????_????_??0?_????);

`endif


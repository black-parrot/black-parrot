
`ifndef BP_COMMON_AVIARY_CFG_PKGDEF_SVH
`define BP_COMMON_AVIARY_CFG_PKGDEF_SVH

  // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = $clog2(max_cfgs);

  // Configuration enums
  typedef enum logic [3:0]
  {
    e_cfg_enabled               = 4'b0000
    ,e_cfg_coherent             = 4'b0001
    ,e_cfg_writeback            = 4'b0010
    ,e_cfg_word_tracking        = 4'b0011
    ,e_cfg_lr_sc                = 4'b0100
    ,e_cfg_amo_swap             = 4'b0101
    ,e_cfg_amo_fetch_logic      = 4'b0110
    ,e_cfg_amo_fetch_arithmetic = 4'b0111
    ,e_cfg_hit_under_miss       = 4'b1000
  } bp_cache_features_e;

  typedef enum logic
  {
    e_basic = 1'b0
    ,e_catchup = 1'b1
  } bp_integer_support_e;

  typedef enum logic [1:0]
  {
    e_idiv    = 2'b00
    ,e_imul   = 2'b01
    ,e_imulh  = 2'b10
    ,e_idiv2b = 2'b11
  } bp_muldiv_support_e;

  typedef enum logic [1:0]
  {
    e_fma         = 2'b00
    ,e_fdivsqrt   = 2'b01
    ,e_fdivsqrt2b = 2'b10
  } bp_fpu_support_e;

  typedef enum logic [15:0]
  {
    e_sacc_none = 0
    ,e_sacc_vdp = 1
    ,e_sacc_scratchpad = 2
  } bp_sacc_type_e;

  typedef enum logic [15:0]
  {
    e_cacc_none = 0
    ,e_cacc_vdp = 1
  } bp_cacc_type_e;

  typedef enum logic [1:0]
  {
    e_cce_uce = 0
    ,e_cce_fsm = 1
    ,e_cce_ucode = 2
    ,e_cce_hybrid = 3
  } bp_cce_type_e;

  typedef struct packed
  {
    // Dimensions of the different complexes
    // Core Complex may be any integer unsigned (though has only been validated up to 4x4)
    // All other Complexes are 1-dimensional
    //                                    [                           ]
    //                                    [        I/O Complex        ]
    //                                    [                           ]
    //
    //  [                               ] [                           ] [                               ]
    //  [ Streaming Accelerator Complex ] [        Core Complex       ] [ Coherent Accelerator Complex  ]
    //  [                               ] [                           ] [                               ]
    //
    //                                    [                           ]
    //                                    [       Memory Complex      ]
    //                                    [                           ]
    //
    integer unsigned cc_x_dim;
    integer unsigned cc_y_dim;
    integer unsigned ic_y_dim;
    integer unsigned mc_y_dim;
    integer unsigned cac_x_dim;
    integer unsigned sac_x_dim;

    // The type of accelerator in the accelerator complexes, selected out of bp_cacc_type_e/bp_sacc_type_e
    // Only supports homogeneous configurations
    integer unsigned cacc_type;
    integer unsigned sacc_type;

    // Number of CCEs/LCEs in the system. Must be consistent within complex dimensions
    integer unsigned num_cce;
    integer unsigned num_lce;

    // Virtual address width
    //   Only tested for SV39 (39-bit virtual address)
    integer unsigned vaddr_width;
    // Physical address width
    //   Only tested for 40-bit physical address
    integer unsigned paddr_width;
    // DRAM address width
    // The max size of the connected DRAM i.e. cached address space
    //   Only tested for 32-bit cacheable address (4 GB space, with 2 GB local I/O)
    integer unsigned daddr_width;
    // Cacheable address width
    // The max size cached by the L1 caches of the system
    integer unsigned caddr_width;
    // Address space ID width
    //   Currently unused, so set to 1 bit
    integer unsigned asid_width;

    // Branch metadata information for the Front End
    // Must be kept consistent with FE
    integer unsigned branch_metadata_fwd_width;
    integer unsigned ras_idx_width;
    integer unsigned btb_tag_width;
    integer unsigned btb_idx_width;
    // bht_row_els is a physically-derived parameter. It describes the number
    //   of entries in a single row of the BHT RAM.  There are 2 bits per entry.
    //   The tradeoff here is a wider RAM is most likely higher performance,
    //   but we need to carry that extra metadata throughout the pipeline to
    //   maintain 1r1w throughput without a RMW.
    // Ghist is the global history width, which in our gselect
    // Thus, the true BHT dimensions are (bht_idx_width+ghist_width)x(2*bht_row_els)
    integer unsigned bht_idx_width;
    integer unsigned bht_row_els;
    integer unsigned ghist_width;

    // Capacity of the Instruction/Data TLBs
    integer unsigned itlb_els_4k;
    integer unsigned itlb_els_1g;
    integer unsigned dtlb_els_4k;
    integer unsigned dtlb_els_1g;

    // I$ cache features
    integer unsigned icache_features;
    // I$ parameterizations
    integer unsigned icache_sets;
    integer unsigned icache_assoc;
    integer unsigned icache_block_width;
    integer unsigned icache_fill_width;

    // D$ cache features
    integer unsigned dcache_features;
    // D$ parameterizations
    integer unsigned dcache_sets;
    integer unsigned dcache_assoc;
    integer unsigned dcache_block_width;
    integer unsigned dcache_fill_width;

    // A$ cache features
    integer unsigned acache_features;
    // A$ parameterizations
    integer unsigned acache_sets;
    integer unsigned acache_assoc;
    integer unsigned acache_block_width;
    integer unsigned acache_fill_width;

    // CCE selection and parameters
    // cce_type defined by bp_cce_type_e
    integer unsigned cce_type;
    // Determines the size of the CCE instruction RAM
    integer unsigned cce_pc_width;
    // The width of the coherence protocol block
    integer unsigned bedrock_block_width;
    // The width of the coherence protocol beats
    integer unsigned bedrock_fill_width;

    // L2 slice parameters (per core)
    // L2 cache features
    integer unsigned l2_features;
    // Number of L2 banks present in the slice
    integer unsigned l2_banks;
    integer unsigned l2_data_width;
    integer unsigned l2_sets;
    integer unsigned l2_assoc;
    integer unsigned l2_block_width;
    integer unsigned l2_fill_width;
    // Number of requests which can be pending in a cache slice
    // Should be 4 < N < 4*l2_banks_p to prevent stalling
    integer unsigned l2_outstanding_reqs;

    // Size of the issue queue
    integer unsigned fe_queue_fifo_els;
    // Size of the cmd queue
    integer unsigned fe_cmd_fifo_els;
    // Integer support in the system. It is a bitmask with:
    //   bit 0: basic alu
    //   bit 1: catchup alu
    integer unsigned integer_support;
    // MULDIV support in the system. It is a bitmask with:
    //   bit 0: div
    //   bit 1: mul
    //   bit 2: iterative mulh
    //   bit 3: 2b iterative div
    integer unsigned muldiv_support;
    // Whether to emulate FPU
    //   bit 0: fma
    //   bit 1: iterative fdivsqrt
    //   bit 2: 2b iterative fdivsqrt
    integer unsigned fpu_support;
    // Whether to enable the "c" extension.
    integer unsigned compressed_support;

    // Whether the coherence network is on the core clock or on its own clock
    integer unsigned async_coh_clk;
    // Flit width of the coherence network. Has major impact on latency / area of the network
    integer unsigned coh_noc_flit_width;
    // Concentrator ID width of the coherence network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned coh_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned coh_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned coh_noc_max_credits;

    // Whether the I/O network is on the core clock or on its own clock
    integer unsigned async_mem_clk;
    // Flit width of the I/O network. Has major impact on latency / area of the network
    integer unsigned mem_noc_flit_width;
    // Concentrator ID width of the I/O network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned mem_noc_cid_width;
    // Domain ID width of the I/O network. Corresponds to how many chips compose a multichip chain
    integer unsigned mem_noc_did_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned mem_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned mem_noc_max_credits;

    // Whether the memory network is on the core clock or on its own clock
    integer unsigned async_dma_clk;
    // Flit width of the memory network. Has major impact on latency / area of the network
    integer unsigned dma_noc_flit_width;
    // Concentrator ID width of the memory network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned dma_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned dma_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned dma_noc_max_credits;

  }  bp_proc_param_s;

  localparam bp_proc_param_s bp_default_cfg_p =
    '{cc_x_dim  : 1
      ,cc_y_dim : 1
      ,ic_y_dim : 0
      ,mc_y_dim : 0
      ,cac_x_dim: 0
      ,sac_x_dim: 0
      ,cacc_type: e_cacc_none
      ,sacc_type: e_sacc_none

      ,num_cce: 1
      ,num_lce: 2

      ,vaddr_width: 39
      ,paddr_width: 40
      ,daddr_width: 33
      ,caddr_width: 32
      ,asid_width : 1

      ,branch_metadata_fwd_width: 47
      ,ras_idx_width            : 3
      ,btb_tag_width            : 9
      ,btb_idx_width            : 6
      ,bht_idx_width            : 7
      ,bht_row_els              : 4
      ,ghist_width              : 2

      ,itlb_els_4k : 8
      ,dtlb_els_4k : 8
      ,itlb_els_1g : 0
      ,dtlb_els_1g : 0

      ,dcache_features      : (1 << e_cfg_enabled)
                              | (1 << e_cfg_writeback)
                              | (1 << e_cfg_lr_sc)
                              | (1 << e_cfg_amo_swap)
                              | (1 << e_cfg_amo_fetch_logic)
                              | (1 << e_cfg_amo_fetch_arithmetic)
                              | (1 << e_cfg_hit_under_miss)
      ,dcache_sets          : 64
      ,dcache_assoc         : 8
      ,dcache_block_width   : 512
      ,dcache_fill_width    : 128

      ,icache_features      : (1 << e_cfg_enabled)
      ,icache_sets          : 64
      ,icache_assoc         : 8
      ,icache_block_width   : 512
      ,icache_fill_width    : 128

      ,acache_features      : (1 << e_cfg_enabled)
      ,acache_sets          : 64
      ,acache_assoc         : 8
      ,acache_block_width   : 512
      ,acache_fill_width    : 128

      ,cce_type             : e_cce_uce
      ,cce_pc_width         : 8
      ,bedrock_block_width  : 512
      ,bedrock_fill_width   : 128

      ,l2_features          : (1 << e_cfg_enabled)
                              | (1 << e_cfg_writeback)
                              | (1 << e_cfg_word_tracking)
                              | (1 << e_cfg_amo_swap)
                              | (1 << e_cfg_amo_fetch_logic)
                              | (1 << e_cfg_amo_fetch_arithmetic)
      ,l2_banks            : 2
      ,l2_data_width       : 128
      ,l2_sets             : 128
      ,l2_assoc            : 8
      ,l2_block_width      : 512
      ,l2_fill_width       : 128
      ,l2_outstanding_reqs : 6

      ,fe_queue_fifo_els : 8
      ,fe_cmd_fifo_els   : 4
      ,integer_support   : (1 << e_basic) | (1 << e_catchup)
      ,muldiv_support    : (1 << e_idiv)
                           | (1 << e_imul)
                           | (1 << e_imulh)
                           | (1 << e_idiv2b)
      ,fpu_support       : (1 << e_fma) | (1 << e_fdivsqrt) | (1 << e_fdivsqrt2b)
      ,compressed_support: 1

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 128
      ,coh_noc_cid_width   : 3
      ,coh_noc_len_width   : 4
      ,coh_noc_max_credits : 32

      ,async_mem_clk         : 0
      ,mem_noc_flit_width    : 128
      ,mem_noc_cid_width     : 3
      ,mem_noc_did_width     : 3
      ,mem_noc_len_width     : 4
      ,mem_noc_max_credits   : 32

      ,async_dma_clk         : 0
      ,dma_noc_flit_width    : 128
      ,dma_noc_cid_width     : 3
      ,dma_noc_len_width     : 4
      ,dma_noc_max_credits   : 32
      };

  // BP_CUSTOM_DEFINES_PATH can be set to a file which has the custom defines below set
  // Or, you can override the empty one in bp_common/src/include
  `ifndef BP_CUSTOM_DEFINES_PATH
    `define BP_CUSTOM_DEFINES_PATH "bp_common_aviary_custom_defines.svh"
  `endif
  `include `BP_CUSTOM_DEFINES_PATH
  `ifndef BP_CUSTOM_BASE_CFG
    `define BP_CUSTOM_BASE_CFG bp_default_cfg_p
  `endif
  // Custom, tick define-based configuration
  localparam bp_proc_param_s bp_custom_cfg_p =
    '{`bp_aviary_define_override(cc_x_dim, BP_CC_X_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cc_y_dim, BP_CC_Y_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ic_y_dim, BP_IC_Y_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mc_y_dim, BP_MC_Y_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cac_x_dim, BP_CAC_X_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(sac_x_dim, BP_SAC_X_DIM, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cacc_type, BP_CACC_TYPE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(sacc_type, BP_SACC_TYPE, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(num_cce, BP_NUM_CCE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(num_lce, BP_NUM_LCE, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(vaddr_width, BP_VADDR_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(paddr_width, BP_PADDR_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(daddr_width, BP_DADDR_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(caddr_width, BP_CADDR_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(asid_width, BP_ASID_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(fe_queue_fifo_els, BP_FE_QUEUE_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(fe_cmd_fifo_els, BP_FE_CMD_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(integer_support, BP_INTEGER_SUPPORT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(muldiv_support, BP_MULDIV_SUPPORT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(fpu_support, BP_FPU_SUPPORT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(compressed_support, BP_COMPRESSED_SUPPORT, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(branch_metadata_fwd_width, BRANCH_METADATA_FWD_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ras_idx_width, BP_RAS_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_tag_width, BP_BTB_TAG_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_idx_width, BP_BTB_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bht_idx_width, BP_BHT_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bht_row_els, BP_BHT_ROW_ELS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ghist_width, BP_GHIST_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(itlb_els_4k, BP_ITLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(itlb_els_1g, BP_ITLB_ELS_1G, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_4k, BP_DTLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_1g, BP_DTLB_ELS_1G, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(icache_features, BP_ICACHE_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_sets, BP_ICACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_assoc, BP_ICACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_block_width, BP_ICACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_fill_width, BP_ICACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(dcache_features, BP_DCACHE_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_sets, BP_DCACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_assoc, BP_DCACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_block_width, BP_DCACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_fill_width, BP_DCACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(acache_features, BP_ACACHE_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_sets, BP_ACACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_assoc, BP_ACACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_block_width, BP_ACACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_fill_width, BP_ACACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(cce_type, BP_CCE_TYPE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cce_pc_width, BP_CCE_PC_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bedrock_block_width, BP_BEDROCK_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bedrock_fill_width, BP_BEDROCK_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(l2_features, BP_L2_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_banks, BP_L2_BANKS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_data_width, BP_L2_DATA_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_sets, BP_L2_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_assoc, BP_L2_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_block_width, BP_L2_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_fill_width, BP_L2_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_outstanding_reqs, BP_L2_OUTSTANDING_REQS, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(async_coh_clk, BP_ASYNC_COH_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_max_credits, BP_COH_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_flit_width, BP_COH_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_cid_width, BP_COH_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(coh_noc_len_width, BP_COH_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(async_mem_clk, BP_ASYNC_IO_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_max_credits, BP_IO_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_flit_width, BP_IO_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_cid_width, BP_IO_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_did_width, BP_IO_NOC_DID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_len_width, BP_IO_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(async_dma_clk, BP_ASYNC_MEM_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dma_noc_max_credits, BP_MEM_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dma_noc_flit_width, BP_MEM_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dma_noc_cid_width, BP_MEM_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dma_noc_len_width, BP_MEM_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)
      };

`endif


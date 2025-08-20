
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
    ,e_cfg_misaligned           = 4'b1001
  } bp_cache_features_e;
  typedef logic [(1<<$bits(bp_cache_features_e))-1:0] bp_cache_features_t;

  typedef enum logic
  {
    e_basic = 1'b0
    ,e_catchup = 1'b1
  } bp_integer_support_e;
  typedef logic [(1<<$bits(bp_integer_support_e))-1:0] bp_integer_support_t;

  typedef enum logic [1:0]
  {
    e_idiv    = 2'b00
    ,e_imul   = 2'b01
    ,e_imulh  = 2'b10
    ,e_idiv2b = 2'b11
  } bp_muldiv_support_e;
  typedef logic [(1<<$bits(bp_muldiv_support_e))-1:0] bp_muldiv_support_t;

  typedef enum logic [1:0]
  {
    e_fma         = 2'b00
    ,e_fdivsqrt   = 2'b01
    ,e_fdivsqrt2b = 2'b10
  } bp_fpu_support_e;
  typedef logic [(1<<$bits(bp_fpu_support_e))-1:0] bp_fpu_support_t;

  typedef enum logic [1:0]
  {
    e_zba         = 2'b00
    ,e_zbb        = 2'b01
    ,e_zbc        = 2'b10
    ,e_zbs        = 2'b11
  } bp_bitmanip_support_e;
  typedef logic [(1<<$bits(bp_bitmanip_support_e))-1:0] bp_bitmanip_support_t;

  typedef enum logic
  {
    e_compressed = 1'b0
  } bp_compressed_support_e;
  typedef logic [(1<<$bits(bp_compressed_support_e))-1:0] bp_compressed_support_t;

  typedef enum logic [15:0]
  {
    e_sacc_none = 16'd0
    ,e_sacc_vdp = 16'd1
    ,e_sacc_scratchpad = 16'd2
  } bp_sacc_type_e;

  typedef enum logic [15:0]
  {
    e_cacc_none = 16'd0
    ,e_cacc_vdp = 16'd1
  } bp_cacc_type_e;

  typedef enum logic [1:0]
  {
    e_cce_uce = 2'd0
    ,e_cce_fsm = 2'd1
    ,e_cce_ucode = 2'd2
    ,e_cce_hybrid = 2'd3
  } bp_cce_type_e;

  typedef struct packed
  {
    // Dimensions of the different complexes
    // Core Complex may be any int (though has only been validated up to 4x4)
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
    int cc_x_dim;
    int cc_y_dim;
    int ic_y_dim;
    int mc_y_dim;
    int cac_x_dim;
    int sac_x_dim;

    // The type of accelerator in the accelerator complexes, selected out of bp_cacc_type_e/bp_sacc_type_e
    // Only supports homogeneous configurations
    int cacc_type;
    int sacc_type;

    // Number of CCEs/LCEs in the system. Must be consistent within complex dimensions
    int num_cce;
    int num_lce;

    // Virtual address width
    //   Only tested for SV39 (39-bit virtual address)
    int vaddr_width;
    // Physical address width
    //   Only tested for 40-bit physical address
    int paddr_width;
    // DRAM address width
    // The max size of the connected DRAM i.e. cached address space
    //   Only tested for 32-bit cacheable address (4 GB space, with 2 GB local I/O)
    int daddr_width;
    // Cacheable address width
    // The max size cached by the L1 caches of the system
    int caddr_width;
    // Address space ID width
    //   Currently unused, so set to 1 bit
    int asid_width;

    // Branch metadata information for the Front End
    // Must be kept consistent with FE
    int branch_metadata_fwd_width;
    int ras_idx_width;
    int btb_tag_width;
    int btb_idx_width;
    // bht_row_els is a physically-derived parameter. It describes the number
    //   of entries in a single row of the BHT RAM.  There are 2 bits per entry.
    //   The tradeoff here is a wider RAM is most likely higher performance,
    //   but we need to carry that extra metadata throughout the pipeline to
    //   maintain 1r1w throughput without a RMW.
    // Ghist is the global history width, which in our gselect
    // Thus, the true BHT dimensions are (bht_idx_width+ghist_width)x(2*bht_row_els)
    int bht_idx_width;
    int bht_row_els;
    int ghist_width;

    // Capacity of the Instruction/Data TLBs
    int itlb_els_4k;
    int itlb_els_2m;
    int itlb_els_1g;
    int dtlb_els_4k;
    int dtlb_els_2m;
    int dtlb_els_1g;

    // I$ cache features
    int icache_features;
    // I$ parameterizations
    int icache_sets;
    int icache_assoc;
    int icache_block_width;
    int icache_fill_width;
    int icache_data_width;
    int icache_mshr;

    // D$ cache features
    int dcache_features;
    // D$ parameterizations
    int dcache_sets;
    int dcache_assoc;
    int dcache_block_width;
    int dcache_fill_width;
    int dcache_data_width;
    int dcache_mshr;

    // A$ cache features
    int acache_features;
    // A$ parameterizations
    int acache_sets;
    int acache_assoc;
    int acache_block_width;
    int acache_fill_width;
    int acache_data_width;
    int acache_mshr;

    // CCE selection and parameters
    // cce_type defined by bp_cce_type_e
    int cce_type;
    // Determines the size of the CCE instruction RAM
    int cce_pc_width;
    // The width of the coherence protocol block
    int bedrock_block_width;
    // The width of the coherence protocol beats
    int bedrock_fill_width;

    // L2 slice parameters (per core)
    // L2 cache features
    int l2_features;
    int l2_slices;
    // Number of L2 banks present in the slice
    int l2_banks;
    int l2_data_width;
    int l2_sets;
    int l2_assoc;
    int l2_block_width;
    int l2_fill_width;

    // Size of the issue queue
    int fe_queue_fifo_els;
    // Size of the cmd queue
    int fe_cmd_fifo_els;
    // Integer support in the system. It is a bitmask with:
    //   bit 0: basic alu
    //   bit 1: catchup alu
    int integer_support;
    // MULDIV support in the system. It is a bitmask with:
    //   bit 0: div
    //   bit 1: mul
    //   bit 2: iterative mulh
    //   bit 3: 2b iterative div
    int muldiv_support;
    // Whether to support FPU
    //   bit 0: fma
    //   bit 1: iterative fdivsqrt
    //   bit 2: 2b iterative fdivsqrt
    int fpu_support;
    // Whether to enable the "c" extension.
    //   bit 0: basic C
    int compressed_support;
    // Whether to enable bitmanip extensions
    int bitmanip_support;

    // Whether the coherence network is on the core clock or on its own clock
    int async_coh_clk;
    // Flit width of the coherence network. Has major impact on latency / area of the network
    int coh_noc_flit_width;
    // Concentrator ID width of the coherence network. Corresponds to how many nodes can be on a
    //   single wormhole router
    int coh_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    int coh_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    int coh_noc_max_credits;

    // Whether the I/O network is on the core clock or on its own clock
    int async_mem_clk;
    // Flit width of the I/O network. Has major impact on latency / area of the network
    int mem_noc_flit_width;
    // Concentrator ID width of the I/O network. Corresponds to how many nodes can be on a
    //   single wormhole router
    int mem_noc_cid_width;
    // Domain ID width of the I/O network. Corresponds to how many chips compose a multichip chain
    int mem_noc_did_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    int mem_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    int mem_noc_max_credits;

    // Whether the memory network is on the core clock or on its own clock
    int async_dma_clk;
    // Flit width of the memory network. Has major impact on latency / area of the network
    int dma_noc_flit_width;
    // Concentrator ID width of the memory network. Corresponds to how many nodes can be on a
    //   single wormhole router
    int dma_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    int dma_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    int dma_noc_max_credits;

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

      ,branch_metadata_fwd_width: 49
      ,ras_idx_width            : 4
      ,btb_tag_width            : 9
      ,btb_idx_width            : 6
      ,bht_idx_width            : 7
      ,bht_row_els              : 4
      ,ghist_width              : 2

      ,itlb_els_4k : 8
      ,itlb_els_2m : 2
      ,itlb_els_1g : 1
      ,dtlb_els_4k : 8
      ,dtlb_els_2m : 2
      ,dtlb_els_1g : 1

      ,icache_features      : (1 << e_cfg_enabled) | (1 << e_cfg_misaligned)
      ,icache_sets          : 64
      ,icache_assoc         : 8
      ,icache_block_width   : 512
      ,icache_fill_width    : 128
      ,icache_mshr          : 1
      ,icache_data_width    : 64

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
      ,dcache_mshr          : 1
      ,dcache_data_width    : 64

      ,acache_features      : (1 << e_cfg_enabled)
      ,acache_sets          : 64
      ,acache_assoc         : 8
      ,acache_block_width   : 512
      ,acache_fill_width    : 128
      ,acache_data_width    : 64
      ,acache_mshr          : 1

      ,cce_type             : e_cce_uce
      ,cce_pc_width         : 8
      ,bedrock_block_width  : 512
      ,bedrock_fill_width   : 128

      ,l2_features          : (1 << e_cfg_enabled)
                              | (1 << e_cfg_writeback)
                              | (1 << e_cfg_amo_swap)
                              | (1 << e_cfg_amo_fetch_logic)
                              | (1 << e_cfg_amo_fetch_arithmetic)
      ,l2_slices           : 2
      ,l2_banks            : 1
      ,l2_data_width       : 128
      ,l2_sets             : 32
      ,l2_assoc            : 2
      ,l2_block_width      : 512
      ,l2_fill_width       : 128

      ,fe_queue_fifo_els : 8
      ,fe_cmd_fifo_els   : 4
      ,integer_support   : (1 << e_basic) | (1 << e_catchup)
      ,muldiv_support    : (1 << e_idiv)
                           | (1 << e_imul)
                           | (1 << e_imulh)
                           | (1 << e_idiv2b)
      ,fpu_support       : (1 << e_fma) | (1 << e_fdivsqrt) | (1 << e_fdivsqrt2b)
      ,bitmanip_support  : (1 << e_zba) | (1 << e_zbb) | (1 << e_zbs)
      ,compressed_support: (1 << e_compressed)

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
      ,`bp_aviary_define_override(bitmanip_support, BP_BITMANIP_SUPPORT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(compressed_support, BP_COMPRESSED_SUPPORT, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(branch_metadata_fwd_width, BRANCH_METADATA_FWD_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ras_idx_width, BP_RAS_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_tag_width, BP_BTB_TAG_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_idx_width, BP_BTB_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bht_idx_width, BP_BHT_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bht_row_els, BP_BHT_ROW_ELS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ghist_width, BP_GHIST_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(itlb_els_4k, BP_ITLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(itlb_els_2m, BP_ITLB_ELS_2M, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(itlb_els_1g, BP_ITLB_ELS_1G, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_4k, BP_DTLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_2m, BP_DTLB_ELS_2M, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_1g, BP_DTLB_ELS_1G, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(icache_features, BP_ICACHE_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_sets, BP_ICACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_assoc, BP_ICACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_block_width, BP_ICACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_fill_width, BP_ICACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_data_width, BP_ICACHE_DATA_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_mshr, BP_ICACHE_MSHR, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(dcache_features, BP_DCACHE_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_sets, BP_DCACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_assoc, BP_DCACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_block_width, BP_DCACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_fill_width, BP_DCACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_data_width, BP_DCACHE_DATA_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_mshr, BP_DCACHE_MSHR, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(acache_features, BP_ACACHE_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_sets, BP_ACACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_assoc, BP_ACACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_block_width, BP_ACACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_fill_width, BP_ACACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_data_width, BP_ACACHE_DATA_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_mshr, BP_ACACHE_MSHR, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(cce_type, BP_CCE_TYPE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cce_pc_width, BP_CCE_PC_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bedrock_block_width, BP_BEDROCK_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bedrock_fill_width, BP_BEDROCK_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(l2_features, BP_L2_FEATURES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_slices, BP_L2_SLICES, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_banks, BP_L2_BANKS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_data_width, BP_L2_DATA_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_sets, BP_L2_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_assoc, BP_L2_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_block_width, BP_L2_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_fill_width, BP_L2_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

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


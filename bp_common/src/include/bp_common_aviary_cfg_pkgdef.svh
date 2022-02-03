
`ifndef BP_COMMON_AVIARY_CFG_PKGDEF_SVH
`define BP_COMMON_AVIARY_CFG_PKGDEF_SVH

  // Suitably high enough to not run out of configs.
  localparam max_cfgs    = 128;
  localparam lg_max_cfgs = $clog2(max_cfgs);

  // Configuration enums
  typedef enum logic [1:0]
  {
    e_lr_sc                 = 2'b00
    ,e_amo_swap             = 2'b01
    ,e_amo_fetch_logic      = 2'b10
    ,e_amo_fetch_arithmetic = 2'b11
  } bp_atomic_support_e;

  typedef enum logic [1:0]
  {
    e_div   = 2'b00
    ,e_mul  = 2'b01
    ,e_mulh = 2'b10
  } bp_muldiv_support_e;

  typedef enum logic [15:0]
  {
    e_sacc_none = 0
    ,e_sacc_vdp = 1
    ,e_sacc_loopback = 2
  } bp_sacc_type_e;

  typedef enum logic [15:0]
  {
    e_cacc_none = 0
    ,e_cacc_vdp = 1
  } bp_cacc_type_e;

  typedef struct packed
  {
    // 0: BP unicore (minimal, single-core configuration)
    // 1: BP multicore (coherent, multi-core configuration)
    integer unsigned multicore;

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

    // The virtual address of the PC coming out of reset
    integer unsigned boot_pc;
    // 0: boots in M-mode, not debug-mode
    // 1: boots in M-mode, debug-mode
    integer unsigned boot_in_debug;

    // Branch metadata information for the Front End
    // Must be kept consistent with FE
    integer unsigned branch_metadata_fwd_width;
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

    // I$ parameterizations
    integer unsigned icache_coherent;
    integer unsigned icache_sets;
    integer unsigned icache_assoc;
    integer unsigned icache_block_width;
    integer unsigned icache_fill_width;

    // D$ parameterizations
    // Whether the D$ is writethrough or writeback
    integer unsigned dcache_writethrough;
    // Atomic support in D$
    //   bit 0: e_lr_sc 
    //   bit 1: e_amo_swap
    //   bit 2: e_amo_fetch_logic
    //   bit 3: e_amo_fetch_arithmetic
    integer unsigned dcache_amo_support;
    integer unsigned dcache_sets;
    integer unsigned dcache_assoc;
    integer unsigned dcache_block_width;
    integer unsigned dcache_fill_width;

    // A$ parameterizations
    // Atomic support in A$
    //   bit 0: e_lr_sc 
    //   bit 1: e_amo_swap
    //   bit 2: e_amo_fetch_logic
    //   bit 3: e_amo_fetch_arithmetic
    integer unsigned acache_amo_support;
    integer unsigned acache_sets;
    integer unsigned acache_assoc;
    integer unsigned acache_block_width;
    integer unsigned acache_fill_width;

    // Microcoded CCE parameters
    // 0: CCE is FSM-based
    // 1: CCE is ucode
    integer unsigned cce_ucode;
    // Determines the size of the CCE instruction RAM
    integer unsigned cce_pc_width;

    // L2 slice parameters (per core)
    // Whether an L2 is present in the system
    integer unsigned l2_en;
    // Number of L2 banks present in the slice
    integer unsigned l2_banks;
    // Atomic support in L2
    //   bit 0: lr_sc
    //   bit 1: amo_swap
    //   bit 2: amo_fetch_logic
    //   bit 3: amo_fetch_arithmetic
    integer unsigned l2_amo_support;
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
    // MULDIV support in the system. It is a bitmask with:
    //   bit 0: div
    //   bit 1: mul
    //   bit 2: mulh
    integer unsigned muldiv_support;
    // Whether to emulate FPU
    //   bit 0: fpu enabled
    integer unsigned fpu_support;

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

    // Whether the memory network is on the core clock or on its own clock
    integer unsigned async_mem_clk;
    // Flit width of the memory network. Has major impact on latency / area of the network
    integer unsigned mem_noc_flit_width;
    // Concentrator ID width of the memory network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned mem_noc_cid_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned mem_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned mem_noc_max_credits;

    // Whether the I/O network is on the core clock or on its own clock
    integer unsigned async_io_clk;
    // Flit width of the I/O network. Has major impact on latency / area of the network
    integer unsigned io_noc_flit_width;
    // Concentrator ID width of the I/O network. Corresponds to how many nodes can be on a
    //   single wormhole router
    integer unsigned io_noc_cid_width;
    // Domain ID width of the I/O network. Corresponds to how many chips compose a multichip chain
    integer unsigned io_noc_did_width;
    // Maximum number of flits in a single wormhole message. Determined by protocol and affects
    //   buffer size
    integer unsigned io_noc_len_width;
    // Maximum credits supported by the network. Correlated to the bandwidth delay product
    integer unsigned io_noc_max_credits;

  }  bp_proc_param_s;

  localparam bp_proc_param_s bp_default_cfg_p =
    '{multicore : 0
      ,cc_x_dim : 1
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

      ,boot_pc       : dram_base_addr_gp
      ,boot_in_debug : 0

      ,branch_metadata_fwd_width: 39
      ,btb_tag_width            : 9
      ,btb_idx_width            : 6
      ,bht_idx_width            : 7
      ,bht_row_els              : 4
      ,ghist_width              : 2

      ,itlb_els_4k : 8
      ,dtlb_els_4k : 8
      ,itlb_els_1g : 0
      ,dtlb_els_1g : 0

      ,dcache_writethrough  : 0
      ,dcache_amo_support   : (1 << e_lr_sc)
                              | (1 << e_amo_swap)
                              | (1 << e_amo_fetch_logic)
                              | (1 << e_amo_fetch_arithmetic)
      ,dcache_sets          : 64
      ,dcache_assoc         : 8
      ,dcache_block_width   : 512
      ,dcache_fill_width    : 64

      ,icache_coherent      : 0
      ,icache_sets          : 64
      ,icache_assoc         : 8
      ,icache_block_width   : 512
      ,icache_fill_width    : 64

      ,acache_amo_support   : 0
      ,acache_sets          : 64
      ,acache_assoc         : 8
      ,acache_block_width   : 512
      ,acache_fill_width    : 64

      ,cce_ucode            : 0
      ,cce_pc_width         : 8

      ,l2_en               : 1
      ,l2_banks            : 2
      ,l2_amo_support      : (1 << e_amo_swap)
                             | (1 << e_amo_fetch_logic)
                             | (1 << e_amo_fetch_arithmetic)
      ,l2_data_width       : 64
      ,l2_sets             : 128
      ,l2_assoc            : 8
      ,l2_block_width      : 512
      ,l2_fill_width       : 64
      ,l2_outstanding_reqs : 6

      ,fe_queue_fifo_els : 8
      ,fe_cmd_fifo_els   : 4
      ,muldiv_support    : (1 << e_div) | (1 << e_mul)
      ,fpu_support       : 1

      ,async_coh_clk       : 0
      ,coh_noc_flit_width  : 128
      ,coh_noc_cid_width   : 2
      ,coh_noc_len_width   : 3
      ,coh_noc_max_credits : 8

      ,async_mem_clk         : 0
      ,mem_noc_flit_width    : 64
      ,mem_noc_cid_width     : 2
      ,mem_noc_len_width     : 4
      ,mem_noc_max_credits   : 8

      ,async_io_clk         : 0
      ,io_noc_flit_width    : 64
      ,io_noc_cid_width     : 2
      ,io_noc_did_width     : 3
      ,io_noc_len_width     : 4
      ,io_noc_max_credits   : 16
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
    '{`bp_aviary_define_override(multicore, BP_MULTICORE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cc_x_dim, BP_CC_X_DIM, `BP_CUSTOM_BASE_CFG)
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

      ,`bp_aviary_define_override(boot_pc, BP_BOOT_PC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(boot_in_debug, BP_BOOT_IN_DEBUG, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(fe_queue_fifo_els, BP_FE_QUEUE_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(fe_cmd_fifo_els, BP_FE_CMD_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(muldiv_support, BP_MULDIV_SUPPORT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(fpu_support, BP_FPU_SUPPORT, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(branch_metadata_fwd_width, BRANCH_METADATA_FWD_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_tag_width, BP_BTB_TAG_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(btb_idx_width, BP_BTB_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bht_idx_width, BP_BHT_IDX_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(bht_row_els, BP_BHT_ROW_ELS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(ghist_width, BP_GHIST_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(itlb_els_4k, BP_ITLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(itlb_els_1g, BP_ITLB_ELS_1G, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_4k, BP_DTLB_ELS_4K, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dtlb_els_1g, BP_DTLB_ELS_1G, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(icache_coherent, BP_ICACHE_COHERENT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_sets, BP_ICACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_assoc, BP_ICACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_block_width, BP_ICACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(icache_fill_width, BP_ICACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(dcache_writethrough, BP_DCACHE_WRITETHROUGH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_amo_support, BP_DCACHE_AMO_SUPPORT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_sets, BP_DCACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_assoc, BP_DCACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_block_width, BP_DCACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(dcache_fill_width, BP_DCACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(acache_amo_support, BP_ACACHE_AMO_SUPPORT, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_sets, BP_ACACHE_SETS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_assoc, BP_ACACHE_ASSOC, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_block_width, BP_ACACHE_BLOCK_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(acache_fill_width, BP_ACACHE_FILL_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(cce_ucode, BP_CCE_UCODE, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(cce_pc_width, BP_CCE_PC_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(l2_en, BP_L2_EN, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_banks, BP_L2_BANKS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(l2_amo_support, BP_L2_AMO_SUPPORT, `BP_CUSTOM_BASE_CFG)
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

      ,`bp_aviary_define_override(async_mem_clk, BP_ASYNC_MEM_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_max_credits, BP_MEM_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_flit_width, BP_MEM_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_cid_width, BP_MEM_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(mem_noc_len_width, BP_MEM_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)

      ,`bp_aviary_define_override(async_io_clk, BP_ASYNC_IO_CLK, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_max_credits, BP_IO_NOC_MAX_CREDITS, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_flit_width, BP_IO_NOC_FLIT_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_cid_width, BP_IO_NOC_CID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_did_width, BP_IO_NOC_DID_WIDTH, `BP_CUSTOM_BASE_CFG)
      ,`bp_aviary_define_override(io_noc_len_width, BP_IO_NOC_LEN_WIDTH, `BP_CUSTOM_BASE_CFG)
      };

`endif


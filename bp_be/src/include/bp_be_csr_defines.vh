`ifndef BP_BE_CSR_DEFINES_VH
`define BP_BE_CSR_DEFINES_VH

`define RV64_PRIV_MODE_M 2'b11
`define RV64_PRIV_MODE_S 2'b01
`define RV64_PRIV_MODE_U 2'b00

`define RV64_CSR_ADDR_USTATUS       12'h000
`define RV64_CSR_ADDR_UIE           12'h004
`define RV64_CSR_ADDR_UTVEC         12'h005

`define RV64_CSR_ADDR_USCRATCH      12'h040
`define RV64_CSR_ADDR_UEPC          12'h041
`define RV64_CSR_ADDR_UCAUSE        12'h042
`define RV64_CSR_ADDR_UTVAL         12'h043
`define RV64_CSR_ADDR_UIP           12'h044

`define RV64_CSR_ADDR_FFLAGS        12'h001
`define RV64_CSR_ADDR_FRM           12'h002
`define RV64_CSR_ADDR_FCSR          12'h003

`define RV64_CSR_ADDR_CYCLE         12'hc00
`define RV64_CSR_ADDR_TIME          12'hc01
`define RV64_CSR_ADDR_INSTRET       12'hc02
`define RV64_CSR_ADDR_HPMCOUNTER3   12'hc03
`define RV64_CSR_ADDR_HPMCOUNTER4   12'hc04
`define RV64_CSR_ADDR_HPMCOUNTER5   12'hc05
`define RV64_CSR_ADDR_HPMCOUNTER6   12'hc06
`define RV64_CSR_ADDR_HPMCOUNTER7   12'hc07
`define RV64_CSR_ADDR_HPMCOUNTER8   12'hc08
`define RV64_CSR_ADDR_HPMCOUNTER9   12'hc09
`define RV64_CSR_ADDR_HPMCOUNTER10  12'hc0a
`define RV64_CSR_ADDR_HPMCOUNTER11  12'hc0b
`define RV64_CSR_ADDR_HPMCOUNTER12  12'hc0c
`define RV64_CSR_ADDR_HPMCOUNTER13  12'hc0d
`define RV64_CSR_ADDR_HPMCOUNTER14  12'hc0e
`define RV64_CSR_ADDR_HPMCOUNTER15  12'hc0f
`define RV64_CSR_ADDR_HPMCOUNTER16  12'hc10
`define RV64_CSR_ADDR_HPMCOUNTER17  12'hc11
`define RV64_CSR_ADDR_HPMCOUNTER18  12'hc12
`define RV64_CSR_ADDR_HPMCOUNTER19  12'hc13
`define RV64_CSR_ADDR_HPMCOUNTER20  12'hc14
`define RV64_CSR_ADDR_HPMCOUNTER21  12'hc15
`define RV64_CSR_ADDR_HPMCOUNTER22  12'hc16
`define RV64_CSR_ADDR_HPMCOUNTER23  12'hc17
`define RV64_CSR_ADDR_HPMCOUNTER24  12'hc18
`define RV64_CSR_ADDR_HPMCOUNTER25  12'hc19
`define RV64_CSR_ADDR_HPMCOUNTER26  12'hc1a
`define RV64_CSR_ADDR_HPMCOUNTER27  12'hc1b
`define RV64_CSR_ADDR_HPMCOUNTER28  12'hc1c
`define RV64_CSR_ADDR_HPMCOUNTER29  12'hc1d
`define RV64_CSR_ADDR_HPMCOUNTER30  12'hc1e
`define RV64_CSR_ADDR_HPMCOUNTER31  12'hc1f

`define RV64_CSR_ADDR_SSTATUS       12'h100
`define RV64_CSR_ADDR_SEDELEG       12'h102
`define RV64_CSR_ADDR_SIDELEG       12'h103
`define RV64_CSR_ADDR_SIE           12'h104
`define RV64_CSR_ADDR_STVEC         12'h105
`define RV64_CSR_ADDR_SCOUNTEREN    12'h106

`define RV64_CSR_ADDR_SSCRATCH      12'h140
`define RV64_CSR_ADDR_SEPC          12'h141
`define RV64_CSR_ADDR_SCAUSE        12'h142
`define RV64_CSR_ADDR_STVAL         12'h143
`define RV64_CSR_ADDR_SIP           12'h144

`define RV64_CSR_ADDR_SATP          12'h180

`define RV64_CSR_ADDR_MVENDORID     12'hf11
`define RV64_CSR_ADDR_MARCHID       12'hf12
`define RV64_CSR_ADDR_MIMPID        12'hf12
`define RV64_CSR_ADDR_MHARTID       12'hf14

`define RV64_CSR_ADDR_MSTATUS       12'h300
`define RV64_CSR_ADDR_MISA          12'h301
`define RV64_CSR_ADDR_MEDELEG       12'h302
`define RV64_CSR_ADDR_MIDELEG       12'h303
`define RV64_CSR_ADDR_MIE           12'h304
`define RV64_CSR_ADDR_MTVEC         12'h305
`define RV64_CSR_ADDR_MCOUNTEREN    12'h306

`define RV64_CSR_ADDR_MSCRATCH      12'h340
`define RV64_CSR_ADDR_MEPC          12'h341
`define RV64_CSR_ADDR_MCAUSE        12'h342
`define RV64_CSR_ADDR_MTVAL         12'h343
`define RV64_CSR_ADDR_MIP           12'h344

`define RV64_CSR_ADDR_PMPCFG0       12'h3a0
`define RV64_CSR_ADDR_PMPCFG2       12'h3a2
`define RV64_CSR_ADDR_PMPADDR0      12'h3b0
`define RV64_CSR_ADDR_PMPADDR1      12'h3b1
`define RV64_CSR_ADDR_PMPADDR2      12'h3b2
`define RV64_CSR_ADDR_PMPADDR3      12'h3b3
`define RV64_CSR_ADDR_PMPADDR4      12'h3b4
`define RV64_CSR_ADDR_PMPADDR5      12'h3b5
`define RV64_CSR_ADDR_PMPADDR6      12'h3b6
`define RV64_CSR_ADDR_PMPADDR7      12'h3b7
`define RV64_CSR_ADDR_PMPADDR8      12'h3b8
`define RV64_CSR_ADDR_PMPADDR9      12'h3b9
`define RV64_CSR_ADDR_PMPADDR10     12'h3ba
`define RV64_CSR_ADDR_PMPADDR11     12'h3bb
`define RV64_CSR_ADDR_PMPADDR12     12'h3bc
`define RV64_CSR_ADDR_PMPADDR13     12'h3bd
`define RV64_CSR_ADDR_PMPADDR14     12'h3be
`define RV64_CSR_ADDR_PMPADDR15     12'h3bf

`define RV64_CSR_ADDR_MCYCLE        12'hb00
`define RV64_CSR_ADDR_MINSTRET      12'hb02
`define RV64_CSR_ADDR_MHPMCOUNTER3  12'hb03
`define RV64_CSR_ADDR_MHPMCOUNTER4  12'hb04
`define RV64_CSR_ADDR_MHPMCOUNTER5  12'hb05
`define RV64_CSR_ADDR_MHPMCOUNTER6  12'hb06
`define RV64_CSR_ADDR_MHPMCOUNTER7  12'hb07
`define RV64_CSR_ADDR_MHPMCOUNTER8  12'hb08
`define RV64_CSR_ADDR_MHPMCOUNTER9  12'hb09
`define RV64_CSR_ADDR_MHPMCOUNTER10 12'hb0a
`define RV64_CSR_ADDR_MHPMCOUNTER11 12'hb0b
`define RV64_CSR_ADDR_MHPMCOUNTER12 12'hb0c
`define RV64_CSR_ADDR_MHPMCOUNTER13 12'hb0d
`define RV64_CSR_ADDR_MHPMCOUNTER14 12'hb0e
`define RV64_CSR_ADDR_MHPMCOUNTER15 12'hb0f
`define RV64_CSR_ADDR_MHPMCOUNTER16 12'hb10
`define RV64_CSR_ADDR_MHPMCOUNTER17 12'hb11
`define RV64_CSR_ADDR_MHPMCOUNTER18 12'hb12
`define RV64_CSR_ADDR_MHPMCOUNTER19 12'hb13
`define RV64_CSR_ADDR_MHPMCOUNTER20 12'hb14
`define RV64_CSR_ADDR_MHPMCOUNTER21 12'hb15
`define RV64_CSR_ADDR_MHPMCOUNTER22 12'hb16
`define RV64_CSR_ADDR_MHPMCOUNTER23 12'hb17
`define RV64_CSR_ADDR_MHPMCOUNTER24 12'hb18
`define RV64_CSR_ADDR_MHPMCOUNTER25 12'hb19
`define RV64_CSR_ADDR_MHPMCOUNTER26 12'hb1a
`define RV64_CSR_ADDR_MHPMCOUNTER27 12'hb1b
`define RV64_CSR_ADDR_MHPMCOUNTER28 12'hb1c
`define RV64_CSR_ADDR_MHPMCOUNTER29 12'hb1d
`define RV64_CSR_ADDR_MHPMCOUNTER30 12'hb1e
`define RV64_CSR_ADDR_MHPMCOUNTER31 12'hb2f

`define RV64_CSR_ADDR_MHPMEVENT3  12'b323
`define RV64_CSR_ADDR_MHPMEVENT4  12'b324
`define RV64_CSR_ADDR_MHPMEVENT5  12'b325
`define RV64_CSR_ADDR_MHPMEVENT6  12'b326
`define RV64_CSR_ADDR_MHPMEVENT7  12'b327
`define RV64_CSR_ADDR_MHPMEVENT8  12'b328
`define RV64_CSR_ADDR_MHPMEVENT9  12'b329
`define RV64_CSR_ADDR_MHPMEVENT10 12'b32a
`define RV64_CSR_ADDR_MHPMEVENT11 12'b32b
`define RV64_CSR_ADDR_MHPMEVENT12 12'b32c
`define RV64_CSR_ADDR_MHPMEVENT13 12'b32d
`define RV64_CSR_ADDR_MHPMEVENT14 12'b32e
`define RV64_CSR_ADDR_MHPMEVENT15 12'b32f
`define RV64_CSR_ADDR_MHPMEVENT16 12'b330
`define RV64_CSR_ADDR_MHPMEVENT17 12'b331
`define RV64_CSR_ADDR_MHPMEVENT18 12'b332
`define RV64_CSR_ADDR_MHPMEVENT19 12'b333
`define RV64_CSR_ADDR_MHPMEVENT20 12'b334
`define RV64_CSR_ADDR_MHPMEVENT21 12'b335
`define RV64_CSR_ADDR_MHPMEVENT22 12'b336
`define RV64_CSR_ADDR_MHPMEVENT23 12'b337
`define RV64_CSR_ADDR_MHPMEVENT24 12'b338
`define RV64_CSR_ADDR_MHPMEVENT25 12'b339
`define RV64_CSR_ADDR_MHPMEVENT26 12'b33a
`define RV64_CSR_ADDR_MHPMEVENT27 12'b33b
`define RV64_CSR_ADDR_MHPMEVENT28 12'b33c
`define RV64_CSR_ADDR_MHPMEVENT29 12'b33d
`define RV64_CSR_ADDR_MHPMEVENT30 12'b33e
`define RV64_CSR_ADDR_MHPMEVENT31 12'b33f

typedef struct packed
{
  // Translation Mode
  //   0000 - No Translation
  //   1000 - SV39
  //   1001 - SV48
  //   Others reserved
  logic [3:0] mode;
  logic [15:0] asid;
  logic [43:0] ppn;
}  rv64_satp_s;

typedef struct packed
{
  // We only support No Translation and SV39
  logic        mode;
  // We don't currently have ASID support
  // We only support 39 bit physical address.
  logic [26:0] ppn;
}  bp_satp_s;

`define bp_satp_width ($bits(bp_satp_s))

`define compress_satp_s(data_cast_mp) \
  bp_satp_s'{mode: data_cast_mp.mode[3]   \
             ,ppn: data_cast_mp.ppn[26:0] \
             }

`define decompress_satp_s(data_comp_mp) \
  rv64_satp_s'{mode: {data_comp_mp.mode, 3'b000} \
               ,ppn: {17'h0, data_comp_mp.ppn}   \
               ,default: '0                      \
               }

typedef struct packed
{
  // State Dirty
  // 0 - FS and XS are both != 11
  // 1 - set if FS or SX == 11
  //  Note: readonly
  logic        sd;
  logic [26:0] wpri1;
  // XLEN
  //   01 - 32 bit data
  //   10 - 64 bit data
  //   11 - 128 bit data
  // MXL is in misa instead.
  logic [1:0]  sxl;
  logic [1:0]  uxl;
  logic [8:0]  wpri2;
  // Trap SRET
  // 0 - SRET permitted in S-mode
  // 1 - SRET in S-mode is illegal
  logic        tsr;
  // Trap WFI
  // 0 - WFI is permitted in S-mode
  // 1 - WFI is executed and not complete within implementation-defined time, is illegal
  logic        tw;
  // Trap VM
  // 0 - The following operations are legal
  // 1 - attempts to read or write satp or execute SFENCE.VMA in S-mode are illegal
  logic        tvm;
  // Make Executable Readable
  //   0 - only loads from pages marked readable succeed
  //   1 - loads from pages marked either readable or executable succeed
  //   No effect when translation is disabled
  logic        mxr;
  // Supervisor User Memory
  //   0 - S-mode memory accesses to U-mode pages will fault
  //   1 - S-mode memory accesses to U-mode pages will succeed
  logic        sum;
  // Modify Privilege
  //   0 - translation and protection behave normally
  //   1 - load and stores are translated as though privilege mode is MPP
  logic        mprv;
  // Extension Status
  //   0 - off
  //   1 - initial (none dirty or clean)
  //   2 - clean (none dirty)
  //   3 - dirty
  // Hardwired to 0 in systems without extensions requiring context (vector)
  logic [1:0]  xs;
  // Floating-point Status
  //   0 - off
  //   1 - initial (none dirty or clean)
  //   2 - clean (none dirty)
  //   3 - dirty
  // Hardwired to 0 in systems without extensions requiring context (floating point)
  logic [1:0]  fs;
  // Previous Privilege
  //   11 - M
  //   01 - S
  //   00 - U
  logic [1:0]  mpp;
  logic [1:0]  wpri3;
  logic        spp;
  // Previous Interrupt Enable
  //   0 - Interrupt Previously Disabled for Privilege Mode
  //   1 - Interrupt Previously Enabled for Privilege Mode
  logic        mpie;
  logic        wpri4;
  logic        spie;
  logic        upie;
  // Global Interrupt Enable
  //   0 - Interrupt Disabled for Privilege Mode
  //   1 - Interrupt Enabled for Privilege Mode
  logic        mie;
  logic        wpri5;
  logic        sie;
  logic        uie; 
}  rv64_mstatus_s;

typedef struct packed
{
  logic [1:0] mpp;
  logic       spp;

  logic       mpie;
  logic       spie;
  logic       upie;

  logic       mie;
  logic       sie;
  logic       uie;
}  bp_mstatus_s;

`define compress_mstatus_s(data_cast_mp) \
  bp_mstatus_s'{mpp  : data_cast_mp.mpp  \
                ,spp : data_cast_mp.spp  \
                ,mpie: data_cast_mp.mpie \
                ,spie: data_cast_mp.spie \
                ,upie: data_cast_mp.upie \
                ,mie : data_cast_mp.mie  \
                ,sie : data_cast_mp.sie  \
                ,uie : data_cast_mp.uie  \
                }

`define decompress_mstatus_s(data_comp_mp) \
  rv64_mstatus_s'{mpp  : data_comp_mp.mpp  \
                  ,spp : data_comp_mp.spp  \
                  ,mpie: data_comp_mp.mpie \
                  ,spie: data_comp_mp.spie \
                  ,upie: data_comp_mp.upie \
                  ,mie : data_comp_mp.mie  \
                  ,sie : data_comp_mp.sie  \
                  ,uie : data_comp_mp.uie  \
                  ,default: '0             \
                  }

typedef logic [63:0] rv64_mscratch_s;
typedef logic [63:0] bp_mscratch_s;

`define compress_mscratch_s(data_cast_mp) \
  data_cast_mp[0+:64]

`define decompress_mscratch_s(data_comp_mp) \
  64'(data_comp_mp)

typedef struct packed
{
  // Base address for traps
  logic [61:0] base;
  // Trap Mode
  //   00 - Direct, all exceptions set pc to BASE
  //   01 - Vectored, interrupts set pc to BASE+4xcause
  logic [1:0]  mode;
}  rv64_mtvec_s;

typedef struct packed
{
  logic [38:0] base;
}  bp_mtvec_s;

`define bp_mtvec_width ($bits(bp_mtvec_s))

`define compress_mtvec_s(data_cast_mp) \
  bp_mtvec_s'{base: data_cast_mp.base[0+:39]}

`define decompress_mtvec_s(data_comp_mp) \
  rv64_mtvec_s'{base : {22'h0, data_comp_mp.base} \
                ,mode: 2'b00                      \
                }

typedef struct packed
{
  logic [51:0] wpri1;
  // M-mode External Interrupt Pending
  logic        meip;
  logic        wpri2;
  // S-mode External Interrupt Pending
  logic        seip;
  // U-mode External Interrupt Pending
  logic        ueip;
  // M-mode Timer Interrupt Pending
  logic        mtip;
  logic        wpri3;
  // S-mode Timer Interrupt Pending
  logic        stip;
  // U-mode Timer Interrupt Pending
  logic        utip;
  // M-mode Software Interrupt Pending
  logic        msip;
  logic        wpri4;
  // S-mode Software Interrupt Pending
  logic        ssip;
  // U-mode Software Interrupt Pending
  logic        usip;
}  rv64_mip_s;

typedef struct packed
{
  logic meip;
  logic seip;
  logic ueip;

  logic mtip;
  logic stip;
  logic utip;

  logic msip;
  logic ssip;
  logic usip;
}   bp_mip_s;

`define compress_mip_s(data_cast_mp) \
  bp_mip_s'{meip : data_cast_mp.meip \
            ,seip: data_cast_mp.seip \
            ,ueip: data_cast_mp.ueip \
                                     \
            ,mtip: data_cast_mp.mtip \
            ,stip: data_cast_mp.stip \
            ,utip: data_cast_mp.utip \
                                     \
            ,msip: data_cast_mp.msip \
            ,ssip: data_cast_mp.ssip \
            ,usip: data_cast_mp.usip \
            }

`define decompress_mip_s(data_comp_mp) \
  rv64_mip_s'{meip : data_comp_mp.meip \
              ,seip: data_comp_mp.seip \
              ,ueip: data_comp_mp.ueip \
                                       \
              ,mtip: data_comp_mp.mtip \
              ,stip: data_comp_mp.stip \
              ,utip: data_comp_mp.utip \
                                       \
              ,msip: data_comp_mp.msip \
              ,ssip: data_comp_mp.ssip \
              ,usip: data_comp_mp.usip \
              ,default: '0             \
              }

typedef struct packed
{
  logic [51:0] wpri1;
  // M-mode External Interrupt Enable
  logic        meie;
  logic        wpri2;
  // S-mode External Interrupt Enable
  logic        seie;
  // U-mode External Interrupt Enable
  logic        ueie;
  // M-mode Timer Interrupt Enable
  logic        mtie;
  logic        wpri3;
  // S-mode Timer Interrupt Enable
  logic        stie;
  // U-mode Timer Interrupt Enable
  logic        utie;
  // M-mode Software Interrupt Enable
  logic        msie;
  logic        wpri4;
  // S-mode Software Interrupt Enable
  logic        ssie;
  // U-mode Software Interrupt Enable
  logic        usie;
}  rv64_mie_s;

typedef struct packed 
{
  logic meie;
  logic seie;
  logic ueie;

  logic mtie;
  logic stie;
  logic utie;

  logic msie;
  logic ssie;
  logic usie;
}  bp_mie_s;

`define compress_mie_s(data_cast_mp) \
  bp_mie_s'{meie : data_cast_mp.meie \
            ,seie: data_cast_mp.seie \
            ,ueie: data_cast_mp.ueie \
                                     \
            ,mtie: data_cast_mp.mtie \
            ,stie: data_cast_mp.stie \
            ,utie: data_cast_mp.utie \
                                     \
            ,msie: data_cast_mp.msie \
            ,ssie: data_cast_mp.ssie \
            ,usie: data_cast_mp.usie \
            }

`define decompress_mie_s(data_comp_mp) \
  rv64_mie_s'{meie : data_comp_mp.meie \
              ,seie: data_comp_mp.seie \
              ,ueie: data_comp_mp.ueie \
                                       \
              ,mtie: data_comp_mp.mtie \
              ,stie: data_comp_mp.stie \
              ,utie: data_comp_mp.utie \
                                       \
              ,msie: data_comp_mp.msie \
              ,ssie: data_comp_mp.ssie \
              ,usie: data_comp_mp.usie \
              ,default: '0             \
              }

typedef logic [63:0] rv64_mtval_s;
typedef logic [38:0] bp_mtval_s;

`define compress_mtval_s(data_cast_mp) \
  data_cast_mp[0+:39]

`define decompress_mtval_s(data_comp_mp) \
  64'(data_comp_mp)

typedef logic [63:0] rv64_mepc_s;
typedef logic [38:0] bp_mepc_s;

`define bp_mepc_width ($bits(bp_mepc_s))

`define compress_mepc_s(data_cast_mp) \
  data_cast_mp[0+:39]

`define decompress_mepc_s(data_comp_mp) \
  64'(data_comp_mp)

typedef struct packed
{
  // Locked - writes to this pmpcfg and corresponding pmpaddr are ignored
  logic          l;
  logic [1:0] wpri;
  // Address Matching Mode
  //  00 - Off  , Null region (disabled)
  //  01 - TOR  , Top of range (pmpaddr[i-1] <= a < pmpaddr[i], or 0 <= a < pmpaddr[0])
  //  10 - NA4  , Naturally aligned four-byte region 
  //  11 - NAPOT, Naturally aligned power-of-two region
  logic [1:0]    a;
  // Execute permissions
  logic          x;
  // Write permissions
  logic          w;
  // Read permissions
  logic          r;
}  rv64_pmpcfg_entry_s;

typedef struct packed
{
  rv64_pmpcfg_entry_s [7:0] pmpcfg;
}  rv64_pmpcfg_s;
typedef rv64_pmpcfg_s rv64_pmpcfg0_s;
typedef rv64_pmpcfg_s rv64_pmpcfg1_s;

typedef struct packed
{
  rv64_pmpcfg_entry_s [3:0] pmpcfg;
}  bp_pmpcfg_s;

typedef bp_pmpcfg_s bp_pmpcfg0_s;

`define compress_pmpcfg_s(data_cast_mp) \
  bp_pmpcfg_s'{pmpcfg: data_cast_mp.pmpcfg[0+:4]}

`define decompress_pmpcfg_s(data_comp_mp) \
  rv64_pmpcfg_s'{pmpcfg: ($bits(rv64_pmpcfg_entry_s)*8)'(data_comp_mp.pmpcfg)}

`define compress_pmpcfg0_s(data_cast_mp) `compress_pmpcfg_s(data_cast_mp)
`define compress_pmpcfg1_s(data_cast_mp) `compress_pmpcfg_s(data_cast_mp)
`define decompress_pmpcfg0_s(data_comp_mp) `decompress_pmpcfg_s(data_comp_mp)
`define decompress_pmpcfg1_s(data_comp_mp) `decompress_pmpcfg_s(data_comp_mp)

typedef struct packed
{
  logic [9:0]  wpri;
  logic [53:0] addr_55_2;
}  rv64_pmpaddr_s;

typedef struct packed
{
  logic [36:0] addr_38_2;
}  bp_pmpaddr_s;

`define compress_pmpaddr_s(data_cast_mp) \
  bp_pmpaddr_s'{addr_38_2: data_cast_mp.addr_55_2[0+:37]}

`define decompress_pmpaddr_s(data_comp_mp) \
  rv64_pmpaddr_s'{addr_55_2: 54'(data_comp_mp.addr_38_2) \
                  ,default: '0                           \
                  }

typedef struct packed
{
  logic        _interrupt;
  logic [62:0] ecode;
}  rv64_mcause_s;

typedef struct packed
{
  logic       _interrupt;
  logic [3:0] ecode;
}  bp_mcause_s;

`define compress_mcause_s(data_cast_mp) \
  bp_mcause_s'{_interrupt: data_cast_mp._interrupt \
               ,ecode: data_cast_mp.ecode[0+:4]  \
               }

`define decompress_mcause_s(data_comp_mp) \
  rv64_mcause_s'{_interrupt: data_comp_mp._interrupt \
                 ,ecode: 63'(data_comp_mp.ecode)   \
                 }

typedef logic [63:0] rv64_mcounter_s;
typedef logic [47:0] bp_mcounter_s;

`define compress_mcounter_s(data_cast_mp) \
  bp_mcounter_s'(data_cast_mp[0+:48])

`define decompress_mcounter_s(data_comp_mp) \
  rv64_mcounter_s'(data_comp_mp)

typedef rv64_mcounter_s rv64_mcycle_s;
typedef rv64_mcounter_s rv64_minstret_s;

typedef bp_mcounter_s bp_mcycle_s;
typedef bp_mcounter_s bp_minstret_s;

`define compress_mcycle_s(data_cast_mp)   `compress_mcounter_s(data_cast_mp)
`define compress_minstret_s(data_cast_mp) `compress_mcounter_s(data_cast_mp)

`define decompress_mcycle_s(data_comp_mp) `decompress_mcounter_s(data_comp_mp)
`define decompress_minstret_s(data_comp_mp) `decompress_mcounter_s(data_comp_mp)

`endif


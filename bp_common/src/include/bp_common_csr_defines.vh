`ifndef BP_COMMON_CSR_DEFINES_VH
`define BP_COMMON_CSR_DEFINES_VH

`define PRIV_MODE_M 2'b11
`define PRIV_MODE_S 2'b01
`define PRIV_MODE_U 1'b0

`define CSR_ADDR_USTATUS       12'h000
`define CSR_ADDR_UIE           12'h004
`define CSR_ADDR_UTVEC         12'h005

`define CSR_ADDR_USCRATCH      12'h040
`define CSR_ADDR_UEPC          12'h041
`define CSR_ADDR_UCAUSE        12'h042
`define CSR_ADDR_UTVAL         12'h043
`define CSR_ADDR_UIP           12'h044

`define CSR_ADDR_FFLAGS        12'h001
`define CSR_ADDR_FRM           12'h002
`define CSR_ADDR_FCSR          12'h003

`define CSR_ADDR_CYCLE         12'hc00
`define CSR_ADDR_TIME          12'hc01
`define CSR_ADDR_INSTRET       12'hc02
`define CSR_ADDR_HPMCOUNTER3   12'hc03
`define CSR_ADDR_HPMCOUNTER4   12'hc04
`define CSR_ADDR_HPMCOUNTER5   12'hc05
`define CSR_ADDR_HPMCOUNTER6   12'hc06
`define CSR_ADDR_HPMCOUNTER7   12'hc07
`define CSR_ADDR_HPMCOUNTER8   12'hc08
`define CSR_ADDR_HPMCOUNTER9   12'hc09
`define CSR_ADDR_HPMCOUNTER10  12'hc0a
`define CSR_ADDR_HPMCOUNTER11  12'hc0b
`define CSR_ADDR_HPMCOUNTER12  12'hc0c
`define CSR_ADDR_HPMCOUNTER13  12'hc0d
`define CSR_ADDR_HPMCOUNTER14  12'hc0e
`define CSR_ADDR_HPMCOUNTER15  12'hc0f
`define CSR_ADDR_HPMCOUNTER16  12'hc10
`define CSR_ADDR_HPMCOUNTER17  12'hc11
`define CSR_ADDR_HPMCOUNTER18  12'hc12
`define CSR_ADDR_HPMCOUNTER19  12'hc13
`define CSR_ADDR_HPMCOUNTER20  12'hc14
`define CSR_ADDR_HPMCOUNTER21  12'hc15
`define CSR_ADDR_HPMCOUNTER22  12'hc16
`define CSR_ADDR_HPMCOUNTER23  12'hc17
`define CSR_ADDR_HPMCOUNTER24  12'hc18
`define CSR_ADDR_HPMCOUNTER25  12'hc19
`define CSR_ADDR_HPMCOUNTER26  12'hc1a
`define CSR_ADDR_HPMCOUNTER27  12'hc1b
`define CSR_ADDR_HPMCOUNTER28  12'hc1c
`define CSR_ADDR_HPMCOUNTER29  12'hc1d
`define CSR_ADDR_HPMCOUNTER30  12'hc1e
`define CSR_ADDR_HPMCOUNTER31  12'hc1f

`define CSR_ADDR_SSTATUS       12'h100
`define CSR_ADDR_SEDELEG       12'h102
`define CSR_ADDR_SIDELEG       12'h103
`define CSR_ADDR_SIE           12'h104
`define CSR_ADDR_STVEC         12'h105
`define CSR_ADDR_SCOUNTEREN    12'h106

`define CSR_ADDR_SSCRATCH      12'h140
`define CSR_ADDR_SEPC          12'h141
`define CSR_ADDR_SCAUSE        12'h142
`define CSR_ADDR_STVAL         12'h143
`define CSR_ADDR_SIP           12'h144

`define CSR_ADDR_SATP          12'h180

`define CSR_ADDR_MVENDORID     12'hf11
`define CSR_ADDR_MARCHID       12'hf12
`define CSR_ADDR_MIMPID        12'hf13
`define CSR_ADDR_MHARTID       12'hf14

`define CSR_ADDR_MSTATUS       12'h300
`define CSR_ADDR_MISA          12'h301
`define CSR_ADDR_MEDELEG       12'h302
`define CSR_ADDR_MIDELEG       12'h303
`define CSR_ADDR_MIE           12'h304
`define CSR_ADDR_MTVEC         12'h305
`define CSR_ADDR_MCOUNTEREN    12'h306

`define CSR_ADDR_MSCRATCH      12'h340
`define CSR_ADDR_MEPC          12'h341
`define CSR_ADDR_MCAUSE        12'h342
`define CSR_ADDR_MTVAL         12'h343
`define CSR_ADDR_MIP           12'h344

`define CSR_ADDR_PMPCFG0       12'h3a0
`define CSR_ADDR_PMPCFG2       12'h3a2
`define CSR_ADDR_PMPADDR0      12'h3b0
`define CSR_ADDR_PMPADDR1      12'h3b1
`define CSR_ADDR_PMPADDR2      12'h3b2
`define CSR_ADDR_PMPADDR3      12'h3b3
`define CSR_ADDR_PMPADDR4      12'h3b4
`define CSR_ADDR_PMPADDR5      12'h3b5
`define CSR_ADDR_PMPADDR6      12'h3b6
`define CSR_ADDR_PMPADDR7      12'h3b7
`define CSR_ADDR_PMPADDR8      12'h3b8
`define CSR_ADDR_PMPADDR9      12'h3b9
`define CSR_ADDR_PMPADDR10     12'h3ba
`define CSR_ADDR_PMPADDR11     12'h3bb
`define CSR_ADDR_PMPADDR12     12'h3bc
`define CSR_ADDR_PMPADDR13     12'h3bd
`define CSR_ADDR_PMPADDR14     12'h3be
`define CSR_ADDR_PMPADDR15     12'h3bf

`define CSR_ADDR_MCYCLE        12'hb00
`define CSR_ADDR_MINSTRET      12'hb02
`define CSR_ADDR_MHPMCOUNTER3  12'hb03
`define CSR_ADDR_MHPMCOUNTER4  12'hb04
`define CSR_ADDR_MHPMCOUNTER5  12'hb05
`define CSR_ADDR_MHPMCOUNTER6  12'hb06
`define CSR_ADDR_MHPMCOUNTER7  12'hb07
`define CSR_ADDR_MHPMCOUNTER8  12'hb08
`define CSR_ADDR_MHPMCOUNTER9  12'hb09
`define CSR_ADDR_MHPMCOUNTER10 12'hb0a
`define CSR_ADDR_MHPMCOUNTER11 12'hb0b
`define CSR_ADDR_MHPMCOUNTER12 12'hb0c
`define CSR_ADDR_MHPMCOUNTER13 12'hb0d
`define CSR_ADDR_MHPMCOUNTER14 12'hb0e
`define CSR_ADDR_MHPMCOUNTER15 12'hb0f
`define CSR_ADDR_MHPMCOUNTER16 12'hb10
`define CSR_ADDR_MHPMCOUNTER17 12'hb11
`define CSR_ADDR_MHPMCOUNTER18 12'hb12
`define CSR_ADDR_MHPMCOUNTER19 12'hb13
`define CSR_ADDR_MHPMCOUNTER20 12'hb14
`define CSR_ADDR_MHPMCOUNTER21 12'hb15
`define CSR_ADDR_MHPMCOUNTER22 12'hb16
`define CSR_ADDR_MHPMCOUNTER23 12'hb17
`define CSR_ADDR_MHPMCOUNTER24 12'hb18
`define CSR_ADDR_MHPMCOUNTER25 12'hb19
`define CSR_ADDR_MHPMCOUNTER26 12'hb1a
`define CSR_ADDR_MHPMCOUNTER27 12'hb1b
`define CSR_ADDR_MHPMCOUNTER28 12'hb1c
`define CSR_ADDR_MHPMCOUNTER29 12'hb1d
`define CSR_ADDR_MHPMCOUNTER30 12'hb1e
`define CSR_ADDR_MHPMCOUNTER31 12'hb1f

`define CSR_ADDR_MCOUNTINHIBIT 12'h320
`define CSR_ADDR_MHPMEVENT3    12'h323
`define CSR_ADDR_MHPMEVENT4    12'h324
`define CSR_ADDR_MHPMEVENT5    12'h325
`define CSR_ADDR_MHPMEVENT6    12'h326
`define CSR_ADDR_MHPMEVENT7    12'h327
`define CSR_ADDR_MHPMEVENT8    12'h328
`define CSR_ADDR_MHPMEVENT9    12'h329
`define CSR_ADDR_MHPMEVENT10   12'h32a
`define CSR_ADDR_MHPMEVENT11   12'h32b
`define CSR_ADDR_MHPMEVENT12   12'h32c
`define CSR_ADDR_MHPMEVENT13   12'h32d
`define CSR_ADDR_MHPMEVENT14   12'h32e
`define CSR_ADDR_MHPMEVENT15   12'h32f
`define CSR_ADDR_MHPMEVENT16   12'h330
`define CSR_ADDR_MHPMEVENT17   12'h331
`define CSR_ADDR_MHPMEVENT18   12'h332
`define CSR_ADDR_MHPMEVENT19   12'h333
`define CSR_ADDR_MHPMEVENT20   12'h334
`define CSR_ADDR_MHPMEVENT21   12'h335
`define CSR_ADDR_MHPMEVENT22   12'h336
`define CSR_ADDR_MHPMEVENT23   12'h337
`define CSR_ADDR_MHPMEVENT24   12'h338
`define CSR_ADDR_MHPMEVENT25   12'h339
`define CSR_ADDR_MHPMEVENT26   12'h33a
`define CSR_ADDR_MHPMEVENT27   12'h33b
`define CSR_ADDR_MHPMEVENT28   12'h33c
`define CSR_ADDR_MHPMEVENT29   12'h33d
`define CSR_ADDR_MHPMEVENT30   12'h33e
`define CSR_ADDR_MHPMEVENT31   12'h33f

`define CSR_ADDR_TSELECT       12'h7a0
`define CSR_ADDR_TDATA1        12'h7a1
`define CSR_ADDR_TDATA2        12'h7a2
`define CSR_ADDR_TDATA3        12'h7a3

`define CSR_ADDR_DCSR          12'h7b0
`define CSR_ADDR_DPC           12'h7b1
`define CSR_ADDR_DSCRATCH0     12'h7b2
`define CSR_ADDR_DSCRATCH1     12'h7b3

typedef struct packed
{
  // Base address for traps
  logic [61:0] base;
  // Trap Mode
  //   00 - Direct, all exceptions set pc to BASE
  //   01 - Vectored, interrupts set pc to BASE+4xcause
  logic [1:0]  mode;
}  rv64_stvec_s;

typedef struct packed
{
  logic [37:0] addr_39_2;
}  bp_stvec_s;

`define bp_stvec_width ($bits(bp_stvec_s))

`define compress_stvec_s(data_cast_mp) \
  '{addr_39_2: data_cast_mp.base[0+:38]}

`define decompress_stvec_s(data_comp_mp) \
  '{base : {24'h0, data_comp_mp.addr_39_2} \
    ,mode: 2'b00                           \
    }

typedef struct packed
{
  logic [31:3] hpm;
  logic        ir;
  logic        cy;
}  rv64_scounteren_s;

typedef struct packed
{
  logic ir;
  logic cy;
}  bp_scounteren_s;

`define bp_scounteren_width ($bits(bp_scounteren_s))

`define compress_scounteren_s(data_cast_mp) \
  '{ir : data_cast_mp.ir \
    ,cy: data_cast_mp.cy \
    };

`define decompress_scounteren_s(data_comp_mp) \
  '{ir : data_comp_mp.ir \
    ,cy: data_comp_mp.cy \
    ,default: '0         \
    };

typedef logic [63:0] rv64_sscratch_s;
typedef logic [63:0] bp_sscratch_s;

`define compress_sscratch_s(data_cast_mp) \
  data_cast_mp[0+:64]

`define decompress_sscratch_s(data_comp_mp) \
  64'(data_comp_mp)

typedef logic [63:0] rv64_sepc_s;
typedef logic [38:0] bp_sepc_s;

`define bp_sepc_width ($bits(bp_sepc_s))

`define compress_sepc_s(data_cast_mp) \
  bp_sepc_s'(data_cast_mp[0+:39])

`define decompress_sepc_s(data_comp_mp) \
  64'($signed(data_comp_mp))

typedef struct packed
{
  logic        _interrupt;
  logic [62:0] ecode;
}  rv64_scause_s;

typedef struct packed
{
  logic       _interrupt;
  logic [3:0] ecode;
}  bp_scause_s;

`define compress_scause_s(data_cast_mp) \
  '{_interrupt: data_cast_mp._interrupt \
    ,ecode: data_cast_mp.ecode[0+:4]    \
    }

`define decompress_scause_s(data_comp_mp) \
  '{_interrupt: data_comp_mp._interrupt \
    ,ecode: 63'(data_comp_mp.ecode)     \
    }

typedef logic [63:0] rv64_stval_s;
typedef logic [39:0] bp_stval_s;

`define compress_stval_s(data_cast_mp) \
  bp_stval_s'(data_cast_mp[0+:40])

`define decompress_stval_s(data_comp_mp) \
  64'($signed(data_comp_mp))

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
  // TODO: Generate this based on vaddr
  logic [27:0] ppn;
}  bp_satp_s;

`define bp_satp_width ($bits(bp_satp_s))

`define compress_satp_s(data_cast_mp) \
  '{mode: data_cast_mp.mode[3]   \
    ,ppn: data_cast_mp.ppn[27:0] \
    }

`define decompress_satp_s(data_comp_mp) \
  '{mode: {data_comp_mp.mode, 3'b000} \
    ,ppn: {16'h0, data_comp_mp.ppn}   \
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
  logic       tsr;
  logic       tw;
  logic       tvm;

  logic       mxr;
  logic       sum;
  logic       mprv;

  logic [1:0] fs;

  logic [1:0] mpp;
  logic       spp;

  logic       mpie;
  logic       spie;

  logic       mie;
  logic       sie;
}  bp_mstatus_s;

`define compress_mstatus_s(data_cast_mp) \
  '{tsr  : data_cast_mp.tsr  \
    ,tw  : data_cast_mp.tw   \
    ,tvm : data_cast_mp.tvm  \
    ,mxr : data_cast_mp.mxr  \
    ,sum : data_cast_mp.sum  \
    ,mprv: data_cast_mp.mprv \
    ,fs  : data_cast_mp.fs   \
    ,mpp : data_cast_mp.mpp  \
    ,spp : data_cast_mp.spp  \
    ,mpie: data_cast_mp.mpie \
    ,spie: data_cast_mp.spie \
    ,mie : data_cast_mp.mie  \
    ,sie : data_cast_mp.sie  \
    }

`define decompress_mstatus_s(data_comp_mp) \
  '{sd   : (data_comp_mp.fs == 2'b11) \
    ,sxl : 2'b10             \
    ,uxl : 2'b10             \
    ,tsr : data_comp_mp.tsr  \
    ,tvm : data_comp_mp.tvm  \
    ,tw  : data_comp_mp.tw   \
    ,mxr : data_comp_mp.mxr  \
    ,sum : data_comp_mp.sum  \
    ,mprv: data_comp_mp.mprv \
    ,fs  : data_comp_mp.fs   \
    ,mpp : data_comp_mp.mpp  \
    ,spp : data_comp_mp.spp  \
    ,mpie: data_comp_mp.mpie \
    ,spie: data_comp_mp.spie \
    ,mie : data_comp_mp.mie  \
    ,sie : data_comp_mp.sie  \
    ,default: '0             \
    }

typedef logic [63:0] rv64_medeleg_s;
// Hardcode exception 10, 11, 14, 16+ to zero
typedef struct packed
{
  logic [15:15] deleg_15;
  logic [13:12] deleg_13to12;
  logic [ 9: 0] deleg_9to0;
}  bp_medeleg_s;

`define compress_medeleg_s(data_cast_mp) \
  '{deleg_15     : data_cast_mp[15]    \
    ,deleg_13to12: data_cast_mp[13:12] \
    ,deleg_9to0  : data_cast_mp[9:0]   \
    };

`define decompress_medeleg_s(data_comp_mp) \
  rv64_medeleg_s'({data_comp_mp.deleg_15      \
                   ,1'b0                      \
                   ,data_comp_mp.deleg_13to12 \
                   ,2'b0                      \
                   ,data_comp_mp.deleg_9to0   \
                   });

typedef struct packed
{
  logic [51:0] wpri1;
  // M-mode External Interrupt Delegation
  logic        mei;
  logic        wpri2;
  // S-mode External Interrupt Delegation
  logic        sei;
  // U-mode External Interrupt Delegation
  logic        uei;
  // M-mode Timer Interrupt Delegation
  logic        mti;
  logic        wpri3;
  // S-mode Timer Interrupt Delegation
  logic        sti;
  // U-mode Timer Interrupt Delegation
  logic        uti;
  // M-mode Software Interrupt Delegation
  logic        msi;
  logic        wpri4;
  // S-mode Software Interrupt Delegation
  logic        ssi;
  // U-mode Software Interrupt Delegation
  logic        usi;
}  rv64_mideleg_s;

typedef struct packed
{
  logic sei;
  logic sti;
  logic ssi;
}  bp_mideleg_s;

`define compress_mideleg_s(data_cast_mp) \
  '{sei : data_cast_mp.sei \
    ,sti: data_cast_mp.sti \
    ,ssi: data_cast_mp.ssi \
    }

`define decompress_mideleg_s(data_comp_mp) \
  '{sei : data_comp_mp.sei \
    ,sti: data_comp_mp.sti \
    ,ssi: data_comp_mp.ssi \
    ,default: '0           \
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

  logic mtie;
  logic stie;

  logic msie;
  logic ssie;
}  bp_mie_s;

`define compress_mie_s(data_cast_mp) \
  '{meie : data_cast_mp.meie \
    ,seie: data_cast_mp.seie \
                             \
    ,mtie: data_cast_mp.mtie \
    ,stie: data_cast_mp.stie \
                             \
    ,msie: data_cast_mp.msie \
    ,ssie: data_cast_mp.ssie \
    }

`define decompress_mie_s(data_comp_mp) \
  '{meie : data_comp_mp.meie \
    ,seie: data_comp_mp.seie \
                             \
    ,mtie: data_comp_mp.mtie \
    ,stie: data_comp_mp.stie \
                             \
    ,msie: data_comp_mp.msie \
    ,ssie: data_comp_mp.ssie \
    ,default: '0             \
    }

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
  logic [37:0] addr_39_2;
}  bp_mtvec_s;

`define bp_mtvec_width ($bits(bp_mtvec_s))

`define compress_mtvec_s(data_cast_mp) \
  '{addr_39_2: data_cast_mp.base[0+:38]}

`define decompress_mtvec_s(data_comp_mp) \
  '{base : {24'h0, data_comp_mp.addr_39_2} \
    ,mode: 2'b00                           \
    }

typedef struct packed
{
  logic [31:3] hpm;
  logic        ir;
  logic        tm;
  logic        cy;
}  rv64_mcounteren_s;

typedef struct packed
{
  logic ir;
  logic cy;
}  bp_mcounteren_s;

`define bp_mcounteren_width ($bits(bp_mcounteren_s))

`define compress_mcounteren_s(data_cast_mp) \
  '{ir : data_cast_mp.ir \
    ,cy: data_cast_mp.cy \
    };

`define decompress_mcounteren_s(data_comp_mp) \
  '{ir : data_comp_mp.ir \
    ,cy: data_comp_mp.cy \
    ,default: '0         \
    };

typedef logic [63:0] rv64_mscratch_s;
typedef logic [63:0] bp_mscratch_s;

`define compress_mscratch_s(data_cast_mp) \
  data_cast_mp[0+:64]

`define decompress_mscratch_s(data_comp_mp) \
  64'(data_comp_mp)

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

  logic mtip;
  logic stip;

  logic msip;
  logic ssip;
}   bp_mip_s;

`define compress_mip_s(data_cast_mp) \
  '{meip : data_cast_mp.meip \
    ,seip: data_cast_mp.seip \
                             \
    ,mtip: data_cast_mp.mtip \
    ,stip: data_cast_mp.stip \
                             \
    ,msip: data_cast_mp.msip \
    ,ssip: data_cast_mp.ssip \
    }

`define decompress_mip_s(data_comp_mp) \
  '{meip : data_comp_mp.meip \
    ,seip: data_comp_mp.seip \
                             \
    ,mtip: data_comp_mp.mtip \
    ,stip: data_comp_mp.stip \
                             \
    ,msip: data_comp_mp.msip \
    ,ssip: data_comp_mp.ssip \
    ,default: '0             \
    }

typedef logic [63:0] rv64_mtval_s;
typedef logic [39:0] bp_mtval_s;

`define compress_mtval_s(data_cast_mp) \
  bp_mtval_s'(data_cast_mp[0+:40])

`define decompress_mtval_s(data_comp_mp) \
  64'($signed(data_comp_mp))

typedef logic [63:0] rv64_mepc_s;
typedef logic [38:0] bp_mepc_s;

`define compress_mepc_s(data_cast_mp) \
  bp_mepc_s'(data_cast_mp[0+:39])

`define decompress_mepc_s(data_comp_mp) \
  64'($signed(data_comp_mp))

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
  '{pmpcfg: data_cast_mp.pmpcfg[0+:4]}

`define decompress_pmpcfg_s(data_comp_mp) \
  '{pmpcfg: ($bits(rv64_pmpcfg_entry_s)*8)'(data_comp_mp.pmpcfg)}

`define compress_pmpcfg0_s(data_cast_mp) `compress_pmpcfg_s(data_cast_mp)
`define compress_pmpcfg1_s(data_cast_mp) `compress_pmpcfg_s(data_cast_mp)
`define decompress_pmpcfg0_s(data_comp_mp) `decompress_pmpcfg_s(data_comp_mp)
`define decompress_pmpcfg1_s(data_comp_mp) `decompress_pmpcfg_s(data_comp_mp)

typedef struct packed
{
  logic [9:0]  warl;
  logic [53:0] addr_55_2;
}  rv64_pmpaddr_s;

typedef rv64_pmpaddr_s rv64_pmpaddr0_s;
typedef rv64_pmpaddr_s rv64_pmpaddr1_s;
typedef rv64_pmpaddr_s rv64_pmpaddr2_s;
typedef rv64_pmpaddr_s rv64_pmpaddr3_s;

typedef struct packed
{
  logic [37:0] addr_39_2;
}  bp_pmpaddr_s;

typedef bp_pmpaddr_s bp_pmpaddr0_s;
typedef bp_pmpaddr_s bp_pmpaddr1_s;
typedef bp_pmpaddr_s bp_pmpaddr2_s;
typedef bp_pmpaddr_s bp_pmpaddr3_s;

`define compress_pmpaddr_s(data_cast_mp) \
  '{addr_39_2: data_cast_mp.addr_55_2[0+:38]}

`define decompress_pmpaddr_s(data_comp_mp) \
  '{addr_55_2: 54'(data_comp_mp.addr_39_2) \
    ,default: '0                           \
    }

`define compress_pmpaddr0_s(data_cast_mp) `compress_pmpaddr_s(data_cast_mp)
`define compress_pmpaddr1_s(data_cast_mp) `compress_pmpaddr_s(data_cast_mp)
`define compress_pmpaddr2_s(data_cast_mp) `compress_pmpaddr_s(data_cast_mp)
`define compress_pmpaddr3_s(data_cast_mp) `compress_pmpaddr_s(data_cast_mp)

`define decompress_pmpaddr0_s(data_cast_mp) `decompress_pmpaddr_s(data_cast_mp)
`define decompress_pmpaddr1_s(data_cast_mp) `decompress_pmpaddr_s(data_cast_mp)
`define decompress_pmpaddr2_s(data_cast_mp) `decompress_pmpaddr_s(data_cast_mp)
`define decompress_pmpaddr3_s(data_cast_mp) `decompress_pmpaddr_s(data_cast_mp)

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
  '{_interrupt: data_cast_mp._interrupt \
    ,ecode: data_cast_mp.ecode[0+:4]  \
    }

`define decompress_mcause_s(data_comp_mp) \
  '{_interrupt: data_comp_mp._interrupt \
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

typedef struct packed
{
  logic [31:3] hpm;
  logic        ir;
  logic        warl;
  logic        cy;
}  rv64_mcountinhibit_s;

typedef struct packed
{
  logic ir;
  logic cy;
}  bp_mcountinhibit_s;

`define compress_mcountinhibit_s(data_cast_mp) \
  '{ir : data_cast_mp.ir \
    ,cy: data_cast_mp.cy \
    }

`define decompress_mcountinhibit_s(data_comp_mp) \
  '{ir : data_comp_mp.ir \
    ,cy: data_comp_mp.cy \
    ,default: '0         \
    }

typedef struct packed
{
  logic [23:0] warl;
  logic [2:0]  frm;
  logic [4:0]  fflags;
}  rv64_fcsr_s;

typedef struct packed
{
  logic [2:0] frm;
  logic [4:0] fflags;
}  bp_fcsr_s;

`define compress_fcsr_s(data_cast_mp) \
  '{frm    : data_cast_mp.frm    \
    ,fflags: data_cast_mp.fflags \
    }

`define decompress_fcsr_s(data_comp_mp) \
  '{frm     : data_comp_mp.frm    \
    ,fflags : data_comp_mp.fflags \
    ,default: '0                  \
    }

typedef struct packed
{
  // Debugger version
  //   0 : No external debug support
  //   4 : External debug support ala RISC-V Debug Spec
  //   15: Non-conformant RISC-V debug spec
  logic [3:0]  xdebugver;
  logic [11:0] reserved1;
  // Ebreak M-mode behavior
  //   0 : behave normally
  //   1 : ebreak in M enters Debug Mode
  logic        ebreakm;
  logic        reserved2;
  // Ebreak S-mode behavior
  //   0 : behave normally
  //   1 : ebreak in S enters Debug Mode
  logic        ebreaks;
  // Ebreak U-mode behavior
  //   0 : behave normally
  //   1 : ebreak in U enters Debug Mode
  logic        ebreaku;
  // Stepping Interrupt Enable
  //   0 : Interrupts are disabled during single stepping
  //   1 : Interrupts are enabled during single stepping
  logic        stepie;
  // Stop Counters
  //   0 : Increment counters while in Debug Mode
  //   1 : Don't increment counters while in Debug Mode or ebreak->Debug Mode
  logic        stopcount;
  // Stop Timers
  //   0 : Increment timers as usual
  //   1 : Don't increment timers in Debug Mode
  logic        stoptime;
  // Cause of Debug Mode entry
  //   1 : Ebreak was executed (priority 3)
  //   2 : Trigger Module caused a breakpoint exception  (priority 4)
  //   3 : Debugger requested entry using haltreq (priority 1)
  //   4 : Hart single stepped (priority 0)
  //   5*: Hart halted out of reset due to resethaltreq (priority 2)
  //         *Also legal to report 3
  logic [3:0]  cause;
  logic        reserved3;
  // MPRV Enable
  //   0 : MPRV is ignored in Debug Mode
  //   1 : MPRV is enabled in Debug Mode
  logic        mprven;
  // Non-Maskable-Interrupt Pending
  //   0 : No NMI pending
  //   1 : NMI pending
  logic        nmip;
  // Single Step Mode
  //   0 : Normal behavior during non-Debug Mode
  //   1 : Hart will only execute a single instruction and then enter Debug Mode.
  //         If the instruction does not complete due to execption, hart enters
  //         Debug Mode after setting exception registers.
  logic        step;
  // Privilege mode
  //   The privilege level the hart was operating in prior to Debug Mode entry
  //   0 : U-mode
  //   1 : S-mode
  //   3 : M-mode
  logic [1:0]  prv;
}  rv64_dcsr_s;

typedef struct packed
{
  logic       ebreakm;
  logic       ebreaks;
  logic       ebreaku;
  logic       stepie;
  logic [3:0] cause;
  logic [1:0] prv;
  logic       step;
}  bp_dcsr_s;

`define compress_dcsr_s(data_cast_mp) \
  '{ebreakm : data_cast_mp.ebreakm \
    ,ebreaks: data_cast_mp.ebreaks \
    ,ebreaku: data_cast_mp.ebreaku \
    ,stepie : data_cast_mp.stepie  \
    ,cause  : data_cast_mp.cause   \
    ,prv    : data_cast_mp.prv     \
    ,step   : data_cast_mp.step    \
    }

`define decompress_dcsr_s(data_comp_mp) \
  '{xdebugver : 4'd4                  \
    ,ebreakm  : data_comp_mp.ebreakm  \
    ,ebreaks  : data_comp_mp.ebreakm  \
    ,ebreaku  : data_comp_mp.ebreakm  \
    ,stepie   : data_comp_mp.stepie   \
    ,stopcount: 1'b0                  \
    ,stoptime : 1'b0                  \
    ,cause    : data_comp_mp.cause    \
    ,mprven   : 1'b1                  \
    ,nmip     : 1'b0                  \
    ,step     : data_comp_mp.step     \
    ,prv      : data_comp_mp.prv      \
    ,default  : '0                    \
    }

typedef logic [63:0] rv64_dpc_s;
typedef logic [38:0] bp_dpc_s;

`define compress_dpc_s(data_cast_mp) \
  bp_dpc_s'(data_cast_mp[0+:39])

`define decompress_dpc_s(data_comp_mp) \
  64'($signed(data_comp_mp))

typedef logic [63:0] rv64_dscratch0_s;
typedef logic [63:0] bp_dscratch0_s;

`define compress_dscratch0_s(data_cast_mp) \
  data_cast_mp[0+:64]

`define decompress_dscratch0_s(data_comp_mp) \
  64'(data_comp_mp)

typedef logic [63:0] rv64_dscratch1_s;
typedef logic [63:0] bp_dscratch1_s;

`define compress_dscratch1_s(data_cast_mp) \
  data_cast_mp[0+:64]

`define decompress_dscratch1_s(data_comp_mp) \
  64'(data_comp_mp)

`define declare_csr(csr_name_mp) \
  /* verilator lint_off UNUSED */                                                               \
  rv64_``csr_name_mp``_s ``csr_name_mp``_li, ``csr_name_mp``_lo;                                \
  bp_``csr_name_mp``_s ``csr_name_mp``_n, ``csr_name_mp``_r;                                    \
  bsg_dff_reset                                                                                 \
   #(.width_p($bits(bp_``csr_name_mp``_s)))                                                     \
  ``csr_name_mp``_reg                                                                           \
    (.clk_i(clk_i), .reset_i(reset_i), .data_i(``csr_name_mp``_n), .data_o(``csr_name_mp``_r)); \
  assign ``csr_name_mp``_lo = `decompress_``csr_name_mp``_s(``csr_name_mp``_r);                 \
  assign ``csr_name_mp``_n  = `compress_``csr_name_mp``_s(``csr_name_mp``_li);                  \
  /* verilator lint_on UNUSED */

`endif



#ifndef BP_CCE_H
#define BP_CCE_H

#define BSG_SAFE_CLOG2(x) ((x <= 1) ? 1 : (int)(ceil(log2((double)x))))

#ifndef N_CCE
#define N_CCE 1
#define LG_N_CCE 1
#endif

#ifndef N_LCE
#define N_LCE 1
#define LG_N_LCE 1
#endif

#ifndef N_MEM
#define N_MEM 1
#define LG_N_MEM 1
#endif

#ifndef LCE_ASSOC
#define LCE_ASSOC 8
#define LG_LCE_ASSOC 3
#endif

#ifndef LCE_SETS
#define LCE_SETS 64
#define LG_LCE_SETS 6
#endif

#define SET_MASK ~((uint64_t)(~0) << LG_LCE_SETS)

#ifndef DATA_WIDTH_BYTES
#define DATA_WIDTH_BYTES 64
#define LG_DATA_WIDTH_BYTES 6
#endif
#define DATA_WIDTH_BITS (DATA_WIDTH_BYTES*8)

#ifndef NC_DATA_WIDTH
#define NC_DATA_WIDTH 64
#endif

#ifndef ADDR_WIDTH
#define ADDR_WIDTH 39
#endif

#define TAG_WIDTH (ADDR_WIDTH-LG_LCE_SETS-LG_DATA_WIDTH_BYTES)

#define TAG_MASK ~((uint64_t)(~0) << TAG_WIDTH)
#define N_WG (LCE_SETS/N_CCE)

#define COH_ST 8
#define LG_COH_ST 3
#define COH_ST_MASK ~((uint64_t)(~0) << LG_COH_ST)

#define WG_WIDTH N_LCE*LCE_ASSOC*(TAG_WIDTH+LG_COH_ST)

#define CFG_LINK_ADDR_WIDTH 16
#define CFG_LINK_DATA_WIDTH 32

#endif

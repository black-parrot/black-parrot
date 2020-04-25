#ifndef CCE_MICROCODE_H
#define CCE_MICROCODE_H

#ifndef BLOCK_SIZE
#define BLOCK_SIZE 64
#endif

#define SYNC 0
#define SC 1
#define INV 2
#define ST 3
#define DATA 4
#define STW 5
#define WB 6
#define ST_WB 7
#define TR 8
#define ST_TR 9
#define ST_TR_WB 10
#define UC_DATA 11
#define UCST 12

#define SYNC_ACK 0
#define INV_ACK 1
#define COH_ACK 2
#define RESP_WB 3
#define RESP_NULL_WB 4

#define COH_I 0
#define COH_S 1
#define COH_E 2
#define COH_F 3
#define COH_M 6
#define COH_O 7

#define MEM_CMD_RD 0
#define MEM_CMD_WR 1
#define MEM_CMD_UC_RD 2
#define MEM_CMD_UC_WR 3
#define MEM_CMD_PRE 4

#endif

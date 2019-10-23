#ifndef CCE_MICROCODE_H
#define CCE_MICROCODE_H

#ifndef BLOCK_SIZE
#define BLOCK_SIZE 64
#endif

#define SYNC 0
#define SC 1
#define TR 2
#define WB 3
#define ST 4
#define STW 5
#define INV 6
#define UCST 7
#define DATA 8
#define UC_DATA 9

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

#define MEM_CMD_REQ 0
#define MEM_CMD_WB 4

#define MEM_CMD_INV 0
#define MEM_CMD_FLUSH 1

#endif

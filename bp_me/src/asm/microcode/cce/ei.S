# This microcode uses EI protocol

#include "microcode.h"

# send sync messages
# r0 counts up from 0 number of sync messages sent
# r1 holds constant numLCE
# r3 stores the constant SYNC_ACK to check response ack type against
# The CCE waits for sync ack after each sync command. This avoids additional buffering being
# required in the CCE, at a small "performance" cost during startup
sync_init: movi 0 r0
movpg numLCE r1
movi SYNC_ACK r3
sync_top: bge r0 r1 finish_init
pushq lceCmd SYNC addr=0 lce=r0 way=0
popq lceResp r4
inc r0
bi sync_top

# set default value for mshr.next_coh_state
finish_init: movip COH_E cohSt

# Ready Routine
ready: wfq lceReq

# LCE Request Routine
lce_req: clm
poph lceReq r0
bf uncached_req ucf
rdp addr=req
bf ready pf
popq lceReq wp
rdw addr=req lce=req lru_way=lru
gad
# fall through

set_entry: wde addr=req lce=req way=lru state=nextCohSt

# Replacement Check Routine
replace_check: bfz transfer_check rf

# Replacement Routine
replace: pushq lceCmd WB addr=lru lce=req way=lru
# wait for writeback response
replacement_poph: poph lceResp r0
beqi r0 COH_ACK replacement_poph
bf complete_replacement nwbf
pushq memCmd MEM_CMD_WR addr=lru lce=req way=lru wp=1
complete_replacement: popq lceResp

# Transfer Check
transfer_check: bfz read_l2 cef cmf cof cff pt

# Transfer routine - other cache has block in E/M
# state for lceCmd will always come from nextCohSt
transfer: movis COH_I nextCohSt
pushq lceCmd ST addr=req lce=owner way=owner
wds addr=req lce=owner way=owner state=nextCohSt
movis COH_E nextCohSt
pushq lceCmd TR addr=req lce=owner way=owner
pushq lceCmd WB addr=req lce=owner way=owner
# wait for transfer WB response
transfer_poph: poph lceResp r0
beqi r0 COH_ACK transfer_poph
bf complete_transfer nwbf
pushq memCmd MEM_CMD_WR addr=req lce=owner way=owner wp=1
complete_transfer: popq lceResp
bi ready

# Read Line from L2 Routine
read_l2: pushq memCmd MEM_CMD_RD addr=req lce=req way=lru wp=1
bi ready

# Uncached Request Routine
uncached_req: bf uncached_store rqf
pushq memCmd MEM_CMD_UC_RD addr=req lce=req
popq lceReq
bi ready
uncached_store: pushq memCmd MEM_CMD_UC_WR addr=req lce=req
popq lceReq
bi ready


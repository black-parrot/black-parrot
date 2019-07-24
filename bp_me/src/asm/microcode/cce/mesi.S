# This microcode uses EI protocol with LCE transfers enabled
# The CCE process requests sequentially, and waits for all memory responses

#include "microcode.h"

# invalidate every entry in directory
rst_wg_init: movi N_WG r0
rst_wg_check: bz r0 set_clear_init
dec r0
rst_lce_init: movi N_LCE r1
rst_lce_check: bz r1 rst_wg_check
dec r1
rst_way_init: movi LCE_ASSOC r2
rst_way_check: bz r2 rst_lce_check
dec r2
wde r0 r1 r2 0 I
bi rst_way_check

# send set_clear messages
set_clear_init: movi 0 r0
movi N_LCE r1
lce_top: bge r0 r1 sync_init
# r2 = way group ID
movi 0 r2
movi N_WG r3
set_clear_top: bge r2 r3 lce_inc
pushq lceCmd SC r0 r2
inc r2
bi set_clear_top
lce_inc: inc r0
bi lce_top

# send sync messages
# r0 counts up from 0 number of sync messages sent
# r1 holds constant N_LCE
# r3 stores the constant SYNC_ACK to check response ack type against
# The CCE waits for sync ack after each sync command. This avoids additional buffering being
# required in the CCE, at a small "performance" cost during startup
sync_init: movi 0 r0
movi N_LCE r1
movi SYNC_ACK r3
sync_top: bge r0 r1 ready
pushq lceCmd SYNC r0
popq lceResp r4
bne r3 r4 error
inc r0
bi sync_top

# Ready Routine
ready: wfq lceReq lceResp
bqr lceResp resp_pop
bqr lceReq lce_req
stall

resp_pop: popq lceResp r4
movi COH_ACK r0
beq r0 r4 ready
# coming from the ready state, the CCE should only receive COH ack
bi error

# LCE Request Routine
lce_req: clm
poph lceReq
bf ucf uncached_req
rdp req
bf pf ready
popq lceReq
rdw req req
gad
# fall through

# Next Coherence State Routine
# write request means set to M, else check non-exclusive request
next_coh_state: bf rqf next_coh_set_m
# check non-exclusive request (read-only) set to S, else check if block cached
bf nerf next_coh_set_s
# block cached somewhere
bf cf next_coh_set_s
# invalidations not required, thus block not cache, set to E
next_coh_set_e: movi E nextCohSt
bi inv_check
next_coh_set_s: movi S nextCohSt
bi inv_check
next_coh_set_m: movi M nextCohSt
# fall through to inv_check

# Invalidation Check
inv_check: bfz if upgrade_check

# Invalidation Routine
invalidate: movi 0 r0
movi N_LCE r1
movi 0 r2
movi INV_ACK r3
inv_top: bge r0 r1 inv_ack_top
bz shHitr0 inv_inc_lce
beq reqLce r0 inv_inc_lce
inc r2
pushq lceCmd INV r0 req shWayR0
wds req r0 shWayR0 I
inv_inc_lce: inc r0
bi inv_top
inv_ack_top: bz r2 upgrade_check
# pop the lce response
inv_ack_pop: popq lceResp r4
# check the response type; if it is an invalidation, decrement the counter and continue looping
# non invalidation acks get popped, and then the PC jumps back to wait for invalidation acks
bne r3 r4 inv_ack_pop
dec r2
bi inv_ack_top

# Upgrade Check Routine
upgrade_check: bfz uf set_entry

# Upgrade Routine
upgrade: wds req req req nextCohSt
pushq lceCmd STW req req req
bi ready

# write directory entry before memory messages may occur
# next_coh_state is not saved/restored across memory access
set_entry: wde req req lru req nextCohSt

# Replacement Check Routine
replace_check: bfz rf transfer_check

# Replacement Routine
replace: pushq lceCmd WB req lru lru
poph lceResp r0
pushq memCmd MEM_CMD_WB lru
popq lceResp r0
# replacement done, explicitly set replacement flag to 0
sfz rf

# Transfer Check
transfer_check: bfz tf read_l2

# Transfer routine - other cache has block in E/M
transfer: pushq lceCmd ST req req lru
pushq lceCmd TR tr req tr
pushq lceCmd WB tr req tr
# wait for transfer WB response
poph lceResp r0
bf nwbf complete_nwb_transfer
# perform the transfer WB to mem
pushq memCmd MEM_CMD_WB req
popq lceResp r0
bi ready

# Null transfer writeback, pop the data response and the transfer ack
complete_nwb_transfer: popq lceResp r0
bi ready

# Read Line from L2 Routine
# TODO: move memory request earlier to hide some latency
read_l2: pushq memCmd
pushq lceCmd ST req req lru
bi ready

# Uncached Request Routine
# TODO: collapse, hardware detects if it is load/store for the memCmd based on rqf
# but, it might be better to change HW to require a command type and addr sel in ucode for every memCmd
uncached_req: popq lceReq
bf rqf uncached_store
pushq memCmd
bi ready
uncached_store: pushq memCmd
bi ready

error: stall

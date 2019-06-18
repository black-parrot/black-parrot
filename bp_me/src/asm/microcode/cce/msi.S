# This microcode uses EI protocol with LCE transfers enabled
# The CCE process requests sequentially, and waits for all memory responses

#include "microcode.h"

# Reset Routine
# clear pending bits for every way-group
rst_wdp_init: movi 0 r0
movi N_WG r1
rst_wdp_check: bge r0 r1 rst_wg_init
wdp r0 0
inc r0
bi rst_wdp_check

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
popq lceResp
bne r3 ackType error
inc r0
bi sync_top

# Ready Routine
# In ready state, the CCE can process lce responses, memory response, or new lce requests
ready: wfq lceReq memResp lceResp
bqr lceResp ack_pop
bqr memResp mem_resp
bqr lceReq lce_req
stall

ack_pop: popq lceResp
movi COH_ACK r0
beq r0 ackType ready
movi TR_ACK r1
beq r1 ackType ready
# coming from the ready state, the CCE should only receive COH or TR acks
bi error

# Memory Response Routine
# A memory response returns after a replacement writeback or a transfer writeback
mem_resp: popq memResp
bf rwbf transfer_check
bi ready

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
# write request means set to M, else read means set to S
next_coh_state: bf rqf next_coh_set_m
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
bz shR0 inv_inc_lce
beq reqLce r0 inv_inc_lce
inc r2
pushq lceCmd INV r0 req shWayR0
wds req r0 shWayR0 I
inv_inc_lce: inc r0
bi inv_top
inv_ack_top: bz r2 upgrade_check
# pop the lce response
inv_ack_pop: popq lceResp
# check the response type; if it is an invalidation, decrement the counter and continue looping
# non invalidation acks get popped, and then the PC jumps back to wait for invalidation acks
bne r3 ackType inv_ack_pop
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
poph lceDataResp
sf rwbf
pushq memDataCmd lru
popq lceDataResp
sfz rwbf
bi ready

# Transfer Check
transfer_check: bfz tf read_l2

# Transfer routine - other cache has block in E/M
transfer: pushq lceCmd ST req req lru
pushq lceCmd TR tr req tr
pushq lceCmd WB tr req tr
# wait for transfer WB response
poph lceDataResp
bf nwbf complete_nwb_transfer
# perform the transfer WB to mem
sfz rwbf
pushq memDataCmd req
popq lceDataResp
bi ready

# Null transfer writeback, pop the data response and the transfer ack
complete_nwb_transfer: popq lceDataResp
bi ready

# Read Line from L2 Routine
read_l2: wde req req lru req nextCohSt
pushq memCmd
pushq lceCmd ST req req lru
bi ready

# Uncached Request Routine
uncached_req: bf rqf uncached_store
pushq memCmd
bi ready
uncached_store: pushq memDataCmd req
popq memResp
pushq lceCmd UCST req req req
bi ready

error: stall

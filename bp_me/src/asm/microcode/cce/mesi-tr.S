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
sync_init: movi 0 r0
movi N_LCE r1
sync_top: bge r0 r1 ack_top
pushq lceCmd SYNC r0
inc r0
bi sync_top
ack_top: bz r0 ready
wfq lceResp
popq lceResp
dec r0
bi ack_top

# Ready Routine
ready: wfq lceReq
bqr lceReq lce_req
bi error

# LCE Request Routine
lce_req: popq lceReq
bf ucf uncached_req
rdp req
bf pf error
rdw req
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
inv_check: bf if invalidate
bi upgrade_check

# Invalidation Routine
invalidate: movi 0 r0
movi N_LCE r1
movi 0 r2
inv_top: bge r0 r1 inv_ack_top
bz shR0 inv_inc_lce
beq reqLce r0 inv_inc_lce
inc r2
pushq lceCmd INV r0 req shWayR0
wds req r0 shWayR0 I
inv_inc_lce: inc r0
bi inv_top
inv_ack_top: bz r2 inv_end
wfq lceResp
popq lceResp
# TODO: check ack_type
dec r2
bi inv_ack_top
inv_end: bi upgrade_check

# Upgrade Check Routine
upgrade_check: bf uf upgrade
bi replace_check

# Upgrade Routine
upgrade: wds req req req nextCohSt
pushq lceCmd STW req req req
wfq lceResp
popq lceResp
bi ready

# Replacement Check Routine
replace_check: bf rf replace
bi transfer_check

# Replacement Routine
replace: pushq lceCmd WB req lru lru
wfq lceDataResp
wdp req 1
sf rwbf
pushq memDataCmd lru
popq lceDataResp
sfz rwbf
wfq memResp
bi mem_resp

# Transfer Check
transfer_check: bf tf transfer
bi read_l2

# Transfer routine - other cache has block in E/M
transfer: wde req req lru req nextCohSt
pushq lceCmd ST req req lru
pushq lceCmd TR tr req tr
pushq lceCmd WB tr req tr
# wait for transfer WB response
wfq lceDataResp
bf nwbf complete_transfer
# perform the transfer WB to mem
wdp req 1
sfz rwbf
pushq memDataCmd req
popq lceDataResp
wfq memResp
popq memResp
wdp req 0
sf pcf

# wait for the transfer ack
complete_transfer: popq lceDataResp
wfq lceResp
popq lceResp
# TODO: ack_type == transfer_ack
bi ready

# Read Line from L2 Routine
read_l2: wdp req 1
wde req req lru req nextCohSt
pushq memCmd
wfq memDataResp
bi mem_data_resp

# Memory Response Routine
mem_resp: popq memResp
wdp req 0
bf rwbf transfer_check
sf pcf
bi ready

# Memory Data Response Routine
mem_data_resp: wdp req 0
pushq lceDataCmd
pushq lceCmd ST req req lru
popq memDataResp
wfq lceResp
popq lceResp
bi ready

# Uncached Request Routine
uncached_req: bf rqf uncached_store
pushq memCmd
wfq memDataResp
pushq lceDataCmd
popq memDataResp
bi ready
uncached_store: pushq memDataCmd req
wfq memResp
popq memResp
bi ready

error: stall

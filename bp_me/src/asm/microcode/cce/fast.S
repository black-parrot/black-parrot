# This microcode uses EI protocol with LCE transfers enabled
# The CCE process requests sequentially, and waits for all memory responses

#include "microcode.h"

# invalidate every entry in directory
rst_wg_init: movsg numWG r0
rst_wg_check: bz r0 set_clear_init
dec r0
rst_lce_init: movsg numLCE r1
rst_lce_check: bz r1 rst_wg_check
dec r1
rst_way_init: movsg lceAssoc r2
rst_way_check: bz r2 rst_lce_check
dec r2
wde r0 r1 r2 0 I
bi rst_way_check

# send set_clear messages
set_clear_init: movsg cceId r5
# r4 holds starting offset for address, assumes blocks striped across CCEs
movi 0 r4
offset_compute: bz r5 stride_compute
addi r4 BLOCK_SIZE r4
dec r5
bi offset_compute
# r6 holds address stride
stride_compute: movsg numCCE r5
movi 0 r6
stride_top: bz r5 sc_init_2
addi r6 BLOCK_SIZE r6
dec r5
bi stride_top

sc_init_2: movi 0 r2
movsg numWG r3
set_clear_top: bge r2 r3 sync_init
movi 0 r0
movsg numLCE r1
lce_top: bge r0 r1 wg_inc
pushq lceCmd SC r0 r4
inc r0
bi lce_top
wg_inc: inc r2
add r4 r6 r4
bi set_clear_top

# send sync messages
# r0 counts up from 0 number of sync messages sent
# r1 holds constant numLCE
# r3 stores the constant SYNC_ACK to check response ack type against
# The CCE waits for sync ack after each sync command. This avoids additional buffering being
# required in the CCE, at a small "performance" cost during startup
sync_init: movi 0 r0
movsg numLCE r1
movi SYNC_ACK r3
sync_top: bge r0 r1 finish_init
pushq lceCmd SYNC r0
popq lceResp r4
bne r3 r4 error
inc r0
bi sync_top

# set default value for mshr.next_coh_state
# may not be needed since wde and wds can use an immediate for the state input
finish_init: movis COH_E cohSt

# Wait for LCE Requests
# Try to fast-path the request
ready: clm
poph lceReq
rdp req
# pending or uncached should be handled without issuing a speculative access
bfor pf ucf handle_pf_ucf
# send speculative memory access, also sets speculative flag
pushq memCmd spec
# dequeue the request
popq lceReq
# read the directory and process
rdw req req req
gad
# handle slowly if invalidate, replacement, transfer, upgrade
bfor if rf tf uf handle_req
# write, cached (but no invalidations), or non-exlcusive read
bfor rqf cf nerf modify_state

# update directory entry
fast_path_complete: wde req req lru req nextCohSt
# clear spec bit
specq unset
# clear spec flag
sfz sf
# request handling complete
bi ready

# write request sets state to M, but otherwise can complete fast-path
modify_state: bfz rqf set_shared
movis COH_M nextCohSt
bi fast_path_complete

# nerf or others with block cached (and no invalidations) sets state to S, but otherwise fast-path
set_shared: movis COH_S nextCohSt
bi fast_path_complete

# handle pending flag set or uncached access
# pending jumps back to ready, waits for memory response to return and clear flag
handle_pf_ucf: bf pf ready
# Uncached Request Routine
# Note: hardware detects if it is load/store for the memCmd based on rqf
# but, it might be better to change HW to require a command type and addr sel in ucode for every memCmd
uncached_req: popq lceReq
pushq memCmd
bi ready

# Handle request that wasn't easily fast-pathed (if, rf, tf, uf)

# Next Coherence State Routine
# write request means set to M, else check non-exclusive request
handle_req: bf rqf next_coh_set_m
# non-exclusive request (read-only) or blocked cached somewhere, set to S
bfor cf nerf next_coh_set_s
# invalidations not required, thus block not cache, set to E
next_coh_set_e: movis E nextCohSt
bi inv_check
next_coh_set_s: movis S nextCohSt
bi inv_check
next_coh_set_m: movis M nextCohSt
# fall through to inv_check

# Invalidation Check
inv_check: bfz if upgrade_check

# Invalidation Routine
invalidate: movi 0 r0
movsg numLCE r1
movi 0 r2
movi INV_ACK r3
inv_top: bge r0 r1 inv_ack_top
bsz shHitr0 inv_inc_lce
bs reqLce r0 inv_inc_lce
inc r2
pushq lceCmd INV r0 req shWayR0
wds req r0 shWayR0 I
inv_inc_lce: inc r0
bi inv_top
inv_ack_top: bz r2 upgrade_check
# pop the lce response
inv_ack_pop: popq lceResp r4
dec r2
bi inv_ack_top

# Upgrade Check Routine
upgrade_check: bfz uf set_entry

# Upgrade Routine
upgrade: wds req req req nextCohSt
pushq lceCmd STW req req req
# squash speculative memory access
specq squash
sfz sf
bi ready

# write directory entry before memory messages may occur
# next_coh_state is not saved/restored across memory access
set_entry: wde req req lru req nextCohSt

# Replacement Check Routine
replace_check: bfz rf transfer_check

# Replacement Routine
replace: pushq lceCmd WB req lru lru
replacement_poph: poph lceResp r0
bf nwbf complete_replacement
pushq memCmd MEM_CMD_WB lru
complete_replacement: popq lceResp r0
# replacement done, explicitly set replacement flag to 0
sfz rf

# Transfer Check
transfer_check: bfz tf read_l2

# Transfer routine - other cache has block in E/M
transfer: pushq lceCmd TR tr req tr
pushq lceCmd WB tr req tr
# squash speculative memory access
specq squash
sfz sf
# wait for transfer WB response
transfer_poph: poph lceResp r0
bf nwbf complete_transfer
# perform the transfer WB to mem
pushq memCmd MEM_CMD_WB req
complete_transfer: popq lceResp r0
bi ready

# Read Line from L2 Routine
# memory access was already issued speculatively, so resolve the speculation
read_l2: bf rqf resolve_fwd_mod_m
bfor cf nerf resolve_fwd_mod_s
# resolve with COH_E, which was state request was issued with
resolve_e: specq unset
sfz sf
bi ready
resolve_fwd_mod_m: specq fwd_mod COH_M
sfz sf
bi ready
resolve_fwd_mod_s: specq fwd_mod COH_S
sfz sf
bi ready

error: stall

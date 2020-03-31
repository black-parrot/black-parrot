# This microcode uses MESI protocol with LCE transfers enabled

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

# Wait for LCE Requests
# Try to fast-path the request
ready: clm
poph lceReq r0
rdp addr=req
# pending or uncached should be handled without issuing a speculative access
bfnz handle_pf_ucf pf ucf
# send speculative memory access, also sets speculative flag
pushq memCmd MEM_CMD_WR addr=req lce=req way=lru spec=1 wp=1
# dequeue the request
popq lceReq wp
# read the directory and process
rdw addr=req lce=req lru_way=lru
gad
# handle slowly if invalidate, replacement, transfer (cached owned), upgrade
bfnz handle_req if rf cof uf
# write, cached (but no invalidations), or non-exlcusive read
bfnz modify_state rqf cf nerf

# complete fast path access
# uses the speculative memory access
fast_path_complete: wde addr=req lce=req way=lru state=nextCohSt
# clear spec bit
specq unset req
# request handling complete
bi ready

# write request sets state to M, but otherwise can complete fast-path
modify_state: bfz set_shared rqf
wde addr=req lce=req way=lru state=imm COH_M
specq fwd_mod req COH_M
bi ready

# nerf or others with block cached (and no invalidations) sets state to S, but otherwise fast-path
set_shared: wde addr=req lce=req way=lru state=imm COH_S
specq fwd_mod req COH_S
bi ready

# handle pending flag set or uncached access
# pending jumps back to ready, waits for memory response to return and clear flag
handle_pf_ucf: bf ready pf
# Uncached Request Routine
uncached_req: bf uncached_store rqf
pushq memCmd MEM_CMD_UC_RD addr=req lce=req
popq lceReq
bi ready
uncached_store: pushq memCmd MEM_CMD_UC_WR addr=req lce=req
popq lceReq
bi ready

# Handle request that wasn't easily fast-pathed (if, rf, cof, uf)

# Next Coherence State Routine
# write request means set to M, else check non-exclusive request
handle_req: bf next_coh_set_m rqf
# non-exclusive request (read-only) or blocked cached somewhere, set to S
bfnz next_coh_set_s cf nerf
# invalidations not required, thus block not cache, set to E
next_coh_set_e: movis COH_E nextCohSt
bi inv_check
next_coh_set_s: movis COH_S nextCohSt
bi inv_check
next_coh_set_m: movis COH_M nextCohSt
# fall through to inv_check

# Invalidation Check
inv_check: bfz upgrade_check if pt

# Invalidation Routine
invalidate: inv

# Upgrade Check Routine
upgrade_check: bfz set_entry uf pt

# Upgrade Routine
upgrade: wds addr=req lce=req way=req state=nextCohSt
pushq lceCmd STW addr=req lce=req way=req
specq squash req
bi ready

set_entry: wde addr=req lce=req way=lru state=nextCohSt

# Replacement Check Routine
replace_check: bfz transfer_check rf

# Replacement Routine
replace: pushq lceCmd WB addr=lru lce=req way=lru
# wait for writeback response
replacement_poph: poph lceResp r0
beqi r0 COH_ACK replacement_poph
bf complete_replacement nwbf
pushq memCmd MEM_CMD_WB addr=lru lce=req way=lru wp=1
complete_replacement: popq lceResp
# replacement done, explicitly set replacement flag to 0
sfz rf

# Transfer Check
transfer_check: bfz read_l2 cof pt
# transfer, squash speculative access
specq squash req

# Transfer routine - other cache has block in E/M
# write requests invalidate owner, read requests downgrade owner to S
transfer: bf transfer_write rqf
movis COH_S nextCohSt
pushq lceCmd ST addr=req lce=owner way=owner
wds addr=req lce=owner way=owner state=nextCohSt
bi transfer_tr
transfer_write: movsg nextCohSt r7
movis COH_I nextCohSt
pushq lceCmd ST addr=req lce=owner way=owner
wds addr=req lce=owner way=owner state=nextCohSt
movgs r7 nextCohSt
transfer_tr: pushq lceCmd TR addr=req lce=owner way=owner
pushq lceCmd WB addr=req lce=owner way=owner
# wait for transfer WB response
transfer_poph: poph lceResp r0
beqi r0 COH_ACK transfer_poph
bf complete_transfer nwbf
pushq memCmd MEM_CMD_WB addr=req lce=owner way=owner wp=1
complete_transfer: popq lceResp
bi ready

# Read Line from L2 Routine
# memory access was already issued speculatively, so resolve the speculation
read_l2: bf resolve_fwd_mod_m rqf
bfnz resolve_fwd_mod_s cf nerf
# resolve with COH_E, which was state request was issued with
resolve_e: specq unset req
bi ready
resolve_fwd_mod_m: specq fwd_mod req COH_M
bi ready
resolve_fwd_mod_s: specq fwd_mod req COH_S
bi ready


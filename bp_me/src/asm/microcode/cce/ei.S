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
sync_top: bge r0 r1 ready
pushq lceCmd SYNC r0
popq lceResp r4
bne r3 r4 error
inc r0
bi sync_top

# Ready Routine
ready: wfq lceReq

# LCE Request Routine
lce_req: clm
poph lceReq
bf ucf uncached_req
rdp req
bf pf ready
popq lceReq
rdw req req req
gad
# fall through

# Next Coherence State Routine
next_coh_state: movis E nextCohSt

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
beqi r4 COH_ACK inv_ack_pop
dec r2
bi inv_ack_top

# Upgrade Check Routine
upgrade_check: bfz uf set_entry

# Upgrade Routine
upgrade: bi error

# write directory entry before memory messages may occur
# next_coh_state is not saved/restored across memory access
set_entry: wde req req lru req nextCohSt

# Replacement Check Routine
replace_check: bfz rf transfer_check

# Replacement Routine
replace: pushq lceCmd WB req lru lru
replacement_poph: poph lceResp r0
beqi r0 COH_ACK replacement_poph
bf nwbf complete_replacement
pushq memCmd MEM_CMD_WB lru
complete_replacement: popq lceResp r0
beqi r0 COH_ACK complete_replacement
# replacement done, explicitly set replacement flag to 0
sfz rf

# Transfer Check
transfer_check: bfz tf read_l2

# Transfer routine - other cache has block in E/M
transfer: pushq lceCmd TR tr req tr
pushq lceCmd WB tr req tr
# wait for transfer WB response
transfer_poph: poph lceResp r0
beqi r0 COH_ACK transfer_poph
bf nwbf complete_transfer
# perform the transfer WB to mem
pushq memCmd MEM_CMD_WB req
complete_transfer: popq lceResp r0
beqi r0 COH_ACK complete_transfer
bi ready

# Read Line from L2 Routine
# TODO: move memory request earlier to hide some latency
read_l2: pushq memCmd
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

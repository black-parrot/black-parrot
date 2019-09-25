# This microcode uses EI protocol with LCE transfers enabled
# The CCE process requests sequentially, and waits for all memory responses

# TODO: WG should move to second or inner loop to avoid pending bit busy as much as possible
# TODO: add pending bit read and check

#include "microcode.h"

fence

movi 0 r0
movi 0 r1
movi 0 r2
movi 0 r3
movi 0 r4
movi 0 r5
movi 0 r6
movi 0 r7

ready: popq memCmd r1
beqi r1 MEM_CMD_FLUSH flush
# beqi r1 MEM_CMD_INV invalidate
bi error

flush: movi 0 r1
movi N_WG r4
flush_wg_check: bz r4 flush_done
dec r4
flush_lce_init: movi N_LCE r5
flush_lce_check: bz r5 flush_wg_check
dec r5
flush_way_init: movi LCE_ASSOC r6
flush_way_check: bz r6 flush_lce_check
dec r6

# inner loop body
# read directory, r4 = WG, r5 = LCE, r6 = way, r7 = dst for tag
rde r4 r5 r6 r7
# copy coherence state read from directory to r2
movsg shstr0 r1
# check coherence state for possibly dirty block
beqi r1 COH_I flush_way_check
beqi r1 COH_S flush_way_check
# send invalidate and writeback commands
pushq lceCmd INV r5 r7 shwayr0
pushq lceCmd WB r5 r7 shwayr0
# pop invalidate ack
popq lceResp r3
bneqi r3 INV_ACK error
# pop header of writeback
poph lceResp r3
bf nwbf complete_wb
pushq memCmd MEM_CMD_WB r7
complete_wb: popq lceResp r3
# wait for response from memory because of pending bits
popq memResp r3

bi flush_way_check
flush_done: pushq memResp MEM_CMD_FLUSH

# invalidate:
# invalidate_done: pushq memResp MEM_CMD_INV

error: stall

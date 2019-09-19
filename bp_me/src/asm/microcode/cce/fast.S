# fast path request processing for read-miss (not cached anywhere in system)

# TODO: make this default programmable by ucode (move to special register, which is used as source on "clm"
init: movi E nextCohStDefault
clm


ready: poph lceReq
rdp req
bf pf pending_set
bf rqf handle_write
rdw req req
gad
# branch if not upgrade, replacement, invalidate, or transfer required
bfz ff handle_slow
pushq memCmd
wde req req lru req nextCohSt
popq lceReq
clm
bi ready




handle_write: movi M nextCohSt
bi inv_check

handle_transfer: xxx

pending_set: bf ucf uncached_req
bi ready

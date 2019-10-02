# fast path request processing for read-miss (not cached anywhere in system)

#include "microcode.h"

init: movi COH_E cohSt
clm

ready: poph lceReq r0
rdp req
bf pf dummy
bf rqf dummy
rdw req req req
gad
# branch if upgrade, replacement, invalidate, or transfer required
bfor uf rf if tf dummy
pushq memCmd
wde req req lru req nextCohSt
popq lceReq r0
clm
bi ready

dummy: bi ready


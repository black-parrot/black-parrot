#
#   bsg_trace_rom.py
#

import sys
import random
sys.path.append("../py/")
from trace_gen import TraceGen

num_lce_p = int(sys.argv[1])
id_p = int(sys.argv[2])
num_instr = int(sys.argv[3])
seed_p = int(sys.argv[4]) + id_p if len(sys.argv) >= 5 else None
random.seed(seed_p)

tg = TraceGen(addr_width_p=39, data_width_p=64)

# preamble  
tg.print_header()

print("# seed: {0}".format(seed_p))

# test begin
store_val = num_lce_p if id_p == 0 else id_p

for i in range(num_instr):
  load_not_store = random.randint(0,1)
  tag = random.randint(0,15) << 10
  block_offset = random.randint(0,7) << 3
  addr = tag + block_offset
  if (load_not_store):
    tg.send_load(size=8, addr=addr, signed=0)
  else:
    tg.send_store(size=8, addr=addr, data=store_val)
    store_val += num_lce_p


# test end
tg.test_done()

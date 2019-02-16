import sys
import random
sys.path.append("../py/")
from trace_gen import TraceGen

num_lce_p = int(sys.argv[1])
id_p = int(sys.argv[2])

tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
random.seed(id_p)
num_instr = 1024
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

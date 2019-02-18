import sys
import random
sys.path.append("../py/")
from trace_gen import TraceGen

num_lce_p = int(sys.argv[1])
id_p = int(sys.argv[2])

tg = TraceGen(addr_width_p=32, data_width_p=64)

# preamble  
tg.print_header()

# test begin
random.seed(id_p)
num_instr = 8
store_val = num_lce_p if id_p == 0 else id_p

block_size_bytes = 64

tg.wait(100)

addr = 0
for i in range(num_instr):
  tg.send_store(size=8, addr=addr, data=store_val)
  tg.recv_data(data=0)
  addr = addr + block_size_bytes
  store_val += num_lce_p

addr = 0
store_val = num_lce_p if id_p == 0 else id_p
for i in range(num_instr):
  tg.send_load(signed=0, size=8, addr=addr)
  tg.recv_data(data=store_val)
  addr = addr + block_size_bytes
  store_val += num_lce_p
  

# test end
tg.test_done()

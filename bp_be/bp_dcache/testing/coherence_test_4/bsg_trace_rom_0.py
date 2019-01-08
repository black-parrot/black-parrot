import sys
sys.path.append("../py/")
from trace_gen import TraceGen

WAIT_TIME = 50

ways = 8
sets = 16
block_size_bytes = 64
cache_size = block_size_bytes * ways * sets
size = 1
addr_inc = block_size_bytes * sets

tg = TraceGen(addr_width_p=20, data_width_p=64)

# preamble
tg.print_header()

# test begin
addr = 0
data = 0

# addr = tag + set idx + offset
# addr = (10) + (6) + (6)

# addr + block size (64) increments set
# addr + cache size changes tag, targets same set

for i in xrange(0,ways):
  tg.send_store(size=size, addr=addr, data=data)
  tg.recv_data(data=0)
  addr = addr + addr_inc
  data = data + 1

"""
addr = 0
data = 0
for i in xrange(0,ways):
  tg.send_load(signed=0, size=size, addr=addr)
  tg.recv_data(data=data)
  addr = addr + addr_inc
  data = data + 1
"""

# test end
tg.test_done()

import sys
sys.path.append("../py/")
from trace_gen import TraceGen

WAIT_TIME = 50

ways = 8
sets = 16
block_size_bytes = 64
cache_size = block_size_bytes * ways * sets

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

for i in xrange(0,8):
  tg.send_store(size=4, addr=addr, data=0xF)
  tg.recv_data(data=0)
  addr = addr + 4

addr = 0
for i in xrange(0,8):
  tg.send_load(signed=0, size=4, addr=addr)
  tg.recv_data(data=0xF)
  addr = addr + 4

# test end
tg.test_done()

import sys
sys.path.append("../py/")
from trace_gen import TraceGen

WAIT_TIME = 50

ways = 8
sets = 16
block_size_bytes = 64
cache_size = block_size_bytes * ways * sets
addr_inc = block_size_bytes * sets

tg = TraceGen(addr_width_p=20, data_width_p=block_size_bytes)

# preamble
tg.print_header()

# test begin
tg.wait(WAIT_TIME*100)

addr = 0
data = 0
for i in xrange(0,ways):
  tg.send_load(signed=0, size=1, addr=addr)
  tg.recv_data(data=data)
  addr = addr + addr_inc
  data = data + 1

# test end
tg.test_done()

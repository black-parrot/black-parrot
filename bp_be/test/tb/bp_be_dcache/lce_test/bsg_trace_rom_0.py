import sys
sys.path.append("../py/")
from trace_gen import TraceGen

tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
N=64
for i in range(N):
  tg.send_store(size=8, addr=i*8, data=i+1)

for i in range(N):
  tg.recv_data(0)

for i in range(N):
  tg.send_load(signed=0, size=8, addr=i*8)

for i in range(N):
  tg.recv_data(i+1)

# test end
tg.test_done()


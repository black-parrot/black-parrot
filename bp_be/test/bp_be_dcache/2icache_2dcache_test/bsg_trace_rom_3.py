#
#   bsg_trace_rom_3.py
#
#   rom for dcache1
#

import sys
sys.path.append("../py/")
from trace_gen import TraceGen


tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
addr_offset = (1<<12)

tg.wait(20000)
for i in range(16):
  store_data = ((i+1)*(i+1) << 32) + (i+1)*(i+1)
  tg.send_store(size=8, addr=addr_offset+(i*8), data=store_data)
  tg.recv_data(data=0)



# test end
tg.test_done()

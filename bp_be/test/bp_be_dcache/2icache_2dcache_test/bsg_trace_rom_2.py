#
#   bsg_trace_rom_2.py
#
#   rom for icache1
#

import sys
sys.path.append("../py/")
from trace_gen import TraceGen

tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
addr_offset = (1<<12)

tg.wait(25000)
for i in range(16):
  load_data = (i+1)*(i+1)
  tg.send_load(signed=0, size=4, addr=addr_offset+(i*8))
  tg.recv_data(data=load_data)
  tg.send_load(signed=0, size=4, addr=addr_offset+(i*8)+4)
  tg.recv_data(data=load_data)


# test end
tg.test_done()

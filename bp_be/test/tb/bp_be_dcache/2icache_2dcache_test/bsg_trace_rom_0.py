#
#   bsg_trace_rom_0.py
#
#   rom for icache0
#

import sys
sys.path.append("../py/")
from trace_gen import TraceGen

tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
tg.wait(8)
tg.send_load(signed=0, size=4, addr=0)
tg.send_load(signed=0, size=4, addr=4)
tg.recv_data(data=1)
tg.recv_data(data=0)

tg.wait(100)
tg.send_load(signed=0, size=4, addr=0)
tg.send_load(signed=0, size=4, addr=4)
tg.recv_data(data=2)
tg.recv_data(data=0)

tg.wait(150)
tg.send_load(signed=0, size=4, addr=0)
tg.send_load(signed=0, size=4, addr=4)
tg.recv_data(data=2)
tg.recv_data(data=0)

# test end
tg.test_done()

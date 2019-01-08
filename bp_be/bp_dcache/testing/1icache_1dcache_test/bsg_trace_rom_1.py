#
#   bsg_trace_rom_1.py
#
#   rom for dcache0
#

import sys
sys.path.append("../py/")
from trace_gen import TraceGen


tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
tg.send_store(size=8, addr=0, data=1)
tg.recv_data(data=0)

tg.wait(60)
tg.send_store(size=8, addr=0, data=2)
tg.recv_data(data=0)

tg.wait(60)
tg.send_load(size=8, addr=0, signed=0)
tg.recv_data(data=2)


# test end
tg.test_done()

import sys
sys.path.append("../py/")
from trace_gen import TraceGen

WAIT_TIME = 50

ways = 8
sets = 16
block_size_bytes = 64
cache_size = block_size_bytes * ways * sets

tg = TraceGen(addr_width_p=20, data_width_p=block_size_bytes)

# preamble
tg.print_header()

# test begin
tg.wait(WAIT_TIME*100)
tg.send_load(signed=0, size=8, addr=0)
tg.recv_data(data=0xF)


# test end
tg.test_done()

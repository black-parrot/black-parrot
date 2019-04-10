import sys
sys.path.append("../py")
from trace_gen import TraceGen

tg = TraceGen(addr_width_p=39, data_width_p=64)

tg.print_header()

tg.send_store(size=8, addr=(0 | (1 << 38)), data=1234567890)
tg.send_load(size=8, addr=(0 | (1 << 38)), signed=0)
tg.recv_data(data=0)
tg.recv_data(data=1234567890)

tg.test_done()

import sys
sys.path.append("../py")
from trace_gen import TraceGen
<<<<<<< HEAD
from npa_addr_gen import NPAAddrGen



tg = TraceGen(addr_width_p=39, data_width_p=64)
npa = NPAAddrGen(y_cord_width_p=1, x_cord_width_p=2, epa_addr_width_p=12)

tg.print_header()

npa_addr = npa.get_npa_addr(y=1,x=0,epa_addr=0)
tg.send_store(size=8, addr=(npa_addr | (1 << 38)), data=1234567890)
tg.send_load(size=8, addr=(npa_addr | (1 << 38)), signed=0)
=======

tg = TraceGen(addr_width_p=39, data_width_p=64)

tg.print_header()

tg.send_store(size=8, addr=(0 | (1 << 38)), data=1234567890)
tg.send_load(size=8, addr=(0 | (1 << 38)), signed=0)
>>>>>>> 03e9ca6d513873c6752377df8de9dee31b625aed
tg.recv_data(data=0)
tg.recv_data(data=1234567890)

tg.test_done()

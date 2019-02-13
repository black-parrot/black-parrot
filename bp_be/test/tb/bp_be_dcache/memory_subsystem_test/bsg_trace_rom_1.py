import sys
sys.path.append("../py/")
from trace_gen import TraceGen


tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
tg.wait(16)
tg.send_load(signed=0, size=8, addr=0)
tg.recv_data(data=1)


# test end
tg.test_done()

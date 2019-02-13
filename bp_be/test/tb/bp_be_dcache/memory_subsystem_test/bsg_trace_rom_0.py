import sys
sys.path.append("../py/")
from trace_gen import TraceGen


tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin
tg.send_store(size=8, addr=0, data=1)
tg.recv_data(data=0)


# test end
tg.test_done()

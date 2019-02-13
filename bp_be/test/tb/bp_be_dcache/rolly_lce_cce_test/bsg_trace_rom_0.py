import sys
sys.path.append("../py/")
from trace_gen import TraceGen


tg = TraceGen(addr_width_p=22, data_width_p=64)

# preamble  
tg.print_header()

# test begin

# store miss
tg.send_store(size=8, addr=0x0000, data=1)
tg.send_load(signed=0, size=8, addr=0x0000)
tg.recv_data(data=0)
tg.recv_data(data=1)

tg.send_store(size=8, addr=0x1000, data=2)
tg.send_load(signed=0, size=8, addr=0x1000)
tg.recv_data(data=0)
tg.recv_data(data=2)

tg.send_store(size=8, addr=0x2000, data=3)
tg.send_load(signed=0, size=8, addr=0x2000)
tg.recv_data(data=0)
tg.recv_data(data=3)

tg.send_store(size=8, addr=0x3000, data=4)
tg.send_load(signed=0, size=8, addr=0x3000)
tg.recv_data(data=0)
tg.recv_data(data=4)

tg.send_store(size=8, addr=0x4000, data=5)
tg.send_load(signed=0, size=8, addr=0x4000)
tg.recv_data(data=0)
tg.recv_data(data=5)

tg.send_store(size=8, addr=0x5000, data=6)
tg.send_load(signed=0, size=8, addr=0x5000)
tg.recv_data(data=0)
tg.recv_data(data=6)

tg.send_store(size=8, addr=0x6000, data=7)
tg.send_load(signed=0, size=8, addr=0x6000)
tg.recv_data(data=0)
tg.recv_data(data=7)

tg.send_store(size=8, addr=0x7000, data=8)
tg.send_load(signed=0, size=8, addr=0x7000)
tg.recv_data(data=0)
tg.recv_data(data=8)

tg.send_store(size=8, addr=0x8000, data=9)
tg.send_load(signed=0, size=8, addr=0x8000)
tg.recv_data(data=0)
tg.recv_data(data=9)

tg.send_load(signed=0, size=8, addr=0x0000)
tg.recv_data(data=1)

tg.send_load(signed=0, size=8, addr=0x4000)
tg.recv_data(data=5)

tg.send_load(signed=0, size=8, addr=0x3000)
tg.recv_data(data=4)

tg.send_load(signed=0, size=8, addr=0x2000)
tg.recv_data(data=3)

tg.send_load(signed=0, size=8, addr=0x6000)
tg.recv_data(data=7)

tg.send_load(signed=0, size=8, addr=0x1000)
tg.recv_data(data=2)

tg.send_load(signed=0, size=8, addr=0x5000)
tg.recv_data(data=6)

tg.send_load(signed=0, size=8, addr=0x2000)
tg.recv_data(data=3)

tg.send_load(signed=0, size=8, addr=0x2000)
tg.recv_data(data=3)


# write blocks
block_val = []
for i in range(16):
  for j in range(8):
    idx = 8*i + j
    block_val.append(16+idx)
    tg.send_store(size=8, addr=8*idx, data=block_val[idx])

tg.test_done()

for i in range(16):
  for j in range(8):
    idx = 8*i + j
    tg.send_load(signed=0, size=8, addr=8*idx)

for i in range(16):
  for j in range(8):
    tg.recv_data(data=0)
    
for i in range(16):
  for j in range(8):
    idx = 8*i + j
    tg.recv_data(block_val[idx])


# test end

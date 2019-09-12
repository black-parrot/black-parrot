import sys
sys.path.append("../software/py")
from trace_gen import TraceGen

paddr_width = 40
uc_mask = (1 << (paddr_width-1))
tg = TraceGen(addr_width_p=paddr_width, data_width_p=64)
# TODO: the addressing below is a carryover from manycore-land. This generates valid addresses,
# but is not exactly how BP works. This test will be changed to use direct assignment of addresses
# in a future change, when we also change the use of the msb bit of the address to no longer rely
# on it for cached/uncached determination.

tg.print_header()

# wait for CCE to do initialization sequence
tg.wait(5000)

base_addr = 0
tg.send_store(size=8, addr=(base_addr | uc_mask), data=1234567890)
tg.recv_data(data=0)
tg.send_load(size=8, addr=(base_addr | uc_mask), signed=0)
tg.recv_data(data=1234567890)

base_addr = 0
tg.send_store(size=8, addr=(base_addr | uc_mask), data=0x1133557722446688)
tg.recv_data(data=0)
tg.send_load(size=1, addr=(base_addr | uc_mask)+0, signed=0)
tg.recv_data(data=0x88)
tg.send_load(size=1, addr=(base_addr | uc_mask)+1, signed=0)
tg.recv_data(data=0x66)
tg.send_load(size=1, addr=(base_addr | uc_mask)+2, signed=0)
tg.recv_data(data=0x44)
tg.send_load(size=1, addr=(base_addr | uc_mask)+3, signed=0)
tg.recv_data(data=0x22)
tg.send_load(size=1, addr=(base_addr | uc_mask)+4, signed=0)
tg.recv_data(data=0x77)
tg.send_load(size=1, addr=(base_addr | uc_mask)+5, signed=0)
tg.recv_data(data=0x55)
tg.send_load(size=1, addr=(base_addr | uc_mask)+6, signed=0)
tg.recv_data(data=0x33)
tg.send_load(size=1, addr=(base_addr | uc_mask)+7, signed=0)
tg.recv_data(data=0x11)

base_addr = 4096
tg.send_store(size=4, addr=(base_addr | uc_mask), data=0xaabbccdd)
tg.recv_data(data=0)
tg.send_store(size=4, addr=(base_addr | uc_mask)+4, data=0xdeadbeef)
tg.recv_data(data=0)
tg.send_load(size=2, addr=(base_addr | uc_mask)+0, signed=0)
tg.recv_data(data=0xccdd)
tg.send_load(size=2, addr=(base_addr | uc_mask)+2, signed=0)
tg.recv_data(data=0xaabb)
tg.send_load(size=2, addr=(base_addr | uc_mask)+4, signed=0)
tg.recv_data(data=0xbeef)
tg.send_load(size=2, addr=(base_addr | uc_mask)+6, signed=0)
tg.recv_data(data=0xdead)

base_addr = 8192
tg.send_store(size=1, addr=(base_addr | uc_mask)+0, data=0xcd)
tg.recv_data(data=0)
tg.send_store(size=1, addr=(base_addr | uc_mask)+1, data=0xef)
tg.recv_data(data=0)
tg.send_store(size=1, addr=(base_addr | uc_mask)+2, data=0xf1)
tg.recv_data(data=0)
tg.send_store(size=1, addr=(base_addr | uc_mask)+3, data=0xe7)
tg.recv_data(data=0)
tg.send_store(size=1, addr=(base_addr | uc_mask)+4, data=0x84)
tg.recv_data(data=0)
tg.send_store(size=1, addr=(base_addr | uc_mask)+5, data=0xd2)
tg.recv_data(data=0)
tg.send_store(size=1, addr=(base_addr | uc_mask)+6, data=0xaa)
tg.recv_data(data=0)
tg.send_store(size=1, addr=(base_addr | uc_mask)+7, data=0xb9)
tg.recv_data(data=0)
tg.send_load(size=8, addr=(base_addr | uc_mask)+0, signed=0)
tg.recv_data(data=0xb9aad284e7f1efcd)
tg.send_load(size=4, addr=(base_addr | uc_mask)+0, signed=0)
tg.recv_data(data=0xe7f1efcd)
tg.send_load(size=4, addr=(base_addr | uc_mask)+4, signed=0)
tg.recv_data(data=0xb9aad284)

base_addr = 256
tg.send_store(size=2, addr=(base_addr | uc_mask)+0, data=0xffcd)
tg.recv_data(data=0)
tg.send_store(size=2, addr=(base_addr | uc_mask)+2, data=0xccef)
tg.recv_data(data=0)
tg.send_store(size=2, addr=(base_addr | uc_mask)+4, data=0x43f1)
tg.recv_data(data=0)
tg.send_store(size=2, addr=(base_addr | uc_mask)+6, data=0x87e7)
tg.recv_data(data=0)
tg.send_load(size=4, addr=(base_addr | uc_mask)+0, signed=0)
tg.recv_data(data=0xccefffcd)
tg.send_load(size=4, addr=(base_addr | uc_mask)+4, signed=0)
tg.recv_data(data=0x87e743f1)

base_addr = 512
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*0, data=0x1111111111111111)
tg.recv_data(data=0)
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*1, data=0x2222222222222222)
tg.recv_data(data=0)
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*2, data=0x3333333333333333)
tg.recv_data(data=0)
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*3, data=0x4444444444444444)
tg.recv_data(data=0)
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*4, data=0x5555555555555555)
tg.recv_data(data=0)
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*5, data=0x6666666666666666)
tg.recv_data(data=0)
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*6, data=0x7777777777777777)
tg.recv_data(data=0)
tg.send_store(size=8, addr=(base_addr | uc_mask)+8*7, data=0x8888888888888888)
tg.recv_data(data=0)

tg.send_load(size=8, addr=(base_addr | uc_mask)+8*0, signed=0)
tg.recv_data(data=0x1111111111111111)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*1, signed=0)
tg.recv_data(data=0x2222222222222222)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*2, signed=0)
tg.recv_data(data=0x3333333333333333)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*3, signed=0)
tg.recv_data(data=0x4444444444444444)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*4, signed=0)
tg.recv_data(data=0x5555555555555555)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*5, signed=0)
tg.recv_data(data=0x6666666666666666)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*6, signed=0)
tg.recv_data(data=0x7777777777777777)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*7, signed=0)
tg.recv_data(data=0x8888888888888888)
tg.send_load(size=8, addr=(base_addr | uc_mask)+8*0, signed=0)
tg.recv_data(data=0x1111111111111111)


tg.test_done()

from __future__ import print_function
import sys
import random
import math
from argparse import ArgumentParser
# import trace generator for D$
sys.path.append("../py/")
from trace_gen import TraceGen

def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

parser = ArgumentParser(description='ME Trace Replay')
parser.add_argument('-n', '--num-instr', dest='num_instr', type=int, default=8,
                    help='Number of memory operations to execute')
parser.add_argument('-s', '--seed', dest='seed', type=int, default=1,
                    help='random number generator seed')
parser.add_argument('-m', dest='paddr_width', type=int, default=32,
                    help='Physical address width in bits')
parser.add_argument('-d', dest='data_width', type=int, default=64,
                    help='Data cache word size in bits')
parser.add_argument('-e', dest='assoc', type=int, default=8,
                    help='Data cache associativity')
parser.add_argument('--sets', dest='sets', type=int, default=16,
                    help='Data cache number of sets')
parser.add_argument('--mem-size', dest='mem_size', type=int, default=2,
                    help='Size of backing memory, given as integer multiple of D$ size')


args = parser.parse_args()

## Cache Parameters
# D$ associativity
E = args.assoc
# D$ number of sets
S = args.sets
s = int(math.log(S, 2))
# D$ number of cache blocks per cache
N_B = E*S
# D$ data word size (in bits)
D = args.data_width
D_bytes = D / 8
# D$ block size (in bytes) is equal to associativity times D$ data word size
B = (D_bytes * E)
b = int(math.log(B, 2))
# D$ size in bytes
C = N_B * B

# number of tag bits
t = args.paddr_width - s - b

# Memory size in bytes
C_MEM = C * args.mem_size
N_B_MEM = N_B * args.mem_size


# Simulated memory
byte_memory = {}

def read_memory(mem, addr, size):
  # get the bytes from addr to addr+(size-1)
  # values are read assuming memory store multi-byte values in Little Endian order
  data = [mem[addr+i] if addr+i in mem else 0 for i in xrange(size-1, -1, -1)]
  val = 0
  for i in xrange(size):
    val = (val << 8) + data[i]
  return val

def write_memory(mem, addr, value, size):
  # by default
  # create an array of "bytes" (really, integer values of each byte) for addr to addr+(size-1)
  # bytes of value are stored into memory in Little Endian order
  for i in xrange(size):
    v = (value >> (i*8)) & 0xff
    #eprint('mem[{0}]: {1}'.format(addr+i, v))
    mem[addr+i] = (value >> (i*8)) & 0xff
    
#write_memory(byte_memory, 0, 256, 2)
#print(read_memory(byte_memory, 0, 1))

tg = TraceGen(addr_width_p=args.paddr_width, data_width_p=args.data_width)

# preamble  
tg.print_header()

# test begin
random.seed(args.seed)

block_size_bytes = B

tg.wait(100)

store_val = 1
"""
addr = 3
tg.send_store(size=1, addr=addr, data=store_val)
tg.recv_data(data=0)
tg.send_load(signed=0, size=1, addr=addr)
tg.recv_data(data=1)
"""

for i in range(args.num_instr):
  load = random.choice([True, False])
  #size = random.choice([1, 2, 4, 8])
  size = 1
  # choose which cache block in memory to target
  #block = random.randint(0, 4)#N_B_MEM)
  block = 0
  # choose offset in cache block based on size of access ("word" size for this access)
  words = B / size
  word = random.randint(0, words)
  # build the address
  addr = (block << b) + (word << (size - 1))

  if load:
    tg.send_load(signed=0, size=size, addr=addr)
    val = read_memory(byte_memory, addr, size)
    eprint(str(i) + ': mem[{0}:{1}] == {2}'.format(addr, size, val))
    tg.recv_data(data=val)
  else:
    tg.send_store(size=size, addr=addr, data=store_val)
    write_memory(byte_memory, addr, store_val, size)
    eprint(str(i) + ': mem[{0}:{1}] := {2}'.format(addr, size, store_val))
    tg.recv_data(data=0)
    store_val += 1

# test end
tg.test_done()

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
parser.add_argument('-m', dest='paddr_width', type=int, default=39,
                    help='Physical address width in bits')
parser.add_argument('-d', dest='data_width', type=int, default=64,
                    help='Data cache word size in bits')
parser.add_argument('-e', dest='assoc', type=int, default=8,
                    help='Data cache associativity')
parser.add_argument('--sets', dest='sets', type=int, default=64,
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
#eprint('D$ blocks: {0}'.format(N_B))
# D$ data word size (in bits)
D = args.data_width
D_bytes = D / 8
# D$ block size (in bytes) is equal to associativity times D$ data word size
B = (D_bytes * E)
b = int(math.log(B, 2))
# D$ size in bytes
C = N_B * B
#eprint('D$ bytes: {0}'.format(C))

# number of tag bits
t = args.paddr_width - s - b
#eprint('t: {0}, s: {1}, b: {2}'.format(t, s, b))

# Memory size in bytes
C_MEM = C * args.mem_size
# Number of cache blocks in memory
N_B_MEM = N_B * args.mem_size
#eprint('Memory blocks: {0}'.format(N_B_MEM))
#eprint('Memory bytes: {0}'.format(C_MEM))

def check_valid_addr(addr):
  assert(addr < C_MEM), 'addr {0} out of range'.format(addr)

# Simulated memory
byte_memory = {}

def read_memory(mem, addr, size):
  # get the bytes from addr to addr+(size-1)
  # values are read assuming memory store multi-byte values in Little Endian order
  data = [mem[addr+i] if addr+i in mem else 0 for i in xrange(size-1, -1, -1)]
  val = 0
  for i in xrange(size):
    #eprint('read: mem[{0}] == {1:x}'.format(addr+i, data[size-1-i]))
    val = (val << 8) + data[i]
  return val

def write_memory(mem, addr, value, size):
  # by default
  # create an array of "bytes" (really, integer values of each byte) for addr to addr+(size-1)
  # bytes of value are stored into memory in Little Endian order
  for i in xrange(size):
    v = (value >> (i*8)) & 0xff
    #eprint('write: mem[{0}] := {1:x}'.format(addr+i, v))
    mem[addr+i] = v
    
#write_memory(byte_memory, 0, 256, 2)
#print(read_memory(byte_memory, 0, 1))

tg = TraceGen(addr_width_p=args.paddr_width, data_width_p=args.data_width)

# preamble  
tg.print_header()

# test begin
random.seed(args.seed)

tg.wait(100)

store_val = 1

for i in range(args.num_instr):
  load = random.choice([True, False])
  size = random.choice([1, 2, 4, 8])
  size_shift = int(math.log(size, 2))
  # choose which cache block in memory to target
  block = random.randint(0, N_B_MEM-1)
  # choose offset in cache block based on size of access ("word" size for this access)
  words = B / size
  word = random.randint(0, words-1)
  # build the address
  addr = (block << b) + (word << size_shift)
  check_valid_addr(addr)

  if load:
    tg.send_load(signed=0, size=size, addr=addr)
    val = read_memory(byte_memory, addr, size)
    #eprint(str(i) + ': mem[{0}:{1}] == {2}'.format(addr, size, val))
    tg.recv_data(data=val)
  else:
    # NOTE: the value being stored will be truncated to size number of bytes
    store_val_trunc = store_val
    if (size < 8):
      store_val_trunc = store_val_trunc & ~(~0 << (size*8))
    tg.send_store(size=size, addr=addr, data=store_val_trunc)
    write_memory(byte_memory, addr, store_val_trunc, size)
    #eprint(str(i) + ': mem[{0}:{1}] := {2}'.format(addr, size, store_val_trunc))
    tg.recv_data(data=0)
    store_val += 1

# test end
tg.test_done()

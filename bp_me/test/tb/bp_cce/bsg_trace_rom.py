from __future__ import print_function
import sys
import random
import math
from argparse import ArgumentParser
# import trace generator for $
# Note: this path is relative to bp_me/syn directory
# it would be nice to simply add the directory that TraceGen source lives in to the path
# that python will search for files in, then remove the sys.path.append call
sys.path.append("../software/py/")
from trace_gen import TraceGen

def eprint(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)

parser = ArgumentParser(description='ME Trace Replay')
parser.add_argument('-n', '--num-instr', dest='num_instr', type=int, default=8,
                    help='Number of memory operations to execute')
parser.add_argument('-s', '--seed', dest='seed', type=int, default=1,
                    help='random number generator seed')
parser.add_argument('-m', dest='paddr_width', type=int, default=40,
                    help='Physical address width in bits')

# cache parameters
parser.add_argument('-b', dest='block_size', type=int, default=512,
                    help='cache block size')
parser.add_argument('-e', dest='assoc', type=int, default=8,
                    help='cache associativity')
parser.add_argument('--sets', dest='sets', type=int, default=64,
                    help='cache sets')
parser.add_argument('-d', dest='dword_size', type=int, default=64,
                    help='dword size')

# operating mode
parser.add_argument('-u', '--uncached', dest='uncached', type=int, default=0,
                    help='Set to issue only uncached and incoherent requests')

# memory map arguments and parameters
# The basic memory map is only DRAM is cacheable and coherent and all other memory
# is incoherent and uncacheable only. Uncacheable accesses may be issued to coherent
# DRAM memory space, and are kept coherent by the CCE.
parser.add_argument('--dram-offset', dest='dram_offset', type=int, default=0x80000000,
                    help='base address of cacheable memory (DRAM)')
parser.add_argument('--dram-high', dest='dram_high', type=int, default=0x100000000,
                    help='DRAM upper limit (i.e., first address above DRAM)')
parser.add_argument('--mem-size', dest='mem_size', type=int, default=2,
                    help='Size of backing memory, given as integer multiple of $ size')



args = parser.parse_args()

## cache parameters
cache_assoc = args.assoc
cache_sets = args.sets
assert cache_sets > 1, 'direct mapped cache not supported'
cache_blocks = cache_assoc*cache_sets
cache_block_size = args.block_size
cache_block_size_bytes = (cache_block_size / 8)
dword_size = args.dword_size

# bits in address
s = int(math.log(cache_sets, 2))
b = int(math.log(cache_block_size_bytes, 2))
t = args.paddr_width - s - b
#eprint('t: {0}, s: {1}, b: {2}'.format(t, s, b))

cache_cap_bytes = cache_blocks * cache_block_size_bytes
#eprint('$ bytes: {0}'.format(cache_cap_bytes))

# memory params
mem_bytes = cache_cap_bytes * args.mem_size
mem_blocks = cache_blocks * args.mem_size
#eprint('memory blocks: {0}'.format(mem_blocks))
#eprint('memory bytes: {0}'.format(mem_bytes))

# base memory address
mem_base = 0 if args.uncached else args.dram_offset
mem_high = mem_base + mem_bytes
#eprint('memory base: 0x{0:010x}'.format(mem_base))
#eprint('memory high: 0x{0:010x}'.format(mem_high))

def check_valid_addr(addr):
  assert ((addr >= mem_base) and (addr < mem_high)), 'illegal address 0x{0:010x}'.format(addr)

# Simulated memory
byte_memory = {}

def read_memory(mem, addr, size):
  # get the bytes from addr to addr+(size-1)
  # values are read assuming memory store multi-byte values in Little Endian order
  data = [mem[addr+i] if addr+i in mem else 0 for i in range(size-1, -1, -1)]
  val = 0
  for i in range(size):
    #eprint('read: mem[{0}] == {1:x}'.format(addr+i, data[size-1-i]))
    val = (val << 8) + data[i]
  return val

def write_memory(mem, addr, value, size):
  # by default
  # create an array of "bytes" (really, integer values of each byte) for addr to addr+(size-1)
  # bytes of value are stored into memory in Little Endian order
  for i in range(size):
    v = (value >> (i*8)) & 0xff
    #eprint('write: mem[{0}] := {1:x}'.format(addr+i, v))
    mem[addr+i] = v
    
#write_memory(byte_memory, 0, 256, 2)
#print(read_memory(byte_memory, 0, 1))

tg = TraceGen(addr_width_p=args.paddr_width, data_width_p=args.dword_size)

# preamble  
tg.print_header()

# test begin
random.seed(args.seed)

tg.wait(100)

store_val = 1

uncached = 1 if args.uncached else 0

for i in range(args.num_instr):
  # pick access parameters
  load = random.choice([True, False])
  size = random.choice([1, 2, 4, 8])
  size_shift = int(math.log(size, 2))
  # choose which cache block in memory to target
  block = random.randint(0, mem_blocks-1)
  #eprint('block: {0}'.format(block))
  # choose offset in cache block based on size of access ("word" size for this access)
  words = cache_block_size_bytes / size
  word = random.randint(0, words-1)
  #eprint('word: {0}'.format(word))
  # build the address
  addr = (block << b) + (word << size_shift)
  if not uncached:
    addr = addr + mem_base
  check_valid_addr(addr)

  if load:
    tg.send_load(signed=0, size=size, addr=addr, uc=uncached)
    val = read_memory(byte_memory, addr, size)
    #eprint(str(i) + ': mem[{0}:{1}] == {2}'.format(addr, size, val))
    tg.recv_data(addr=addr, data=val, uc=uncached)
  else:
    # NOTE: the value being stored will be truncated to size number of bytes
    store_val_trunc = store_val
    if (size < 8):
      store_val_trunc = store_val_trunc & ~(~0 << (size*8))
    tg.send_store(size=size, addr=addr, data=store_val_trunc, uc=uncached)
    write_memory(byte_memory, addr, store_val_trunc, size)
    #eprint(str(i) + ': mem[{0}:{1}] := {2}'.format(addr, size, store_val_trunc))
    tg.recv_data(addr=addr, data=0, uc=uncached)
    store_val += 1

# test end
tg.test_done()


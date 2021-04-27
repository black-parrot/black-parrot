from __future__ import print_function
import sys
import random
import math
# import trace generator for $
# Note: this path is relative to bp_me/syn directory
# it would be nice to simply add the directory that TraceGen source lives in to the path
# that python will search for files in, then remove the sys.path.append call
sys.path.append("../software/py/")
from trace_gen import TraceGen
from test_memory import TestMemory

# Test Generator class
# a test is defined as a sequence of load and store operation tuples
# Each operation tuple is: (store, address, size in bytes, uncached, value)
# If store=True, op is a store, else op is a load
# size is in bytes, and must be 1, 2, 4, or 8
# If uncached=1, op is an uncached access, else it is a cached access
# value is the store value or expected load value
class TestGenerator(object):
  def __init__(self, paddr_width=40, data_width=64, debug=False):
    self.paddr_width = paddr_width
    self.data_width = data_width
    self.tg = TraceGen(addr_width_p=self.paddr_width, data_width_p=self.data_width)
    self.debug = debug

  def eprint(self, *args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

  def generateTrace(self, ops):
    # preamble
    self.tg.print_header()
    self.tg.wait(100)
    for (st,addr,size,uc,val) in ops:
      if st:
        self.tg.send_store(size=size, addr=addr, data=val, uc=uc)
        self.tg.recv_data(addr=addr, data=0, uc=uc)
      else:
        # TODO: signed operations
        self.tg.send_load(signed=0, size=size, addr=addr, uc=uc)
        self.tg.recv_data(addr=addr, data=val, uc=uc)
    # test end
    self.tg.test_done()

  # single cached store
  def storeTest(self, mem_base=0):
    addr = mem_base
    return [(True, addr, 8, 0, 1)]

  # cached store/load pair
  def loadTest(self, mem_base=0):
    addr = mem_base
    return [(True, addr, 8, 0, 1), (False, addr, 8, 0, 1)]

  # fill a cache set with stores
  # evict an entry
  # load back the entry
  def setTest(self, mem_base=0, assoc=8, sets=64, block_size=64):
    ops = []
    addr = mem_base
    # blocks in same set are separated by (sets*block_size) in byte-addressable memory
    stride = sets*block_size
    store_val = 1
    for i in range(assoc+1):
      ops.append((True, addr, 8, 0, store_val))
      addr += stride
      store_val += 1
    ops.append((False, mem_base, 8, 0, 1))
    return ops

  # Random loads and stores to a single set (set 0)
  def setHammerTest(self, N=16, mem_base=0, mem_bytes=1024, mem_block_size=64, mem_size=2, assoc=8, sets=64, seed=0, lce_mode=0):
    # test begin
    random.seed(seed)
    ops = []
    mem = TestMemory(mem_base, mem_bytes, mem_block_size, self.debug)
    # compute block addresses for all blocks mapping to set 0
    blocks = [i*sets*mem_block_size for i in range(assoc*mem_size)]

    store_val = 1
    for i in range(N):
      # pick access parameters
      store = random.choice([True, False])
      size = random.choice([1, 2, 4, 8])
      size_shift = int(math.log(size, 2))
      # determine type of request (cached or uncached)
      uncached_req = 0
      if lce_mode == 2:
        uncached_req = random.choice([0,1])
      elif lce_mode == 1:
        uncached_req = 1

      # choose which cache block in memory to target
      block = random.choice(blocks)
      # choose offset in cache block based on size of access ("word" size for this access)
      words = mem_block_size / size
      word = random.randint(0, words-1)
      # build the address
      addr = block + (word << size_shift) + mem_base
      mem.check_valid_addr(addr)

      val = 0
      if store:
        # NOTE: the value being stored will be truncated to size number of bytes
        store_val_trunc = store_val
        if (size < 8):
          store_val_trunc = store_val_trunc & ~(~0 << (size*8))
        mem.write_memory(addr, store_val_trunc, size)
        val = store_val_trunc
        store_val += 1
      else:
        val = mem.read_memory(addr, size)

      ops.append((store, addr, size, uncached_req, val))

    return ops

  # Random loads and stores to a single cache block
  def blockTest(self, N=16, mem_base=0, block_size=64, seed=0):
    return self.randomTest(N, mem_base, block_size, block_size, seed, 0)

  # Random Test generator
  # N is number of operations
  # lce_mode = 0, 1, or 2 -> 0 = cached only, 1 = uncached only, 2 = mixed
  def randomTest(self, N=16, mem_base=0, mem_bytes=1024, mem_block_size=64, seed=0, lce_mode=0):
    # test begin
    random.seed(seed)
    ops = []
    mem = TestMemory(mem_base, mem_bytes, mem_block_size, self.debug)
    mem_blocks = mem_bytes / mem_block_size
    b = int(math.log(mem_block_size, 2))
    store_val = 1
    for i in range(N):
      # pick access parameters
      store = random.choice([True, False])
      size = random.choice([1, 2, 4, 8])
      size_shift = int(math.log(size, 2))
      # determine type of request (cached or uncached)
      uncached_req = 0
      if lce_mode == 2:
        uncached_req = random.choice([0,1])
      elif lce_mode == 1:
        uncached_req = 1

      # choose which cache block in memory to target
      block = random.randint(0, mem_blocks-1)
      # choose offset in cache block based on size of access ("word" size for this access)
      words = mem_block_size / size
      word = random.randint(0, words-1)
      # build the address
      addr = (block << b) + (word << size_shift) + mem_base
      mem.check_valid_addr(addr)

      val = 0
      if store:
        # NOTE: the value being stored will be truncated to size number of bytes
        store_val_trunc = store_val
        if (size < 8):
          store_val_trunc = store_val_trunc & ~(~0 << (size*8))
        mem.write_memory(addr, store_val_trunc, size)
        val = store_val_trunc
        store_val += 1
      else:
        val = mem.read_memory(addr, size)

      ops.append((store, addr, size, uncached_req, val))

    # return the test operations
    return ops


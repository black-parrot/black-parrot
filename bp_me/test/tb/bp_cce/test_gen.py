from __future__ import print_function
import sys
import random
import math
import os
from trace_gen import TraceGen
from test_memory import TestMemory

# Test Generator class
# a test is defined as a sequence of command operation tuples
# Each operation tuple is: (command, address/cycles, size in bytes, uncached, value)
# Command is one of 'store', 'load', 'wait'
# address/cycles is either the address for the load/store or the number of cycles for wait
# size is in bytes, and must be 1, 2, 4, or 8 (ignored for wait)
# If uncached=1, op is an uncached access, else it is a cached access (ignored for wait)
# value is the store value or expected load value (ignored for wait)

class TestGenerator(object):
  def __init__(self, paddr_width=40, data_width=64, debug=False):
    self.paddr_width = paddr_width
    self.data_width = data_width
    self.tg = TraceGen(addr_width_p=self.paddr_width, data_width_p=self.data_width)
    self.debug = debug

  def eprint(self, *args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

  # Write ops to file
  # ops is a dictionary, indexed by thread ID (integer) as key
  # the values are lists of command tuples
  def generateTrace(self, ops, out_dir, out_file_base):
    for lce in ops:
      file_name = '{0}_{1}.tr'.format(out_file_base, lce)
      with open(os.path.join(out_dir, file_name), 'w') as lce_trace_file:
        # preamble
        lce_trace_file.write(self.tg.print_header())
        lce_trace_file.write(self.tg.wait(100))
        # commands
        for (cmd,addr,size,uc,val) in ops[lce]:
          if cmd == 'store':
            lce_trace_file.write(self.tg.send_store(size=size, addr=addr, data=val, uc=uc))
            lce_trace_file.write(self.tg.recv_store(size=size, addr=addr, uc=uc))
          elif cmd == 'load':
            lce_trace_file.write(self.tg.send_load(signed=0, size=size, addr=addr, uc=uc))
            lce_trace_file.write(self.tg.recv_load(signed=0, size=size, addr=addr, data=val, uc=uc))
          elif cmd == 'wait':
            # addr is used as number of cycles
            lce_trace_file.write(self.tg.wait(addr))
        # test end
        lce_trace_file.write(self.tg.test_done())

  # read trace from file
  def readTrace(self, infile):
    ops = {}
    with open(infile, 'r') as trace_file:
      for raw_line in trace_file:
        trim_line = raw_line.strip()
        if not trim_line.startswith('#') and trim_line:
          # cmd = thread: load/store addr size uc value
          # cmd = thread: wait cycles
          line = [x.strip() for x in trim_line.split(':')]
          thread = int(line[0])
          cmd = [x.strip() for x in line[1].split(' ')]
          if not thread in ops:
            ops[thread] = []

          if cmd[0] == 'wait':
            cycles = int(cmd[1])
            ops[thread].append(('wait', cycles, 0, 0, 0))
          else:
            op = cmd[0]
            if not (op == 'store' or op == 'load'):
              self.eprint('[ME TraceGen]: unrecognized op in trace file: {0}'.format(op))
              return {}
            addr = int(cmd[1], 16)
            size = int(cmd[2])
            uc = int(cmd[3])
            if (cmd[4].startswith('0x')):
              value = int(cmd[4], 16)
            else:
              value = int(cmd[4])
            ops[thread].append((op, addr, size, uc, value))
    return ops

  # Random Test generator
  # N is number of operations
  # lce_mode = 0, 1, or 2 -> 0 = cached only, 1 = uncached only, 2 = mixed
  # cache_sets is number of sets in the cache
  # lce is number of LCEs to use (multi-LCE requires axe=True)
  # test_sets is number of cache sets to use in test
  # test_ways is number of cache ways per set to use in test
  def randomTest(self, N=16, mem_base=0, cache_sets=64, block_size=64, seed=0, lce_mode=0, lce=1
                 ,test_sets=64, test_ways=2, axe=False):

    random.seed(seed)
    ops = {i:[] for i in range(lce)}

    # test memory - large enough for full number of cache sets across test_ways number of ways
    mem_blocks = (cache_sets * test_ways)
    mem_bytes = (mem_blocks * block_size)
    mem = TestMemory(mem_base, mem_bytes, block_size, self.debug)

    # generate collection of block IDs that are used for testing
    # start with set 0 and use test_sets number of sets across test_ways number of ways
    test_blocks = [s + w*cache_sets for s in range(test_sets) for w in range(test_ways)]

    b = int(math.log(block_size, 2))
    store_val = 1

    for i in range(N):
      for l in range(lce):
        # pick access parameters
        store = random.choice([True, False])
        # all accesses are size 8B for AXE tracing
        size = 8 if axe else random.choice([1, 2, 4, 8])
        size_shift = int(math.log(size, 2))
        # determine type of request (cached or uncached)
        uncached_req = 0
        if lce_mode == 2:
          uncached_req = random.choice([0,1])
        elif lce_mode == 1:
          uncached_req = 1

        # choose which cache block to access
        block = random.choice(test_blocks)
        # choose offset in cache block based on size of access ("word" size for this access)
        words = block_size / size
        word = random.randint(0, words-1)
        # build the address
        addr = (block << b) + (word << size_shift) + mem_base
        mem.check_valid_addr(addr)

        val = 0
        if store:
          # note: the value being stored will be truncated to size number of bytes
          store_val_trunc = store_val
          if (size < 8):
            store_val_trunc = store_val_trunc & ~(~0 << (size*8))
          if not axe:
            mem.write_memory(addr, store_val_trunc, size)
          val = store_val_trunc
          store_val += 1
        elif not axe:
          val = mem.read_memory(addr, size)

        ops[l].append(('store' if store else 'load', addr, size, uncached_req, val))

    # return the test operations
    return ops


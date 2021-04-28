from __future__ import print_function
import random
import math
from argparse import ArgumentParser
from test_gen import TestGenerator

parser = ArgumentParser(description='ME Trace Replay')

# basic test arguments
parser.add_argument('-n', '--num-instr', dest='num_instr', type=int, default=8,
                    help='Number of memory operations to execute')
parser.add_argument('-s', '--seed', dest='seed', type=int, default=1,
                    help='random number generator seed')
parser.add_argument('--test', dest='test', type=int, default=0,
                    help='Test selector: 0 = random, 1 = store test, 2 = load test, 3 = set test')

# operating mode
parser.add_argument('--lce-mode', dest='lce_mode', type=int, default=0,
                    help='0 = cached requests, 1 = uncached requests, 2 = mixed (only if cce-mode == 0)')
parser.add_argument('--cce-mode', dest='cce_mode', type=int, default=0,
                    help='0 = normal, 1 = uncached only (requires lce-mode == 1)')


# system, memory, and cache parameters
parser.add_argument('-m', dest='paddr_width', type=int, default=40,
                    help='Physical address width in bits')
parser.add_argument('-b', dest='block_size', type=int, default=64,
                    help='block size in bytes (for cache and memory)')
parser.add_argument('-e', dest='assoc', type=int, default=8,
                    help='cache associativity')
parser.add_argument('--sets', dest='sets', type=int, default=64,
                    help='cache sets')
parser.add_argument('-d', dest='dword_size', type=int, default=64,
                    help='dword size')

# The basic memory map is only DRAM is cacheable and all other memory uncacheable
# Uncacheable accesses may be issued to DRAM, and are kept coherent by the CCE.
parser.add_argument('--dram-offset', dest='dram_offset', type=int, default=0x80000000,
                    help='base address of cacheable memory (DRAM)')
parser.add_argument('--dram-high', dest='dram_high', type=int, default=0x100000000,
                    help='DRAM upper limit (i.e., first address above DRAM)')
parser.add_argument('--mem-size', dest='mem_size', type=int, default=2,
                    help='Size of backing memory, given as integer multiple of $ size')


if __name__ == '__main__':
  args = parser.parse_args()

  # LCE and CCE operating modes
  cce_mode = 1 if (args.cce_mode == 1) else 0
  lce_uncached = 1 if (args.lce_mode == 1) else 0
  lce_mixed = 1 if (args.lce_mode == 2) else 0
  lce_cached = 1 if (args.lce_mode == 0) else 0
  # Validate modes
  assert (args.lce_mode >= 0 and args.lce_mode <= 2), '[ME TraceGen]: LCE mode invalid'
  assert (args.cce_mode >= 0 and args.cce_mode <= 1), '[ME TraceGen]: CCE mode invalid'
  # if CCE mode is uncached, LCE mode must be uncached only
  # if CCE mode is normal, LCE mode can be any
  if cce_mode:
    assert (lce_uncached == 1), '[ME TraceGen]: LCE mode must be uncached only if CCE mode is uncached only'

  # Cache parameters
  block_size = args.block_size
  dword_size = args.dword_size
  cache_assoc = args.assoc
  cache_sets = args.sets
  cache_blocks = cache_assoc*cache_sets
  cache_size = cache_blocks * block_size
  assert (cache_sets > 1), '[ME TraceGen]: direct mapped cache not supported'

  # Memory parameters
  mem_bytes = cache_size * args.mem_size
  mem_blocks = cache_blocks * args.mem_size
  mem_base = args.dram_offset
  mem_high = mem_base + mem_bytes

  # bits in address
  s = int(math.log(cache_sets, 2))
  b = int(math.log(block_size, 2))
  t = args.paddr_width - s - b

  # test generation
  test = args.test
  assert (test >= 0 and test <= 5), '[ME TraceGen]: invalid test selected'
  testGen = TestGenerator(paddr_width=args.paddr_width, data_width=args.dword_size)
  ops = []
  if test == 0:
    ops = testGen.randomTest(N=args.num_instr, mem_base=mem_base, mem_bytes=mem_bytes, mem_block_size=block_size, seed=args.seed, lce_mode=args.lce_mode)
  elif test == 1:
    assert (cce_mode == 0), '[ME TraceGen]: Store Test requires normal CCE mode'
    ops = testGen.storeTest(mem_base)
  elif test == 2:
    assert (cce_mode == 0), '[ME TraceGen]: Load Test requires normal CCE mode'
    ops = testGen.loadTest(mem_base)
  elif test == 3:
    assert (cce_mode == 0), '[ME TraceGen]: Set Test requires normal CCE mode'
    ops = testGen.setTest(mem_base, cache_assoc)
  elif test == 4:
    assert (cce_mode == 0), '[ME TraceGen]: Block Test requires normal CCE mode'
    ops = testGen.blockTest(N=args.num_instr, mem_base=mem_base, block_size=block_size, seed=args.seed)
  elif test == 5:
    assert (cce_mode == 0), '[ME TraceGen]: Set Hammer Test requires normal CCE mode'
    ops = testGen.setHammerTest(N=args.num_instr
                                , mem_base=mem_base
                                , mem_bytes=mem_bytes
                                , mem_block_size=block_size
                                , mem_size=args.mem_size
                                , assoc=cache_assoc
                                , sets=cache_sets
                                , seed=args.seed
                                , lce_mode=args.lce_mode)

  # output test trace
  testGen.generateTrace(ops)


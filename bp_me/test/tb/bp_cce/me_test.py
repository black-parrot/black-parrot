from __future__ import print_function
import random
import math
import os
from argparse import ArgumentParser
from test_gen import TestGenerator

parser = ArgumentParser(description='ME Trace Replay')

# output arguments
parser.add_argument('--dir', dest='dir', type=str, default='.',
                    help='Output directory for traces')
parser.add_argument('--file-name', dest='file_name', type=str, default='test',
                    help='Base file name, without extension for traces')

# basic test arguments
parser.add_argument('-n', '--num-instr', dest='num_instr', type=int, default=8,
                    help='Number of memory operations to execute')
parser.add_argument('--seed', dest='seed', type=int, default=1,
                    help='random number generator seed')
parser.add_argument('--test', dest='test', type=int, default=0, choices=range(0,7), metavar='[0-6]',
                    help="""0 = random, 1 = store test, 2 = load test, 3 = set test,
                    4 = block test, 5 = cache hammer test, 6 = AXE test""")
parser.add_argument('-l', '--lce', dest='num_lce', type=int, default=1,
                    help='Number of LCEs')

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
parser.add_argument('-s', dest='sets', type=int, default=64,
                    help='cache sets')
parser.add_argument('-d', dest='dword_size', type=int, default=64,
                    help='dword size')

# The basic memory map is only DRAM is cacheable and all other memory uncacheable
# Uncacheable accesses may be issued to DRAM, and are kept coherent by the CCE.
parser.add_argument('--mem-base', dest='mem_base', type=int, default=0x80000000,
                    help='base address of memory')
parser.add_argument('--mem-blocks', dest='mem_blocks', type=int, default=0,
                    help='Number of memory blocks to use, starting at the DRAM offset')

# debug mode
parser.add_argument('--debug', dest='debug', action='store_true', default=False,
                    help='Enable debug prints')

if __name__ == '__main__':
  args = parser.parse_args()

  # check output path
  out_dir = os.path.abspath(os.path.expanduser(args.dir))
  assert (os.path.isdir(out_dir)), '[ME TraceGen]: Invalid output directory'

  # verify number of LCEs
  assert (args.num_lce in [1, 2, 4, 8]), '[ME TraceGen]: Invalid number of LCEs'

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
  mem_blocks = cache_blocks*2 if (args.mem_blocks == 0) else args.mem_blocks
  mem_bytes = block_size * mem_blocks
  mem_base = args.mem_base

  # bits in address
  s = int(math.log(cache_sets, 2))
  b = int(math.log(block_size, 2))
  t = args.paddr_width - s - b

  # test generation
  test = args.test
  assert (test >= 0 and test <= 6), '[ME TraceGen]: invalid test selected'
  testGen = TestGenerator(paddr_width=args.paddr_width
                          , data_width=args.dword_size
                          , num_lce=args.num_lce
                          , out_dir=out_dir
                          , trace_file=args.file_name
                          , debug=args.debug)

  ops = {}
  if test == 0:
    ops[0] = testGen.randomTest(N=args.num_instr, mem_base=mem_base, mem_bytes=mem_bytes, mem_block_size=block_size, seed=args.seed, lce_mode=args.lce_mode)
  elif test == 1:
    assert (cce_mode == 0), '[ME TraceGen]: Store Test requires normal CCE mode'
    ops[0] = testGen.storeTest(mem_base)
  elif test == 2:
    assert (cce_mode == 0), '[ME TraceGen]: Load Test requires normal CCE mode'
    ops[0] = testGen.loadTest(mem_base)
  elif test == 3:
    assert (cce_mode == 0), '[ME TraceGen]: Set Test requires normal CCE mode'
    ops[0] = testGen.setTest(mem_base, cache_assoc)
  elif test == 4:
    assert (cce_mode == 0), '[ME TraceGen]: Block Test requires normal CCE mode'
    ops[0] = testGen.blockTest(N=args.num_instr, mem_base=mem_base, block_size=block_size, seed=args.seed)
  elif test == 5:
    assert (cce_mode == 0), '[ME TraceGen]: Set Hammer Test requires normal CCE mode'
    ops[0] = testGen.setHammerTest(N=args.num_instr
                                   , mem_base=mem_base
                                   , mem_bytes=mem_bytes
                                   , mem_block_size=block_size
                                   , mem_blocks=cache_assoc*2
                                   , assoc=cache_assoc
                                   , sets=cache_sets
                                   , seed=args.seed
                                   , lce_mode=args.lce_mode
                                   , target_set=None)
  elif test == 6:
    ops = testGen.axeTest(lce=args.num_lce
                          , N=args.num_instr
                          , mem_base=mem_base
                          , mem_bytes=mem_bytes
                          , mem_block_size=block_size
                          , seed=args.seed
                          , lce_mode=args.lce_mode)

  # output test trace
  testGen.generateTrace(ops)


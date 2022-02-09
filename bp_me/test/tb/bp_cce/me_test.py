from __future__ import print_function
import random
import math
import os
from argparse import ArgumentParser
from test_gen import TestGenerator

parser = ArgumentParser(description='ME Trace Replay')

# output arguments
parser.add_argument('--out-dir', dest='outdir', type=str, default='.',
                    help='Output directory for traces')
parser.add_argument('--out-file', dest='outfile', type=str, default='test',
                    help='Base file name, without extension for traces')

# input trace
parser.add_argument('--in-dir', dest='indir', type=str, default='.',
                    help='Input directory for custom trace')
parser.add_argument('--in-file', dest='infile', type=str, default='test.trace',
                    help='Input file containing custom trace')

# basic test options
parser.add_argument('--test', dest='test', type=int, default=0,
                    help="""0 = random, 1 = AXE random, 2 = trace file,
                    3 = AXE set hammer""")
parser.add_argument('--seed', dest='seed', type=int, default=1,
                    help='random number generator seed')
parser.add_argument('-n', '--num-instr', dest='num_instr', type=int, default=8,
                    help='Number of memory operations to execute')

# coherence system operating modes
parser.add_argument('--lce-mode', dest='lce_mode', type=int, default=0,
                    help='0 = cached requests, 1 = uncached requests, 2 = mixed (only if cce-mode == 0)')
parser.add_argument('--cce-mode', dest='cce_mode', type=int, default=0,
                    help='0 = normal, 1 = uncached only (requires lce-mode == 1)')

# system, memory, and cache parameters
parser.add_argument('-l', '--lce', dest='num_lce', type=int, default=1,
                    help='Number of LCEs')
parser.add_argument('-m', dest='paddr_width', type=int, default=40,
                    help='Physical address width in bits')
parser.add_argument('-b', dest='block_size', type=int, default=64,
                    help='block size in bytes (for cache and memory)')
parser.add_argument('-e', dest='assoc', type=int, default=2,
                    help='cache associativity')
parser.add_argument('-s', dest='sets', type=int, default=64,
                    help='cache sets')

# The basic memory map is only DRAM is cacheable and all other memory uncacheable
# Uncacheable accesses may be issued to DRAM, and are kept coherent by the CCE.
parser.add_argument('--mem-base', dest='mem_base', type=int, default=0x80000000,
                    help='base address of memory')
# number of memory blocks is computed as args.mem_blocks * (cache_assoc*cache_sets)
parser.add_argument('--mem-blocks', dest='mem_blocks', type=int, default=2,
                    help='Number of memory blocks, as factor of cache size')

# debug mode
parser.add_argument('--debug', dest='debug', action='store_true', default=False,
                    help='Enable debug prints')

if __name__ == '__main__':
  args = parser.parse_args()

  test = args.test

  # check output path
  outdir = os.path.abspath(os.path.expanduser(args.outdir))
  assert (os.path.isdir(outdir)), '[ME TraceGen]: Invalid output directory'

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
  data_width = 64
  block_size = args.block_size
  cache_assoc = args.assoc
  cache_sets = args.sets
  cache_blocks = (cache_assoc * cache_sets)
  cache_size = (cache_blocks * block_size)

  # Memory parameters
  mem_blocks = (cache_blocks * 2) if (args.mem_blocks == 0) else (cache_blocks * args.mem_blocks)
  mem_bytes = (block_size * mem_blocks)
  mem_base = args.mem_base

  # test generation
  testGen = TestGenerator(paddr_width=args.paddr_width, data_width=data_width, debug=args.debug)

  ops = {}
  if test == 0:
    ops = testGen.randomTest(N=args.num_instr
                             , mem_base=mem_base
                             , mem_bytes=mem_bytes
                             , block_size=block_size
                             , seed=args.seed
                             , lce_mode=args.lce_mode)

  elif test == 1:
    ops = testGen.randomTest(N=args.num_instr
                             , mem_base=mem_base
                             , mem_bytes=mem_bytes
                             , block_size=block_size
                             , seed=args.seed
                             , lce_mode=args.lce_mode
                             , lce=args.num_lce
                             , axe=True)

  elif test == 2:
    # read test from trace file
    indir = os.path.abspath(os.path.expanduser(args.indir))
    infile = os.path.join(indir, args.infile)
    assert (os.path.isdir(indir)), '[ME TraceGen]: Invalid input directory'
    assert (os.path.exists(infile)), '[ME TraceGen]: Invalid input file'
    ops = testGen.readTrace(infile)

  elif test == 3:
    ops = testGen.setTest(N=args.num_instr
                          , mem_base=mem_base
                          , block_size=block_size
                          , cache_sets=cache_sets
                          , cache_assoc=cache_assoc
                          , target_set=0
                          , seed=args.seed
                          , lce_mode=args.lce_mode
                          , lce=args.num_lce
                          , axe=True)

  # output test trace
  testGen.generateTrace(ops, outdir, args.outfile)


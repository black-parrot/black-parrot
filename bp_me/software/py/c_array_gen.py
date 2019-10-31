from __future__ import print_function
from argparse import ArgumentParser
import random

parser = ArgumentParser()
parser.add_argument('-n', dest='n', default=1, type=int, required=True,
                    help='Number of sub-arrays')
parser.add_argument('-a', dest='arr_len', default=1, type=int, required=True,
                    help='Length of sub-arrays')
parser.add_argument('-r', dest='rand_max', default=4096, type=int, required=False,
                    help='Max random value')

args = parser.parse_args()

print("#define DATA_LEN " + str(args.n*args.arr_len))
print("uint32_t DATA[DATA_LEN] __attribute__((aligned(64)))= {")
for i in xrange(args.n):
  print("  ", end='')
  for j in xrange(args.arr_len-1):
    print("{0}, ".format(random.randint(0,args.rand_max)), end='')
  if i == args.n-1:
    print("{0}".format(random.randint(0,args.rand_max)))
  else:
    print("{0},".format(random.randint(0,args.rand_max)))

print("};")

from argparse import ArgumentParser
import os
import sys

parser = ArgumentParser(description='CCE Microcode ROM generator')
parser.add_argument('-i', dest='in_file', type=str, default=None,
                    help='Input assembly file (.S)', required=True)
#parser.add_argument('--outdir', dest='outdir', type=str, default='./out',
#                    help='Output directory path')

args = parser.parse_args()

with open(os.path.abspath(args.in_file), 'r') as f:
  addr = 0
  for line in f:
    if not line.strip():
      print
    elif line.strip()[0] == '#':
      print(line.strip())
    elif line.strip():
      print('({0:02X}) {1}'.format(addr, line.strip()))
      addr += 1

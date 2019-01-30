import os
import sys
from argparse import ArgumentParser

parser = ArgumentParser('checker.py')
parser.add_argument('-d', dest='dir', type=str, default=None, required=True, help='input directory')
parser.add_argument('-c', dest='len', type=int, default=100, required=False, help='max line length')
args = parser.parse_args()

for root, dirs, files in os.walk(os.path.abspath(args.dir)):
  for f in files:
    if f.endswith('.v'):
      fpath = os.path.join(root, f)
      i = 1
      with open(fpath) as fread:
        for line in fread:
          l = line.strip()
          if len(l) > args.len:
            print "{0}: {1}".format(i, l)
          i = i+1

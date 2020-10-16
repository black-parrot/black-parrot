""" 
  This file is used to convert the CCE ucode from a 34-bit binary representation to a 64-bit hexadecimal representation.
  This makes it easier to link the CCE ucode into the bootrom
"""

import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--ucode', dest='ucode_file', type=str, required=True, help='CCE ucode file')
parser.add_argument('--path', dest='path', type=str, required=True, help='Output path')
args = parser.parse_args()

with open(args.ucode_file, 'r') as rf:
  lines = rf.readlines()
  for line in lines:
    line = line.strip()
    hex64 = str(hex(int(line.zfill(64), 2)))[2:].zfill(16)
    reverse_bytes = hex64[::-1]
    reversed_bytes = ''
    for i in range(0, 15, 2):
      reversed_bytes = reversed_bytes + reverse_bytes[i:i+2][::-1]
    print(reversed_bytes)
  print("FFFFFFFFFFFFFFFF")

rf.close()

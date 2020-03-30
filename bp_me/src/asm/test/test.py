from __future__ import print_function
from argparse import ArgumentParser
import os
import sys

parser = ArgumentParser(description='CCE Microcode Test Code Generator')
parser.add_argument('-o', '--outfile', dest='outfile', type=str, default='test.S',
                    help='Output assembly file')

args = parser.parse_args()

gprs = ['r0','r1','r2','r3','r4','r5','r6','r7']
gpr_pairs = [(x,y) for x in gprs for y in gprs]

alu_2reg_ops = ['add', 'sub', 'lsh', 'rsh', 'and', 'or', 'xor']
alu_imm_ops = ['addi', 'subi', 'lshi', 'rshi']
alu_unary_ops = ['neg', 'inc', 'dec', 'not']

br_2reg_ops = ['beq', 'bne', 'ble', 'bge', 'blt', 'bgt']
br_imm_ops = ['beqi', 'bneqi']
br_1reg_ops = ['bz', 'bnz']
# bi
# bs, bss, bsi
# bz, bnz

def nop(f):
  f.write('nop\n')

def label(f, l):
  f.write(l)

with open(os.path.abspath(args.outfile), 'w') as f:
  label(f, 'start: ')
  nop(f)

  for op in alu_2reg_ops:
    for opds in gpr_pairs:
      for dst in gprs:
        f.write('{0} {1} {2} {3}\n'.format(op, opds[0], opds[1], dst))

  for op in alu_imm_ops:
    f.write('{0} r0 1 r1\n'.format(op))

  for op in alu_unary_ops:
    f.write('{0} r2\n'.format(op))

  for op in br_2reg_ops:
    f.write('{0} r0 r1 start\n'.format(op))

  for op in br_imm_ops:
    f.write('{0} r0 2 start\n'.format(op))

  for op in br_1reg_ops:
    f.write('{0} r1 start\n'.format(op))

  f.write('bi start\n')

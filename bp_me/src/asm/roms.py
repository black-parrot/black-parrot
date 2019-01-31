from argparse import ArgumentParser
import os
import sys

parser = ArgumentParser(description='CCE Microcode ROM generator')
parser.add_argument('-i', dest='in_file', type=str, default=None,
                    help='Input assembly file (.S)', required=True)
parser.add_argument('-N', dest='n_lce', type=int, nargs='+', help='Number of LCEs')
parser.add_argument('-E', dest='lce_assoc', type=int, nargs='+', help='LCE Associativity')
parser.add_argument('-S', dest='lce_sets', type=int, nargs='+', help='Number of Sets in each LCE')
parser.add_argument('-C', dest='n_cce', type=int, nargs='+', help='Number of CCEs')
parser.add_argument('-W', dest='n_wg', type=int, nargs='+', help='Number of Way-Groups per CCE')

parser.add_argument('--bsg', dest='bsg', type=str, default='../../../bsg_ip_cores/bsg_mem',
                    help='Path to bsg_ip_cores/bsg_mem')
parser.add_argument('--script', dest='script', type=str, default='bsg_ascii_to_rom.py',
                    help='Name of ROM generator script')

args = parser.parse_args()

# get the args, open the file
n_cce = args.n_cce if not (args.n_cce is None) else [1]
n_lce = args.n_lce if not(args.n_lce is None) else [1]
lce_sets = args.lce_sets if not (args.lce_sets is None) else [16]
lce_assoc = args.lce_assoc if not(args.lce_assoc is None) else [8]

n_wg = sorted(list(set([x/y for x in lce_sets for y in n_cce]))) if args.n_wg is None else args.n_wg

file_abs_path = os.path.abspath(args.in_file)
file_name = os.path.split(file_abs_path)[1]
file_base = file_name.split('.')[0]

pre_file = os.path.join(os.path.split(file_abs_path)[0], file_base + '.pre')
mem_file = os.path.join(os.path.split(file_abs_path)[0], file_base + '.mem')

for w in n_wg:
  for n in n_lce:
      for e in lce_assoc:
        cflags = 'CFLAGS="-DN_WG={0} -DN_LCE={1} -DLCE_ASSOC={2}"'.format(w, n, e)
        pre_cmd = 'make {0} {1}'.format(cflags, mem_file)
        os.system(pre_cmd)
        rom_file_path = os.path.join(os.path.split(file_abs_path)[0], 'bp_cce_inst_rom_{0}_lce{1}_wg{2}_assoc{3}.v'.format(file_base, n, w, e))
        bsg_script = os.path.join(os.path.abspath(args.bsg), args.script)
        #rom_module = 'bp_cce_inst_rom_lce{0}_wg{1}_assoc{2}'.format(n, w, e)
        rom_module = 'bp_cce_inst_rom'
        rom_cmd = 'python2 {0} {1} {2} > {3}'.format(bsg_script, mem_file, rom_module, rom_file_path)
        os.system(rom_cmd)
        rm_cmd = 'rm {0}'.format(mem_file)
        os.system(rm_cmd)

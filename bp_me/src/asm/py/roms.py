from argparse import ArgumentParser
import os
import sys

parser = ArgumentParser(description='CCE Microcode ROM generator')
parser.add_argument('-i', dest='in_file', type=str, default=None,
                    help='Input assembly file (.S)', required=True)

parser.add_argument('--bsg', dest='bsg', type=str, default='./basejump_stl/bsg_mem',
                    help='Path to basejump_stl/bsg_mem')
parser.add_argument('--script', dest='script', type=str, default='bsg_ascii_to_rom.py',
                    help='Name of ROM generator script')
parser.add_argument('--module', dest='module', type=str, default='bp_cce_inst_rom',
                    help='CCE Instruction ROM module name')
parser.add_argument('--outdir', dest='outdir', type=str, default='./out',
                    help='Output directory path')

# get the args, open the file
args = parser.parse_args()

file_abs_path = os.path.abspath(args.in_file)
file_name = os.path.split(file_abs_path)[1]
file_base = file_name.split('.')[0]

pre_file = os.path.join(os.path.split(file_abs_path)[0], file_base + '.pre')
mem_file = os.path.join(os.path.split(file_abs_path)[0], file_base + '.mem')

out_dir = os.path.abspath(args.outdir)
if not os.path.exists(out_dir):
  os.makedirs(out_dir)

pre_cmd = 'make {0}'.format(mem_file)
os.system(pre_cmd)
rom_file_path = os.path.join(out_dir, 'bp_cce_inst_rom_{0}.v'.format(file_base))
mem_file_path = os.path.join(out_dir, 'bp_cce_inst_rom_{0}.mem'.format(file_base))
cp_cmd = 'cp {0} {1}'.format(mem_file, mem_file_path)
os.system(cp_cmd)
bin_file_path = os.path.join(out_dir, 'bp_cce_inst_rom_{0}.bin'.format(file_base))
bin_cmd = 'xxd -r -p {0} > {1}'.format(mem_file_path, bin_file_path)
os.system(bin_cmd)
bsg_script = os.path.join(os.path.abspath(args.bsg), args.script)
rom_module=args.module
rom_cmd = 'python2 {0} {1} {2} zero > {3}'.format(bsg_script, mem_file, rom_module, rom_file_path)
os.system(rom_cmd)
rm_cmd = 'rm {0}'.format(mem_file)
os.system(rm_cmd)


import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--ucode', dest='ucode_file', type=str, required=True, help='CCE ucode file')
parser.add_argument('--path', dest='path', type=str, required=True, help='Output path')
args = parser.parse_args()

out_file = args.path + "/cce_ucode.mem"
wf = open(out_file, 'w')
with open(args.ucode_file, 'r') as rf:
  lines = rf.readlines()
  for line in lines:
    line = line.strip()
    hex64 = hex(int(line.zfill(64), 2))
    wf.write(str(hex64)[2:].zfill(16))
    wf.write("\n")
  wf.write("FFFFFFFFFFFFFFFF")
  wf.write("\n")

rf.close()
wf.close()

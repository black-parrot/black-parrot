#!/usr/bin/python
import sys

def int2bin(num, width):
  spec = '{fill}{align}{width}{type}'.format(
      fill='0', align='>', width=width, type='b')
  return format(num, spec)


def hex2bin(hex, width):
  integer = int(hex, 16)
  return int2bin(integer, width)


def sendBinary(send):
  binary = '# ' + '\t branch target: ' + \
      str(send[0]) + '\t branch taken: ' + str(send[1]) + '\n'
  binary += '0001_' + hex2bin(send[0], 64) + '_' + \
                              hex2bin(send[1], 1) + '_' + hex2bin('0', 31)

  return binary


def recvBinary(recv):
  binary = '# ' + '\tpc: ' + str(recv[0]) + '\t instr: ' + str(recv[1]) + '\n'
  binary += '0010_' + hex2bin(recv[0], 64) + '_' + hex2bin(recv[1], 32)

  return binary

def tr_done():
  binary  = '# Done' + '\n'
  binary += '0011_' + hex2bin(str(0), 64) + '_' + hex2bin(str(0), 32)

  return binary

name = str(sys.argv[1])
infile = open(name + ".spike", "r")
outfile = open(name + ".tr", "w")

outfile.write("# Trace format: recv (4bit)_pc          (64 bit)_instruction(32 bits)\n")
outfile.write("#               send (4bit)_branchtarget(64 bit)_branchtaken(1   bit)_padding(31 bits)\n")


msg = []

lines = infile.readlines()

pc_list = [line.split()[2] for line in lines if "core" in line] + ["0x0000000000000000"]
pc_idx  = 0

jal_op    = "1101111"
jalr_op   = "1100111"
branch_op = "1100011"

# TODO: More elegant solution
skip_unbooted = True
boot_pc       = "0x0000000080000124"

msg.append(("send", ["0x0000000080000124", "0"]))

for i in xrange(len(lines)-2):
  line = lines[i].rstrip("\n\r").split()
  reg_line = lines[i+1].rstrip("\n\r").split()
  if(len(line) != 0):
    if("ecall" in line):
      break
    if(line[0] == "core" and line[2][:2] == "0x"):
      pc = line[2]

      pc_idx = pc_idx + 1
      if skip_unbooted and boot_pc != pc:
        continue

      skip_unbooted = False
      next_pc = pc_list[pc_idx]
      instr_hex = line[3][1:-1]
      opcode = hex2bin(instr_hex[-2:], 8)[1:]

      if opcode == jal_op or opcode == jalr_op or opcode == branch_op:
        branch_target = next_pc

        if int(branch_target, 16) == int(pc, 16) + 4:
          branch_taken = '0'
        else:
          branch_taken = '1'

        msg.append(("recv", [pc, instr_hex]))
        msg.append(("send", [branch_target, branch_taken]))
      else:
        msg.append(("recv", [pc, instr_hex]))
  
for i in msg:
  if i[0] == "send":
    outfile.write(sendBinary(i[1]) + '\n')
  else:
    outfile.write(recvBinary(i[1]) + '\n')

outfile.write(tr_done() + '\n')
outfile.close()
    
  

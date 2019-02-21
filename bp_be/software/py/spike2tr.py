#!/usr/bin/python
import sys
	
def int2bin(num, width):
	spec = '{fill}{align}{width}{type}'.format(fill='0', align='>', width=width, type='b')
	return format(num, spec)
	
def hex2bin(hex, width):
	integer = int(hex, 16)
	return int2bin(integer, width)

def sendBinary(send):
	binary = '# ' + str(send[2]) + '\n'
	binary += "0001_" 
	for i in xrange(33):
		binary += '0'
	binary += '_' + hex2bin(send[0], 16*4) + '_' + hex2bin(send[1], 8*4)
	return binary

def recvBinary(recv):
	memNotReg = 1 if(recv[0] == '1') else 0
	if(memNotReg):
		binary = '# check mem[' + recv[1] + '] == ' + recv[2] + '\n'
		binary += "0010_1_" + hex2bin(recv[1], 16*4) + '_' + hex2bin(recv[2], 16*4)
	else:
		binary = '# check r' + str(recv[1]) + ' == ' + recv[2] + '\n'
		binary += "0010_0_" 
		for i in xrange(64-5):
			binary += '0'
		binary += '_' + int2bin(recv[1], 5) + '_' + hex2bin(recv[2], 16*4)
	return binary

def tr_finish():
  binary  = '# Finish' + '\n'
  binary += '0100_0_' + hex2bin(str(0), 64) + '_' + hex2bin(str(0), 64)
  return binary

def tr_done():
  binary  = '# Done' + '\n'
  binary += '0011_0_' + hex2bin(str(0), 64) + '_' + hex2bin(str(0), 64)
  return binary


name = str(sys.argv[1])
infile = open(name + ".spike", "r")
outfile = open(name + ".tr", "w")

outfile.write("# Send format: 		0001_pc(64 bit)_instruction(32 bit) \n")
outfile.write("# Receive formats: \n")
outfile.write("# Register write:	0010_0_rd(5 bit)_data(64 bit) \n")
outfile.write("# Memory write:		0010_1_addr(64 bit)_data(64 bit) \n")

send = []
recv = []

start = 0
lines = infile.readlines()

for i in xrange(len(lines)):
	line = lines[i].rstrip("\n\r").split()
	
	if("ecall" in line):
		break
	if(line[0] == "core" and line[2][:2] == "0x"):
		skip = 0
		pc = line[2]
		instr_hex = line[3][1:-1]
		instr_str = ''
		for k in xrange(len(line[4:])):
			instr_str = instr_str + str(line[4+k]) + ' '
		if(pc == "0x0000000080000124"):
			start = 1
		if(instr_str[:3] == "csr"):
			skip = 1;
		if(start and (not skip)):
			send.append([pc, instr_hex, instr_str])
	
	if(line[0] == "rd"):
		if(len(line[2]) == 1):
			regNum = int(line[3])
			wrData = line[4]
		else:
			regNum = int(line[2][1:])
			wrData = line[3]
		if(start and (not skip)):
			recv.append(['0', regNum, wrData])
		
	if(line[0] == "mem" and line[2] == 's'):
		if(start and (not skip)):
			recv.append(['1', line[1], line[3]])
		
#	if(len(recv) == recv_els or i == (len(lines) - 1)):
#		for i in xrange(len(send)):
#			outfile.write(sendBinary(send[i]) + '\n')
#		for i in xrange(len(recv)):
#			outfile.write(recvBinary(recv[i]) + '\n')
#		send = []
#		recv = []


for i in xrange(len(recv)):
	outfile.write(recvBinary(recv[i]) + '\n')

outfile.write(tr_done() + '\n')
outfile.close()

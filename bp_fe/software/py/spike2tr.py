#!/usr/bin/python
import sys
	
def int2bin(num, width):
	spec = '{fill}{align}{width}{type}'.format(fill='0', align='>', width=width, type='b')
	return format(num, spec)
	
def hex2bin(hex, width):
	integer = int(hex, 16)
	return int2bin(integer, width)

def sendBinary(send):
	binary = '# ' + str(send[2]) + '\tpc: ' + str(send[0]) + '\t branch target: ' + str(send[3]) + '\n'
	binary += hex2bin(send[0], 16*4) + '_' + hex2bin(send[1], 8*4)
        if(not send[3]):
                binary += '_' + hex2bin('0x0', 16*4)
        else:
                binary +=  '_' + hex2bin(send[3], 16*4)
        binary += '_' + send[4]
	return binary


name = str(sys.argv[1])
recv_els = int(sys.argv[2])
infile = open(name + ".spike", "r")
outfile = open(name + ".tr", "w")

outfile.write("# Trace format: pc(64 bit)_instruction(32 bit)_branchtarget(64 bit)_branchdirection(1 bit) \n")

send = []
recv = []

lines = infile.readlines()

for i in xrange(len(lines)-2):
	line = lines[i].rstrip("\n\r").split()
	reg_line = lines[i+1].rstrip("\n\r").split()
        next_pc_line = lines[i+2].rstrip("\n\r").split()
	if(len(line) != 0):
          if(line[0] == "core" and line[2][:2] == "0x"):
		pc = line[2]
		instr_hex = line[3][1:-1]
		instr_str = ''
		for k in xrange(len(line[4:])):
			instr_str = instr_str + str(line[4+k]) + ' '
                j_target = ''
                next_pc = next_pc_line[2]
                branch_direction = '0'
                if(line[4] == "jr"):
                        j_target = reg_line[4]
                        if (next_pc == j_target):
                                branch_direction = '1'
                elif(line[4] == "jalr"):
                        if (line[-1][0] == "-"):
                                j_target = hex(int(reg_line[4],16) - int(line[-1][1:],16))
                        else:
                                j_target = hex(int(reg_line[4],16) + int(line[-1],16))
                        if (int(next_pc,16) == int(j_target,16)):
                                branch_direction = '1'
                elif (line[4] == "j" or line[4] == "bnez" or line[4] == "beqz" or line[4] == "bne" or line[4] == "bgez" or line[4] == "jal" or line[4] == "beq" or line[4] == "bge" or line[4] == "bgeu" or line[4] == "blt" or line[4] == "bltu"):
                        if(line[-2] == "+"):
                                j_target = hex(int(pc, 16) + int(line[-1], 16))
                        elif(line[-2] == "-"):
                                j_target = hex(int(pc, 16) - int(line[-1], 16))
                        if (int(next_pc,16) == int(j_target,16)):
                                branch_direction = '1'
	        send.append([pc, instr_hex, instr_str, j_target, branch_direction])
	
for i in xrange(len(send)):
	outfile.write(sendBinary(send[i]) + '\n')

outfile.close()
		
	
	
	
	

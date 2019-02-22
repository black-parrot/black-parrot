#!/usr/bin/python
import sys

# import trace generator for D$
from trace_gen import TraceGen

name = str(sys.argv[1])
infile = open(name + ".spike", "r")
outfile = open(name + ".tr", "w")

print("# Trace format: wait (4bit)_padding(124 bit)\n")
print("#               send (4bit)_size(4 bit)_address(56 bit)_data(64 bit)\n")
print("#               recv (4bit)_size(4 bit)_padding(56 bit)_data(64 bit)\n")

msg = []

lines = infile.readlines()

jal_op    = "1101111"
jalr_op   = "1100111"
branch_op = "1100011"

# TODO: More elegant solution
skip_unbooted = True
boot_pc       = "0x0000000080000124"

tg = TraceGen(addr_width_p=56, data_width_p=64)

for i in xrange(len(lines)-2):
  line = lines[i].rstrip("\n\r").split()
  stld_line = lines[i+1].rstrip("\n\r").split()
  
  if(len(line) != 0):
    if("ecall" in line):
      break
    if(line[0] == "core" and line[2][:2] == "0x"):
      pc = line[2]
      instr = line[3][1:-1]

      if skip_unbooted and boot_pc != pc:
        continue

      skip_unbooted = False

      op_string = lines[i+1].rstrip("\n\r").split()[0]

      # Send a fetch instruction
      tg.send_load(0, 15, int(pc, 16))
      tg.recv_data(int(instr, 16))

      if op_string not in ["lb", "lbu", "lh", "lhu", "lw", "lwu", "ld", "sb", "sh", "sw", "sd"]:
        tg.nop()
        continue

      addr = int(lines[i+5].rstrip("\n\r").split()[1], 16)
      data = int(lines[i+5].rstrip("\n\r").split()[3], 16)

      if op_string == "lb":
        signed = 1
        size = 1
        
        tg.send_load(signed, size, addr)
        tg.recv_data(data)
      elif op_string == "lbu":
        signed = 0
        size = 1

        tg.send_load(signed, size, addr)
        tg.recv_data(data)
      elif op_string == "lh":
        signed = 1
        size = 2
        
        tg.send_load(signed, size, addr)
        tg.recv_data(data)
      elif op_string == "lhu":
        signed = 0
        size = 2
        
        tg.send_load(signed, size, addr)
        tg.recv_data(data)
      elif op_string == "lw":
        signed = 1
        size = 4
        
        tg.send_load(signed, size, addr)
        tg.recv_data(data)
      elif op_string == "lwu":
        signed = 0
        size = 4
        
        tg.send_load(signed, size, addr)
        tg.recv_data(data)
      elif op_string == "ld":
        signed = 0
        size = 8
        
        tg.send_load(signed, size, addr)
        tg.recv_data(data)
      elif op_string == "sb":
        size = 1

        tg.send_store(size, addr, data)
        tg.recv_data(0)
      elif op_string == "sh":
        size = 2

        tg.send_store(size, addr, data)
        tg.recv_data(0)
      elif op_string == "sw":
        size = 4

        tg.send_store(size, addr, data)
        tg.recv_data(0)
      elif op_string == "sd":
        size = 8

        tg.send_store(size, addr, data)
        tg.recv_data(0)

    
tg.test_done()
  

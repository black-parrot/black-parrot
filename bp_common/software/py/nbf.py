#
#   nbf.py
#
#   MEM (.mem) to Network Boot Format (.nbf)
#


import sys
import math
import os
import subprocess


class NBF:

  # constructor
  def __init__(self, config):
    self.config = config

    # input parameters
    self.mem_file = config["mem_file"]
    self.addr_width = 40
    self.block_size = 8

    # process riscv
    self.read_dram()
   
  ##### UTIL FUNCTIONS #####

  # take width and val and convert to hex string
  def get_hexstr(self, val, width):
    return format(val, "0"+str(width)+"x")

  # take x,y coord, epa, data and turn it into nbf format.
  def print_nbf(self, opcode, addr, data):
    line =  self.get_hexstr(opcode, 2) + "_"
    line += self.get_hexstr(addr, int(self.addr_width)//4) + "_"
    line += self.get_hexstr(data, self.block_size*2)
    print(line)
  
  # decide how many bytes to write
  def get_opcode(self, addr):
    opcode = 2
    if addr % 8 == 0:
      opcode = 3
    return opcode

  # read objcopy dumped in 'verilog' format.
  # return in EPA (word addr) and 32-bit value dictionary
  def read_objcopy(self, mem_file):
  
    addr_val = {}
    curr_addr = 0
    addr_step = 0
    count = 0
    assembled_hex = ""

    f = open(mem_file, "r")
    lines = f.readlines()

    for line in lines:
      stripped = line.strip()
      if stripped:
        if stripped.startswith("@"):
          if count != 0:
            addr_val[curr_addr] = int(assembled_hex, 16)
            assembled_hex = ""
            count = 0
          curr_addr = int(stripped.strip("@"), 16)
          addr_step = 1 << self.get_opcode(curr_addr)
        else:
          words = stripped.split()
          for i in range(len(words)):
            assembled_hex = words[i] + assembled_hex
            count += 1
            if count == addr_step:
              addr_val[curr_addr] = int(assembled_hex, 16)
              curr_addr += addr_step
              addr_step = 1 << self.get_opcode(curr_addr)
              assembled_hex = ""
              count = 0
              
    if count != 0:
      addr_val[curr_addr] = int(assembled_hex, 16)

    return addr_val

  # read dram
  def read_dram(self):
    self.dram_data = self.read_objcopy(self.mem_file)    

  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####

 
  # initialize icache
  def init_cache(self):
    for k in sorted(self.dram_data.keys()):
      addr = k
      opcode = self.get_opcode(addr)
      self.print_nbf(opcode, addr, self.dram_data[k])

  # print finish
  # when spmd loader sees, this it stops sending packets.
  def print_finish(self):
    self.print_nbf(0xff, 0x0, 0x0)


  ##### LOADER ROUTINES END  #####  

  # users only have to call this function.
  def dump(self):
    self.init_cache()
    self.print_finish()


#
#   main()
#
if __name__ == "__main__":

  if len(sys.argv) == 2:
    # config setting
    config = {
      "mem_file" : sys.argv[1],
    }
    converter = NBF(config)
    converter.dump()
  else:
    print("USAGE:")
    command = "python nbf.py {program.mem}"
    print(command)


#
#   nbf.py
#
#   MEM (.mem) to Network Boot Format (.nbf)
#

import argparse
import sys
import math
import os
import subprocess


class NBF:

  # constructor
  def __init__(self):
    # input parameters
    self.addr_width = 40
    self.block_size = 8

  ##### UTIL FUNCTIONS #####

  # take width and val and convert to hex string
  def get_hexstr(self, val, width):
    return format(val, "0"+str(width)+"x")

  # take x,y coord, epa, data and turn it into nbf format.
  def print_nbf(self, opcode, addr, data):
    line  = self.get_hexstr(opcode, 2) + "_"
    line += self.get_hexstr(addr, int(self.addr_width)//4) + "_"
    line += self.get_hexstr(data, self.block_size*2)
    print(line)
  
  def get_size(self, addr):
    #if addr % 64 == 0:
    #  size = 6
    #elif addr % 32 == 0:
    #  size = 5
    #elif addr % 16 == 0:
    #  size = 4
    if addr % 8 == 0:
      size = 3
    elif addr % 4 == 0:
      size = 2
    elif addr % 2 == 0:
      size = 1
    else:
      size = 0

    return size

  def get_store_opcode(self, addr):
    size = self.get_size(addr)

    return size

  def get_load_opcode(self, addr):
    size = self.get_size(addr)
    opcode = size | (1 << 4)

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
          addr_step = 1 << self.get_size(curr_addr)
        else:
          words = stripped.split()
          for i in range(len(words)):
            assembled_hex = words[i] + assembled_hex
            count += 1
            if count == addr_step:
              addr_val[curr_addr] = int(assembled_hex, 16)
              curr_addr += addr_step
              addr_step = 1 << self.get_size(curr_addr)
              assembled_hex = ""
              count = 0
              
    if count != 0:
      addr_val[curr_addr] = int(assembled_hex, 16)

    return addr_val

  # read dram
  def read_dram(self, mem_file):
    self.dram_data = self.read_objcopy(mem_file)    

  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####

 
  # initialize icache
  def init_cache(self):
    for k in sorted(self.dram_data.keys()):
      addr = k
      opcode = self.get_store_opcode(addr)
      self.print_nbf(opcode, addr, self.dram_data[k])

  def dram_iter(self, N):
    for k in range(N):
      addr = k << 6
      opcode = 0 | (1 << 4)
      self.print_nbf(opcode, addr, 0)

  # print finish
  # when spmd loader sees, this it stops sending packets.
  def print_finish(self):
    self.print_nbf(0xff, 0x0, 0x0)

  ##### LOADER ROUTINES END  #####  

#
#   main()
#
if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument("--mem_file")
  parser.add_argument("--dram")
  args = parser.parse_args()

  dram_iter = args.dram

  converter = NBF()

  if args.mem_file:
    converter.read_dram(args.mem_file)
    converter.init_cache()
    converter.print_finish()
  elif args.dram:
    converter.dram_iter(int(args.dram))
    converter.print_finish()
  else:
    print("Error: either pass --mem_file or --dram")


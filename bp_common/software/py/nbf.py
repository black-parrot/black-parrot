#
#   nbf.py
#
#   MEM (.mem) to Network Boot Format (.nbf)
#


import sys
import argparse
import math
import os
import subprocess

cfg_base_addr          = 0x200000
cfg_reg_reset          = 0x01
cfg_reg_freeze         = 0x02
cfg_domain_mask        = 0x09
cfg_sac_mask           = 0x0a
cfg_reg_icache_mode    = 0x22
cfg_reg_npc            = 0x40
cfg_reg_dcache_mode    = 0x43
cfg_reg_cce_mode       = 0x81
cfg_mem_base_cce_ucode = 0x8000

cfg_core_offset = 24

class NBF:

  # constructor
  def __init__(self, ncpus, ucode_file, mem_file, checkpoint_file, config, skip_zeros):

    # input parameters
    self.ncpus = ncpus
    self.ucode_file = ucode_file
    self.mem_file = mem_file
    self.config = config
    self.checkpoint_file = checkpoint_file
    self.skip_zeros = skip_zeros
    self.addr_width = 40
    self.block_size = 8

    if self.ucode_file:
      self.ucode = self.read_binary(self.ucode_file)

    # process riscv
    if self.mem_file:
      self.dram_data = self.read_dram(self.mem_file)

    if self.checkpoint_file:
      self.checkpoint = self.read_file(self.checkpoint_file)

  ##### UTIL FUNCTIONS #####

  # take width and val and convert to hex string
  def get_hexstr(self, val, width):
    return format(val, "0"+str(width)+"x")

  # take size, addr, data and turn it into nbf format.
  def print_nbf(self, opcode, addr, data):
    line =  self.get_hexstr(opcode, 2) + "_"
    line += self.get_hexstr(addr, int(self.addr_width)//4) + "_"
    line += self.get_hexstr(data, self.block_size*2)
    print(line)

  def print_nbf_allcores(self, opcode, addr, data):
    for i in range(self.ncpus):
       full_addr = addr + (i << cfg_core_offset)
       self.print_nbf(opcode, full_addr, data)

  # decide how many bytes to write
  def get_opcode(self, addr):
    opcode = 2
    if addr % 8 == 0:
      opcode = 3
    return opcode

  def read_binary(self, file):
    data = []
    f = open(file, "r")
    lines = f.readlines()
    for line in lines:
      line = line.strip()
      data.append(int(line, 2))
    return data

  def read_file(self, file):
    data = []
    f = open(file, "r")
    lines = f.readlines()
    for line in lines:
      data.append(line.strip())
    return data

  # read dram dumped in 'verilog' format.
  # return in EPA (word addr) and 32-bit value dictionary
  def read_dram(self, mem_file):
  
    addr_val = {}
    curr_addr = 0
    addr_step = 0
    count = 0
    assembled_hex = ""
    base_addr = 0x80000000

    f = open(mem_file, "r")
    lines = f.readlines()

    for line in lines:
      stripped = line.strip()
      if stripped:
        if stripped.startswith("@"):
          if count != 0:
            addr_val[base_addr+curr_addr] = int(assembled_hex, 16)
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
              addr_val[base_addr+curr_addr] = int(assembled_hex, 16)
              curr_addr += addr_step
              addr_step = 1 << self.get_opcode(curr_addr)
              assembled_hex = ""
              count = 0
              
    if count != 0:
      addr_val[base_addr+curr_addr] = int(assembled_hex, 16)

    return addr_val

  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####

  # initialize dram
  def init_dram(self):
    for k in sorted(self.dram_data.keys()):
      addr = k
      opcode = self.get_opcode(addr)
      if not(self.skip_zeros and self.dram_data[k] == 0):
        self.print_nbf(opcode, addr, self.dram_data[k])

  # print fence
  # when loader sees this, it waits until all packets are received to proceed
  def print_fence(self):
    self.print_nbf(0xfe, 0x0, 0x0)

  # print finish
  # when spmd loader sees, this it stops sending packets.
  def print_finish(self):
    self.print_nbf(0xff, 0x0, 0x0)


  ##### LOADER ROUTINES END  #####  

  # users only have to call this function.
  def dump(self):

    # Reset set
    self.print_nbf_allcores(3, cfg_base_addr + cfg_reg_reset, 1)
    # Freeze set
    self.print_nbf_allcores(3, cfg_base_addr + cfg_reg_freeze, 1)
    # Reset clear
    self.print_nbf_allcores(3, cfg_base_addr + cfg_reg_reset, 0)
    
    self.print_fence()

    # For regular execution, the CCE ucode and cache/CCE modes are loaded by the bootrom
    if self.config:
      # Write CCE ucode
      if self.ucode_file:
        for core in range(self.ncpus):
          for i in range(len(self.ucode)):
            full_addr = cfg_base_addr + cfg_mem_base_cce_ucode + (core << cfg_core_offset) + i
            self.print_nbf(3, full_addr, self.ucode[i])
       
      # Write I$, D$, and CCE modes
      self.print_nbf_allcores(3, cfg_base_addr + cfg_reg_icache_mode, 1)
      self.print_nbf_allcores(3, cfg_base_addr + cfg_reg_dcache_mode, 1)
      self.print_nbf_allcores(3, cfg_base_addr + cfg_reg_cce_mode, 1)

    self.print_fence()

    # Write DRAM
    if self.mem_file:
      self.init_dram()

    self.print_fence()

    # For checkpoint, load CCE ucode, cache/CCE modes and the checkpoint
    if self.checkpoint_file:
      # Write the checkpoint
      for nbf in self.checkpoint:
        print(nbf)

    self.print_fence()

    # Freeze clear
    self.print_nbf_allcores(3, cfg_base_addr + cfg_reg_freeze, 0)
    # EOF
    self.print_fence()
    self.print_finish()

#
#   main()
#
if __name__ == "__main__":

  parser = argparse.ArgumentParser()
  parser.add_argument('--ncpus', type=int, default=1, help='number of BlackParrot cores')
  parser.add_argument('--ucode', dest='ucode_file', metavar='ucode.mem', help='CCE ucode file')
  parser.add_argument("--mem", dest='mem_file', metavar='prog.mem', help='DRAM verilog file')
  parser.add_argument("--config", dest='config', action='store_true', help='Do config over nbf')
  parser.add_argument("--checkpoint", dest='checkpoint_file', metavar='sample.nbf',help='checkpoint nbf file')
  parser.add_argument('--skip_zeros', dest='skip_zeros', action='store_true', help='skip zero DRAM entries')

  args = parser.parse_args()

  converter = NBF(args.ncpus, args.ucode_file, args.mem_file, args.checkpoint_file, args.config, args.skip_zeros)
  converter.dump()

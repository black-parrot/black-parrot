# SPDX-License-Identifier: BSD-3-Clause
#
#   nbf.py
#
#   MEM (.mem) to Network Boot Format (.nbf)
#
#   NBF format is
#   opcode_addr_data
#   opcode map:
#     8'h00: 1 byte write
#     8'h01: 2 byte write
#     8'h02: 4 byte write
#     8'h03: 8 byte write
#
#     8'h10: 1 byte read
#     8'h11: 2 byte read
#     8'h12: 4 byte read
#     8'h13: 8 byte read
#
#     8'hfe: fence, waits for outgoing commands to finish before progressing
#     8'hff: finish, terminates the nbf sequence


import sys
import argparse
import math
import os
import subprocess

##  // The overall memory map of the config link is:
##  //   16'h0000 - 16'h01ff: chip level config
##  //   16'h0200 - 16'h03ff: fe config
##  //   16'h0400 - 16'h05ff: be config
##  //   16'h0600 - 16'h07ff: me config
##  //   16'h0800 - 16'h7fff: reserved
##  //   16'h8000 - 16'h8fff: cce ucode
##
##  localparam cfg_base_addr_gp           = (dev_id_width_gp+dev_addr_width_gp)'('h0020_0000);
##  localparam cfg_match_addr_gp          = (dev_id_width_gp+dev_addr_width_gp)'('h002?_????);
##
##  localparam cfg_reg_freeze_gp          = (dev_addr_width_gp)'('h0_0008);
##  localparam cfg_reg_npc_gp             = (dev_addr_width_gp)'('h0_0010);
##  localparam cfg_reg_core_id_gp         = (dev_addr_width_gp)'('h0_0018);
##  localparam cfg_reg_did_gp             = (dev_addr_width_gp)'('h0_0020);
##  localparam cfg_reg_cord_gp            = (dev_addr_width_gp)'('h0_0028);
##  localparam cfg_reg_host_did_gp        = (dev_addr_width_gp)'('h0_0030);
##  // Used until PMP are setup properly
##  localparam cfg_reg_hio_mask_gp        = (dev_addr_width_gp)'('h0_0038);
##  localparam cfg_reg_icache_id_gp       = (dev_addr_width_gp)'('h0_0200);
##  localparam cfg_reg_icache_mode_gp     = (dev_addr_width_gp)'('h0_0208);
##  localparam cfg_reg_dcache_id_gp       = (dev_addr_width_gp)'('h0_0400);
##  localparam cfg_reg_dcache_mode_gp     = (dev_addr_width_gp)'('h0_0408);
##  localparam cfg_reg_cce_id_gp          = (dev_addr_width_gp)'('h0_0600);
##  localparam cfg_reg_cce_mode_gp        = (dev_addr_width_gp)'('h0_0608);
##  localparam cfg_mem_cce_ucode_base_gp  = (dev_addr_width_gp)'('h0_8000);
##  localparam cfg_mem_cce_ucode_match_gp = (dev_addr_width_gp)'('h0_8???);

cfg_base_addr          = 0x200000
cfg_reg_freeze         = 0x0008
cfg_reg_npc            = 0x0010
cfg_reg_core_id        = 0x0018
cfg_reg_did            = 0x0020
cfg_reg_cord           = 0x0028
cfg_reg_host_did       = 0x0030
cfg_reg_hio_mask       = 0x0038
cfg_reg_icache_id      = 0x0200
cfg_reg_icache_mode    = 0x0208
cfg_reg_dcache_id      = 0x0400
cfg_reg_dcache_mode    = 0x0408
cfg_reg_cce_id         = 0x0600
cfg_reg_cce_mode       = 0x0608
cfg_mem_base_cce_ucode = 0x8000

clint_base_addr       = 0x300000
clint_reg_mtimesel    = 0x8000
clint_reg_debug       = 0xc000

cfg_core_offset = 24

class NBF:

  # constructor
  def __init__(self, ncpus, ucode_file, mem_file, mem_size, bootrom_file, bootrom_size, checkpoint_file,
               config, skip_zeros, data_width, boot_pc, debug, verify, start_cached):

    # input parameters
    self.ncpus = ncpus
    self.ucode_file = ucode_file
    self.mem_file = mem_file
    self.mem_size = mem_size
    self.bootrom_file = bootrom_file
    self.bootrom_size = bootrom_size
    self.config = config
    self.checkpoint_file = checkpoint_file
    self.skip_zeros = skip_zeros
    self.data_width = data_width
    self.addr_width = data_width
    self.boot_pc = boot_pc
    self.debug = debug
    self.verify = verify
    self.start_cached = start_cached

    # Grab various files
    if self.mem_file:
      self.dram_data = self.read_dram(self.mem_file)

    if self.bootrom_file:
      self.bootrom_data = self.read_bootrom(self.bootrom_file)

    if self.ucode_file:
      self.ucode = self.read_binary(self.ucode_file)

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
    line += self.get_hexstr(data, self.data_width//4)
    print(line)

  def print_nbf_allcores(self, opcode, addr, data):
    for i in range(self.ncpus):
       full_addr = addr + (i << cfg_core_offset)
       self.print_nbf(opcode, full_addr, data)

  # decide how many bytes to write or read
  def get_size(self, addr):
    if addr % 8 == 0:
      size = 3
    elif addr % 4 == 0:
      size = 2
    elif addr % 2 == 0:
      size = 1
    else:
      size = 0

    return size

  # read file in binary format
  # returns flat data
  def read_binary(self, filename):
    data = []
    f = open(filename, "r")
    lines = f.readlines()
    for line in lines:
      line = line.strip()
      data.append(int(line, 2))
    return data

  # read file line by line
  # returns flat data
  def read_file(self, filename):
    data = []
    f = open(filename, "r")
    lines = f.readlines()
    for line in lines:
      data.append(line.strip())
    return data

  # read dram dumped in 'verilog' format.
  # returns [addr : data] dictionary
  def read_dram(self, mem_file):

    addr_val = {}
    curr_addr = 0
    addr_step = 0
    count = 0
    assembled_hex = ""
    #base_addr = 0x80000000
    base_addr = 0x0

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
          addr_step = 1 << self.get_size(curr_addr)
        else:
          words = stripped.split()
          for i in range(len(words)):
            assembled_hex = words[i] + assembled_hex
            count += 1
            if count == addr_step:
              addr_val[base_addr+curr_addr] = int(assembled_hex, 16)
              curr_addr += addr_step
              addr_step = 1 << self.get_size(curr_addr)
              assembled_hex = ""
              count = 0

    if count != 0:
      addr_val[base_addr+curr_addr] = int(assembled_hex, 16)

    return addr_val

  # read bootrom dumped in 'verilog' format.
  # returns [addr : data] dictionary
  def read_bootrom(self, mem_file):

    addr_val = {}
    curr_addr = 0
    addr_step = 0
    count = 0
    assembled_hex = ""
    #base_addr = 0x00110000
    base_addr = 0x0

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
          addr_step = 1 << self.get_size(curr_addr)
        else:
          words = stripped.split()
          for i in range(len(words)):
            assembled_hex = words[i] + assembled_hex
            count += 1
            if count == addr_step:
              addr_val[base_addr+curr_addr] = int(assembled_hex, 16)
              curr_addr += addr_step
              addr_step = 1 << self.get_size(curr_addr)
              assembled_hex = ""
              count = 0

    if count != 0:
      addr_val[base_addr+curr_addr] = int(assembled_hex, 16)

    return addr_val


  ##### END UTIL FUNCTIONS #####

  ##### LOADER ROUTINES #####

  # initialize dram
  def init_dram(self):
    if not(self.skip_zeros):
      for k in xrange(self.mem_size*1024*1024/8):
        self.print_nbf(3, 0x80000000 + k*8, 0)
    for k in sorted(self.dram_data.keys()):
      addr = k
      opcode = self.get_size(addr)
      if not(self.skip_zeros and self.dram_data[k] == 0):
        self.print_nbf(opcode, addr, self.dram_data[k])

  # initialize dram
  def init_bootrom(self):
    if not(self.skip_zeros):
      for k in xrange(self.bootrom_size*1024/8):
        self.print_nbf(3, 0x00110000 + k*8, 0)
    for k in sorted(self.bootrom_data.keys()):
      addr = k
      opcode = self.get_size(addr)
      if not(self.skip_zeros and self.bootrom_data[k] == 0):
        self.print_nbf(opcode, addr, self.bootrom_data[k])

  # print fence
  # when loader sees this, it waits until all packets are received to proceed
  def print_fence(self):
    self.print_nbf(0xfe, 0x0, 0x0)

  # print finish
  # when loader sees this, it stops sending packets.
  def print_finish(self):
    self.print_nbf(0xff, 0x0, 0x0)

  ##### LOADER ROUTINES END  #####

  # users only have to call this function.
  def dump(self):

    # Freeze set
    self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_freeze, 1)
    # Boot PC set
    if self.boot_pc:
      self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_npc, int(self.boot_pc, 16))
    if self.debug:
      self.print_nbf_allcores(2, clint_base_addr + clint_reg_debug, 1)
      self.print_fence()
      self.print_nbf_allcores(2, clint_base_addr + clint_reg_debug, 0)

    if self.start_cached:
      # Write I$, D$, and CCE modes
      self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_cce_mode, 1)
      self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_icache_mode, 1)
      self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_dcache_mode, 1)

    # For regular execution, the CCE ucode and cache/CCE modes are loaded by the bootrom
    if self.config:
      # Write CCE ucode
      if self.ucode_file:
        for core in range(self.ncpus):
          for i in range(len(self.ucode)):
            full_addr = cfg_base_addr + cfg_mem_base_cce_ucode + (core << cfg_core_offset) + i*8
            self.print_nbf(3, full_addr, self.ucode[i])

      # Write I$, D$, and CCE modes
      self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_cce_mode, 1)
      self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_icache_mode, 1)
      self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_dcache_mode, 1)

      if self.verify:
        # Read back I$, D$ and CCE modes for verification
        self.print_nbf(0x12, cfg_base_addr + cfg_reg_icache_mode, 1)
        self.print_nbf(0x12, cfg_base_addr + cfg_reg_dcache_mode, 1)
        self.print_nbf(0x12, cfg_base_addr + cfg_reg_cce_mode, 1)

    # Write RTC
    self.print_nbf_allcores(2, clint_base_addr + clint_reg_mtimesel, 1)

    self.print_fence()

    # Write bootrom
    if self.bootrom_file:
      self.init_bootrom()

    # Write DRAM
    if self.mem_file:
      self.init_dram()

    self.print_fence()

    # For checkpoint, load CCE ucode, cache/CCE modes and the checkpoint
    if self.checkpoint_file:
      for nbf in self.checkpoint:
        print(nbf)

    self.print_fence()

    # Freeze clear
    self.print_nbf_allcores(2, cfg_base_addr + cfg_reg_freeze, 0)
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
  parser.add_argument("--mem_size", type=int, default=64, help='DRAM size in MiB')
  parser.add_argument("--bootrom", dest='bootrom_file', metavar='bootrom.mem', help='Bootrom verilog file')
  parser.add_argument("--bootrom_size", type=int, default=64, help='DRAM size in KiB')
  parser.add_argument("--config", dest='config', action='store_true', help='Do config over nbf')
  parser.add_argument("--checkpoint", dest='checkpoint_file', metavar='sample.nbf',help='checkpoint nbf file')
  parser.add_argument('--skip_zeros', dest='skip_zeros', action='store_true', help='skip zero DRAM entries')
  parser.add_argument('--data_width', type=int, default=64, help='Data width')
  parser.add_argument('--boot_pc', dest='boot_pc', help='The first PC to be fetched')
  parser.add_argument('--debug', dest='debug', action='store_true', help='Whether to start in debug mode')
  parser.add_argument("--verify", dest='verify', action='store_true', help='Read back mode registers')
  parser.add_argument("--start_cached", dest='start_cached', action='store_true', help='Set LCE and CCE modes to cached before unfreeze')

  args = parser.parse_args()

  converter = NBF(args.ncpus, args.ucode_file, args.mem_file, args.mem_size, args.bootrom_file, args.bootrom_size,
                  args.checkpoint_file, args.config, args.skip_zeros, args.data_width,
                  args.boot_pc, args.debug, args.verify, args.start_cached)
  converter.dump()

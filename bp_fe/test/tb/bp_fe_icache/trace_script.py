#!/bin/usr/python

import sys, getopt
from trace_gen import TraceGen

def main():
  
  tracer = TraceGen(39, 28, 32)
  filepath = sys.argv[1]

  filename = filepath + "test_load.tr"
  file = open(filename, "w")

  file.write(tracer.print_header())
  
  file.write(tracer.print_comment("Load from address - 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60"))
  for i in range(0, 64, 4):
    temp_vaddr = (1 << 31) | i
    temp_ptag = (1<<19)
    file.write(tracer.send_load(temp_vaddr, temp_ptag, False))
    
  for i in range(0, 64, 4):
    file.write(tracer.recv_data(i))

  file.write(tracer.test_done())
  file.close()

  filename = filepath + "test_uncached_load.tr"
  file = open(filename, "w")
  
  file.write(tracer.print_header())
  
  file.write(tracer.print_comment("Uncached Load from address 36"))
  temp_vaddr = (1 << 31) | 36
  temp_ptag = (1 << 19)
  file.write(tracer.send_load(temp_vaddr, temp_ptag, True))
  file.write(tracer.recv_data(36))

  file.write(tracer.test_done())
  file.close()

if __name__ == "__main__":
  main()
  

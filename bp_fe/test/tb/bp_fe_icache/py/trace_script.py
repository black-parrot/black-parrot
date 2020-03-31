#!/bin/usr/python

import sys, getopt
from trace_gen import TraceGen

def main():
  
  tracer = TraceGen(39, 28, 32)
  file = open("test_load.tr", "w")

  file.write(tracer.print_header())
  
  file.write(tracer.print_comment("Load from address - 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60"))
  for i in range(0, 64, 4):
    temp_vaddr = (1 << 31) | i
    temp_ptag = (1<<19)
    file.write(tracer.send_load(temp_vaddr, temp_ptag, False))
    file.write(tracer.nop())
    file.write(tracer.recv_data(i))
    file.write(tracer.nop())

  file.write(tracer.test_finish())
  file.close()

  file = open("test_uncached_load.tr", "w")
  
  file.write(tracer.print_header())
  
  file.write(tracer.print_comment("Uncached Load from address 36"))
  temp_vaddr = (1 << 31) | 36
  temp_ptag = (1 << 19)
  file.write(tracer.send_load(temp_vaddr, temp_ptag, True))
  file.write(tracer.nop())
  file.write(tracer.recv_data(36))

  file.write(tracer.test_finish())
  file.close()

if __name__ == "__main__":
  main()

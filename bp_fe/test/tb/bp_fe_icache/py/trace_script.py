#!/bin/usr/python

import sys, getopt
from trace_gen import TraceGen

def main(argv):
  filename = ""
  try:
    opts, args = getopt.getopt(argv, "hi:", ["trace_file="])
  except getopt.GetoptError:
    print("trace_script.py -i <input_trace_file_name>")
    sys.exit(2)

  for opt, arg in opts:
    if opt == "-h":
      print("trace_script.pt -i <input_trace_file_name>")
      sys.exit()
    elif opt in ("-i", "--trace_file"):
      filename = arg
  
  tracer = TraceGen(39, 28, 32)
  file = open(filename, "w")

  file.write(tracer.print_header())
  
  file.write(tracer.print_comment("load from address - 0, 4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60"))
  for i in range(0, 64, 4):
    temp_vaddr = (1 << 31) | i
    temp_ptag = (1<<19)
    file.write(tracer.send_load(temp_vaddr, temp_ptag))
    file.write(tracer.nop())
    file.write(tracer.recv_data(i))
    file.write(tracer.nop())

  # file.write(tracer.test_done())
  file.write(tracer.test_finish())
  file.close()

if __name__ == "__main__":
  main(sys.argv[1:])

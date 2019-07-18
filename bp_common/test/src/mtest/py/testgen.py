#!/usr/bin/python

import sys

def usage():
  print "Usage: testgen.py <NC> <tests>"
  print "Example: testgen.py 2 bs bubblesort"
  
if len(sys.argv) < 3:
  usage()

NC = int(sys.argv[1])
benchmarks = []
for i in xrange(NC):
  benchmarks.append(sys.argv[i+2]+".bin")

print "#define NC " + str(NC)

str = "char* benchmarks[NC] = {"
for i in xrange(NC):
  str += "\"" + benchmarks[i] + "\""
  if (i != NC-1):
    str += ", "
str += "};"

print str
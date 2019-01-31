import sys

trace_file = open(sys.argv[1])

for line in trace_file:
  if line.startswith("#AXE"):
    print(line.replace("#AXE", "").strip())


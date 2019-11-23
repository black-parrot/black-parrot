from __future__ import print_function

N = 1024*1024
cols = 16
rows = N//cols

print('@0')
for i in range(rows):
  for j in range(cols-1):
    print('00 ', end='')
  print('00')

print()

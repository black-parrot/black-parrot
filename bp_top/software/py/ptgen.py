#!/usr/bin/python
import sys
import math

def help():
  print "Usage: ptgen.py <outfile> <root table address> <data sections roots> <data sections size(in pages)>"
  print "Example: python ptgen.py pt.S 0x80008000 0x80000000,0x8fffc000 4,1"

def int2hex(num, width):
  return "{0:#0{1}x}".format(num,width/4 + 2)
  
def checkAddr(vpn, as_start_vpn, as_size, page_pte_num, level, pt_depth):
  for i in xrange(len(as_start_vpn)):
    as_start = as_start_vpn[i]
    as_end = as_start_vpn[i] + as_size[i] - 1
    
    page_start = vpn
    page_end = vpn + page_pte_num**(pt_depth-level-1) - 1
    
    if not(as_start > page_end or as_end < page_start):
      return 1   
  return 0

#######################################
try:
  fileName = str(sys.argv[1])  
  root_table_addr = sys.argv[2]
  as_start = sys.argv[3].split(',')
  as_size = map(int, sys.argv[4].split(','))
except:
  help()
  quit()

#print root_table_addr
#print as_start
#print as_size
  
page_offset_width = 12
vaddr_width = 39
paddr_width = 55
pte_width = 64
#######################################
page_size = 2**page_offset_width

root_table_ppn = int(root_table_addr, 16)/page_size

as_start_vpn = [0]*len(as_start)
for i in xrange(len(as_start)):
  as_start_vpn[i] = int(as_start[i], 16)/page_size

vpn_width = vaddr_width - page_offset_width
ppn_width = paddr_width - page_offset_width

lg_page_pte_num = int(page_offset_width - math.log(pte_width/8, 2))
page_pte_num = int(2**lg_page_pte_num)
pt_depth = int(vpn_width/lg_page_pte_num)

#######################################

#print lg_page_pte_num

pt_table_num = [0] * pt_depth 
pt_roots = []
page_table = []

pt_table_num[0] = 1
table_vpns = [[0], [], []]
for level in xrange(1, pt_depth):
  last_vpn = -1
  #print "#######"
  for j in xrange(len(as_start_vpn)):
    masked_vpn = as_start_vpn[j] >> ((pt_depth-level)*lg_page_pte_num)
    masked_vpn = masked_vpn << ((pt_depth-level)*lg_page_pte_num)
    if(last_vpn != masked_vpn):
      last_vpn = masked_vpn
      table_vpns[level].append(masked_vpn)
      #print hex(masked_vpn)
      pt_table_num[level] += 1

last_ppn = root_table_ppn
for level in xrange(pt_depth):
  pt_roots.append([])
  for tableNum in xrange(pt_table_num[level]):
    pt_roots[level].append(last_ppn)
    last_ppn += 1 
    
#print pt_table_num
#print pt_roots
#print table_vpns
    
for level in xrange(pt_depth):
  page_table.append([])
  #print "---------"
  for tableNum in xrange(pt_table_num[level]):
    page_table[level].append([])
    target_tableNum = 0
    for offset in xrange(page_pte_num):
    
      vpn = table_vpns[level][tableNum] + (offset << ((pt_depth-level-1)*lg_page_pte_num))  
            
      if checkAddr(vpn, as_start_vpn, as_size, page_pte_num, level, pt_depth):
        #print "table vpn: " + hex(table_vpns[level][tableNum])
        #print "offset: " + hex(offset)
        #print "vpn: " + hex(vpn)
        valid = 1
        if level != pt_depth-1:
          xwr = 0
          ppn = pt_roots[level+1][target_tableNum]
          target_tableNum += 1
        else:
          xwr = 7
          ppn = vpn
      else:
        valid = 0
      
      if(valid):
        d = 1
        a = 1
        g = 0
        u = 0
        pte = (ppn << 10) + (d << 7) + (a << 6) + (g << 5) + (u << 4) + (xwr << 1) + valid
        #print "ppn: " + hex(ppn)
        page_table[level][tableNum].append(pte)
      else:
        page_table[level][tableNum].append(0)  

#######################################

outfile = open(fileName, "w")

outfile.write("/* page table start: " + root_table_addr + " */ \n")
outfile.write("/* address space start: " + str(as_start) + " */ \n")
outfile.write("/* address space size in pages: " + str(as_size) + " */ \n")
outfile.write(".section \".data.pt\"\n")
outfile.write(".globl _pt\n\n")
outfile.write("_pt:\n")
for i in xrange(len(page_table)):
  for j in xrange(len(page_table[i])):
    for k in xrange(len(page_table[i][j])):
      outfile.write("    .dword " + int2hex(page_table[i][j][k], 64) + "\n")
outfile.close()

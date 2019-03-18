#!/usr/bin/python
import sys
import math

def int2hex(num, width):
  return "{0:#0{1}x}".format(num,width/4 + 2)

#######################################
root_table_addr = "0x80003000"

address_space_start = "0x80000124"
address_space_size = 2**14;
  
page_offset_width = 12
vaddr_width = 39
paddr_width = 55
pte_width = 64
#######################################

page_size = 2**page_offset_width
as_page_num = int(math.ceil(1.0 * address_space_size/page_size));

root_table_ppn = int(root_table_addr, 16)/page_size
as_start_ppn = int(address_space_start, 16)/page_size

vpn_width = vaddr_width - page_offset_width
ppn_width = paddr_width - page_offset_width

lg_page_pte_num = int(page_offset_width - math.log(pte_width/8, 2))
page_pte_num = int(2**lg_page_pte_num)
pt_depth = int(vpn_width/lg_page_pte_num)

#######################################

pt_table_num = [0] * pt_depth 
pt_roots = []
page_table = []

pt_table_num[pt_depth-1] = int(math.ceil(1.0 * as_page_num/page_pte_num))
for i in xrange(pt_depth-2, -1, -1):
  pt_table_num[i] = int(math.ceil(1.0 * pt_table_num[i+1]/page_pte_num)) 

last_ppn = root_table_ppn
for level in xrange(pt_depth):
  pt_roots.append([])
  for tableNum in xrange(pt_table_num[level]):
    pt_roots[level].append(last_ppn)
    last_ppn += 1 

for level in xrange(pt_depth):
  page_table.append([])
  for tableNum in xrange(pt_table_num[level]):
    page_table[level].append([])
    target_tableNum = 0
    for offset in xrange(page_pte_num):
      vpn = as_start_ppn >> ((pt_depth-level)*lg_page_pte_num)
      vpn = vpn << ((pt_depth-level)*lg_page_pte_num)
      vpn += (tableNum*page_pte_num + offset) << ((pt_depth-level-1)*lg_page_pte_num)
      if vpn >= as_start_ppn and vpn < (as_start_ppn + as_page_num):
        valid = 1
        if level != pt_depth-1:
          ppn = pt_roots[level+1][target_tableNum]
          target_tableNum += 1
        else:
          ppn = vpn
      else:
        valid = 0
        ppn = 0
      page_table[level][tableNum].append((ppn << 9) + valid)

# print pt_depth
# print pt_table_num
# print pt_roots
# print page_table[0]
# print page_table[1]
# print page_table[2]  

name = str(sys.argv[1])  
outfile = open(name, "w")

outfile.write("/* page table start: " + root_table_addr + " */ \n")
outfile.write("/* address space start: " + address_space_start + " */ \n")
outfile.write("/* address space size in pages: " + str(as_page_num) + " */ \n")
outfile.write(".section \".data.pt\"\n")
outfile.write(".globl _pt\n\n")
outfile.write("_pt:\n")
for i in xrange(len(page_table)):
  for j in xrange(len(page_table[i])):
    for k in xrange(len(page_table[i][j])):
      outfile.write("    .dword " + int2hex(page_table[i][j][k], 64) + "\n")
outfile.close()


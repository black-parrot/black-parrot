#!/usr/bin/python

import sys

if len(sys.argv) != 3:
    print "Usage: hex2binascii.py <hexfile> <width>"
else:
    hexfile = open(sys.argv[1], "r")
    width   = int(sys.argv[2])
    assert (width%8 == 0), "width is a multiple of 8"

def hex2bin(hexchar):
    bindict = {
        "0": "0000"
       ,"1": "0001"
       ,"2": "0010"
       ,"3": "0011"
       ,"4": "0100"
       ,"5": "0101"
       ,"6": "0110"
       ,"7": "0111"
       ,"8": "1000"
       ,"9": "1001"
       ,"a": "1010"
       ,"b": "1011"
       ,"c": "1100"
       ,"d": "1101"
       ,"e": "1110"
       ,"f": "1111"
    }
    return bindict[hexchar]

hexcode = ""
bincode = ""

for line in hexfile:
    hexcode += line.strip()[::-1]

for hexchar in hexcode:
    bincode += hex2bin(hexchar)

for i in range(0, len(bincode), width):
    binline = ""
    for j in range(width, 0, -4):
        binline += bincode[i:(i+width)][j-4:j]
    print binline


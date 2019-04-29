.section ".text.amo"
.option nopic
.text

.global amo_swapw, amo_swapd
.global amo_addw, amo_addd
.global amo_xorw, amo_xord
.global amo_andw, amo_andd
.global amo_orw, amo_ord
.global amo_minw, amo_mind
.global amo_maxw, amo_maxd
.global amo_minuw, amo_minud
.global amo_maxuw, amo_maxud

# AMO_SWAP.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to store in [a0]
# Return
#   Data originally in [a0]
amo_swapw:
  lr.w t0, (a0)
  sc.w t1, a1, (a0)
  bnez t1, amo_swapw
  mv a0, t0
  jalr x0, ra

# AMO_SWAP.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to store in [a0]
# Return
#   ra: Data originally in [a0]
amo_swapd:
  lr.d t0, (a0)
  sc.d t1, a1, (a0)
  bnez t1, amo_swapd
  mv a0, t0
  jalr x0, ra

# AMO_ADD.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to add to [a0]
# Return
#   ra: Data originally in [a0]
amo_addw:
  lr.w t0, (a0)
  addw t1, t0, a1
  sc.w t1, t1, (a0)
  bnez t1, amo_addw
  mv a0, t0
  jalr x0, ra

# AMO_ADD.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to add to [a0]
# Return
#   ra: Data originally in [a0]
amo_addd:
  lr.d t0, (a0)
  add  t1, t0, a1
  sc.d t1, t1, (a0)
  bnez t1, amo_addd
  mv a0, t0
  jalr x0, ra

# AMO_AND.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to and with [a0]
# Return
#   ra: Data originally in [a0]
amo_andw:
  lr.w t0, (a0)
  and t1, t0, a1
  sc.w t1, t1, (a0)
  bnez t1, amo_andw
  mv a0, t0
  jalr x0, ra

# AMO_AND.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to and with [a0]
# Return
#   ra: Data originally in [a0]
amo_andd:
  lr.d t0, (a0)
  and  t1, t0, a1
  sc.d t1, t1, (a0)
  bnez t1, amo_andd
  mv a0, t0
  jalr x0, ra

# AMO_OR.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to or with [a0]
# Return
#   ra: Data originally in [a0]
amo_orw:
  lr.w t0, (a0)
  or t1, t0, a1
  sc.w t1, t1, (a0)
  bnez t1, amo_orw
  mv a0, t0
  jalr x0, ra

# AMO_OR.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to or with [a0]
# Return
#   ra: Data originally in [a0]
amo_ord:
  lr.d t0, (a0)
  or  t1, t0, a1
  sc.d t1, t1, (a0)
  bnez t1, amo_ord
  mv a0, t0
  jalr x0, ra

# AMO_XOR.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to xor with [a0]
# Return
#   ra: Data originally in [a0]
amo_xorw:
  lr.w t0, (a0)
  xor t1, t0, a1
  sc.w t1, t1, (a0)
  bnez t1, amo_xorw
  mv a0, t0
  jalr x0, ra

# AMO_XOR.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to xor with [a0]
# Return
#   ra: Data originally in [a0]
amo_xord:
  lr.d t0, (a0)
  xor  t1, t0, a1
  sc.d t1, t1, (a0)
  bnez t1, amo_xord
  mv a0, t0
  jalr x0, ra

# AMO_MAX.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to max with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# x ^ ((x ^ y) & -(x < y))
amo_maxd:
  # t0 = x
  # a1 = y
  lr.d t0, (a0)
  # t1 = -(x < y)
  slt t1, t0, a1
  neg t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = max(x, y)
  xor t3, t0, t3
  
  sc.d t1, t3, (a0)
  bnez t1, amo_maxd
  mv a0, t0
  jalr x0, ra

# AMO_MAX.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to max with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# x ^ ((x ^ y) & -(x < y))
amo_maxw:
  # t0 = x
  # a1 = y
  lr.w t0, (a0)
  # t1 = -(x < y)
  slt t1, t0, a1
  negw t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = max(x, y)
  xor t3, t0, t3

  sc.w t1, t3, (a0)
  bnez t1, amo_maxw
  mv a0, t0
  jalr x0, ra

# AMO_MAXU.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to maxu with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# x ^ ((x ^ y) & -(x < y))
amo_maxud:
  # t0 = x
  # a1 = y
  lr.d t0, (a0)
  # t1 = -(x < y)
  sltu t1, t0, a1
  neg t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = max(x, y)
  xor t3, t0, t3

  sc.d t1, t3, (a0)
  bnez t1, amo_maxud
  mv a0, t0
  jalr x0, ra

# AMO_MAXU.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to maxu with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# x ^ ((x ^ y) & -(x < y))
amo_maxuw:
  # t0 = x
  # a1 = y
  lr.w t0, (a0)
  # t1 = -(x < y)
  sltu t1, t0, a1
  negw t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = max(x, y)
  xor t3, t0, t3

  sc.w t1, t3, (a0)
  bnez t1, amo_maxuw
  mv a0, t0
  jalr x0, ra

# AMO_MIN.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to max with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# y ^ ((x ^ y) & -(x < y))
amo_mind:
  # t0 = x
  # a1 = y
  lr.d t0, (a0)
  # t1 = -(x < y)
  slt t1, t0, a1
  neg t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = min(x, y)
  xor t3, a1, t3
  
  sc.d t1, t3, (a0)
  bnez t1, amo_mind
  mv a0, t0
  jalr x0, ra

# AMO_MIN.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to minw with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# y ^ ((x ^ y) & -(x < y))
amo_minw:
  # t0 = x
  # a1 = y
  lr.w t0, (a0)
  # t1 = -(x < y)
  slt t1, t0, a1
  negw t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = min(x, y)
  xor t3, a1, t3

  sc.w t1, t3, (a0)
  bnez t1, amo_minw
  mv a0, t0
  jalr x0, ra

# AMO_MINU.D
# Parameters
#   a0: 64-bit aligned address
#   a1: data to minu with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# y ^ ((x ^ y) & -(x < y))
amo_minud:
  # t0 = x
  # a1 = y
  lr.d t0, (a0)
  # t1 = -(x < y)
  sltu t1, t0, a1
  neg t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = min(x, y)
  xor t3, a1, t3

  sc.d t1, t3, (a0)
  bnez t1, amo_minud
  mv a0, t0
  jalr x0, ra

# AMO_MINU.W
# Parameters
#   a0: 32-bit aligned address
#   a1: data to max with [a0]
# Return
#   ra: Data originally in [a0]
#
# Notes:
# We use this equation to achieve max without branching
# y ^ ((x ^ y) & -(x < y))
amo_minuw:
  # t0 = x
  # a1 = y
  lr.w t0, (a0)
  # t1 = -(x < y)
  sltu t1, t0, a1
  negw t1, t1
  # t2 = (x ^ y)
  xor t2, t0, a1
  # t3 = ((x ^ y) & -(x < y))
  and t3, t1, t2
  # t3 = min(x, y)
  xor t3, a1, t3

  sc.w t1, t3, (a0)
  bnez t1, amo_minuw
  mv a0, t0
  jalr x0, ra


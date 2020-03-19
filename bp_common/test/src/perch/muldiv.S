.section ".text.amo"
.option nopic
.text

.global mul_mulh
.global mul_mulhsu
.global mul_mulhu

# MULH
# Parameters
#   a0: A[63:0]
#   a1: B[63:0]
# Return
#   upper 64 bits of (signed(a0) * signed(a1))
# Algorithm:
#   https://www.codeproject.com/Tips/618570/UInt-Multiplication-Squaring
#   with sign adjustment at the end
mul_mulh:
  # u1 = u & 0xffff_ffff
  slli a2, a0, 32
  srli a2, a2, 32
  # v1 = v & 0xffff_ffff
  slli a3, a1, 32
  srli a3, a3, 32
  # t = u1 * v1
  mul a4, a2, a3
  # k = t >> 32
  srai a5, a4, 32
  # u >>= 32
  srai t0, a0, 32
  # t = (u * v1) + k
  mul a4, t0, a3
  add a4, a4, a5
  # k = t & 0xffff_ffff
  slli a5, a4, 32
  srli a5, a5, 32
  # w1 = t >> 32
  srai a6, a4, 32
  # v >>= 32
  srai t1, a1, 32
  # t = (u1 * v) + k
  mul a4, a2, t1
  add a4, a4, a5
  # k = t >> 32
  srai a5, a4, 32
  # h = (u * v) + w1 + k
  mul t0, t0, t1
  add t0, t0, a6
  add a0, t0, a5
  jalr x0, ra


# MULHSU
# Parameters
#   a0: A[63:0]
#   a1: B[63:0]
# Return
#   upper 64 bits of (signed(a0) * unsigned(a1))
mul_mulhsu:
  # u1 = u & 0xffff_ffff
  slli a2, a0, 32
  srli a2, a2, 32
  # v1 = v & 0xffff_ffff
  slli a3, a1, 32
  srli a3, a3, 32
  # t = u1 * v1
  mul a4, a2, a3
  # k = t >> 32
  srai a5, a4, 32
  # u >>= 32
  srai t0, a0, 32
  # t = (u * v1) + k
  mul a4, t0, a3
  add a4, a4, a5
  # k = t & 0xffff_ffff
  slli a5, a4, 32
  srli a5, a5, 32
  # w1 = t >> 32
  srai a6, a4, 32
  # v >>= 32
  srli t1, a1, 32
  # t = (u1 * v) + k
  mul a4, a2, t1
  add a4, a4, a5
  # k = t >> 32
  srli a5, a4, 32
  # h = (u * v) + w1 + k
  mul t0, t0, t1
  add t0, t0, a6
  add a0, t0, a5
  jalr x0, ra

# MULHU
# Parameters
#   a0: A[63:0]
#   a1: B[63:0]
# Return
#   upper 64 bits of (unsigned(a0) * unsigned(a1))
# Algorithm:
#   https://www.codeproject.com/Tips/618570/UInt-Multiplication-Squaring
mul_mulhu:
  # u1 = u & 0xffff_ffff
  slli a2, a0, 32
  srli a2, a2, 32
  # u >>= 32
  srli t0, a0, 32
  # v1 = v & 0xffff_ffff
  slli a3, a1, 32
  srli a3, a3, 32
  # v >>= 32
  srli t1, a1, 32
  # t = u1 * v1
  mul a4, a2, a3
  # k = t >> 32
  srli a5, a4, 32
  # t = (u * v1) + k
  mul a4, t0, a3
  add a4, a4, a5
  # k = t & 0xffff_ffff
  slli a5, a4, 32
  srli a5, a5, 32
  # w1 = t >> 32
  srli a6, a4, 32
  # t = (u1 * v) + k
  mul a4, a2, t1
  add a4, a4, a5
  # k = t >> 32
  srli a5, a4, 32
  # h = (u * v) + w1 + k
  mul t0, t0, t1
  add t0, t0, a6
  add a0, t0, a5
  jalr x0, ra


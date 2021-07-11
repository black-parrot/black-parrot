from __future__ import print_function

class TestMemory(object):
  def __init__(self, base, size, block_size, debug=False):
    self.mem = {}
    self.base = base
    self.size = size
    self.high = base + size
    self.block_size = block_size
    self.debug = debug
    assert (size % block_size == 0), '[TestMemory]: size must be multiple of block_size'
    assert (base % block_size == 0), '[TestMemory]: base address must be multiple of block_size'

  def eprint(self, *args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

  def check_valid_addr(self, addr):
    assert ((addr >= self.base) and (addr < self.high)), 'illegal address 0x{0:010x}'.format(addr)

  def reset(self):
    self.mem.clear()

  def read_memory(self, addr, size):
    # get the bytes from addr to addr+(size-1)
    # values are read assuming memory store multi-byte values in Little Endian order
    data = [self.mem[addr+i] if addr+i in self.mem else 0 for i in range(size-1, -1, -1)]
    val = 0
    for i in range(size):
      if self.debug:
        self.eprint('read: mem[{0}] == {1:x}'.format(addr+i, data[size-1-i]))
      val = (val << 8) + data[i]
    return val

  def write_memory(self, addr, value, size):
    # create an array of "bytes" (really, integer values of each byte) for addr to addr+(size-1)
    # bytes of value are stored into memory in Little Endian order
    for i in range(size):
      v = (value >> (i*8)) & 0xff
      if self.debug:
        self.eprint('write: mem[{0}] := {1:x}'.format(addr+i, v))
      self.mem[addr+i] = v


#
# trace_gen.py
#
# Generates trace replay commands for the BE dcache testbench.
#
# Packet format (from bp_be_dcache_defines.svh):
#   bp_be_dcache_pkt_s = { rd_addr, opcode, vaddr }
#   pkt_width = reg_addr_width_gp(5) + bits(bp_be_dcache_fu_op_e)(6) + vaddr_width_p
#
# Full trace replay command format:
#   { tr_op(4) | ptag(paddr_width_p - vaddr_width_p) | dcache_pkt | uncached(1) }
#
# Usage:
#   python trace_gen.py <data_width> <vaddr_width> <paddr_width>

# opcode constants from bp_be_dcache_fu_op_e (bp_be_ctl_pkgdef.svh, logic [5:0])
# extend here when adding AMO, LR/SC, or other operation tests
DCACHE_OP_LD = 0b000011   # load doubleword
DCACHE_OP_SD = 0b001011   # store doubleword

class TraceGen(object):

    # from bp_common_rv64_pkgdef.svh
    _REG_ADDR_WIDTH = 5
    # from bp_be_ctl_pkgdef.svh — typedef enum logic [5:0]
    _OPCODE_WIDTH   = 6

    def __init__(self, data_width_p, vaddr_width_p, paddr_width_p):
        self._data_width_p  = data_width_p
        self._vaddr_width_p = vaddr_width_p
        self._paddr_width_p = paddr_width_p
        self._ptag_width_p  = paddr_width_p - vaddr_width_p
        # from bp_be_dcache_pkt_width macro:
        # reg_addr_width_gp + $bits(bp_be_dcache_fu_op_e) + vaddr_width_mp
        self._dcache_pkt_width = (self._REG_ADDR_WIDTH
                                  + self._OPCODE_WIDTH
                                  + vaddr_width_p)

    def send_write(self, addr):
        trace  = "0001_"
        trace += self.format_bin_str(addr >> self._vaddr_width_p, self._ptag_width_p) + "_"
        trace += self.format_bin_str(0,            self._REG_ADDR_WIDTH) + "_"
        trace += self.format_bin_str(DCACHE_OP_SD, self._OPCODE_WIDTH)  + "_"
        trace += self.format_addr(addr)  + "_"
        trace += "0"   # uncached bit
        print(trace)

    def send_read(self, addr):
        trace  = "0001_"
        trace += self.format_bin_str(addr >> self._vaddr_width_p, self._ptag_width_p) + "_"
        trace += self.format_bin_str(0,            self._REG_ADDR_WIDTH) + "_"
        trace += self.format_bin_str(DCACHE_OP_LD, self._OPCODE_WIDTH)  + "_"
        trace += self.format_addr(addr)  + "_"
        trace += "0"   # uncached bit
        print(trace)

    def done(self):
        trace  = "0011_"
        trace += self.format_bin_str(0, self._ptag_width_p)   + "_"
        trace += self.format_bin_str(0, self._REG_ADDR_WIDTH) + "_"
        trace += self.format_bin_str(0, self._OPCODE_WIDTH)   + "_"
        trace += self.format_addr(0) + "_"
        trace += "0"   # uncached bit
        print(trace)

    def max_addr(self):
        return (1 << self._vaddr_width_p) - 1

    def format_bin_str(self, value, width):
        return format(value, "0" + str(width) + "b")

    def format_addr(self, addr):
        addr &= self.max_addr()
        return self.format_bin_str(addr, self._vaddr_width_p)


def basic_dram(tg, n):
    # DRAM base address is 0x8000_0000. Accesses must be 8-byte aligned (doubleword).
    dram_base = 0x80000000
    for i in range(n):
        addr = dram_base + i * 8
        tg.send_write(addr)
    for i in range(n):
        addr = dram_base + i * 8
        tg.send_read(addr)
    return


if __name__ == "__main__":
    import sys
    data_width  = int(sys.argv[1])
    vaddr_width = int(sys.argv[2])
    paddr_width = int(sys.argv[3])
    tg = TraceGen(data_width, vaddr_width, paddr_width)
    N = 4
    basic_dram(tg, N)
    tg.done()

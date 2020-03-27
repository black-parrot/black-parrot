#
#   npa_addr_gen.py
#
#   NPA = {y, x, EPA}
#


class NPAAddrGen:
  def __init__(self, y_cord_width_p, x_cord_width_p, epa_addr_width_p):
    self.y_cord_width_p = y_cord_width_p
    self.x_cord_width_p = x_cord_width_p
    self.epa_addr_width_p = epa_addr_width_p # this is word-address

  #
  #   plug in y,x coordinate and EPA word address.
  #   returns NPA address in byte address
  #
  def get_npa_addr(self, y, x, epa_addr):
    word_addr = (epa_addr
      + (x << self.epa_addr_width_p)
      + (y << (self.epa_addr_width_p + self.x_cord_width_p)))
    return word_addr << 2

import argparse
import sys

class SpikeLogEntry:
  def __init__(self, string_entry):
    instr_string = string_entry.split('\n')[0].replace(':','').split()
    commit_string = string_entry.split('\n')[1].replace('x ', 'x').split()

    self.core = int(instr_string[0], 16)
    self.pc = int(instr_string[1], 16)
    self.instr = int(instr_string[2].replace('(','').replace(')',''), 16)
    self.dasm = ' '.join(instr_string[3:])

    if len(commit_string) > 0:
      self.priv = int(commit_string[0], 16)
    if len(commit_string) > 3 and "mem" not in commit_string:
      self.rd_addr = int(commit_string[3].replace('x',''), 10)
      self.rf_instr = (self.rd_addr > 0)
    else:
      self.rf_instr = False
    if len(commit_string) > 4 and self.rf_instr:
      self.rd_data = int(commit_string[4], 16)

  def __eq__(self, rhs):
    pc_match = self.pc == rhs.pc
    rd_match = not self.rf_instr or ((self.rd_addr == rhs.rd_addr) and (self.rd_data == rhs.rd_data))

    return pc_match and rd_match

  def __ne__(self, rhs):
    return not self.__eq__(rhs)

  def __str__(self):
    display = "core: {} pc: {} instr: {} dasm: {}\n".format(hex(self.core), hex(self.pc),hex(self.instr), self.dasm)
    if self.rf_instr:
      display += "\t{} <- {}".format(hex(self.rd_addr), hex(self.rd_data))

    return display

class SimLogEntry:
  def __init__(self, string_entry):
    commit_string = string_entry.split('\n')[0].split()
    
    if len(commit_string) > 0:
      self.core = int(commit_string[0], 16)
    if len(commit_string) > 1:
      self.pc = int(commit_string[1], 16)
    if len(commit_string) > 2:
      self.instr = int(commit_string[2], 16)
    if len(commit_string) > 3:
      self.itag = int(commit_string[3], 16)
    if len(commit_string) > 4:
      self.rd_addr = int(commit_string[4], 16)
      self.rf_instr = (self.rd_addr > 0)
    else:
      self.rf_instr = False
    if len(commit_string) > 5 and self.rf_instr:
      try:
        self.rd_data = int(commit_string[5], 16)
      except:
        self.rd_data = 0

  def __eq__(self, rhs):
    pc_match = self.pc == rhs.pc
    rd_match = not self.rf_instr or ((self.rd_addr == rhs.rd_addr) and (self.rd_data == rhs.rd_data))

    return pc_match and rd_match

  def __ne__(self, rhs):
    return not self.__eq__(rhs)

  def __str__(self):
    display = "core: {} pc: {} instr: {}\n".format(hex(self.core), hex(self.pc), hex(self.instr))
    if self.rf_instr:
      display += "\t{} <- {}".format(hex(self.rd_addr), hex(self.rd_data))

    return display


def compare_trace(spike_entries, sim_entries, start_pc):
  mismatches = 0
  spike_index = 0
  sim_index = 0

  # Fast-forward to start PC
  while True:
    if spike_index >= len(spike_entries):
      print("Start PC not found in spike trace!")
      return False
    if spike_entries[spike_index].pc == start_pc:
      break
    spike_index += 1

  # Fast-forward to start PC
  while True:
    if sim_index >= len(sim_entries):
      print("Start PC not found in sim trace!")
      return False
    if sim_entries[sim_index].pc == start_pc:
      break
    sim_index += 1

  while True:
    if sim_index >= len(sim_entries):
      print("Sim trace finished!")
      break
    if spike_index >= len(spike_entries):
      print("Spike trace finished!")
      break

    if spike_entries[spike_index] != sim_entries[sim_index]:
      mismatches += 1
      print("Mismatch!")
      print("\tSpike PC: {} Instr: {} DASM: {}".format(
        hex(spike_entries[spike_index].pc),
        hex(spike_entries[spike_index].instr),
        spike_entries[spike_index].dasm))
      print("\tSim PC: {} Instr: {} itag: {}".format(
        hex(sim_entries[sim_index].pc),
        hex(sim_entries[sim_index].instr),
        hex(sim_entries[sim_index].itag)))
      print("\tPrevious Spike PC: {} Instr: {} DASM: {}".format(
        hex(spike_entries[spike_index-1].pc),
        hex(spike_entries[spike_index-1].instr),
        spike_entries[spike_index-1].dasm))
      print("\tPrevious Sim PC: {} Instr: {} itag: {}".format(
        hex(sim_entries[sim_index-1].pc),
        hex(sim_entries[sim_index-1].instr),
        hex(sim_entries[sim_index-1].itag)))
    #else:
    #  print("Match: Spike PC: {} Sim PC: {}".format(hex(spike_entries[spike_index].pc),
    #      hex(sim_entries[sim_index].pc)))

    sim_index += 1
    spike_index += 1

  return mismatches


if __name__ == "__main__":
  parser = argparse.ArgumentParser(description='Diff traces between spike and sim')
  parser.add_argument('spike_log')
  parser.add_argument('sim_log')
  parser.add_argument('start_pc')
  parser.add_argument('--tolerance', nargs='?', default=0)

  args = parser.parse_args()
  spike_log = args.spike_log
  sim_log = args.sim_log
  start_pc = int(args.start_pc, 16)
  tolerance = int(args.tolerance)

  spike_entries = []
  with open(spike_log, 'r') as f:
    entries = f.read().split("core  ")[1:]

    for entry in entries:
        if ('\n' in entry[:-1]):
            spike_entries.append(SpikeLogEntry(entry))

  sim_entries = []
  with open(sim_log, 'r') as f:
    entries = f.readlines()

    for entry in entries:
      sim_entries.append(SimLogEntry(entry))

  mismatches = compare_trace(spike_entries, sim_entries, start_pc)
  if mismatches > tolerance:
    print("Mismatch! {} errors, tolerance={}".format(mismatches, tolerance))
    exit(1)
  else:
    print("MATCH")
    print("# spike instrs: {}".format(len(spike_entries)))
    print("# sim   instrs: {}".format(len(sim_entries)))
    print("# mismatch    : {}".format(mismatches))
    print("tolerance     : {}".format(tolerance))
    exit(0)



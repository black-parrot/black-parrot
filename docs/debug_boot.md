# Debugging Your BlackParrot Boot

## Nothing Happens!

When integrating any IP into your project, the most common error is "nothing happens!". When dealing with a large, complex codebase, this is an intimidating blocker. This section details what to look for in your BlackParrot boot to smoke test the environment.

If you're working on FPGA, first make sure BlackParrot can boot in RTL simulation.

If you're working in RTL simulation, simply add these signals to the waveform environment. If they don't roughly match with this tutorial, double check that your environment emulates the testbench in bp\_top/test/tb/bp\_tethered/testbench.sv.

If you're working on FPGA, _first make sure BlackParrot can boot in RTL simulation_. It's incredibly hard to debug FPGA environments, with the limited visibility that they provide. We (BlackParrot team) cannot provide debugging help for specific FPGA environments. Instead, we request all bug reports to be reproducible from within the tethered testbench provided. (If the bug cannot be reproduced by the specific construction of the tethered testbench, those reports are also welcome).

## Boot Process (Method 1: NBF)

The first method of boot involves a host tether which sets up BlackParrot for execution. The BlackParrot NBF boot happens in several steps. An NBF (network boot format) loader in the testbench takes in an NBF file, and converts it into a series of I/O writes into the core. This I/O fills the DRAM, cce microcode, and sets configuration registers within BlackParrot. Usage of nbf.py is shown below:


    usage: nbf.py [-h] [--ncpus NCPUS] [--ucode ucode.mem] [--mem prog.mem]
              [--config] [--checkpoint sample.nbf] [--skip_zeros]
              [--addr_width ADDR_WIDTH]

The default NPF boot sequence is as follows (waveforms shown from executing the "hello world" program):
- reset is lowered. This must be lowered for 10 or more cycles. reset is raised.
- The freeze register is set. This prevents BlackParrot from fetching or executing instructions.
- I/O writes begin happening. There should be a single response for each request. These should look like the following:

![I/O Writes](debug_io.png)

- Configuration registers are set as seen below:

![Configuration Registers](debug_cfgbus.png)

- The program is loaded into the L2 cache:

![Cache Transactions](debug_cache.png)

- The cache will fetch allocated lines from the DRAM. (In simulation this will be zero, but in hardware this may be an arbitrary uninitialized value):

![DMA Transactions](debug_dma.png)

- The freeze register is lowered. Instructions begin to be fetched:

![Begin Fetch](debug_freeze.png)

- The register file should begin to see reads and writes:

![Regfile](debug_rf.png)


## Boot Process (Method 2: Bootrom)

The second method of boot involves BlackParrot bootstrapping itself using an external bootrom. This configuration is demonstrated using a bootrom config such as e_bp_unicore_bootrom_cfg. Users can build a BlackParrot which uses this configuration by setting This version of BlackParrot will go through exactly the same steps as Method 1. However, the process is not driven through an NBF loader. Instead, BlackParrot will start fetching from the bootrom, which contains the configuration registers and cce microcode for a core. This self-bootstrapping bootrom can be found here: https://github.com/black-parrot-sdk/bootrom/blob/master/bootrom.S.

In the tethered testbench, this bootrom lives in the host https://github.com/black-parrot/black-parrot/blob/master/bp_top/test/common/bp_nonsynth_host.sv#L228. Any environment constructed using a bootrom configuration will need the bootrom mapped onto the I/O bus, beginning at the address found here: https://github.com/black-parrot/black-parrot/blob/master/bp_common/src/include/bp_common_addr_pkgdef.svh#L31.


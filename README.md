# coming-soon
Black Parrot is coming soon.

To run the demo code:

Clone the latest bsg_ip_cores (in the same hierarchical level as bp_fe, bp_me, etc...):

git clone https://bitbucket.org/taylor-bsg/bsg_ip_cores.git

cd bp_top/syn

The general command to run a test program with a testbench wrapper (found in bp_top/test/tb) is
make TEST_ROM=<rom from test/rom/v/> <wrapper>.run.v

For example,

make TEST_ROM=rv64ui_p_add_rom.v bp_single_demo.run.v

make TEST_ROM=hello_world_rom.v bp_single_demo.run.v

make TEST_ROM=queue_demo_rom.v bp_dual_demo.run.v

This command also works for system wrappers found in bp_be.  For example:
You must first 

cd bp_be/tb/asm && make && make -f Makefile.demo, which will generate all of the test roms in bp_be/tb/rom

then

make TEST_ROM=rv64ui_p_ld_rom.v bp_be_nonsynth_mock_fe_top_wrapper.run.v

Other tests may or may not run based on this command.  In those cases, running 'make' in the test directory should run the test. Else, contact petrisko@cs.washington.edu who can direct you to the correct implementor.

See preliminary BlackParrot coding guidelines at:
https://docs.google.com/document/d/1GOSp6NVQUzGAAk_ahleAsANaQK2XJ0MUOZFPC9DLbLQ/edit?usp=sharing

NOTE: Currently, BlackParrot requires a VCS license.  Work in is progress to adapt the project to Verilator (https://www.veripool.org/wiki/verilator), an open-source simulator.  At the moment, for the purpose of this pre-alpha release, please contact petrisko@cs.washington.edu for help massaging your own VCS setup into this build flow (or pull-request a working Verilator build =))

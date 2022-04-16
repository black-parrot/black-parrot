## Current Extent of UVM Support
  Currently UVM is only supported for the BP L1 I-cache found in /bp_fe/src/v/bp_fe_icache.sv with a UCE connected.

## How to Simulate Existing Testbenches:
* Navigate to /bp_fe/syn/
* Base command: make run_testlist.v UCE_P=1 UVM=1
  * Note: At this time the UVM testbench only supports VCS.
* Options:
  * UVM_VERBOSITY = UVM_NONE - UVM_FULL
    * Sets the verbosity of UVM messages for the simulation using the plusarg of the same name.
  * DEBUG = 1
    * Launches DVE/Verdi in interactive mode depending on whether the $VERDI_HOME environment variable has been set.

## Explanation of Testbench Design:

### UVM Background:
If you are new to the Universal Verification Methodology(UVM), then you should first spend some time learning the general concepts.  A few recommended resources are listed below:
https://verificationacademy.com/cookbook/uvm
https://verificationacademy.com/courses/uvm-basics
https://verificationacademy.com/courses/advanced-uvm
https://ieeexplore-ieee-org.ezproxy.bu.edu/document/9195920

### I-Cache Testbench Overview:
[INSERT DIAGRAM HERE OF INTERFACES]
The top level module [testbench.sv](../bp_fe/test/tb/uvm/testbench.sv) contains an instance of the I$, the UCE, and non-synthesizable DRAM.
There are four interfaces, the data input, the data output, the TLB, and the Cace Engine (UCE).  These are all defined in [icache_uvm_if.sv](../bp_fe/test/tb/uvm/icache_uvm_if.sv).  The reason that four separate interfaces are used is to be able to drive and monitor each interface independent from the other (as will be discussed further when talking about virtual sequences below).

### I-Cache Testbench Components
#### Drivers
#### Monitors
#### Agents
#### Enviornment

### I-Cache Analysis Components
#### Coverage Collector
#### Scoreboard

### I-Cache Tests and Sequences
#### Current Tests

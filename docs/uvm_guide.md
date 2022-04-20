# UVM GUIDE For Black Parrot
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
![UVM_top.png](UVM_top.png)

The top level module [testbench.sv](../bp_fe/test/tb/uvm/testbench.sv) contains an instance of the I$, the UCE, and non-synthesizable DRAM.
There are four interfaces, the data input, the data output, the TLB, and the Cace Engine (UCE).  These are all defined in [icache_uvm_if.sv](../bp_fe/test/tb/uvm/icache_uvm_if.sv).  The reason that four separate interfaces are used is to be able to drive and monitor each interface independent from the other (as will be discussed further when talking about virtual sequences below).

### I-Cache Testbench Components
#### Enviornment
Located at [icache_uvm_cfg.sv](../bp_fe/test/tb/uvm/icache_uvm_cfg.sv), the configuration information for the enviorment (and agents) are passed using configuration objects.  For the enviornment, the configuration objet (which is set by each test) passes handles to each of the four interfaces and a bool for each interface to indicate whether that interface's agent is active or passive.  This information is then passed to each agent (there is one for each interface) by creating agent configuration objects and setting the activity of the agent. In the context of UVM, an active agent is one who has a sequencer and a driver, where a passive agent does not (there will be a monitor regardless).  

#### Agents
The agent contains the monitor and depending on the activity level also the sequencer and driver, which for the sake of discussing connections we will assume are instantiated.  Within the agent, the sequencer is connected to the driver and sends transactions for the driver to drive depending on the sequence defined in the test.  The monitor is also connected to the analysis port that each agent posses, which broadcasts to the subscribers.

#### Monitors
The monitor is intended at every positive clock edge to make a transaction from the values of the wires on the interface at that given point in time and send them to the subscribers.
* There is one monitor per interface in the design.
* The run phase consists of the following steps:
  * Waits for reset to go low intially.
  * At each positive clock edge:
  1. Package interface pins as a transaction.
  2. Send transaction over analysis port to subscribers (described below).

#### Drivers
At 'every' clock edge the driver takes transactions from the sequencer and drives the wires on a given interface with the values in the transaction.
* There is one driver per interface in the design.
* The run phase for the input driver consists of the following steps:
  * Waits for reset to go low initially.
  * The following code loops:
  1. Get a transaction from the sequencer (wait until one is sent).
  2. Wait until we are at a positive clock edge
  3. Drive transaction at a pin level on the interface.
  4. If we sent a transaction with v_i set across the interface, wait for the ready_o signal to be set by the cache.
  5. Send a message to the sequencer indicating that we have completed the transaction.
* The run phase for the TLB driver is the same with two exceptions.  First, it does not wait for the ready_o signal to be set, as that is not present on the TLB interface.  Second, it adds the transactions received from the sequencer into a queue of length one, achieving the effect of delaying the transaction from the sequencer by 1 cycle.  This is desired because the cache wants the ptag for a given input transaction a cycle after that input transaction, so if we are driving our TLB and input in parallel in a virtual sequence as discussed below, we can define the input and tlb transactions at the same time.

### I-Cache Analysis Components
#### Coverage Collector
#### Scoreboard

### I-Cache Tests and Sequences
#### Transactions
There are four interfaces, so it follows that there will be four different types of transactions to be driven on each interface.  These transactions contain the bits that we use to define them on each interface as well as helper functions for handling the transactions.  In all of the transaction classes, the do_copy() and convert2string() function are defined for all interfaces.  In addition, the output interface defines the do_compare() function to be used in the comparator of the scoreboard analysis componenet, defining how we determine if two output transactions are equal.

#### Current Tests

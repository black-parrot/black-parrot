![BlackParrot Logo](docs/bp_logo.png)

# BlackParrot: A Linux-Capable Accelerator Host Multicore [![License](https://img.shields.io/badge/License-BSD%203--Clause-blue.svg)](https://opensource.org/licenses/BSD-3-Clause) [![Gitlab CI](https://gitlab.com/black-parrot/black-parrot/badges/master/pipeline.svg)](https://gitlab.com/black-parrot/black-parrot/pipelines) [![Contributers](https://img.shields.io/github/contributors/black-parrot/black-parrot.svg?style=flat)]() [![Twitter Follow](https://img.shields.io/twitter/follow/BlackParrotCore.svg?style=social)](https://twitter.com/BlackParrotCore)

BlackParrot aims to be the default open-source, Linux-capable, cache-coherent, RV64GC multicore used by the world. Although originally developed by the University of Washington and Boston University, BlackParrot strives to be community-driven and infrastructure agnostic, a core which is Pareto optimal in terms of power, performance, area and complexity. In order to ensure BlackParrot is easy to use, integrate, modify and trust, development is guided by three core principles: Be Tiny, Be Modular, and Be Friendly. Development efforts have prioritized ease of use and silicon validation as first order design metrics, so that users can quickly get started and trust that their results will be representative of state-of-the-art ASIC designs. BlackParrot is ideal as the basis for a lightweight accelerator host, a standalone Linux core, or as a hardware research platform.

## The BlackParrot Manifesto
- Be TINY
    - When deliberating between two options, consider the one with least hardware cost/complexity.
- Be Modular
    - Prevent tight coupling between modules by designing latency insenstive interfaces.
- Be Friendly
    - Combat NIH, welcome external contributions and strive for infrastructure agnosticism.

## Project Status
The next release of BlackParrot, v 1.0, is coming in March 2020, and will contain support for an up to 16-core cache coherent multicore, including enough baseline user and privilege mode functionality to run Linux. An optimized single core variant of BlackParrot will also be released at this time.

A 12nm BlackParrot multicore chip was taped out in July 2019.

## Press
We first announced BlackParrot at FOSDEM 2020! [slides](https://fosdem.org/2020/schedule/event/riscv_blackparrot/attachments/slides/3718/export/events/attachments/riscv_blackparrot/slides/3718/Talk_Slides) [video](https://video.fosdem.org/2020/K.3.401/riscv_blackparrot.mp4) 

# Getting Started
## Tire Kick
Users who just want to test their setup and run a minimal BlackParrot test should run the following:

    # Clone the latest repo
    git clone https://github.com/black-parrot/black-parrot.git
    cd black-parrot
    # Checkout the correct branch
    git checkout uw_ee477_pparrot_wi20

    # Install a minimal set of tools
    make libs
    make verilator
    make ucode

    # Running your first test
    cd bp_top/syn
    # Run a test in Verilator (indicated by .sc extension)
    make build.sc sim.sc PROG=hello_world

This should output (roughly)

    Hello world!
    [CORE0 FSH] PASS
    [CORE0 STATS]
        clk   :                  220
        instr :                   66
        fe_nop:                    0
        be_nop:                    0
        me_nop:                    0
        poison:                  115
        roll  :                   21
        mIPC  :                  300
    All cores finished! Terminating...

## Getting Started for Real
Users who want to fully evaluate BlackParrot, or develop hardware or software using it should follow [Getting Started (Full)](docs/getting_started.md).

## How to Contribute
We welcome external contributions! Please join our mailing at (Coming soon!) and follow us on [Twitter](https://twitter.com/BlackParrotCore) to discuss, ask questions or just tell us how you're using BlackParrot! For a smooth contribution experience, take a look at our [Contribution Guide](CONTRIBUTING.md).

## Coding Style
BlackParrot is written in standard SystemVerilog, using a subset of the language known to be both synthesizable and compatible with a wide variety of vendor tools. Details of these style choices both functional and aesthetic can be found in our [Style Guide](docs/style_guide.md)

## Software Developer Guide
BlackParrot is Linux-capable, so it is possible to run all programs which run on BusyBox. However, for more targeted benchmarks which don't want O/S management overheads (or the overheads of a long Linux boot time in simulation!), it is preferable to write for bare-metal. Additionally, some platform-specific features are only available at the firmware level. Developers looking to write low-level BlackParrot code, or optimize for the BlackParrot platform should look at our [SW Developer Guide](docs/software_guide.md)

## Interface Specification
BlackParrot is an aggresively modular design: communication between the components is performed over a set of narrow, latency-insensitive interfaces. The interfaces are designed to allow implementations of the various system components to change independently of one another, without worrying about cascading functional or timing effects. Read more about BlackParrot's standardized interfaces here: [Interface Specification](docs/interface_specification.md)

## BedRock Coherence System Guide
Coming soon!
[BedRock Guide](docs/bedrock_guide.md)

## Microarchitecture Guide
Coming soon!
[Microarchitecture Guide](docs/microarchitecture_guide.md)

## Platform Guide
Coming soon!
[Platform Guide](docs/platform_guide.md)

## CAD Backend Guide
A key feature of using BlackParrot is that it has been heavily validated in both silicon and FPGA implementations.  All BlackParrot tapeouts and FPGA environments can be found at [BlackParrot Examples](https://github.com/black-parrot-examples/). Taped out BlackParrot yourself and want to share tips and tricks? Let us know and we can add it to the collection! Looking to implement BlackParrot in a physical system? Take a look at our [CAD Backend Guide](docs/backend_guide.md).

## Continuous Integration
Upon commit to the listed branch, a functional regression consisting of full-system tests and module level tests is run and checked for correctness. Additionally, the design is checked with Synopsys DC to verify synthesizability. Work is in progress to continuously monitor PPA.


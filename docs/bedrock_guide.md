# BedRock Cache Coherence System Guide

## BedRock Cache Coherence Protocol

BedRock is a family of directory-based invalidate cache coherence protocols based on the standard
MOESIF coherence states. Protocol variants are defined for the MI, MSI, MESI, MOSI, MOESI, MESIF,
and MOESIF subsets of states. The protocol relies on a duplicate tag, fully inclusive, standalone
coherence directory to precisely track the coherence state of every block cached within the
coherence system. A full description of the BedRock cache coherence protocol and system is available
[here](bedrock_protocol_specification.pdf).

## BlackParrot BedRock Cache Coherence System

BlackParrot implements BedRock to provide cache coherence between the processor cores and
coherent accelerators in a multicore BlackParrot system. This system is called BlackParrot Bedrock
(BP-BedRock).

The BlackParrot BedRock Interface is defined in the following files:
- [bp\_common\_bedrock\_if.svh](../bp_common/src/include/bp_common_bedrock_if.svh)
- [bp\_common\_bedrock\_pkgdef.svh](../bp_common/src/include/bp_common_bedrock_pkgdef.svh)
- [bp\_common\_bedrock\_wormhole_defines.svh](../bp_common/src/include/bp_common_bedrock_wormhole_defines.svh)

These files are the authoritative definitions for the BP-BedRock interface implementation. In the
event that the code differs from any documentation on or referenced by this page, the code
shall be considered as the current and authoritative specification.


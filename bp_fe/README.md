# Black Parrot Front End
The Front End (FE) consists of two different stages: PC Generation (PC_GEN) and Instruction Fetch
  (IF). These two stages receive the same PC value at the beginning of the stage; as a result, we
  consider them as one stage. PC_GEN specifies the next virtual PC value that will be fetched. The
  IF stage receives the virtual PC from the PC_GEN, fetches the next instruction and enqueues the
  fetched PC/Instruction pair alongside branch prediction metadata into the frontend queue.

The FE of the BlackParrot processor contains the following components:

1. PC\_GEN (including the PC\_GEN logic and Branch Prediction Logic)

2. Instruction TLB (I-TLB)

3. Instruction Cache (I-Cache)

## PC Generation

*pc\_gen.v* provides the interfaces for the PC\_GEN logics and also interfacing other modules in the
  FE. PC\_GEN provides the pc for the I-TLB and I-Cache. PC\_GEN also provides the BTB, BHT and
  RAS indexes for the Back End (BE) (the queue between the FE and the FE, i.e. the frontend queue).

### Branch Target Buffer (BTB)
Branch Target Buffer (BTB) stores the addresses of the branch targets and the corresponding branch
  sites. Branch happens from the branch sites to the branch targets. In order to save the logic
  sizes, the BTB is designed to have limited  entries for storing the branch sites, branch target
  pairs. The implementation  uses the bsg\_mem\_1r1w RAM design.

### Branch History Table (BHT)

Branch History Table (BHT) records a history of branch prediction results, and predict whether next
  branch should be taken or not. After each prediction, the back-end (BE) informs the front-end (FE)
  whether the previous prediction is  correct or not. The BHT will update the corresponding entry
  according to the  previous results. The two bits in each entry of the BHT follows the rule in the
  table. 

| Bit 1              | Bit 0         | 
|--------------------|---------------|
| taken or not taken | strong or weak|

1. If the entry in the BHT shows that the previous prediction is strong, and the BE informs the FE
  that the previous prediction is correct, the BHT does not update any of the entry.

2. If the entry in the BHT indicates that the previous prediction is weak, and at the same time, the
  BE informs the FE that the previous prediction is correct, the BHT will update its entry to make
  it strong prediction.

3. If the entry in the BHT shows that the previous prediction is strong, but the BE informs the FE
  that the previous prediction is wrong, the BHT changes the  strong prediction to weak prediction
  in the corresponding entry.

4. If the entry in the BHT indicates that the previous prediction is weak and at the same time, the
  BE informs the FE that the previous prediction is wrong, the BHT will change the prediction either
  from taken to not taken, or from not taken to taken, in the corresponding entry.

During the branch prediction, the FE reads the corresponding entry taken or not taken bit (Bit 1) to
  predict. If the Bit 1 is 1, then the FE take the branch prediction. If the Bit 1 is 0, the FE does
  not take the branch prediction.

## I-Cache
The I-Cache (I$) is implemented as a virtually-indexed physically-tagged cache. The I-Cache module
  consists of two components: cache logic and Local Cache Engine (LCE). The cache logic is a
  two-staged pipelined cache (consisting of Tag-Lookup (TL) stage and Tag-Verify (TV) stage) and the
  LCE is the cache entity participating in coherence.

The file *bp\_fe\_icache.v* defines the top level I-Cache module. This module is instantiated once
  per Black Parrot multi-core processor. This module implements the cache logic and instantiates the
  LCE module.

#### Local Cache Engine (LCE)
The file *bp\_fe\_lce.v* defines the top level LCE module.

### Parameters
* __eaddr\_width\_p__ \- effective address width
* __data\_width\_p__ \- data width
* __instr\_width\_p__ \- instruction width
* __tag\_width\_p__ \- tag width
* __num\_cce\_p__ \- number of CCEs in the system
* __num\_lce\_p__ \- number of LCEs in the system
* __lce\_id\_p__ \- ID of this LCE in the system
* __lce\_assoc\_p__ \- Associativity of this LCE
* __lce\_sets\_p__ \- Number of sets in this LCE
* __lce\_states\_p__ \- Number of coherency states for the LCE
* __block\_size\_in\_bytes\_p__ \- The cache line (block) size in bytes


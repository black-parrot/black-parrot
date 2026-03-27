# BlackParrot Accelerator Developer's Guide

## Accelerator Complex High Level Block Diagram

In both coherent and streaming accelerator complexes, all accelerator tiles are connected
through three 2D mesh networks (coherency networks). Each accelerator tile contains the
accelerator design and wormhole routers to connect to the coherency network.

A typical accelerator design includes the following components:
* RTL description of the algorithm or function being accelerated
* Logic to map AFU CSRs into MMIO space
* BlackParrot Cache+LCE in the case of coherent accelerators and SPM+LCE_Link in the case of streaming accelerators

![Accelerator Complex](accelerator_complex.png)

The detailed schematic of accelerator tile node and accelerator tile can be found [here](https://docs.google.com/presentation/d/1I8RHFAAT-yERvWZpmGOr8IMzqYVs5tThM_jM6fuXKqs/edit?usp=sharing).

## Bare-metal Environment

**Commands to Run Accelerator Demos**

Clone the latest repo and follow the getting started guide to build the tools. For accelerator
tests, run the following command from `bp_top/verilator`:
```
make build.verilator sim.verilator \
  PROG=streaming_accelerator_vdp \
  CFG=e_bp_multicore_1_accelerator_cfg
```

Available accelerator test programs (located in `black-parrot-sdk/bp-tests/src/`):
* `streaming_accelerator_vdp` — streaming vector dot product
* `streaming_accelerator_loopback` — streaming loopback test
* `streaming_accelerator_zipline` — streaming zipline test
* `coherent_accelerator_vdp` — coherent vector dot product

**Accelerator API**

Considering the BlackParrot memory address map defined in the [platform guide](platform_guide.md),
accelerator CSRs can be mapped into MMIO space (16 MB of MMIO space for each coherent and
streaming accelerator).

Basic APIs such as `bp_set_mmio_csr`, `bp_get_mmio_csr`, and `dma_cpy` are defined in the
BlackParrot bare-metal library `lib_perch`, located at `bp_common/test/src/perch`. Additional
functions can be added based on accelerator functionality. The base address for each accelerator,
accelerator ID, and list of CSRs can be defined in the library.

Example software program:
```c
sw_kernel_1();
// Set CSR values
vdp_csr.input_a_ptr  = (uint64_t *) &input_array_a;
vdp_csr.input_b_ptr  = (uint64_t *) &input_array_b;
vdp_csr.input_length = vlen;
vdp_csr.resp_ptr     = (uint64_t *) &resp_data;

id = 0; // coherent accelerator
bp_call_vector_dot_product_accelerator(id, vdp_csr);
id = 1; // streaming accelerator
bp_call_vector_dot_product_accelerator(id, vdp_csr);

sw_kernel_2();
```

The call sets the corresponding CSRs, sends a start command to the accelerator, copies input
data to accelerator memory space, waits for completion, and copies the response back to user
memory.

All required hardware and software modifications are implemented for the example coherent and
streaming accelerators (vector dot product) and can be used as a reference for adding new
accelerators to BlackParrot.

## Linux Environment

**Commands to Run Accelerator Demos**

> Note: Linux accelerator support requires additional setup. Please refer to the
> [BlackParrot SDK](https://github.com/black-parrot-sdk/black-parrot-sdk) for current
> Linux build instructions.

**Accelerator Kernel Driver**

After adding a new accelerator to BlackParrot, provide a kernel driver to let user programs
communicate with it. Example drivers are in `linux/drivers/`. The `bp_dummy` driver can be
used as a tutorial. This driver installs a character device that user processes can write to
in order to initialize accelerator settings. Adding a new driver is as easy as replacing
"dummy" with the accelerator name and modifying the ioctl function to configure the
corresponding accelerator using SBI calls. Basic SBI calls such as `sbi_set_mmio_csr`,
`sbi_get_mmio_csr`, and `sbi_dma` are already implemented.

To use the accelerator in a user program, open its corresponding device file:
```c
int fd = open("/dev/bp_dummy", O_RDWR);
if (fd > 0)
  printf("bp_dummy driver opened %d\n", fd);
else {
  printf("Error opening bp_dummy\n");
  exit(1);
}
```

Then use the returned file descriptor to call ioctl to configure the accelerator. If the
accelerator does not handle page faults, lock input/output data pages using `mlock` before
passing pointers to the kernel driver, and unlock with `munlock` at the end:
```c
#define IOCTL_CFG_VDP _IOW('S', 1, struct cfg_vdp *)

cfg_param.input_a_ptr  = array_a;
cfg_param.input_b_ptr  = array_b;
cfg_param.input_length = vlen;
cfg_param.resp_ptr     = &result;

ioctl(fd, IOCTL_CFG_VDP, &cfg_param);
```

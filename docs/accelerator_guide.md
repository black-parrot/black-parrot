# BlackParrot Accelerator Developer's Guide

## Accelerator Complex High Level Block Diagram

In the both coherent and streaming accelerator complexes, all the accelerator tiles are connected through three 2D mesh networks (coherency networks). Each accelerator tile contains the accelerator design and wormhole routers to connect to the coherency network.

A typical accelerator design includes the following components:
* RTL description of the algorithm or function being accelerated
* Logic to map AFU CSRs into MMIO space 
* BlackParrot Cache+LCE in the case of coherent accelerators and SPM+LCE_Link in the case of streaming accelerators

![Accelerator Complex](accelerator_complex.png)

The detailed schematic of accelerator tile node and accelerator tile can be found [here](https://docs.google.com/presentation/d/1I8RHFAAT-yERvWZpmGOr8IMzqYVs5tThM_jM6fuXKqs/edit?usp=sharing).


## Bare-metal Environment
**Commands to Run Accelerator Demos**

Clone the latest repo and follow the getting started page to run the general tests. For accelerator tests, to run vector_dot_product example, run the following command in bp_top/syn:
 
```
make build_dump.v sim_dump.v  SUITE=bp-tests PROG=streaming_accelerator_demo CFG=e_bp_multicore_1_accelerator_cfg
```

**Accelerator API**

Considering BlackParrot memory address map, defined in the [platform guide](platform_guide.md), accelerators CSRs can be mapped into MMIO space (16 MB of MMIO space for each coherent and streaming accelerator).

Some basic APIs such as bp_set_mmio_csr, bp_get_mmio_csr, and dma_cpy functions are defined in the BlackParrot bare-metal library, lib_perch, located at bp_common/test/src/perch. Other required functions can be added to the library based on the accelerator functionality. The base address for each accelerator, accelerator ID, and also a list of each accelerator CSRs can be defined in the library. 

Example for sw program:

```
sw_kernel_1()
...
//set CSRs values
vdp_csr.input_a_ptr = (uint64_t *) &input_array_a;
vdp_csr.input_b_ptr = (uint64_t *) &input_array_b;
vdp_csr.input_length = vlen;
vdp_csr.resp_ptr = (uint64_t *) &resp_data;
...
id=0; //coherent accelerator
bp_call_vector_dot_product_accelerator(id, vdp_csr);
id=1; //streaming accelerator
bp_call_vector_dot_product_accelerator(id, vdp_csr);
...
sw_kernel_2()
...
```

Call accelerator function sets the corresponding CSRs, sends start command to accelerator (setting the start CSR), copies the input data to accelerator memory space, waits for completion (checking the status CSR), and copies the response back into user memory space.

All the required hardware and software modifications have already been implemented for example coherent and streaming accelerators (vector dot_product). They can be used as a reference for adding new accelerators to the BlackParrot SoC.

 
## Linux Environment

**Commands to Run Accelerator Demos**

Clone bp_accelerator_mods branch of https://github.com/bsg-external/freedom-u-sdk.git repo and run make in the top level directory to create the bbl image. Then clone the accelerator_dromajo branch of BlackParrot repo and follow the getting started page to build the tools.  
To boot up linux on dromajo, run the following command in black-parrot/external/dromajo/src/.

./dromajo  --host  bbl

![Login Prompt](login_prompt.png)

Once you get the login prompt, enter "root" username and "blackparrot" password to login. Then change the directory to /usr/bin to find the accelerator test programs. Run cvdp and svdp binaries to test coherent and streaming vector_dot_product accelerators, respectively. Both programs get the vector length as the input argument, generate random input arrays, pass them to the accelerator, and print the accelerator response once it's done. 

![Linux](linux.png)

To make it easier to add new local programs to the generated rootfs, we created a separate buildroot package at freedom-u-sdk/buildroot/package/localprog. To add a new program, you just need to copy the source files in the src directory of the package and modify the available makefile to build the programs, the output binaries are placed in the bin folder of the package, and get automatically added to rootfs in /usr/bin directory.

**Accelerator Kernel Driver**

After adding a new accelerator to BlackParrot SoC, you need to provide a kernel driver to let the user program communicate with the accelerator. All the example drivers are in linux/drivers/ directory. The bp_dummy driver can be used as a tutorial to develop drivers for the accelerators added to BlackParrot SoC. This driver installs a character device that the user process can write to in order to initialize the settings of the accelerator. Adding a new driver is as easy as replacing "dummy" with the accelerator name and modifying the ioctl function to configure the corresponding accelerator using SBI calls. The basic SBI calls such as sbi_set_mmio_csr, sbi_get_mmio_csr, and sbi_dma are already implemented. If needed, new SBI calls can be added to both Linux (linux/arch/riscv/include/asm/sbi.h) and riscv-pk (riscv-pk/machine/mtrap.c).

To use the accelerator in the user program, you first need to open its corresponding device file.

```
int fd;
fd = open("/dev/bp_dummy", O_RDWR);
if(fd > 0)
  printf("bp_dummy driver opened %d\n", fd);
else
{
  printf("Error opening bp_dummy\n");
  exit(1);
}
```

If the device file is opened successfully, you can use the returned file descriptor to call the ioctl function to configure the accelerator. If the accelerator does not have any mechanism to handle page faults, make sure to lock the input/output data pages using mlock before passing their pointers to the accelerator kernel driver and unlock them using munlock at the end of the program.

```
#define IOCTL_CFG_VDP  _IOW ('S', 1, struct cfg_vdp *)

cfg_param.input_a_ptr= array_a;
cfg_param.input_b_ptr= array_b;
cfg_param.input_length= vlen;
cfg_param.resp_ptr= &result;

ioctl(fd, IOCTL_CFG_VDP, &cfg_param );
```

You can find example user programs in the Buildroot localprog package for both coherent and streaming vector_dot_product accelerators.
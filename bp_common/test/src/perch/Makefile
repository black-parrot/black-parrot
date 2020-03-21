
RISCV_GCC = riscv64-unknown-elf-dramfs-gcc -fPIC -march=rv64ima -mabi=lp64 -mcmodel=medany -static
RISCV_AR = riscv64-unknown-elf-dramfs-ar
RISCV_RANLIB = riscv64-unknown-elf-dramfs-ranlib

build:
	$(RISCV_GCC) -c *.c *.S
	$(RISCV_AR) -rc libperch.a *.o
	$(RISCV_RANLIB) libperch.a

clean:
	-rm -rf *.a
	-rm -rf *.o



RISCV_GCC = riscv64-unknown-elf-gcc -fPIC -march=rv64ia -mabi=lp64 -mcmodel=medany -static
RISCV_AR = riscv64-unknown-elf-ar 
RISCV_RANLIB = riscv64-unknown-elf-ranlib

build:
	$(RISCV_GCC) -c *.c *.S
	$(RISCV_AR) -rc libperch.a *.o
	$(RISCV_RANLIB) libperch.a

clean:
	-rm -rf *.a
	-rm -rf *.o


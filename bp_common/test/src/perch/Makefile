
RISCV_GCC = $(CROSS_COMPILE)gcc -fPIC -march=rv64ima -mabi=lp64 -mcmodel=medany -static
RISCV_AR = $(CROSS_COMPILE)ar
RISCV_RANLIB = $(CROSS_COMPILE)ranlib

.PHONY: all perch crt0.o

all: perch crt0.o

crt0.o: start.S
	$(RISCV_GCC) -D_DRAMFS -o $@ -c $<

perch:
	$(RISCV_GCC) -c *.c *.S
	$(RISCV_AR) -rc libperch.a *.o
	$(RISCV_RANLIB) libperch.a

clean:
	-rm -rf *.a
	-rm -rf *.o

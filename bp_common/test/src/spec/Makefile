include Makefile.frag

RUNS = $(patsubst %,%.riscv,$(BENCHMARKS))

all:
	$(MAKE) $(RUNS)

spec2000:
	git submodule update --init --recursive --merge spec2000

%.riscv: spec2000
	$(MAKE) -f Makefile.$*
	$(MAKE) -f Makefile.$* clean

clean:
	for benchmark in $(BENCHMARKS) ; do \
	rm -rf $$benchmark.riscv; \
	$(MAKE) -f Makefile.$$benchmark clean; \
	done;

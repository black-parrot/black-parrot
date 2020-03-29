include Makefile.frag

URL = https://github.com/black-parrot/spec2000
BRANCH = blackparrot_mods

RUNS = $(patsubst %,%.riscv,$(BENCHMARKS))

all:
	$(MAKE) $(RUNS)

%.riscv:
	$(MAKE) -f Makefile.$*
	$(MAKE) -f Makefile.$* clean

checkout:
	git clone -b $(BRANCH) $(URL) 2> /dev/null || git -C spec2000 pull

clean:
	for benchmark in $(BENCHMARKS) ; do \
	rm -rf $$benchmark.riscv; \
	$(MAKE) -f Makefile.$$benchmark clean; \
	done;

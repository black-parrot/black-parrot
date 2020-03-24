#BENCHMARKS = 000.test
#BENCHMARKS+= 164.gzip
BENCHMARKS = 175.vpr
#BENCHMARKS+= 181.mcf
#BENCHMARKS+= 186.crafty
#BENCHMARKS+= 197.parser
#BENCHMARKS+= 256.bzip2
#BENCHMARKS+= 300.twolf

URL = https://github.com/black-parrot/spec2000
BRANCH = blackparrot_mods

RUNS = $(patsubst %,%.riscv,$(BENCHMARKS))

all:
	$(MAKE) $(RUNS)

%.riscv:
	$(MAKE) -f Makefile.$*

checkout:
	git clone -b $(BRANCH) $(URL) 2> /dev/null || git -C spec2000 pull

clean:
	rm -rf *.o
	for benchmark in $(BENCHMARKS) ; do \
	$(MAKE) -f Makefile.$$benchmark clean; \
	done;

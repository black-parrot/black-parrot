Multi-corner regression
=======================
To run multi-corner regression:
  - Update the list of coners in `CORNERS` variable in `Makefile`.
  - Update test list in `REGRESS_LIST` variable in `Makefile`.
  - `make checkout` to checkout repos to run tests in.
  - `make -j <n> build` to do a parallel build of machines for each process corner.
  - `make -j <n> run` to do a prallel run of regression.

Help:
- `make checkout`: Checkout bsg_manycore repos for each corner.
- `make build`: Build machines for each corner.
- `make run`: Run tests listed in REGRESS_LIST variable in `Makefile`.
- `make bleach-checkout`: Clean run repos.
- `make bleach-build`: Clean machine builds.
- `make bleach_all`: Clean everything!
- `make clean_runs`: Recurse clean in individual test directories.

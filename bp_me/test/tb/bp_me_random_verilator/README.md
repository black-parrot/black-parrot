## ME Random Load and Store Test
- Run `make` to run the simulation
  - optionally, `make SEED_P=123` to set the random seed. By default, system clock is used for seed.
  - optionally, `make NUM_INSTR_P=5000` to set the number of instruction for each cache. By default, it is set to be 10000.

- If the Trace Replay master ends simulation with a mismatched value error, then something went wrong!. If not, the test passed.

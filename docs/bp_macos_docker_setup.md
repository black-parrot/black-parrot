# BlackParrot Docker Setup (macOS)
This guide targets Apple Silicon macOS systems where native
BlackParrot builds can be difficult due to toolchain incompatibilities.
Docker is used to provide a reproducible Linux environment.

The flow pins Verilator to v5.008 because newer releases removed the
`--binary` option required by the current BlackParrot Verilator flow.

The commands in this guide assume the repository is cloned under
`~/Desktop`. Any other directory can be used if the paths are adjusted
accordingly.

## Tested Environment

- Host: macOS (Apple Silicon M1)
- Docker: Default architecture (linux/arm64)
- Container: Ubuntu 24.04
- Verilator: v5.008

## Prerequisites

The following tools should be installed on the host system:

- Docker
- Git

## Clone BlackParrot

```bash
cd ~/Desktop
mkdir black-parrot
cd black-parrot
git clone https://github.com/black-parrot/black-parrot.git
cd black-parrot
git submodule sync --recursive
git submodule update --init --recursive
```
Workspace layout should look like:
```
Desktop/
 └── black-parrot/
      └── black-parrot/
```

## Host Workspace Setup

A host directory is mounted into the container to persist build artifacts.

Create a workspace on the Desktop:
```
mkdir -p ~/Desktop/work
```
Waveforms and copied simulation artifacts are stored in this directory.


## Build Docker Image
Move to this folder in the repository:
```bash
cd ~/Desktop/black-parrot/black-parrot/docker
```
From the docker/ directory:

```bash
make docker-build DOCKER_PLATFORM=ubuntu24.04
```
This creates the Docker image used for all subsequent steps.

## Run the Docker Image 

First verify if the image is built:
```bash
docker images
```
This command builds the `black-parrot` Docker image used in the next step.
```bash
docker run -it \
--name bp-verilator \
-v ~/Desktop/work:/work \
-v ~/Desktop/black-parrot/black-parrot:/workspace/black-parrot \
--user root \
black-parrot
```

### Verify Volume Mapping (Important)
Input:
```bash
ls /
```

Expected directories include:
`bin  boot  dev  etc  home  lib  proc  root  usr  workspace  work`

Input:
```bash
touch /work/test.txt
ls /work
```
Expected output:

`test.txt`

Input:
```bash
ls /workspace/black-parrot
```
Output:

```
CONTRIBUTING.md  LICENSE  Makefile  Makefile.common  Makefile.env  README.md  bp_be  bp_common	bp_fe  bp_me  bp_top  ci  docker  docs	external  mk  tcl
```

## Install Dependencies

Inside the container:
```bash
apt update
apt install -y \
  git build-essential \
  autoconf automake libtool \
  python3 python3-pip \
  cmake ninja-build \
  bison flex \
  libgmp-dev libmpc-dev libmpfr-dev \
  zlib1g-dev \
  device-tree-compiler \
  curl \
  help2man
```


## Install Verilator (v5.008)
```bash
cd /workspace
git clone https://github.com/verilator/verilator
cd verilator
git checkout v5.008
autoconf
./configure
make -j2
make install
```
`-j2` is recommended for machines with 8GB RAM to avoid out-of-memory errors during compilation.

Verify installation:
```bash
verilator --version
which verilator
```

Expected:
```
Verilator 5.008
/usr/local/bin/verilator
```
Newer Verilator releases remove the `--binary` option used by the current BlackParrot Verilator Makefiles. Verilator v5.008 is verified to be compatible with the current BlackParrot Verilator flow.

If a newer Verilator version is used, the build fails with:
```
%Error: Invalid option: --binary
```

In that case, reinstall Verilator and ensure that version v5.008 is checked out before building.



## Configuration 

Check if all the submodules are in place

```bash
cd /workspace/black-parrot
make checkout
```
Then build the libraries

```bash
make libs
```
This builds external dependency libraries required by the BlackParrot toolchain.

Set the environment variables

```bash
echo 'export BP_DIR=/workspace/black-parrot' >> ~/.bashrc
echo 'export BP_EXTERNAL_DIR=$BP_DIR/external' >> ~/.bashrc
echo 'export BASEJUMP_STL_DIR=$BP_EXTERNAL_DIR/basejump_stl' >> ~/.bashrc
echo 'export HARDFLOAT_DIR=$BP_EXTERNAL_DIR/HardFloat' >> ~/.bashrc
source ~/.bashrc
```

Verify:
```bash
echo $HARDFLOAT_DIR
ls $HARDFLOAT_DIR/source/RISCV
```

You should see:
```
HardFloat_consts.vi
HardFloat_specialize.vi
```

## Running Verilator Simulation

Navigate to the Verilator flow:
```bash
cd /workspace/black-parrot/bp_top/verilator
```

Available targets:
```bash
make help
```

Common targets:
```
- help 
- lint.verilator
- build.verilator
- sim.verilator
- wave.verilator
```


## Build and Simulate

Clean previous artifacts:
```bash
make clean
rm -rf obj_dir results
```

Build with waveform support:

```bash
make build.verilator TRACE=1 -j2
```

- TRACE=1 enables --trace-fst in Verilator and generates waveform dump files.
- Do not increase parallelism beyond available RAM (e.g., avoid -j8 on 8GB systems).

Run simulation:
```bash
make sim.verilator TRACE=1
```



## Expected Output

A successful run includes:
```
Hello World!
[CORE FSH] PASS
[BSG-PASS]
Verilog $finish
```

Presence of [BSG-PASS] indicates successful simulation.


If `TRACE=1` is enabled, an FST waveform file is generated in the results directory.

## Viewing Waveforms (Host)

Copy the FST file from the container:
```bash
find results -name "*.fst" -exec cp {} /work/ \;
```
This ensures the waveform is copied even if the results directory changes.

To view the waveform, either exit the container or open a new terminal on the host.
Open with GTKWave:
```bash
brew install gtkwave # If gtkwave is not installed
gtkwave ~/Desktop/work/dump.fst
```

## Exiting the container
```bash
exit
```
## Re-entering the container 
```bash
docker start bp-verilator
docker exec -it bp-verilator bash
cd /workspace/black-parrot
```

## Memory End Verification Flow (bp_me) — With Waveform Support
This evaluation flow validates the Memory End with full waveform generation enabled.
Navigate to the Memory End Verilator flow:
```bash
cd /workspace/black-parrot/bp_me/verilator
```
Clean Build with Waveform Support
```bash
make clean
rm -rf obj_dir results
make build.verilator TRACE=1 -j2
```
- TRACE=1 enables --trace-fst
- Generates ```.fst``` waveform files
- Required for debugging coherence transitions
1. Random Coherence Stress
```bash
make sim.verilator TRACE=1 PROG=random_test NUM_INSTR_P=5000
```
Validates:
- LCE/CCE protocol transitions
- Coherence state correctness
- Randomized memory access patterns
Waveform Use:
- Inspect LCE state machine transitions
- Observe CCE directory updates
- Check request/response timing
2. Set Hammer Test
```bash
make sim.verilator TRACE=1 PROG=set_test ME_TEST_P=1
```
Validates:
- Cache eviction behavior
- Replacement logic
- Single-set stress conditions
Waveform Use:
- Observe eviction decision logic
- Track tag comparisons
- Verify replacement policy behavior
3. Load/Store Directed Test
```bash
make sim.verilator TRACE=1 PROG=ld_st
```
Validates:
- Deterministic load/store ordering
- Basic memory correctness
Waveform Use:
- Inspect memory request pipeline
- Verify load-return timing
- Confirm no dropped transactions
4. Trace-Based Deterministic Test (Waveform Enabled)
```bash
make sim.verilator TRACE=1 PROG=mixed ME_TEST_P=2
```
Validates:
- Trace replay correctness
- Reproducibility of test scenarios
Waveform Use:
- Inspect coherence protocol behavior in the waveform.

## Notes

- TRACE is disabled by default (TRACE ?= 0).
- Use `make clean` if CONFIG, FLAGS, or PARAMS are changed.
- The mounted host directory preserves build artifacts across container restarts.
- The flow has been validated with Verilator v5.008.

### Troubleshooting

Error:
```
%Error: Invalid option: --binary
```

Cause:
A newer version of Verilator is installed. Newer releases removed the
`--binary` option used by the current BlackParrot Verilator flow.

Fix:
Reinstall Verilator and ensure version **v5.008** is checked out before building.
### Architecture

```
Host macOS
   │
   ├── Docker Container (Ubuntu)
   │       │
   │       ├── Verilator
   │       └── BlackParrot
   │
   └── Mounted Volume
        ~/Desktop/work  ← copied waveforms
```

### Cleanup

To remove the container:
```bash
docker rm bp-verilator
```

To remove the image:
```bash
docker rmi black-parrot
```

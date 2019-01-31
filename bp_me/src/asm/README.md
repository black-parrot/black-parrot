# CCE Microcode Assembler

## Build
```
make as
```

## Create Microcde ROMs
To create a set of Microcode ROMs from an existing assembly file, execute the following command:

```
python2 roms.py -i microcode/cce/demo.S -W 8 16 32 64 -N 1 2 4 8 16 -E 8
```

The parameters are as follows:

* \-i: input assembly file
* \-W: number of Way-Groups per CCE (space separated list)
* \-N: number of LCEs (space separated list)
* \-E: associativity of LCEs (space separated list)

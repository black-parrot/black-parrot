#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

#crc32
#ctl-string
#ludcmp
#matmult-float
#rijndael
#st
suite=beebs
progs=(
    aha-compress
    aha-mont64
    bs
    bubblesort
    cnt
    compress
    cover
    crc
    ctl-stack
    ctl-vector
    cubic
    dijkstra
    dtoa
    duff
    edn
    expint
    fac
    fasta
    fdct
    fibcall
    fir
    frac
    huffbench
    insertsort
    janne_complex
    jfdctint
    lcdnum
    levenshtein
    matmult-int
    mergesort
    miniz
    minver
    nbody
    ndes
    nettle-aes
    nettle-arcfour
    nettle-cast128
    nettle-des
    nettle-md5
    nettle-sha256
    newlib-exp
    newlib-log
    newlib-mod
    newlib-sqrt
    nsichneu
    ns
    picojpeg
    prime
    qrduino
    qsort
    qurt
    recursion
    select
    sglib-arraybinsearch
    sglib-arrayheapsort
    sglib-arrayquicksort
    sglib-dllist
    sglib-hashtable
    sglib-listinsertsort
    sglib-listsort
    sglib-queue
    sglib-rbtree
    slre
    sqrt
    statemate
    stb_perlin
    stringsearch1
    strstr
    tarai
    template
    trio-snprintf
    trio-sscanf
    ud
    whetstone
    wikisort
)

export DROMAJO_COSIM=1
export CFG=${cfg}
bsg_run_task "building ${cfg}" make -C ${bsg_top}/${end}/${tool} build.${tool}
parallel -j${cores} do_single_sim ${tool} ${cfg} ${suite} {} ::: "${progs[@]}"

bsg_pass $(basename $0)


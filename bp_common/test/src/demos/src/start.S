#include "../env/v/riscv_test.h"

.section ".text"
.globl userstart

userstart:
    li   sp, 0x80008FF0
    jal main

/* to stop, make an ecall */
loop:
    addi x0, x0, 0
    j loop

#!/bin/bash
source $(dirname $0)/functions.sh

tool=$1
end=$2
cfg=$3
cores=${4:-1}

suite=riscv-arch
progs=(add-01 addi-01 addiw-01 add.uw-01 addw-01 amoadd.d-01 amoadd.w-01 amoand.d-01 amoand.w-01 amomax.d-01 amomaxu.d-01 amomaxu.w-01 amomax.w-01 amomin.d-01 amominu.d-01 amominu.w-01 amomin.w-01 amoor.d-01 amoor.w-01 amoswap.d-01 amoswap.w-01 amoxor.d-01 amoxor.w-01 and-01 andi-01 andn-01 auipc-01 bclr-01 bclri-01 beq-01 bext-01 bexti-01 bge-01 bgeu-01 binv-01 binvi-01 blt-01 bltu-01 bne-01 bset-01 bseti-01 cadd-01 caddi-01 caddi16sp-01 caddi4spn-01 caddiw-01 caddw-01 cand-01 candi-01 cbeqz-01 cbnez-01 cebreak-01 cj-01 cjalr-01 cjr-01 cld-01 cldsp-01 cli-01 clui-01 clw-01 clwsp-01 clz-01 clzw-01 cmv-01 cnop-01 cor-01 cpop-01 cpopw-01 csd-01 csdsp-01 cslli-01 csrai-01 csrli-01 csub-01 csubw-01 csw-01 cswsp-01 ctz-01 ctzw-01 cxor-01 div-01 divu-01 divuw-01 divw-01 fcvt.d.l_b25-01 fcvt.d.l_b26-01 fcvt.d.lu_b25-01 fcvt.d.lu_b26-01 fcvt.l.d_b1-01 fcvt.l.d_b22-01 fcvt.l.d_b23-01 fcvt.l.d_b24-01 fcvt.l.d_b27-01 fcvt.l.d_b28-01 fcvt.l.d_b29-01 fcvt.l.s_b1-01 fcvt.l.s_b22-01 fcvt.l.s_b23-01 fcvt.l.s_b24-01 fcvt.l.s_b27-01 fcvt.l.s_b28-01 fcvt.l.s_b29-01 fcvt.lu.d_b1-01 fcvt.lu.d_b22-01 fcvt.lu.d_b23-01 fcvt.lu.d_b24-01 fcvt.lu.d_b27-01 fcvt.lu.d_b28-01 fcvt.lu.d_b29-01 fcvt.lu.s_b1-01 fcvt.lu.s_b22-01 fcvt.lu.s_b23-01 fcvt.lu.s_b24-01 fcvt.lu.s_b27-01 fcvt.lu.s_b28-01 fcvt.lu.s_b29-01 fcvt.s.l_b25-01 fcvt.s.l_b26-01 fcvt.s.lu_b25-01 fcvt.s.lu_b26-01 fence-01 fmv.d.x_b25-01 fmv.d.x_b26-01 fmv.x.d_b1-01 fmv.x.d_b22-01 fmv.x.d_b23-01 fmv.x.d_b24-01 fmv.x.d_b27-01 fmv.x.d_b28-01 fmv.x.d_b29-01 jal-01 jalr-01 lb-align-01 lbu-align-01 ld-align-01 lh-align-01 lhu-align-01 lui-01 lw-align-01 lwu-align-01 max-01 maxu-01 min-01 minu-01 misalign1-cjalr-01 misalign1-cjr-01 misalign1-jalr-01 misalign2-jalr-01 misalign-beq-01 misalign-bge-01 misalign-bgeu-01 misalign-blt-01 misalign-bltu-01 misalign-bne-01 misalign-jal-01 misalign-ld-01 misalign-lh-01 misalign-lhu-01 misalign-lw-01 misalign-lwu-01 misalign-sd-01 misalign-sh-01 misalign-sw-01 mul-01 mulh-01 mulhsu-01 mulhu-01 mulw-01 or-01 orcb_64-01 ori-01 orn-01 rem-01 remu-01 remuw-01 remw-01 rev8-01 rol-01 rolw-01 ror-01 rori-01 roriw-01 rorw-01 sb-align-01 sd-align-01 sext.b-01 sext.h-01 sh1add-01 sh1add.uw-01 sh2add-01 sh2add.uw-01 sh3add-01 sh3add.uw-01 sh-align-01 sll-01 slli-01 slli.uw-01 slliw-01 sllw-01 slt-01 slti-01 sltiu-01 sltu-01 sra-01 srai-01 sraiw-01 sraw-01 srl-01 srli-01 srliw-01 srlw-01 sub-01 subw-01 sw-align-01 xnor-01 xor-01 xori-01 zext.h_64-01)

export SPIKE_COSIM=1
export CFG=${cfg}
bsg_run_task "building ${cfg}" make -C ${bsg_top}/${end}/${tool} build.${tool}
parallel -j${cores} do_single_sim ${tool} ${cfg} ${suite} {} ::: "${progs[@]}"

bsg_pass $(basename $0)


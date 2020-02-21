BP_DEMOS = \
  bs                  \
  uc_simple           \
  simple              \
  hello_world         \
  basic_demo          \
  atomic_queue_demo_2 \
  atomic_queue_demo_4 \
  atomic_queue_demo_8 \
  atomic_queue_demo_12 \
  atomic_queue_demo_16 \
  queue_demo_2  \
  queue_demo_4  \
  queue_demo_8  \
  queue_demo_2  \
  queue_demo_4  \
  queue_demo_8  \
  copy_example  \
  trap_demo     \
  atomic_demo   \
  mc_sanity_1 \
  mc_sanity_2 \
  mc_sanity_3 \
  mc_sanity_4 \
  mc_sanity_6 \
  mc_sanity_8 \
  mc_sanity_12 \
  mc_sanity_16 \
  mc_template_1 \
  mc_template_2 \
  mc_rand_walk_1 \
  mc_rand_walk_2 \
  mc_rand_walk_3 \
  mc_rand_walk_4 \
  mc_rand_walk_6 \
  mc_rand_walk_8 \
  mc_rand_walk_12 \
  mc_rand_walk_16 \
  mc_work_share_sort_1 \
  mc_work_share_sort_2 \
  mc_work_share_sort_3 \
  mc_work_share_sort_4 \
  mc_work_share_sort_6 \
  mc_work_share_sort_8 \
  mc_work_share_sort_12 \
  mc_work_share_sort_16

RV64_BENCHMARKS = \
  median   \
  multiply \
  towers   \
  vvadd    \
  qsort    \
  rsort    \
  dhrystone #\
  mm \
  spmv \
  mt-vvadd \
  mt-matmul \
  pmp 

  # Uses m-mode illegal instruction exception
  #rv64mi-p-csr
  #rv64mi-p-illegal
  #rv64mi-p-sbreak
  #rv64si-p-csr
  #rv64si-p-sbreak
  #rv64si-p-scall
  #rv64si-p-ma_fetch
  #rv64mi-p-ma_fetch
  #rv64mi-p-access
  #rv64mi-p-breakpoint
  #rv64mi-p-ma_addr
  #rv64mi-p-mcsr
  #rv64mi-p-scall
  #rv64si-p-dirty
  #rv64si-p-icache-alias
  #rv64si-p-wfi
RV64_P_TESTS = \
  rv64ui-p-add     \
  rv64ui-p-addi    \
  rv64ui-p-addiw   \
  rv64ui-p-addw    \
  rv64ui-p-and     \
  rv64ui-p-andi    \
  rv64ui-p-auipc   \
  rv64ui-p-beq     \
  rv64ui-p-bge     \
  rv64ui-p-bgeu    \
  rv64ui-p-blt     \
  rv64ui-p-bltu    \
  rv64ui-p-bne     \
  rv64ui-p-fence_i \
  rv64ui-p-jal     \
  rv64ui-p-jalr    \
  rv64ui-p-lb      \
  rv64ui-p-lbu     \
  rv64ui-p-ld      \
  rv64ui-p-lh      \
  rv64ui-p-lhu     \
  rv64ui-p-lui     \
  rv64ui-p-lw      \
  rv64ui-p-lwu     \
  rv64ui-p-or      \
  rv64ui-p-ori     \
  rv64ui-p-sb      \
  rv64ui-p-sd      \
  rv64ui-p-sh      \
  rv64ui-p-simple  \
  rv64ui-p-sll     \
  rv64ui-p-slli    \
  rv64ui-p-slliw   \
  rv64ui-p-sllw    \
  rv64ui-p-slt     \
  rv64ui-p-slti    \
  rv64ui-p-sltiu   \
  rv64ui-p-sltu    \
  rv64ui-p-sra     \
  rv64ui-p-srai    \
  rv64ui-p-sraiw   \
  rv64ui-p-sraw    \
  rv64ui-p-srl     \
  rv64ui-p-srli    \
  rv64ui-p-srliw   \
  rv64ui-p-srlw    \
  rv64ui-p-sub     \
  rv64ui-p-subw    \
  rv64ui-p-sw      \
  rv64ui-p-xor     \
  rv64ui-p-xori    \
  rv64ua-p-amoadd_d  \
  rv64ua-p-amoadd_w  \
  rv64ua-p-amoand_d  \
  rv64ua-p-amoand_w  \
  rv64ua-p-amomax_d  \
  rv64ua-p-amomax_w  \
  rv64ua-p-amomaxu_w \
  rv64ua-p-amomaxu_d \
  rv64ua-p-amomin_d  \
  rv64ua-p-amomin_w  \
  rv64ua-p-amominu_w \
  rv64ua-p-amominu_d \
  rv64ua-p-amoor_d   \
  rv64ua-p-amoor_w   \
  rv64ua-p-amoswap_d \
  rv64ua-p-amoswap_w \
  rv64ua-p-amoxor_d  \
  rv64ua-p-amoxor_w  \
  rv64ua-p-lrsc

  #rv64ua-v-amominu_w
RV64_V_TESTS = \
  rv64ui-v-add     \
  rv64ui-v-addi    \
  rv64ui-v-addiw   \
  rv64ui-v-addw    \
  rv64ui-v-and     \
  rv64ui-v-andi    \
  rv64ui-v-auipc   \
  rv64ui-v-beq     \
  rv64ui-v-bge     \
  rv64ui-v-bgeu    \
  rv64ui-v-blt     \
  rv64ui-v-bltu    \
  rv64ui-v-bne     \
  rv64ui-v-fence_i \
  rv64ui-v-jal     \
  rv64ui-v-jalr    \
  rv64ui-v-lb      \
  rv64ui-v-lbu     \
  rv64ui-v-ld      \
  rv64ui-v-lh      \
  rv64ui-v-lhu     \
  rv64ui-v-lui     \
  rv64ui-v-lw      \
  rv64ui-v-lwu     \
  rv64ui-v-or      \
  rv64ui-v-ori     \
  rv64ui-v-sb      \
  rv64ui-v-sd      \
  rv64ui-v-sh      \
  rv64ui-v-simple  \
  rv64ui-v-sll     \
  rv64ui-v-slli    \
  rv64ui-v-slliw   \
  rv64ui-v-sllw    \
  rv64ui-v-slt     \
  rv64ui-v-slti    \
  rv64ui-v-sltiu   \
  rv64ui-v-sltu    \
  rv64ui-v-sra     \
  rv64ui-v-srai    \
  rv64ui-v-sraiw   \
  rv64ui-v-sraw    \
  rv64ui-v-srl     \
  rv64ui-v-srli    \
  rv64ui-v-srliw   \
  rv64ui-v-srlw    \
  rv64ui-v-sub     \
  rv64ui-v-subw    \
  rv64ui-v-sw      \
  rv64ui-v-xor     \
  rv64ui-v-xori    \
  #rv64ua-v-amoadd_d  \
  rv64ua-v-amoadd_w  \
  rv64ua-v-amoand_d  \
  rv64ua-v-amoand_w  \
  rv64ua-v-amomax_d  \
  rv64ua-v-amomax_w  \
  rv64ua-v-amomaxu_w \
  rv64ua-v-amomaxu_d \
  rv64ua-v-amomin_d  \
  rv64ua-v-amomin_w  \
  rv64ua-v-amominu_d \
  rv64ua-v-amoor_d   \
  rv64ua-v-amoor_w   \
  rv64ua-v-amoswap_d \
  rv64ua-v-amoswap_w \
  rv64ua-v-amoxor_d  \
  rv64ua-v-amoxor_w  \
  rv64ua-v-lrsc

RV64_PT_TESTS = \
  rv64ui-pt-add     \
  rv64ui-pt-addi    \
  rv64ui-pt-addiw   \
  rv64ui-pt-addw    \
  rv64ui-pt-and     \
  rv64ui-pt-andi    \
  rv64ui-pt-auipc   \
  rv64ui-pt-beq     \
  rv64ui-pt-bge     \
  rv64ui-pt-bgeu    \
  rv64ui-pt-blt     \
  rv64ui-pt-bltu    \
  rv64ui-pt-bne     \
  rv64ui-pt-fence_i \
  rv64ui-pt-jal     \
  rv64ui-pt-jalr    \
  rv64ui-pt-lb      \
  rv64ui-pt-lbu     \
  rv64ui-pt-ld      \
  rv64ui-pt-lh      \
  rv64ui-pt-lhu     \
  rv64ui-pt-lui     \
  rv64ui-pt-lw      \
  rv64ui-pt-lwu     \
  rv64ui-pt-or      \
  rv64ui-pt-ori     \
  rv64ui-pt-sb      \
  rv64ui-pt-sd      \
  rv64ui-pt-sh      \
  rv64ui-pt-simple  \
  rv64ui-pt-sll     \
  rv64ui-pt-slli    \
  rv64ui-pt-slliw   \
  rv64ui-pt-sllw    \
  rv64ui-pt-slt     \
  rv64ui-pt-slti    \
  rv64ui-pt-sltiu   \
  rv64ui-pt-sltu    \
  rv64ui-pt-sra     \
  rv64ui-pt-srai    \
  rv64ui-pt-sraiw   \
  rv64ui-pt-sraw    \
  rv64ui-pt-srl     \
  rv64ui-pt-srli    \
  rv64ui-pt-srliw   \
  rv64ui-pt-srlw    \
  rv64ui-pt-sub     \
  rv64ui-pt-subw    \
  rv64ui-pt-sw      \
  rv64ui-pt-xor     \
  rv64ui-pt-xori    \
  #rv64ua-pt-amoadd_d  \
  rv64ua-pt-amoadd_w  \
  rv64ua-pt-amoand_d  \
  rv64ua-pt-amoand_w  \
  rv64ua-pt-amomax_d  \
  rv64ua-pt-amomax_w  \
  rv64ua-pt-amomaxu_w \
  rv64ua-pt-amomaxu_d \
  rv64ua-pt-amomin_d  \
  rv64ua-pt-amomin_w  \
  rv64ua-pt-amominu_w \
  rv64ua-pt-amominu_d \
  rv64ua-pt-amoor_d   \
  rv64ua-pt-amoor_w   \
  rv64ua-pt-amoswap_d \
  rv64ua-pt-amoswap_w \
  rv64ua-pt-amoxor_d  \
  rv64ua-pt-amoxor_w  \
  rv64ua-pt-lrsc


RV64_VT_TESTS = \
  rv64ui-vt-add     \
  rv64ui-vt-addi    \
  rv64ui-vt-addiw   \
  rv64ui-vt-addw    \
  rv64ui-vt-and     \
  rv64ui-vt-andi    \
  rv64ui-vt-auipc   \
  rv64ui-vt-beq     \
  rv64ui-vt-bge     \
  rv64ui-vt-bgeu    \
  rv64ui-vt-blt     \
  rv64ui-vt-bltu    \
  rv64ui-vt-bne     \
  rv64ui-vt-fence_i \
  rv64ui-vt-jal     \
  rv64ui-vt-jalr    \
  rv64ui-vt-lb      \
  rv64ui-vt-lbu     \
  rv64ui-vt-ld      \
  rv64ui-vt-lh      \
  rv64ui-vt-lhu     \
  rv64ui-vt-lui     \
  rv64ui-vt-lw      \
  rv64ui-vt-lwu     \
  rv64ui-vt-or      \
  rv64ui-vt-ori     \
  rv64ui-vt-sb      \
  rv64ui-vt-sd      \
  rv64ui-vt-sh      \
  rv64ui-vt-simple  \
  rv64ui-vt-sll     \
  rv64ui-vt-slli    \
  rv64ui-vt-slliw   \
  rv64ui-vt-sllw    \
  rv64ui-vt-slt     \
  rv64ui-vt-slti    \
  rv64ui-vt-sltiu   \
  rv64ui-vt-sltu    \
  rv64ui-vt-sra     \
  rv64ui-vt-srai    \
  rv64ui-vt-sraiw   \
  rv64ui-vt-sraw    \
  rv64ui-vt-srl     \
  rv64ui-vt-srli    \
  rv64ui-vt-srliw   \
  rv64ui-vt-srlw    \
  rv64ui-vt-sub     \
  rv64ui-vt-subw    \
  rv64ui-vt-sw      \
  rv64ui-vt-xor     \
  rv64ui-vt-xori    \
  #rv64ua-vt-amoadd_d  \
  rv64ua-vt-amoadd_w  \
  rv64ua-vt-amoand_d  \
  rv64ua-vt-amoand_w  \
  rv64ua-vt-amomax_d  \
  rv64ua-vt-amomax_w  \
  rv64ua-vt-amomaxu_w \
  rv64ua-vt-amomaxu_d \
  rv64ua-vt-amomin_d  \
  rv64ua-vt-amomin_w  \
  rv64ua-vt-amominu_w \
  rv64ua-vt-amominu_d \
  rv64ua-vt-amoor_d   \
  rv64ua-vt-amoor_w   \
  rv64ua-vt-amoswap_d \
  rv64ua-vt-amoswap_w \
  rv64ua-vt-amoxor_d  \
  rv64ua-vt-amoxor_w  \
  rv64ua-vt-lrsc



#Removed from beebs testsuite - 
#ctl, matmul, sglib-arraysort, trio due to beebs configure -> makefile -> make bug (no exe made)
#crc32, ctl-string, dtoa, rijndael fail in spike 
BEEBS_TESTS = \
  aha-compress \
  aha-mont64 \
  bs \
  bubblesort \
  cnt \
  compress \
  cover \
  crc \
  ctl-stack \
  ctl-vector \
  cubic \
  dijkstra \
  duff \
  edn \
  expint \
  fac \
  fasta \
  fdct \
  fibcall \
  fir \
  frac \
  huffbench \
  insertsort \
  janne_complex \
  jfdctint \
  lcdnum \
  levenshtein \
  ludcmp \
  matmult-float \
  matmult-int \
  mergesort \
  miniz \
  minver \
  nbody \
  ndes \
  nettle-aes \
  nettle-arcfour \
  nettle-cast128 \
  nettle-des \
  nettle-md5 \
  nettle-sha256 \
  newlib-exp \
  newlib-log \
  newlib-mod \
  newlib-sqrt \
  ns \
  nsichneu \
  picojpeg \
  prime \
  qrduino \
  qurt \
  recursion \
  select \
  sglib-arraybinsearch \
  sglib-arrayheapsort \
  sglib-arrayquicksort \
  sglib-dllist \
  sglib-hashtable \
  sglib-listinsertsort \
  sglib-listsort \
  sglib-queue \
  sglib-rbtree \
  slre \
  sqrt \
  st \
  statemate \
  stb_perlin \
  stringsearch1 \
  strstr \
  tarai \
  template \
  trio-snprintf \
  trio-sscanf \
  ud \
  whetstone \
  wikisort
  # qsort works, but there's a name conflict with riscv-tests. We should fix this
  #   by putting each test suite in its own mem directory
  #qsort \

BP_SPEC = \
  vpr

BP_RVDV = \
  riscv_arithmetic_basic_test \
  riscv_mmu_stress_test \
  riscv_privileged_mode_rand_test \
  riscv_rand_instr_test \
  riscv_loop_test \
  riscv_rand_jump_test \
  riscv_no_fence_test \
  riscv_sfence_exception_test \
  riscv_illegal_instr_test \
  riscv_full_interrupt_test

  


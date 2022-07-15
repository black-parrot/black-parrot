// Copyright (c) 2022, University of Washington
// Copyright and related rights are licensed under the BSD 3-Clause
// License (the “License”); you may not use this file except in compliance
// with the License. You may obtain a copy of the License at
// https://github.com/black-parrot/black-parrot/LICENSE.
// Unless required by applicable law or agreed to in writing, software,
// hardware and materials distributed under this License is distributed
// on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language
// governing permissions and limitations under the License.

`ifndef BP_ME_CCE_INST_DEFINES_SVH
`define BP_ME_CCE_INST_DEFINES_SVH

  /*
   * Instruction width definitions
   */

  // Instructions are 32-bits wide with 2 bits of attached metadata
  // cce_instr_width_gp should be equal to 34, and used when passing instruction+metadata
  `define bp_cce_inst_data_width 32
  `define bp_cce_inst_metadata_width 2
  `define bp_cce_inst_op_width 3
  `define bp_cce_inst_minor_op_width 4

  // Microcode RAM address width
  // 9 bits allows up to 512 instructions
  // this must be greater or equal to cce_pc_width_p in bp_common_aviary_pkg
  `define bp_cce_inst_addr_width 9

  // Immediate field widths
  `define bp_cce_inst_imm1_width 1
  `define bp_cce_inst_imm2_width 2
  `define bp_cce_inst_imm4_width 4
  `define bp_cce_inst_imm8_width 8
  `define bp_cce_inst_imm16_width 16

  /*
   * General Purpose Registers
   *
   * Note: number of GPRs must be less than or equal to the number that can be
   * represented in the GPR operand enum. Currently, the maximum is 16 GPRs, but only
   * 8 are actually implemented and used.
   */

  `define bp_cce_inst_num_gpr 8
  // Note: this is hard-coded so it can be used in part-select / bit-slicing expressions
  `define bp_cce_inst_gpr_sel_width 3
  //`BSG_SAFE_CLOG2(`bp_cce_inst_num_gpr)
  `define bp_cce_inst_gpr_width 64

  `define bp_cce_inst_opd_width 4

`endif


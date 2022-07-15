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

/**
 *
 * Name:
 *   bp_cce_branch.sv
 *
 * Description:
 *   Branch evaluation logic for the CCE implementing equality/inequality and less than comparison.
 *   The branch unit also performs misprediction resolution, if needed.
 *
 *   Some microcode operations such as bgt are implemented via assembler/softwware transforms.
 *   See bp_cce_inst.svh for SW supported operations.
 *
 *   The operand width is parameterizable, and set based on the microarchitecture design.
 *
 *   The branch unit also computes and outputs the correct next PC for all instructions.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_branch
  import bp_me_pkg::*;
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(cce_pc_width_p)
  )
  (input [width_p-1:0]                       opd_a_i
   , input [width_p-1:0]                     opd_b_i
   , input                                   branch_i
   , input                                   predicted_taken_i
   , input bp_cce_inst_branch_op_e           branch_op_i
   , input [cce_pc_width_p-1:0]              execute_pc_i
   , input [cce_pc_width_p-1:0]              branch_target_i
   , output logic                            mispredict_o
   , output logic [cce_pc_width_p-1:0]       pc_o
  );

  wire equal = (opd_a_i == opd_b_i);
  wire not_equal = ~equal;
  wire less = (opd_a_i < opd_b_i);

  wire [cce_pc_width_p-1:0] execute_pc_plus_one = cce_pc_width_p'(execute_pc_i + 'd1);

  logic branch_res;
  always_comb begin : branch
    unique case (branch_op_i)
      e_branch_eq:  branch_res = equal;
      e_branch_neq: branch_res = not_equal;
      e_branch_lt:  branch_res = less;
      e_branch_le:  branch_res = (less | equal);
      default:      branch_res = '0;
    endcase

    // Misprediction happens if instruction is branch and:
    // a) branch was predicted not taken, but branch should have been taken
    // b) branch was predicted taken, but branch should not have been taken
    mispredict_o = branch_i & ((!predicted_taken_i & branch_res)
                               | (predicted_taken_i & !branch_res));

    // Output correct next PC (for all instructions)
    // If the current instruction is a branch and the branch evaluates to taken, the next PC
    // is the branch target. Else, the next PC is the current PC plus one.
    pc_o = (branch_i & branch_res)
           ? branch_target_i
           : execute_pc_plus_one;
  end

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_branch)

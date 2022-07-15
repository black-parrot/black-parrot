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

`ifndef BP_COMMON_ACCELERATOR_PKGDEF_SVH
`define BP_COMMON_ACCELERATOR_PKGDEF_SVH

  //vector-dot-product accelerator CSR indexes
  localparam inputa_ptr_csr_idx_gp = 20'h0_0000;
  localparam inputb_ptr_csr_idx_gp = 20'h0_0008; 
  localparam input_len_csr_idx_gp  = 20'h0_0010;
  localparam start_cmd_csr_idx_gp  = 20'h0_0018;
  localparam res_status_csr_idx_gp = 20'h0_0020;
  localparam res_ptr_csr_idx_gp    = 20'h0_0028;
  localparam res_len_csr_idx_gp    = 20'h0_0030;
  localparam operation_csr_idx_gp  = 20'h0_0038;


  //loopback accelerator CSR indexes
  localparam accel_wr_cnt_csr_idx_gp = 20'h0_0000;

`endif

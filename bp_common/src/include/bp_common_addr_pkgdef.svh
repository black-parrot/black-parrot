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

`ifndef BP_COMMON_ADDR_PKGDEF
`define BP_COMMON_ADDR_PKGDEF

  // TODO: These could be parameterizable, but there are some constraints of
  //   of bit placement within the local uncached space.
  // TL;DR 16MB ought to be enough for anyone
  localparam tile_id_width_gp  = 7;
  localparam dev_id_width_gp   = 4;
  localparam dev_addr_width_gp = 20;

  localparam host_dev_gp  = 1;
  localparam cfg_dev_gp   = 2;
  localparam clint_dev_gp = 3;
  localparam cache_dev_gp = 4;

                             // 0x00_0(nnnN)(D)(A_AAAA)
  localparam host_dev_base_addr_gp     = 32'h0010_0000;
  localparam cfg_dev_base_addr_gp      = 32'h0020_0000;
  localparam clint_dev_base_addr_gp    = 32'h0030_0000;
  localparam cache_dev_base_addr_gp    = 32'h0040_0000;

  // TODO: This is hardcoded for a 32-bit DRAM address, will need to be adjusted
  //   for a different address space
  localparam boot_base_addr_gp         = 40'h00_0011_0000;
  localparam dram_base_addr_gp         = 40'h00_8000_0000;
  localparam dram_uc_base_addr_gp      = 40'h01_0000_0000;
  localparam coproc_base_addr_gp       = 40'h02_0000_0000;
  localparam global_base_addr_gp       = 40'h03_0000_0000;

`endif


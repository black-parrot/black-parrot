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

/*
 * bp_me_pkg.svh
 *
 * Contains the interface structures used for communicating between the CCE and Memory.
 *
 */

  `include "bp_me_defines.svh"

package bp_me_pkg;

  import bp_common_pkg::*;

  `include "bp_me_cce_pkgdef.svh"
  `include "bp_me_cce_inst_pkgdef.svh"

endpackage


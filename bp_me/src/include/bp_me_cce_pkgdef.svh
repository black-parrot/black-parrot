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
 *   bp_me_cce_pkgdef.svh
 *
 * Description:
 */

`ifndef BP_ME_CCE_PKGDEF_SVH
`define BP_ME_CCE_PKGDEF_SVH

  // Struct that defines speculative memory access tracking metadata
  // This is used in the decoded instruction and the bp_cce_spec module
  typedef struct packed
  {
    logic           spec;
    logic           squash;
    logic           fwd_mod;
    bp_coh_states_e state;
  } bp_cce_spec_s;

  // Coherence Request Processing Flags
  // TODO: reorder this struct - requires reording in CCE instruction define and ucode assembler
  typedef struct packed {
    // request to cacheable address
    logic cacheable_address;
    // atomics
    logic atomic_no_return;
    logic atomic;
    // GAD flags
    logic upgrade;
    logic replacement;
    logic cached_forward;
    logic cached_owned;
    logic cached_modified;
    logic cached_exclusive;
    logic cached_shared;
    // misc flags
    logic speculative;
    logic pending;
    logic null_writeback;
    // request flags
    logic non_exclusive;
    logic uncached;
    logic write_not_read;
  } bp_cce_flags_s;

`endif


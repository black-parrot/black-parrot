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
 *  Name:
 *    bp_me_bedrock_wormhole_header_encode_lce_req.sv
 *
 *  Description:
 *    Outputs a bedrock wormhole header given an LCE Command input header.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_bedrock_wormhole_header_encode_lce_req
  import bp_common_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)

    , localparam wh_header_width_lp = `bp_bedrock_wormhole_header_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_req_header_width_lp)
    )
   (input [lce_req_header_width_lp-1:0]       header_i
    , output logic [wh_header_width_lp-1:0]   wh_header_o
    , output logic [coh_noc_len_width_p-1:0]  data_len_o
    );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `bp_cast_i(bp_bedrock_lce_req_header_s, header);

  logic [coh_noc_cord_width_p-1:0] cce_cord_li;
  logic [coh_noc_cid_width_p-1:0]  cce_cid_li;
  bp_me_cce_id_to_cord
    #(.bp_params_p(bp_params_p))
    router_cord
     (.cce_id_i(header_cast_i.payload.dst_id)
      ,.cce_cord_o(cce_cord_li)
      ,.cce_cid_o(cce_cid_li)
      );

  bp_me_bedrock_wormhole_header_encode
    #(.bp_params_p(bp_params_p)
      ,.flit_width_p(coh_noc_flit_width_p)
      ,.cord_width_p(coh_noc_cord_width_p)
      ,.cid_width_p(coh_noc_cid_width_p)
      ,.len_width_p(coh_noc_len_width_p)
      ,.payload_width_p(lce_req_payload_width_lp)
      ,.payload_mask_p(lce_req_payload_mask_gp)
      )
    header_encode
     (.header_i(header_i)
      ,.dst_cord_i(cce_cord_li)
      ,.dst_cid_i(cce_cid_li)
      ,.wh_header_o(wh_header_o)
      ,.data_len_o(data_len_o)
      );

endmodule


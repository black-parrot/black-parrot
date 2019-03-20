/**
 *
 * Name:
 *   bp_me_network.v
 *
 * Description:
 *   Each coherence network is a N x 1 mesh of routers connecting the LCEs and CCEs. The first
 *   router will connect to both an LCE and an CCE, while following routers may connect to both or
 *   only an LCE or CCE, depending on the number of each in the system. The width of the mesh is the
 *   max of the number of LCEs and CCEs. The exception to this is the LCE-LCE transfer network,
 *   which connects each LCE to every other LCE, and has width of number of LCEs.
 *
 *   Input and output signals should be concatenated together at instantiation
 *   Example input and output assignment ,.lce_cmd_x({lce_cmd_x_2, lce_cmd_x_1, lce_cmd_x_0})
 *
 *   Network is demanding as a producer and helpful as a consumer
 *   producer (outputs): ready_i, v_o (ready->valid)
 *   consumer (inputs): ready_o, v_i (valid->ready)
 *
 */

module bp_me_network
  import bp_common_pkg::*;
  #(parameter num_lce_p                 = "inv"
    , parameter num_cce_p               = "inv"
    , parameter paddr_width_p           = "inv"
    , parameter lce_assoc_p             = "inv"
    , parameter block_size_in_bytes_p   = "inv"

    // Default parameters
    , parameter data_cmd_max_num_flit_p  = 4
    , parameter data_resp_max_num_flit_p = 4
    , parameter debug_p                  = 0

    // Derived parameters
    , localparam block_size_in_bits_lp  = block_size_in_bytes_p*8

    // Coherence Message Widths
    , localparam bp_lce_cce_req_width_lp=
      `bp_lce_cce_req_width(num_cce_p,num_lce_p,paddr_width_p,lce_assoc_p)
    , localparam bp_lce_cce_resp_width_lp=
      `bp_lce_cce_resp_width(num_cce_p,num_lce_p,paddr_width_p)
    , localparam bp_lce_cce_data_resp_width_lp=
      `bp_lce_cce_data_resp_width(num_cce_p,num_lce_p,paddr_width_p,block_size_in_bits_lp)
    , localparam bp_cce_lce_cmd_width_lp=
      `bp_cce_lce_cmd_width(num_cce_p,num_lce_p,paddr_width_p,lce_assoc_p)
    , localparam bp_lce_data_cmd_width_lp=
      `bp_lce_data_cmd_width(num_lce_p,block_size_in_bits_lp,lce_assoc_p)
  )
  (input                                                        clk_i
   , input                                                      reset_i

   // CCE Command Network - (CCE->trans_net->LCE)
   // (LCE side)
   , output [num_lce_p-1:0][bp_cce_lce_cmd_width_lp-1:0]        lce_cmd_o
   , output [num_lce_p-1:0]                                     lce_cmd_v_o
   , input  [num_lce_p-1:0]                                     lce_cmd_ready_i
   // (CCE side)
   , input  [num_cce_p-1:0][bp_cce_lce_cmd_width_lp-1:0]        lce_cmd_i
   , input  [num_cce_p-1:0]                                     lce_cmd_v_i
   , output [num_cce_p-1:0]                                     lce_cmd_ready_o

   // Data Command Network
   // (LCE dest)
   , output [num_lce_p-1:0][bp_lce_data_cmd_width_lp-1:0]       lce_data_cmd_o
   , output [num_lce_p-1:0]                                     lce_data_cmd_v_o
   , input  [num_lce_p-1:0]                                     lce_data_cmd_ready_i
   // (CCE source)
   , input  [num_cce_p-1:0][bp_lce_data_cmd_width_lp-1:0]       cce_lce_data_cmd_i
   , input  [num_cce_p-1:0]                                     cce_lce_data_cmd_v_i
   , output [num_cce_p-1:0]                                     cce_lce_data_cmd_ready_o
   // (LCE source)
   , input  [num_lce_p-1:0][bp_lce_data_cmd_width_lp-1:0]       lce_lce_data_cmd_i
   , input  [num_lce_p-1:0]                                     lce_lce_data_cmd_v_i
   , output [num_lce_p-1:0]                                     lce_lce_data_cmd_ready_o

   // LCE Request Network - (LCE->trans_net->CCE)
   // (LCE side)
   , input  [num_lce_p-1:0][bp_lce_cce_req_width_lp-1:0]        lce_req_i
   , input  [num_lce_p-1:0]                                     lce_req_v_i
   , output [num_lce_p-1:0]                                     lce_req_ready_o
   // (CCE side)
   , output [num_cce_p-1:0][bp_lce_cce_req_width_lp-1:0]        lce_req_o
   , output [num_cce_p-1:0]                                     lce_req_v_o
   , input  [num_cce_p-1:0]                                     lce_req_ready_i

   // LCE Response Network - (LCE->trans_net->CCE)
   // (LCE side)
   , input  [num_lce_p-1:0][bp_lce_cce_resp_width_lp-1:0]       lce_resp_i
   , input  [num_lce_p-1:0]                                     lce_resp_v_i
   , output [num_lce_p-1:0]                                     lce_resp_ready_o
   // (CCE side)
   , output [num_cce_p-1:0][bp_lce_cce_resp_width_lp-1:0]       lce_resp_o
   , output [num_cce_p-1:0]                                     lce_resp_v_o
   , input  [num_cce_p-1:0]                                     lce_resp_ready_i

   // LCE Data Response Network - (LCE->trans_net->CCE)
   // (LCE side)
   , input  [num_lce_p-1:0][bp_lce_cce_data_resp_width_lp-1:0]  lce_data_resp_i
   , input  [num_lce_p-1:0]                                     lce_data_resp_v_i
   , output [num_lce_p-1:0]                                     lce_data_resp_ready_o
   // (CCE side)
   , output [num_cce_p-1:0][bp_lce_cce_data_resp_width_lp-1:0]  lce_data_resp_o
   , output [num_cce_p-1:0]                                     lce_data_resp_v_o
   , input  [num_cce_p-1:0]                                     lce_data_resp_ready_i
  );

  // CCE Command Network - (CCE->trans_net->LCE)
  bp_me_network_channel_mesh
    #(.packet_width_p(bp_cce_lce_cmd_width_lp)
      ,.num_src_p(num_cce_p)
      ,.num_dst_p(num_lce_p)
      ,.debug_p(debug_p)
      )
    cce_lce_cmd_network
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // South Port (src)
      ,.src_data_i(lce_cmd_i)
      ,.src_v_i(lce_cmd_v_i)
      ,.src_ready_o(lce_cmd_ready_o)
      // Proc Port (dst)
      ,.dst_data_o(lce_cmd_o)
      ,.dst_v_o(lce_cmd_v_o)
      ,.dst_ready_i(lce_cmd_ready_i)
      );

  // LCE Request Network - (LCE->trans_net->CCE)
  bp_me_network_channel_mesh
    #(.packet_width_p(bp_lce_cce_req_width_lp)
      ,.num_src_p(num_lce_p)
      ,.num_dst_p(num_cce_p)
      ,.debug_p(debug_p)
      )
    lce_cce_req_network
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // South Port (src)
      ,.src_data_i(lce_req_i)
      ,.src_v_i(lce_req_v_i)
      ,.src_ready_o(lce_req_ready_o)
      // Proc Port (dst)
      ,.dst_data_o(lce_req_o)
      ,.dst_v_o(lce_req_v_o)
      ,.dst_ready_i(lce_req_ready_i)
      );

  // LCE Response Network - (LCE->trans_net->CCE)
  bp_me_network_channel_mesh
    #(.packet_width_p(bp_lce_cce_resp_width_lp)
      ,.num_src_p(num_lce_p)
      ,.num_dst_p(num_cce_p)
      ,.debug_p(debug_p)
      )
    lce_cce_resp_network
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // South Port (src)
      ,.src_data_i(lce_resp_i)
      ,.src_v_i(lce_resp_v_i)
      ,.src_ready_o(lce_resp_ready_o)
      // Proc Port (dst)
      ,.dst_data_o(lce_resp_o)
      ,.dst_v_o(lce_resp_v_o)
      ,.dst_ready_i(lce_resp_ready_i)
      );

  // LCE Data Response Network - (LCE->trans_net->CCE)
  bp_me_network_channel_data_resp #(
    .num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p)
    ,.block_size_bits_p(block_size_in_bits_lp)
    ,.max_num_flit_p(data_resp_max_num_flit_p)
  ) data_resp_channel (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_data_resp_i(lce_data_resp_i)
    ,.lce_data_resp_v_i(lce_data_resp_v_i)
    ,.lce_data_resp_ready_o(lce_data_resp_ready_o)

    ,.lce_data_resp_o(lce_data_resp_o)
    ,.lce_data_resp_v_o(lce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_i)
  );

  // LCE data cmd network
  bp_me_network_channel_data_cmd #(
    .num_lce_p(num_lce_p)
    ,.num_cce_p(num_cce_p) 
    ,.block_size_in_bits_p(block_size_in_bits_lp)
    ,.lce_assoc_p(lce_assoc_p)
    ,.max_num_flit_p(data_cmd_max_num_flit_p)
  ) data_cmd_channel (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_data_cmd_o(lce_data_cmd_o)
    ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
    ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

    ,.cce_lce_data_cmd_i(cce_lce_data_cmd_i)
    ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
    ,.cce_lce_data_cmd_ready_o(cce_lce_data_cmd_ready_o)

    ,.lce_lce_data_cmd_i(lce_lce_data_cmd_i)
    ,.lce_lce_data_cmd_v_i(lce_lce_data_cmd_v_i)
    ,.lce_lce_data_cmd_ready_o(lce_lce_data_cmd_ready_o)
  );

  
endmodule

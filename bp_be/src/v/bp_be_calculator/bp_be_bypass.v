/**
 *
 * Name:
 *   bp_be_bypass.v
 *
 * Description:
 *   Register bypass network for up to 2 source registers and 1 destination register.
 *
 * Notes:
 *
 */

module bp_be_bypass
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , parameter depth_p   = "inv"
   , parameter els_p     = "inv"
   , parameter zero_x0_p = 0
   )
  (
   // Dispatched instruction operands
   input [els_p-1:0][reg_addr_width_p-1:0]      id_addr_i
   , input [els_p-1:0][dpath_width_p-1:0]       id_i

   // Completed rd writes in the pipeline
   , input [depth_p-1:0]                        fwd_rd_v_i
   , input [depth_p-1:0][reg_addr_width_p-1:0]  fwd_rd_addr_i
   , input [depth_p-1:0][dpath_width_p-1:0]     fwd_rd_i

   // The latest valid rs1, rs2 data
   , output [els_p-1:0][dpath_width_p-1:0]      bypass_o
   );

  // synopsys translate_off
  initial begin : parameter_validation
    assert (depth_p > 0 && depth_p != "inv")
      else $error("depth_p must be positive, else there is nothing to bypass. \
                   Did you remember to set it?"
                  );
  end
  // synopsys translate_on

  // Intermediate connections
  logic [els_p-1:0][depth_p:0]                        match_vector;
  logic [els_p-1:0][depth_p:0]                        match_vector_onehot;
  logic [els_p-1:0][depth_p:0][dpath_width_p-1:0] data_vector;
  logic [els_p-1:0][dpath_width_p-1:0]            bypass_lo;

  // Datapath
  for (genvar j = 0; j < els_p; j++)
    begin : els
      // Find the youngest valid data to forward
      bsg_priority_encode_one_hot_out
       #(.width_p(depth_p+1)
         ,.lo_to_hi_p(1)
         )
       match_one_hot
        (.i(match_vector[j])
         ,.o(match_vector_onehot[j])
         ,.v_o()
         );

      // Bypass data with a simple crossbar
      // Completion data has priority over dispatched data, so dispatched data goes to MSB
      bsg_crossbar_o_by_i
       #(.i_els_p(depth_p+1)
         ,.o_els_p(1)
         ,.width_p(dpath_width_p)
         )
       crossbar
        (.i({id_i[j], fwd_rd_i})
         ,.sel_oi_one_hot_i(match_vector_onehot[j])
         ,.o(bypass_lo[j])
         );

      assign bypass_o[j] = ((zero_x0_p == 1) & (id_addr_i[j] == '0)) ? '0 : bypass_lo[j];
    end

  always_comb
    for (integer j = 0; j < els_p; j++)
      for (integer i = 0; i < depth_p+1; i++)
        // Dispatched data always matches the dispatched data, otherwise check for:
        //   * Register address match
        //   * The completing instruction is writing and the dispatched instruction is reading
        //   * Do not forward x0 data, RISC-V defines this as always 0
        match_vector[j][i] = ((i == depth_p) || ((id_addr_i[j] == fwd_rd_addr_i[i]) & fwd_rd_v_i[i]));

endmodule


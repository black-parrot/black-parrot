/**
 *
 * Name:
 *   bp_cce_spec.v
 *
 * Description:
 *   This module contains the metadata required for speculative memory accesses.
 *
 *   These bits are stored in flops and may be read asynchronously.
 *
 *   Write to Read forwarding is supported.
 *
 */

module bp_cce_spec
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_way_groups_p            = "inv"

    // Derived parameters
    , localparam lg_num_way_groups_lp     = `BSG_SAFE_CLOG2(num_way_groups_p)

  )
  (input                                                          clk_i
   , input                                                        reset_i

   , input                                                        w_v_i
   , input [lg_num_way_groups_lp-1:0]                             w_way_group_i

   , input                                                        spec_v_i
   , input                                                        spec_i

   , input                                                        squash_v_i
   , input                                                        squash_i

   , input                                                        fwd_mod_v_i
   , input                                                        fwd_mod_i

   , input                                                        state_v_i
   , input [`bp_coh_bits-1:0]                                     state_i

   , input                                                        r_v_i
   , input [lg_num_way_groups_lp-1:0]                             r_way_group_i

   , output bp_cce_spec_s                                         data_o
   , output logic                                                 v_o

  );

  // speculation metadata bits
  bp_cce_spec_s [num_way_groups_p-1:0] data_r, data_n;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      data_r <= '0;
    end else begin
      data_r <= data_n;
    end
  end

  always_comb begin
    if (reset_i) begin
      data_n = '0;
    end else begin
      data_n = data_r;
      if (w_v_i) begin
        if (spec_v_i) begin
          data_n[w_way_group_i].spec = spec_i;
        end
        if (squash_v_i) begin
          data_n[w_way_group_i].squash = squash_i;
        end
        if (fwd_mod_v_i) begin
          data_n[w_way_group_i].fwd_mod = fwd_mod_i;
        end
        if (state_v_i) begin
          data_n[w_way_group_i].state = state_i;
        end
      end
    end
  end

  // Output
  // Normally, the output is determined by the read way group and comes from the flopped values
  // If reading from the same way group that is being written, output the next value
  assign data_o = (r_v_i & w_v_i & (w_way_group_i == r_way_group_i))
    ? data_n[r_way_group_i]
    : data_r[r_way_group_i];

  // Output is valid if read signal is asserted
  assign v_o = r_v_i;

endmodule

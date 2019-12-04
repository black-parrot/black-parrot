

// This is helper module to convert a coordinate into a set of ids. It assumes that
//   the SoC topology is a fixed 2d mesh with a set mapping.  Should be made more flexible
module bp_me_cord_to_id
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   )
  (input [coh_noc_cord_width_p-1:0]      cord_i
   , output logic [core_id_width_p-1:0]  core_id_o
   , output logic [cce_id_width_p-1:0]   cce_id_o
   , output logic [lce_id_width_p-1:0]   lce_id0_o
   , output logic [lce_id_width_p-1:0]   lce_id1_o
   );

  wire [coh_noc_x_cord_width_p-1:0] xcord_li = cord_i[0+:coh_noc_x_cord_width_p];
  wire [coh_noc_y_cord_width_p-1:0] ycord_li = cord_i[coh_noc_x_cord_width_p+:coh_noc_y_cord_width_p];

  localparam io_rows_lp  = `BSG_CDIV(num_io_p, cc_x_dim_p);
  localparam mc_rows_lp  = `BSG_CDIV(num_l2e_p, cc_x_dim_p);
  localparam cac_cols_lp = `BSG_CDIV(num_cacc_p, cc_y_dim_p);
  localparam sac_cols_lp = `BSG_CDIV(num_sacc_p, cc_y_dim_p);

  localparam max_cc_core_lp  = num_core_p;
  localparam max_mc_core_lp  = max_cc_core_lp + num_l2e_p;
  localparam max_cac_core_lp = max_mc_core_lp + num_cacc_p;
  localparam max_sac_core_lp = max_cac_core_lp + num_sacc_p;
  localparam max_ioc_core_lp = max_sac_core_lp + num_io_p;

  localparam max_cc_cce_lp  = num_core_p;
  localparam max_mc_cce_lp  = max_cc_cce_lp + num_l2e_p;
  localparam max_cac_cce_lp = max_mc_cce_lp + num_cacc_p;
  localparam max_sac_cce_lp = max_cac_cce_lp + num_sacc_p;
  localparam max_ioc_cce_lp = max_sac_cce_lp + num_io_p;

  localparam max_cc_lce_lp  = num_core_p*2;
  localparam max_cac_lce_lp = max_cc_lce_lp + num_cacc_p;
  localparam max_mc_lce_lp  = max_cac_lce_lp + num_l2e_p;
  localparam max_sac_lce_lp = max_mc_lce_lp + num_sacc_p;
  localparam max_ioc_lce_lp = max_sac_lce_lp + num_io_p;

  wire cord_in_cc_li  = (xcord_li >= sac_cols_lp) & (xcord_li <= sac_cols_lp+cc_x_dim_p)
                        & (ycord_li >= io_rows_lp) & (ycord_li <= io_rows_lp+cc_y_dim_p);
  wire cord_in_mc_li  = (xcord_li >= sac_cols_lp) & (xcord_li <= sac_cols_lp+cc_x_dim_p)
                        & (ycord_li > io_rows_lp+cc_y_dim_p);
  wire cord_in_cac_li = (xcord_li > sac_cols_lp+cc_x_dim_p)
                        & (ycord_li >= io_rows_lp) & (ycord_li <= io_rows_lp+cc_y_dim_p);
  wire cord_in_sac_li = (xcord_li < sac_cols_lp)
                        & (ycord_li >= io_rows_lp) & (ycord_li <= io_rows_lp+cc_y_dim_p);
  wire cord_in_io_li  = (xcord_li >= sac_cols_lp) & (xcord_li <= sac_cols_lp+cc_x_dim_p)
                        & (ycord_li < io_rows_lp);
  always_comb
    if (cord_in_cc_li)
      begin
        core_id_o   = (xcord_li-sac_cols_lp) + cc_x_dim_p * (ycord_li-io_rows_lp);
        cce_id_o    = core_id_o;
        lce_id0_o   = (core_id_o << 1'b1) + 1'b0;
        lce_id1_o   = (core_id_o << 1'b1) + 1'b1;
      end
    else if (cord_in_mc_li)
      begin
        core_id_o   = max_cc_core_lp + (xcord_li-sac_cols_lp);
        cce_id_o    = core_id_o;
        lce_id0_o   = max_cc_lce_lp + (xcord_li-sac_cols_lp);
        lce_id1_o   = 'X;
      end
    else if (cord_in_cac_li)
      begin
        core_id_o   = max_mc_core_lp + (ycord_li-io_rows_lp);
        cce_id_o    = core_id_o;
        lce_id0_o   = max_mc_lce_lp + (ycord_li-io_rows_lp);
        lce_id1_o   = 'X;
      end
    else if (cord_in_sac_li)
      begin
        core_id_o   = max_cac_core_lp + (ycord_li-io_rows_lp);
        cce_id_o    = core_id_o;
        lce_id0_o   = max_cac_lce_lp + (ycord_li-io_rows_lp);
        lce_id1_o   = 'X;
      end
    else if (cord_in_io_li)
      begin
        core_id_o   = max_sac_core_lp + (xcord_li-sac_cols_lp);
        cce_id_o    = core_id_o;
        lce_id0_o   = max_sac_lce_lp + (xcord_li-sac_cols_lp);
        lce_id1_o   = 'X;
      end

endmodule


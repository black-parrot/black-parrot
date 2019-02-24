/*
 *
 * bp_be_bserial_regfile.v
 *
 */

module bp_be_bserial_regfile
 import bp_be_rv64_pkg::*;
 #(localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam rf_els_lp       = rv64_rf_els_gp
   , localparam lg_rf_els_lp    = `BSG_SAFE_CLOG2(rv64_rf_els_gp)
   )
  (input                      clk_i
   , input                    reset_i

   , input                    en_i
   , input                    dir_i

   , input                    rs1_r_v_i
   , input [lg_rf_els_lp-1:0] rs1_addr_i
   , output                   rs1_data_o

   , input                    rs2_r_v_i
   , input [lg_rf_els_lp-1:0] rs2_addr_i
   , output                   rs2_data_o

   , input                    rd_w_v_i
   , input [lg_rf_els_lp-1:0] rd_addr_i
   , input                    rd_data_i
   , output                   rd_data_o
   );

logic [rf_els_lp-1:0] data_r;

generate
  assign rs1_data_o = (rs1_addr_i == lg_rf_els_lp'(0)) ? 1'b0 : data_r[rs1_addr_i];
  assign rs2_data_o = (rs2_addr_i == lg_rf_els_lp'(0)) ? 1'b0 : data_r[rs2_addr_i];
  assign rd_data_o  = (rd_addr_i  == lg_rf_els_lp'(0)) ? 1'b0 : data_r[rd_addr_i ];

asdflksnklnasdlkga;sldgklajsg
// Figure out why recovery mechanism isn't working

  for (genvar i = 0; i < rf_els_lp; i++)
    begin : rof1
      bsg_shift_reg
       #(.width_p(1)
         ,.stages_p(reg_data_width_lp)
         )
       register
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i( rd_w_v_i & (i == rd_addr_i) ? rd_data_i : data_r[i])
         ,.v_i(en_i & 
               ((rd_w_v_i & (i == rd_addr_i)) 
                | (rs1_r_v_i & (i == rs1_addr_i))
                | (rs2_r_v_i & (i == rs2_addr_i))
                )
               )
         ,.dir_i(dir_i)

         ,.data_o(data_r[i])
         );
    end // rof1
endgenerate

endmodule : bp_be_bserial_regfile


/**
 *
 * bp_be_calc_bypass.v
 *
 */

`include "bsg_defines.v"
`include "bp_be_internal_if.vh"

module bp_be_calc_bypass
 #(parameter num_pipe_els_p="inv"
   , parameter enable_p=1

   , localparam reg_addr_width_lp=RV64_reg_addr_width_gp
   , localparam reg_data_width_lp=RV64_reg_data_width_gp
   )
  (input logic                                               id_rs1_v_i
   , input logic [reg_addr_width_lp-1:0]                     id_rs1_addr_i
   , input logic [reg_data_width_lp-1:0]                     id_rs1_i

   , input logic                                             id_rs2_v_i
   , input logic [reg_addr_width_lp-1:0]                     id_rs2_addr_i
   , input logic [reg_data_width_lp-1:0]                     id_rs2_i

   , input logic [num_pipe_els_p-1:0]                        comp_v_i
   , input logic [num_pipe_els_p-1:0]                        comp_rf_w_v_i
   , input logic [num_pipe_els_p-1:0][reg_addr_width_lp-1:0] comp_rd_addr_i
   , input logic [num_pipe_els_p-1:0][reg_data_width_lp-1:0] comp_rd_i

   , output logic [reg_data_width_lp-1:0]                    bypass_rs1_o
   , output logic [reg_data_width_lp-1:0]                    bypass_rs2_o
   );

logic[num_pipe_els_p:0]                        rs1_match_vector, rs2_match_vector;
logic[num_pipe_els_p:0]                        rs1_match_vector_onehot, rs2_match_vector_onehot;
logic[num_pipe_els_p:0][reg_data_width_lp-1:0] rs1_data_vector, rs2_data_vector;

if(enable_p == 1) begin
    bsg_priority_encode_one_hot_out #(.width_p(num_pipe_els_p+1)
                                      ,.lo_to_hi_p(1)
                                      )
                    match_one_hot_rs1(.i(rs1_match_vector)
                                      ,.o(rs1_match_vector_onehot)
                                      );

    bsg_priority_encode_one_hot_out #(.width_p(num_pipe_els_p+1)
                                      ,.lo_to_hi_p(1)
                                      )
                    match_one_hot_rs2(.i(rs2_match_vector)
                                      ,.o(rs2_match_vector_onehot)
                                      );

    bsg_crossbar_o_by_i #(.i_els_p(num_pipe_els_p+1)
                          ,.o_els_p(1)
                          ,.width_p(reg_data_width_lp)
                          )
             rs1_crossbar(.i(rs1_data_vector)
                          ,.sel_oi_one_hot_i(rs1_match_vector_onehot)
                          ,.o(bypass_rs1_o)
                          );

    bsg_crossbar_o_by_i #(.i_els_p(num_pipe_els_p+1)
                          ,.o_els_p(1)
                          ,.width_p(reg_data_width_lp)
                          )
             rs2_crossbar(.i(rs2_data_vector)
                          ,.sel_oi_one_hot_i(rs2_match_vector_onehot)
                          ,.o(bypass_rs2_o)
                          );
end else begin
    assign bypass_rs1_o = id_rs1_i;
    assign bypass_rs2_o = id_rs2_i;
end

always_comb begin
    rs1_data_vector = {id_rs1_i, comp_rd_i};
    rs2_data_vector = {id_rs2_i, comp_rd_i};

    for(integer i = 0; i <= num_pipe_els_p; i+=1) begin : match_vector
        rs1_match_vector[i] = ((i == num_pipe_els_p)
                               || (comp_v_i[i] & (id_rs1_addr_i == comp_rd_addr_i[i]) 
                                   & (id_rs1_v_i & comp_rf_w_v_i[i])
                                   & (id_rs1_addr_i != '0)
                                   )
                               );

        rs2_match_vector[i] = ((i == num_pipe_els_p)
                               || (comp_v_i[i] & (id_rs2_addr_i == comp_rd_addr_i[i]) 
                                   & (id_rs2_v_i & comp_rf_w_v_i[i]) 
                                   & (id_rs2_addr_i != '0)
                                   )
                               );
    end
end

endmodule : bp_be_calc_bypass


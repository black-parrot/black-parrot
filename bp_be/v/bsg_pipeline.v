/**
 * 
 *  bsg_pipeline.v
 *
 */

`include "bsg_defines.v"

module bsg_pipeline #(parameter width_p="inv"
                     ,parameter stage_els_p="inv"

                     ,localparam act_stage_els_lp=`BSG_MAX(stage_els_p,1)
                     )
  (input logic                                      clk_i
   ,input logic                                     data_v_i
   ,input logic[width_p-1:0]                        data_i
   ,output logic[act_stage_els_lp-1:0][width_p-1:0] data_o
   );

logic [act_stage_els_lp:0][width_p-1:0] data_r;

assign data_r[0] = data_v_i ? data_i : '0;

genvar i;
for(i=1; i<= act_stage_els_lp; i++) begin : stage
    bsg_dff #(.width_p(width_p)
              )
        data (.clk_i(clk_i)
              ,.data_i(data_r[i-1])
              ,.data_o(data_r[i])
              );
    assign data_o[i-1] = data_r[i];
end

endmodule

/**
 *
 * bp_be_regfile.v
 *
 */

`include "bsg_defines.v"

module bp_be_regfile 
 #(parameter width_p="inv"
   ,parameter els_p="inv"
   
   ,localparam addr_width_lp=`BSG_SAFE_CLOG2(els_p)
   )
  (input logic                      clk_i
   ,input logic                     reset_i

   ,input logic                     issue_v_i

   ,input logic                     rd_w_v_i
   ,input logic [addr_width_lp-1:0] rd_addr_i
   ,input logic [width_p-1:0]       rd_data_i

   ,input logic                     rs1_r_v_i
   ,input logic [addr_width_lp-1:0] rs1_addr_i
   ,output logic [width_p-1:0]      rs1_data_o
   
   ,input logic                     rs2_r_v_i
   ,input logic [addr_width_lp-1:0] rs2_addr_i
   ,output logic [width_p-1:0]      rs2_data_o
   );

logic [width_p-1:0] rs1_data_read, rs2_data_read;
logic [addr_width_lp-1:0] rs1_addr_r, rs2_addr_r;
logic [addr_width_lp-1:0] rs1_reread_addr, rs2_reread_addr;

/* TODO: Is it okay to continuously read on stalls? There's no switching, so energy may not 
 *         be an issue
 *       Verify this reread logic with MBT
 */

bsg_mem_2r1w_sync_synth #(.width_p(width_p)
                          ,.els_p(els_p)
                          )
                       rf(.clk_i(clk_i)
                          ,.reset_i(reset_i)

                          ,.w_v_i(rd_w_v_i)
                          ,.w_addr_i(rd_addr_i)
                          ,.w_data_i(rd_data_i)

                          ,.r0_v_i(1'b1)
                          ,.r0_addr_i(rs1_reread_addr)
                          ,.r0_data_o(rs1_data_read)

                          ,.r1_v_i(1'b1)
                          ,.r1_addr_i(rs2_reread_addr)
                          ,.r1_data_o(rs2_data_read)
                          );

bsg_dff_en #(.width_p(addr_width_lp)
             )
    rs1_addr(.clk_i(clk_i)
             ,.en_i(issue_v_i)
             ,.data_i(rs1_addr_i)
             ,.data_o(rs1_addr_r)
             );

bsg_dff_en #(.width_p(addr_width_lp)
             )
    rs2_addr(.clk_i(clk_i)
             ,.en_i(issue_v_i)
             ,.data_i(rs2_addr_i)
             ,.data_o(rs2_addr_r)
             );

 bsg_mux #(.width_p(addr_width_lp)
           ,.els_p(2)
           )
rs1_reread(.data_i({rs1_addr_r, rs1_addr_i})
           ,.sel_i(~issue_v_i)
           ,.data_o(rs1_reread_addr)
           );

 bsg_mux #(.width_p(addr_width_lp)
           ,.els_p(2)
           )
rs2_reread(.data_i({rs2_addr_r, rs2_addr_i})
           ,.sel_i(~issue_v_i)
           ,.data_o(rs2_reread_addr)
           );

always_comb begin
    /* TODO: write-> read bypassing */
    rs1_data_o = (rs1_addr_r > 0) ? rs1_data_read : 0;
    rs2_data_o = (rs2_addr_r > 0) ? rs2_data_read : 0;
end

endmodule : bp_be_regfile


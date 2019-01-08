
/*
 * Branch Target Buffer (BTB) stores the addresses of the branch targets and the
 * corresponding branch sites. Branch happens from the branch sites to the branch
 * targets. In order to save the logic sizes, the BTB is designed to have limited 
 * entries for storing the branch sites, branch target pairs. The implementation 
 * uses the bsg_mem_1rw_sync_synth RAM design.
*/

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif


module btb 
#(
    parameter bp_fe_pc_gen_btb_idx_width_lp=9
    ,parameter eaddr_width_p="inv"
) (
    input logic clk_i
    ,input logic reset_i 

    ,input logic [bp_fe_pc_gen_btb_idx_width_lp-1:0]  btb_idx_w_i
    ,input logic [bp_fe_pc_gen_btb_idx_width_lp-1:0]  btb_idx_r_i
    ,input logic                                      btb_r_i
    ,input logic                                      btb_w_i

    ,input  logic [eaddr_width_p-1:0]                 branch_target_i
    ,output logic [eaddr_width_p-1:0]                 branch_target_o

    ,output logic                                     read_valid_o
);

logic [2**bp_fe_pc_gen_btb_idx_width_lp-1:0]             keeping_track;

always_ff @(posedge clk_i) begin
    if (reset_i) begin
        keeping_track <= '{default:'0};
        //$display("%s [WRITE]0", __DEBUG__MSG__);
    end else begin
       if (btb_w_i) begin
           // keeping track tells if the memory is x
           keeping_track[btb_idx_w_i]           <= '1;
           //$display("%s [WRITE]1", __DEBUG__MSG__);
       end
    end
end

assign read_valid_o        = keeping_track[btb_idx_r_i];

bsg_mem_1r1w
#(
    .width_p(eaddr_width_p)
    ,.els_p(2**bp_fe_pc_gen_btb_idx_width_lp)
    ,.addr_width_lp(bp_fe_pc_gen_btb_idx_width_lp)

) bsg_mem_1rw_sync_synth_1 (
    .w_clk_i(clk_i)
    ,.w_reset_i(reset_i)

    ,.w_v_i(btb_w_i)
    ,.w_addr_i(btb_idx_w_i)
    ,.w_data_i(branch_target_i)
   
    ,.r_v_i(btb_r_i)
    ,.r_addr_i(btb_idx_r_i)
    ,.r_data_o(branch_target_o)
);

endmodule

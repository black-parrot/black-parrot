/*
 * Branch History Table (BHT) records the information of the branch history, i.e.
 * branch taken or not taken.  The index uses the virtual address bit 10 - bit 20.
 * Each entry consists of 2 bit saturation counter.  If the counter value is in
 * the positive regime, the BHT predicts ``taken''; if the counter value is in the
 * negative regime, the BHT predicts ``not taken''. The implementation of BHT is
 * native to this design.
*/

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

module bht 
#(
    parameter saturation_size_lp=2
    ,parameter bht_indx_width_p=5
    ,parameter els_lp=2**bht_indx_width_p
)(
    input   logic                           clk_i
    ,input  logic                           v_i
    ,input  logic                           reset_i

    ,input  logic [bht_indx_width_p-1:0]    bht_idx_r_i
    ,input  logic [bht_indx_width_p-1:0]    bht_idx_w_i

    ,input  logic                           bht_r_i
    ,input  logic                           bht_w_i

    ,input  logic                           correct_i
    ,output logic                           predict_o
);

logic [els_lp-1:0][saturation_size_lp-1:0]   mem;

assign predict_o = mem[bht_idx_r_i][1];

always_ff @(posedge clk_i) begin
    if (v_i) begin
         if (reset_i) begin
            mem       <= '{default:2'b01};
         end else begin

            if (bht_w_i) begin
                case ({correct_i, mem[bht_idx_w_i][1], mem[bht_idx_w_i][0]}) 
                    3'b000: mem[bht_idx_w_i] <= 2'b01;
                    3'b001: mem[bht_idx_w_i] <= 2'b10;
                    3'b010: mem[bht_idx_w_i] <= 2'b01;
                    3'b011: mem[bht_idx_w_i] <= 2'b11;
                    3'b100: mem[bht_idx_w_i] <= 2'b00;
                    3'b101: mem[bht_idx_w_i] <= 2'b00;
                    3'b110: mem[bht_idx_w_i] <= 2'b11;
                    3'b111: mem[bht_idx_w_i] <= 2'b11;
                endcase
            end 
         end
    end
end

/* assertions checking for the read/write address collisions, 
and access address is valid */

// read_write_collision: assert property (@(posedge clk_i) ~v_i || reset_i === 'X || reset_i === 1'b1 
// || ~bht_r_i || ~bht_w_i || bht_idx_r_i != bht_idx_w_i) 
// else $error("Read/write address collisions on address %x", bht_idx_r_i);

//read_check:assert property (@(posedge clk_i) ~v_i || reset_i === 'X || reset_i === 1'b1 
//|| bht_r_i === 'X || bht_r_i === '0 || (bht_idx_r_i < els_lp))
//else $error("Invalid address %x", bht_idx_r_i);

//write_check:assert property (@(posedge clk_i) ~v_i || reset_i === 'X || reset_i === 1'b1 
//|| bht_idx_w_i < els_lp)
//else $error("Invalid address %x", bht_idx_w_i);
initial begin
end
endmodule

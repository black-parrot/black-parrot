/**
 *
 * test_bp.v
 *
 */

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_internal_if.vh"

module test_bp
 #(parameter num_pipe_els_p="inv"
   ,parameter enable_p="inv"

   ,localparam reg_data_width_lp=RV64_reg_data_width_gp
   ,localparam reg_addr_width_lp=RV64_reg_addr_width_gp
   );

logic                                             clk, reset;
logic                                             id_rs1_v, id_rs2_v;
logic [reg_addr_width_lp-1:0]                     id_rs1_addr, id_rs2_addr;
logic [reg_data_width_lp-1:0]                     id_rs1, id_rs2;
logic [num_pipe_els_p-1:0]                        comp_psn;
logic [num_pipe_els_p-1:0]                        comp_rf_w_v;
logic [num_pipe_els_p-1:0][reg_addr_width_lp-1:0] comp_rd_addr;
logic [num_pipe_els_p-1:0][reg_data_width_lp-1:0] comp_rd;
logic [reg_data_width_lp-1:0]                     bypass_rs1, bypass_rs2;

bsg_nonsynth_clock_gen #(.cycle_time_p(10)
                         )
              clock_gen (.o(clk)
                         );

bsg_nonsynth_reset_gen #(.num_clocks_p(1)
                         ,.reset_cycles_lo_p(1)
                         ,.reset_cycles_hi_p(9)
                         )
               reset_gen(.clk_i(clk)
                         ,.async_reset_o(reset)
                         );

bp_be_calc_bypass #(.num_pipe_els_p(num_pipe_els_p)
                    ,.enable_p(enable_p)
                    )
                DUT(.id_rs1_v_i(id_rs1_v)
                    ,.id_rs1_addr_i(id_rs1_addr)
                    ,.id_rs1_i(id_rs1)

                    ,.id_rs2_v_i(id_rs2_v)
                    ,.id_rs2_addr_i(id_rs2_addr)
                    ,.id_rs2_i(id_rs2)

                    ,.comp_psn_i(comp_psn)
                    ,.comp_rf_w_v_i(comp_rf_w_v)
                    ,.comp_rd_addr_i(comp_rd_addr)
                    ,.comp_rd_i(comp_rd)

                    ,.bypass_rs1_o(bypass_rs1)
                    ,.bypass_rs2_o(bypass_rs2)
                    );

integer last_match;
always_ff @(posedge clk) begin
    if(reset) begin
        id_rs1_v     <= '0;
        id_rs1_addr  <= '0;
        id_rs1       <= '0;

        id_rs2_v     <= '0;
        id_rs2_addr  <= '0;
        id_rs2       <= '0;

        comp_psn     <= '0;
        comp_rf_w_v  <= '0;
        comp_rd_addr <= '0;
        comp_rd      <= '0;
    end else begin
        id_rs1_v     <= $random();
        id_rs1_addr  <= $random() % 8;   // Reduced set of registers
        id_rs1       <= $random() % 100; // Reduced data range

        id_rs2_v     <= $random();
        id_rs2_addr  <= $random() % 8;   // Reduced set of registers
        id_rs2       <= $random() % 100; // Reduced data range

        for(integer i=0; i<num_pipe_els_p; i+=1) begin
            comp_psn    [i] <= $random();
            comp_rf_w_v [i] <= $random();
            comp_rd_addr[i] <= $random() % 8;   // Reduced set of registers
            comp_rd     [i] <= $random() % 100; // Reduced data range
        end

        for(integer i=0; i<num_pipe_els_p; i+=1) begin
            if(id_rs1_v & comp_rf_w_v[i] & ~comp_psn[i] 
               & (id_rs1_addr == comp_rd_addr[i]) & (id_rs1_addr != '0)) begin
                    if(bypass_rs1 != comp_rd[i]) begin
                        $display("[FAIL] RS1 should bypass");
                        $finish();
                    end
            end
        end

        for(integer i=0; i<num_pipe_els_p; i+=1) begin
            if(id_rs2_v & comp_rf_w_v[i] & ~comp_psn[i] 
               & (id_rs2_addr == comp_rd_addr[i]) & (id_rs2_addr != '0)) begin
                    if(bypass_rs2 != comp_rd[i]) begin
                        $display("[FAIL] RS2 should bypass");
                        $finish();
                    end
            end
        end
    end
end

endmodule : test_bp


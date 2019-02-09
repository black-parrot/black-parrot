/**
 *  Name:
 *    bp_be_dcache_wbuf_queue.v
 *
 *  Description:
 *    Data cache write buffer queue.
 */

module bp_be_dcache_wbuf_queue
  #(parameter width_p="inv")
  (
    input clk_i
    , input [width_p-1:0] data_i
    , input el0_en_i
    , input el1_en_i
    , input mux0_sel_i
    , input mux1_sel_i
    , output logic [width_p-1:0] el0_snoop_o
    , output logic [width_p-1:0] el1_snoop_o
    , output logic [width_p-1:0] data_o
  );

  logic [width_p-1:0] el0_r, el1_r;

  always_ff @ (posedge clk_i) begin
    if (el0_en_i) begin
      el0_r <= data_i;
    end

    if (el1_en_i) begin
      el1_r <= mux0_sel_i ? el0_r : data_i;
    end
  end

  assign data_o = mux1_sel_i ? el1_r : data_i;
  assign el0_snoop_o = el0_r;
  assign el1_snoop_o = el1_r;

endmodule

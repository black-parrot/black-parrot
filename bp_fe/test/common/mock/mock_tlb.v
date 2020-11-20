module mock_tlb
  #(parameter tag_width_p="inv")
  (
    input clk_i

    ,input v_i
    ,input [tag_width_p-1:0] tag_i

    ,output logic [tag_width_p-1:0] tag_o
    ,output logic tlb_miss_o
  );

  always_ff @ (posedge clk_i) begin
    if (v_i) begin
      tag_o <= tag_i;
    end
  end

  assign tlb_miss_o = 1'b0;

endmodule

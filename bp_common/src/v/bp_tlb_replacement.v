
module bp_tlb_replacement
  #(parameter ways_p="inv"
    ,localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
  )
  (input                            clk_i
   , input                          reset_i
   , input                          v_i
   , input [lg_ways_lp-1:0]         way_i
   , output logic [lg_ways_lp-1:0]  way_o
  );

   
logic [ways_p-2:0]                     lru_r, lru_n, update_mask, update_data;

for(genvar i = 0; i < ways_p-1; i++) begin: rof
  assign lru_n[i] = (update_mask[i]) ? update_data[i] : lru_r[i];
end

// Update lru_r
always_ff @(posedge clk_i) 
  begin
    if (reset_i) 
      lru_r <= '0;
    else if (v_i) begin
      lru_r <= lru_n;
    end
  end

bsg_lru_pseudo_tree_decode #(.ways_p(ways_p))
  decoder 
  (.way_id_i(way_i)
   ,.data_o(update_data)
   ,.mask_o(update_mask)
  );

bsg_lru_pseudo_tree_encode #(.ways_p(ways_p))
  encoder 
  (.lru_i(lru_r)
   ,.way_id_o(way_o)
  );  
  
endmodule

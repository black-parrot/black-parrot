
module bp_plru
  #(parameter ways_p="inv"
    ,localparam lg_ways_lp=`BSG_SAFE_CLOG2(ways_p)
  )
  (input                            clk_i
   , input                          reset_i
   , input                          v_i
   , input [lg_ways_lp-1:0]         way_i
   , output logic [lg_ways_lp-1:0]  way_o
  );
    
logic [ways_p-2:0]                     lru_r, lru_n, mask, mask_update;
logic [lg_ways_lp-1:0][ways_p-2:0]     enc_i;  
logic [lg_ways_lp-1:0][lg_ways_lp-1:0] enc_addr;

// Decode way_i to lru_n
assign lru_n = lru_r ^ mask_update;
assign mask_update[0] = 1'b1;
genvar i;
for(i=1; i<ways_p-1; i++) begin
  always_comb begin
    if(i%2==1)
      mask_update[i] = mask_update[(i-1)/2] & ~way_i[lg_ways_lp+1-$clog2(i+2)];
    else
      mask_update[i] = mask_update[(i-2)/2] & way_i[lg_ways_lp+1-$clog2(i+2)];
  end
end

// Encode lru_r to way_o
assign mask[0] = 1'b1;
for(i=1; i<ways_p-1; i++) begin
  always_comb begin
    if(i%2==1 && lru_r[(i-1)/2]==0)
      mask[i] = mask[(i-1)/2];
    else if(i%2==0 && lru_r[(i-2)/2]==1)
      mask[i] = mask[(i-2)/2];
    else
      mask[i] = 1'b0;
  end
end

for(i=0; i<lg_ways_lp; i++) begin
  always_comb begin
    if(i==0)
      enc_i[i] = mask; 
    else
      enc_i[i] = enc_i[i-1] ^ ({{(ways_p-2){1'b0}}, 1'b1} << enc_addr[i-1]);
      
    way_o[lg_ways_lp-1-i] = lru_r[enc_addr[i]];
  end
  
  bsg_priority_encode 
    #(.width_p(ways_p-1)
      ,.lo_to_hi_p(1'b1)
    ) encoder 
    (.i(enc_i[i])
     ,.addr_o(enc_addr[i])
     ,.v_o()
    );
end

// Update lru_r
always_ff @(posedge clk_i) begin
  if(reset_i) begin
    lru_r <= '0;
  end else if(v_i) begin
    lru_r <= lru_n;
  end
end

endmodule
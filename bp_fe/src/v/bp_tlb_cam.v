
module bp_tlb_cam
  #(parameter els_p= "inv"
    ,parameter width_p= "inv"
  )
  (input                                      clk_i
   , input                                     reset_i

   , input                                     w_v_i
   , input [`BSG_SAFE_CLOG2(els_p)-1:0]        w_addr_i
   , input [width_p-1:0]                       w_data_i
   
   , input                                     r_v_i
   , input [width_p-1:0]                       r_data_i
   
   , output logic                              r_v_o
   , output logic [`BSG_SAFE_CLOG2(els_p)-1:0] r_addr_o
   
   , output logic                              empty_v_o
   , output logic [`BSG_SAFE_CLOG2(els_p)-1:0] empty_addr_o
  );

  
logic [width_p-1:0] mem [0:els_p-1];
logic [els_p-1:0]   match_array;
logic [els_p-1:0]   valid;
logic               matched;

assign r_v_o = r_v_i & matched;
    
//write the input pattern into the cam and set the corresponding valid bit
always_ff @(posedge clk_i) 
begin
  if (reset_i) begin
    valid <= 0;
  end 
  else if (w_v_i) begin
    assert(w_addr_i < els_p)
      else $error("Invalid address %x of size %x\n", w_addr_i, els_p);

    valid[w_addr_i] <= 1'b1;
    mem  [w_addr_i] <= w_data_i;
  end
end

   
//compare the input pattern with all stored valid patterns inside the cam.
//In the case of a match, set the corresponding bit in match_array.
genvar i;
for (i = 0; i < els_p; i++) begin
  always_comb begin
    match_array[i] = ~reset_i & (mem[i] == r_data_i) & valid[i];
  end
end


bsg_priority_encode
  #(.width_p(els_p)
    ,.lo_to_hi_p(1)
  ) 
  eenc
  (.i(~valid)
   ,.addr_o(empty_addr_o)
   ,.v_o(empty_v_o)
  );

bsg_encode_one_hot
  #(.width_p(els_p)
    ,.lo_to_hi_p(1)
  ) 
  renc
  (.i(match_array)
   ,.addr_o(r_addr_o)
   ,.v_o(matched)
  );
  
 
always_ff @(negedge clk_i) 
begin
  if (~reset_i & r_v_i) begin
    assert($countones(match_array) <= 1)
      else $error("Multiple similar entries are found in match_array %x \n", match_array);       
  end
end 
 
endmodule

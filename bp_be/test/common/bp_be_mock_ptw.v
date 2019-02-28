
module bp_be_mock_ptw
  #(parameter vtag_width_p="inv"
   ,parameter ptag_width_p="inv"   
  )
  (input                             clk_i
   , input                           reset_i
   
   , input                           miss_v_i
   , input [vtag_width_p-1:0]        vtag_i
   
   , output logic                    v_o
   , output logic [vtag_width_p-1:0] vtag_o
   , output logic [ptag_width_p-1:0] ptag_o
  );

typedef enum [1:0] { eWait, eBusy, eDone, eStuck } state_e;
state_e state, state_n;

logic [7:0] counter;
logic [ptag_width_p-1:0] ptag_n;

assign ptag_n = {(ptag_width_p-vtag_width_p)'(0), vtag_i};

assign rdy_o = (state == eWait);
assign v_o   = (state == eDone);
 
always_ff @(posedge clk_i) begin
  if(reset_i) begin
    state   <= eWait;
	counter <= '0;
  end
  else begin
    state   <= state_n; 
	counter <= counter + 'b1;
  end
end

always_comb begin
  case(state)
    eWait: state_n = (miss_v_i)? eBusy : eWait;
    eBusy: state_n = (counter == '0)? eDone : eBusy;
	eDone: state_n = (miss_v_i)? eWait : eDone;
	default: state_n = eStuck;
  endcase
end

bsg_dff_reset_en #(.width_p(vtag_width_p))
  vtag_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(miss_v_i)
   ,.data_i(vtag_i)
   ,.data_o(vtag_o)
  );
  
bsg_dff_reset_en #(.width_p(ptag_width_p))
  ptag_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(miss_v_i)
   ,.data_i(ptag_n)
   ,.data_o(ptag_o)
  );
 
endmodule

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"

module bp_be_mock_ptw
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  #(parameter vtag_width_p="inv"
   ,parameter ptag_width_p="inv"

   ,localparam entry_width_lp = `bp_be_tlb_entry_width(ptag_width_p)
  )
  (input                               clk_i
   , input                             reset_i

   , input                             miss_v_i
   , input [vtag_width_p-1:0]          vtag_i

   , output logic                      v_o
   , output logic [vtag_width_p-1:0]   vtag_o
   , output logic [entry_width_lp-1:0] entry_o
  );

`declare_bp_be_tlb_entry_s(ptag_width_p);

typedef enum [1:0] { eWait, eBusy, eDone, eStuck } state_e;
state_e state, state_n;

bp_be_tlb_entry_s entry_n;

assign entry_n.ptag   = {(ptag_width_p-vtag_width_p)'(0), vtag_i};
assign entry_n.extent = '0;
assign entry_n.u      = '0;
assign entry_n.g      = '0;
assign entry_n.l      = '0;
assign entry_n.x      = '0;

assign rdy_o = (state == eWait);
assign v_o   = (state == eDone);

logic [7:0] counter;

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

bsg_dff_reset_en #(.width_p(entry_width_lp))
  entry_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(miss_v_i)
   ,.data_i(entry_n)
   ,.data_o(entry_o)
  );

endmodule
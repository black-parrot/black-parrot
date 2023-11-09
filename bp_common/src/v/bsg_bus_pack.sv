
`include "bsg_defines.sv"

module bsg_bus_pack
 #(// Width of the bus
   parameter `BSG_INV_PARAM(in_width_p)
   , parameter out_width_p = in_width_p

   // Selection granularity of the bus, default to byte width
   , parameter unit_width_p       = 8
   , localparam sel_width_lp      = `BSG_SAFE_CLOG2(in_width_p/unit_width_p)
   , localparam size_width_lp     = `BSG_WIDTH(sel_width_lp)
   )
  (input [in_width_p-1:0]            data_i
   , input [sel_width_lp-1:0]        sel_i
   , input [size_width_lp-1:0]       size_i
   , output logic [out_width_p-1:0]  data_o
   );

  localparam lg_unit_width_lp = `BSG_SAFE_CLOG2(unit_width_p);
  logic [in_width_p-1:0] data_rot_lo;
  bsg_rotate_right
   #(.width_p(in_width_p))
   rot
    (.data_i(data_i)
     // Align to unit granularity
     ,.rot_i({sel_i, {lg_unit_width_lp{1'b0}}})
     ,.o(data_rot_lo)
     );

  localparam num_size_lp = 2**size_width_lp;
  logic [num_size_lp-1:0][in_width_p-1:0] data_repl_lo;
  for (genvar i = 0; i <= sel_width_lp; i++)
    begin : repl
      localparam slice_width_lp = (unit_width_p*(2**i));
      assign data_repl_lo[i] = {in_width_p/slice_width_lp{data_rot_lo[0+:slice_width_lp]}};
    end

  logic [in_width_p-1:0] data_lo;
  bsg_mux
   #(.width_p(in_width_p), .els_p(num_size_lp))
   repl_mux
    (.data_i(data_repl_lo)
     ,.sel_i(size_i)
     ,.data_o(data_lo)
     );

  if (out_width_p > in_width_p)
    assign data_o = {out_width_p/in_width_p{data_lo}};
  else
    assign data_o = data_lo[0+:out_width_p];

  // synopsys translate_off
  if (!`BSG_IS_POW2(in_width_p) || !`BSG_IS_POW2(out_width_p))
    $fatal(1, "Bus width must be a power of 2");

  if (unit_width_p < 2)
    $fatal(1, "Bit width replication unsupported");
  // synopsys translate_on

endmodule

`BSG_ABSTRACT_MODULE(bsg_bus_pack)


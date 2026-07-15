
`include "bsg_defines.sv"

module bsg_fifo_1r1w_rolly
  #(parameter `BSG_INV_PARAM(width_p)
    , parameter `BSG_INV_PARAM(els_p)
    , parameter ready_THEN_valid_p = 0

    , localparam ptr_width_lp = `BSG_SAFE_CLOG2(els_p)
    )
  (input                  clk_i
   , input                reset_i

   , input                clr_v_i
   , input                deq_v_i
   , input                roll_v_i

   , input [width_p-1:0]  data_i
   , input                v_i
   , output               ready_o

   , output [width_p-1:0] data_o
   , output               v_o
   , input                yumi_i
   );

  // One read pointer, one write pointer, one checkpoint pointer
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] wptr_r, rptr_r, cptr_r;

  // Used to catch up on roll and clear
  logic [ptr_width_lp:0] rptr_jmp, wptr_jmp;

  // Operations
  wire enq  = ready_THEN_valid_p ? v_i : ready_o & v_i;
  wire deq  = deq_v_i;
  wire read = yumi_i;
  wire clr  = clr_v_i;
  wire roll = roll_v_i;

  assign rptr_jmp = roll
                    ? (cptr_r - rptr_r + (ptr_width_lp+1)'(deq))
                    : read
                       ? ((ptr_width_lp+1)'(1))
                       : ((ptr_width_lp+1)'(0));

  assign wptr_jmp = clr
                    ? (rptr_r - wptr_r + (ptr_width_lp+1)'(read))
                    : enq
                       ? ((ptr_width_lp+1)'(1))
                       : ((ptr_width_lp+1)'(0));

  wire empty = (rptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
               & (rptr_r[ptr_width_lp] == wptr_r[ptr_width_lp]);
  wire full = (cptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
              & (cptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);

  assign ready_o = ~clr & ~full;
  assign v_o     = ~roll & ~empty;

  bsg_circular_ptr
   #(.slots_p(2*els_p), .max_add_p(1))
   cptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(deq_v_i)
    ,.o(cptr_r)
    ,.n_o()
     );

  bsg_circular_ptr
   #(.slots_p(2*els_p),.max_add_p(2*els_p-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o()
     );

  bsg_circular_ptr
  #(.slots_p(2*els_p), .max_add_p(2*els_p-1))
  rptr_circ_ptr
   (.clk(clk_i)
    ,.reset_i(reset_i)
    ,.add_i(rptr_jmp)
    ,.o(rptr_r)
    ,.n_o()
    );

  bsg_mem_1r1w
  #(.width_p(width_p), .els_p(els_p))
  fifo_mem
   (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r[0+:ptr_width_lp])
    ,.w_data_i(data_i)
    ,.r_v_i(read)
    ,.r_addr_i(rptr_r[0+:ptr_width_lp])
    ,.r_data_o(data_o)
    );

endmodule

`BSG_ABSTRACT_MODULE(bsg_fifo_1r1w_rolly)



module bsg_fifo_1r1w_rolly
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_single_core_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_fe_be_if_widths(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p)

   , localparam ptr_width_lp = `BSG_SAFE_CLOG2(fe_queue_fifo_els_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   , input                                  clr_v_i
   , input                                  deq_v_i
   , input                                  roll_v_i

   , input [fe_queue_width_lp-1:0]          fe_queue_i
   , input                                  fe_queue_v_i
   , output logic                           fe_queue_ready_o
   
   , output logic [fe_queue_width_lp-1:0]   fe_queue_o
   , output logic                           fe_queue_v_o
   , input                                  fe_queue_yumi_i

   , output logic [reg_addr_width_p-1:0]    rs1_addr_o
   , output logic                           rs1_v_o

   , output logic [reg_addr_width_p-1:0]    rs2_addr_o
   , output logic                           rs2_v_o
   );

  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `bp_cast_i(bp_fe_queue_s, fe_queue);
  `bp_cast_o(bp_fe_queue_s, fe_queue);

  // One read pointer, one write pointer, one checkpoint pointer
  // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0] wptr_n, rptr_n, cptr_n;
  logic [ptr_width_lp:0] wptr_r, rptr_r, cptr_r;
    
  // Used to catch up on roll and clear
  logic [ptr_width_lp:0] wptr_jmp, rptr_jmp, cptr_jmp;

  // Operations
  wire enq  = fe_queue_ready_o & fe_queue_v_i;
  wire deq  = deq_v_i;
  wire read = fe_queue_yumi_i;
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
  assign cptr_jmp = 1'b1;

  wire empty = (rptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp]) 
               & (rptr_r[ptr_width_lp] == wptr_r[ptr_width_lp]);
  wire empty_n = (rptr_n[0+:ptr_width_lp] == wptr_n[0+:ptr_width_lp]) 
                 & (rptr_n[ptr_width_lp] == wptr_n[ptr_width_lp]);
  wire full  = (cptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp])
               & (cptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);
  wire full_n = (cptr_n[0+:ptr_width_lp] == wptr_n[0+:ptr_width_lp])
                & (cptr_n[ptr_width_lp] != wptr_n[ptr_width_lp]);

  bsg_circular_ptr 
   #(.slots_p(2*fe_queue_fifo_els_p), .max_add_p(1))
   cptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(deq_v_i)
     ,.o(cptr_r)
     ,.n_o(cptr_n)
     );
    
  bsg_circular_ptr 
   #(.slots_p(2*fe_queue_fifo_els_p),.max_add_p(2*fe_queue_fifo_els_p-1))
   wptr
    (.clk(clk_i)
     ,.reset_i(reset_i)
     ,.add_i(wptr_jmp)
     ,.o(wptr_r)
     ,.n_o(wptr_n)
     );

  bsg_circular_ptr 
  #(.slots_p(2*fe_queue_fifo_els_p), .max_add_p(2*fe_queue_fifo_els_p-1))
  rptr
   (.clk(clk_i)
    ,.reset_i(reset_i)
    ,.add_i(rptr_jmp)
    ,.o(rptr_r)
    ,.n_o(rptr_n)
    );
  
  bsg_mem_1r1w 
  #(.width_p(fe_queue_width_lp), .els_p(fe_queue_fifo_els_p)) 
  queue_fifo_mem
   (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r[0+:ptr_width_lp])
    ,.w_data_i(fe_queue_cast_i)
    ,.r_v_i(read & ~empty)
    ,.r_addr_i(rptr_r[0+:ptr_width_lp])
    ,.r_data_o(fe_queue_cast_o)
    );
  assign fe_queue_v_o     = ~roll & ~empty;
  assign fe_queue_ready_o = ~clr & ~full;

  wire bypass_reg = (wptr_r == rptr_n);
  rv64_instr_rtype_s fetch_instr;
  assign fetch_instr = fe_queue_cast_i.msg.fetch.instr;
  logic [reg_addr_width_p-1:0] rs1_addr_li, rs2_addr_li;
  logic [reg_addr_width_p-1:0] rs1_addr_lo, rs2_addr_lo;
  assign rs1_addr_li = fetch_instr.rs1_addr;
  assign rs2_addr_li = fetch_instr.rs2_addr;
  bsg_mem_1r1w
  #(.width_p(2*reg_addr_width_p), .els_p(fe_queue_fifo_els_p), .read_write_same_addr_p(1))
  reg_fifo_mem
   (.w_clk_i(clk_i)
    ,.w_reset_i(reset_i)
    ,.w_v_i(enq)
    ,.w_addr_i(wptr_r[0+:ptr_width_lp])
    ,.w_data_i({rs2_addr_li, rs1_addr_li})
    ,.r_v_i(1'b1)
    ,.r_addr_i(rptr_n[0+:ptr_width_lp])
    ,.r_data_o({rs2_addr_lo, rs1_addr_lo})
    );
  // TODO: Save power by predecoding
  assign rs1_v_o = (fe_queue_yumi_i & ~empty_n) | roll_v_i | (fe_queue_v_i & empty);
  assign rs2_v_o = (fe_queue_yumi_i & ~empty_n) | roll_v_i | (fe_queue_v_i & empty);

  assign rs1_addr_o = bypass_reg ? rs1_addr_li : rs1_addr_lo;
  assign rs2_addr_o = bypass_reg ? rs2_addr_li : rs2_addr_lo;

endmodule



module bsg_fifo_1r1w_rolly
`include "bsg_defines.v"
  #(parameter width_p         = -1
    ,parameter els_p        = -1
    ,parameter ready_THEN_valid_p   = 0
    
    ,localparam ptr_width_lp = `BSG_SAFE_CLOG2(els_p)
  )
  (
    input logic          clk_i
    ,input logic        reset_i

    ,input logic        clr_v_i
    ,input logic        ckpt_v_i
    ,input logic        roll_v_i

    ,input logic [width_p-1:0]  data_i
    ,input logic         v_i
    ,output logic         ready_o
    
    ,output logic [width_p-1:0]  data_o
    ,output logic        v_o
    ,input logic        yumi_i
  );
  
    // One read pointer, one write pointer, one checkpoint pointer
    // ptr_width + 1 for wrap bit
  logic [ptr_width_lp:0]  wptr_r, rptr_r, cptr_r;
    
    // Used to latch last operation, to determine fifo state
    logic                       enq, deq, clr;
  logic             enq_r, deq_r, clr_r;
  
    // Used to catch up on roll and clear
    logic [ptr_width_lp:0]    rptr_jmp, wptr_jmp;

    // Status
  logic            empty, full;
  
    assign rptr_jmp = roll_v_i 
                      ? (cptr_r - rptr_r) 
                      : deq 
                         ? ('b1)
                         : ('b0);

    assign wptr_jmp = clr_v_i
                      ? (rptr_r - wptr_r)
                      : enq
                         ? ('b1)
                         : ('b0);

    assign empty = (rptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp]) 
                   & (rptr_r[ptr_width_lp] == wptr_r[ptr_width_lp]);
    assign full = (cptr_r[0+:ptr_width_lp] == wptr_r[0+:ptr_width_lp]) 
                  & (cptr_r[ptr_width_lp] != wptr_r[ptr_width_lp]);

    if(ready_THEN_valid_p == 1) begin
        assign enq = v_i;
    end else begin
        assign enq = v_i & ready_o;
    end
    assign deq = yumi_i;
    assign clr = clr_v_i;

    assign ready_o = ~reset_i & ~clr_v_i & ~full;
    assign v_o     = ~reset_i & ~roll_v_i & ~empty;

  //always_ff @(posedge clk_i)
    //assert ((v_i & ~ready_o) !== 1) 
            //else $error("write ignored: reset or full FIFO");
    
  //always_ff @(posedge clk_i)
    //assert ((yumi_i & ~v_o) !== 1) 
            //else $error("read ignored: empty read space");
  
  //always_ff @(posedge clk_i)
    //assert ((yumi_i & rollback_v_i) !== 1) 
            //else $error("read ignored due to rollback");
  
  //always_ff @(posedge clk_i)
    //assert ((ckpt_inc_v_i & rollback_v_i) !==1) 
            //else $error("checkpoint increment ignored due to rollback");

  bsg_circular_ptr #(.slots_p(2*els_p)
             ,.max_add_p(1)
             ) cptr_circ_ptr
   (.clk      (clk_i)
      ,.reset_i  (reset_i)
      ,.add_i    (ckpt_v_i)
      ,.o        (cptr_r)
      );
    
  bsg_circular_ptr #(.slots_p(2*els_p)
             ,.max_add_p(2*els_p-1)
             ) wptr_circ_ptr
   (.clk      (clk_i)
      ,.reset_i  (reset_i)
      ,.add_i    (wptr_jmp)
      ,.o        (wptr_r)
      );

  bsg_circular_ptr #(.slots_p(2*els_p)
             ,.max_add_p(2*els_p-1)
             ) rptr_circ_ptr
   (.clk      (clk_i)
      ,.reset_i  (reset_i)
      ,.add_i    (rptr_jmp)
      ,.o        (rptr_r)
      );
  
  bsg_mem_1r1w #(.width_p (width_p)
            ,.els_p    (els_p)
            ) fifo_mem
     (.w_clk_i     (clk_i)
      ,.w_reset_i  (reset_i)
      ,.w_v_i      (enq)
      ,.w_addr_i   (wptr_r[0+:ptr_width_lp])
      ,.w_data_i   (data_i)
      ,.r_v_i      (deq)
      ,.r_addr_i   (rptr_r[0+:ptr_width_lp])
      ,.r_data_o   (data_o)
      );
  
endmodule : bsg_fifo_1r1w_rolly

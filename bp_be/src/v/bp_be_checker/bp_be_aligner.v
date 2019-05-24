module aligner 
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
   , parameter asid_width_p                = "inv"
   , localparam fe_fetch_width_lp  = `bp_fe_fetch_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam unaligned_instr_metadata_width_lp = `bp_be_unaligned_instr_metadata_width
  ) 
 (input clk_i
  , input reset_i

  , input  [fe_fetch_width_lp-1:0] input_fe_fetch_i
  , output logic [fe_fetch_width_lp-1:0] fe_fetch_o

  , input fe_queue_v_i
  , output logic fe_queue_v_o

  , output logic aligner_ready_o

  , input pc_redirect_i
  , input cache_miss_i
  , input roll_i
  );

// Declare parameterizable structures
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );
   
bp_fe_fetch_s fe_fetch, fe_fetch_out;   
assign fe_fetch   = input_fe_fetch_i;
assign fe_fetch_o = fe_fetch_out;
   

logic [rv64_eaddr_width_gp-1:0] prev_v_pc;
logic second_instr, second_instr_r, jump_unaligned, cache_miss_r;
bp_be_unaligned_instr_metadata  unaligned_instr, unaligned_instr_r;
   
always_comb begin : aligner
   unaligned_instr = unaligned_instr_r;
   second_instr = second_instr_r;          
   fe_fetch_out.pc                  = fe_fetch.pc;
   fe_fetch_out.instr               = fe_fetch.instr;
   fe_fetch_out.branch_metadata_fwd = fe_fetch.branch_metadata_fwd;
   fe_fetch_out.valid_branch_taken  = fe_fetch.valid_branch_taken;
   fe_fetch_out.iscompressed        = 0;
   fe_fetch_out.isfirstinstr        = 0;
   fe_fetch_out.hastwoinstrs        = 0;
   aligner_ready_o                  = fe_queue_v_i;
   fe_queue_v_o                     = ((cache_miss_i || cache_miss_r) && unaligned_instr_r.valid) ? 0 : fe_queue_v_i;
   jump_unaligned = 1'b0;

   if (fe_queue_v_i && !second_instr_r) begin
      if (fe_fetch.pc[1] == 1'b0) begin
         if (!unaligned_instr_r.valid) begin
            unaligned_instr.valid = 1'b0;
            if (fe_fetch.instr[1:0] != 2'b11) begin
               fe_fetch_out.instr = {15'b0, fe_fetch.instr[15:0]};
               fe_fetch_out.iscompressed = 1'b1;
               fe_fetch_out.isfirstinstr = 1;
               fe_fetch_out.hastwoinstrs = 0;
               if (!fe_fetch.valid_branch_taken[0])
                 fe_fetch_out.valid_branch_taken[0] = 1'b0;
               if (!fe_fetch.valid_branch_taken[0]) begin
                  if (fe_fetch.instr[17:16] != 2'b11) begin
                     second_instr = 1'b1;
                     aligner_ready_o = 1'b0;
                     fe_fetch_out.hastwoinstrs = 1;
                  end else begin
                     unaligned_instr.instr = fe_fetch.instr[31:16];
                     unaligned_instr.address = {fe_fetch.pc[63:2], 2'b10};
                     unaligned_instr.valid = 1'b1;
                     fe_fetch_out.hastwoinstrs = 0;
                  end
               end
            end
         end       
         else if (unaligned_instr_r.valid) begin
            fe_fetch_out.pc = unaligned_instr_r.address;
            fe_fetch_out.instr = {fe_fetch.instr[15:0], unaligned_instr_r.instr};
            fe_fetch_out.iscompressed = 1'b0;
            fe_fetch_out.isfirstinstr = 1;
            fe_fetch_out.hastwoinstrs = 0;
            if (!fe_fetch.valid_branch_taken[0]) begin
               if (fe_fetch.instr[17:16] != 2'b11) begin
                  second_instr = 1'b1;
                  aligner_ready_o = 1'b0;
                  unaligned_instr.valid = 1'b0;
                  fe_fetch_out.hastwoinstrs = 1;
                  if (!fe_fetch.valid_branch_taken[0])
                    fe_fetch_out.valid_branch_taken[0] = 1'b0;
               end else if (!fe_fetch.valid_branch_taken[0]) begin 
                  unaligned_instr.instr = fe_fetch.instr[31:16];
                  unaligned_instr.address = {fe_fetch.pc[63:2], 2'b10};
                  unaligned_instr.valid = 1'b1;
                  fe_fetch_out.hastwoinstrs = 0;
               end 
            end 
            else if (fe_fetch.valid_branch_taken[0]) begin
               unaligned_instr.valid = 1'b0;
            end
         end   
      end 
      else if (fe_fetch.pc[1] == 1'b1) begin // half word access
         unaligned_instr.valid = 1'b0;
         if (fe_fetch.instr[17:16] != 2'b11) begin
            fe_fetch_out.instr= {15'b0, fe_fetch.instr[31:16]};
            fe_fetch_out.iscompressed = 1'b1;
            fe_fetch_out.isfirstinstr = 1;
            fe_fetch_out.hastwoinstrs = 0;
         end else begin
            unaligned_instr.instr = fe_fetch.instr[31:16];
            unaligned_instr.valid = 1'b1;
            unaligned_instr.address = {fe_fetch.pc[63:2], 2'b10};
            aligner_ready_o = 1'b1;
            fe_queue_v_o = 1'b0;
            jump_unaligned = 1'b1;
            fe_fetch_out.iscompressed = 1'b0;
            fe_fetch_out.isfirstinstr = 0; //no valid instr
            fe_fetch_out.hastwoinstrs = 0;
         end 
      end 
   end

   if (second_instr_r) begin
      aligner_ready_o = fe_queue_v_i;
      second_instr = 1'b0;
      fe_fetch_out.instr = {16'b0, fe_fetch.instr[31:16]};
      fe_fetch_out.iscompressed = 1'b1;
      fe_fetch_out.isfirstinstr = 0;
      fe_fetch_out.hastwoinstrs = 1;
      fe_fetch_out.pc = {fe_fetch.pc[63:2], 2'b10};
      fe_queue_v_o = ((cache_miss_i || cache_miss_r) && unaligned_instr_r.valid) ? 0 : 1'b1;
   end
   

   if ((!fe_queue_v_i) && !jump_unaligned) begin
      unaligned_instr.valid   = unaligned_instr_r.valid;
      unaligned_instr.instr   = unaligned_instr_r.instr;
      second_instr            = second_instr_r;
      unaligned_instr.address = unaligned_instr_r.address;
   end

   if (roll_i)
     begin
        second_instr = 0;
        unaligned_instr.valid  = 0;
     end

end    

bsg_dff_reset_en
  #(.width_p(unaligned_instr_metadata_width_lp)
   )
   unaligned_instr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i || pc_redirect_i)
     ,.en_i(~(reset_i || pc_redirect_i))
     ,.data_i(unaligned_instr)
     ,.data_o(unaligned_instr_r)
    );

   
bsg_dff_reset_en
    #(.width_p(1)
      )
      second_instr_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i || pc_redirect_i)
         ,.en_i(~(reset_i || pc_redirect_i))
         ,.data_i(second_instr)
         ,.data_o(second_instr_r)
        );


bsg_dff_reset_en
      #(.width_p(1)
        )
        cache_miss_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.en_i(fe_queue_v_i)
         ,.data_i(cache_miss_i)
         ,.data_o(cache_miss_r)
         );
   
   
bsg_dff_reset_en
  #(.width_p(rv64_eaddr_width_gp)
   )
   prev_pc_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(fe_queue_v_i)
     ,.data_i(fe_fetch.pc)
     ,.data_o(prev_v_pc)
     );
 
    
endmodule : aligner

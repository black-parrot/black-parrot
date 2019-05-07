module aligner 
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
   , parameter asid_width_p                = "inv"
   , localparam fe_fetch_width_lp  = `bp_fe_fetch_width(vaddr_width_p, branch_metadata_fwd_width_p)
  ) 
 (input clk_i
  , input reset_i
  , input  [fe_fetch_width_lp-1:0] input_fe_fetch_i
  , output logic [fe_fetch_width_lp-1:0] fe_fetch_o
  , input fe_queue_v_i
  , output logic fe_queue_v_o
  , output logic aligner_ready_o
  , input pc_redirect_i
  );

//bp_fe_fetch_s
//logic [bp_eaddr_width_gp-1:0]             pc;
//logic [bp_instr_width_gp-1:0]             instr;
//logic [branch_metadata_fwd_width_mp-1:0]  branch_metadata_fwd; 

//which instruction info is this in the case of having two compressed instructions in the fetch 32-bit instruction ==> these are useful for branch instructions
//  is realignment in the FE checking this stuff 
// they were some aligments when there were two back to back branch instructions
//bp_fe_branch_metadata_fwd_s
//btb_tag
//btb_indx
//bht_indx
//ras_addr

// Declare parameterizable structures
`declare_bp_common_fe_be_if_structs(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                   );

   
bp_fe_fetch_s fe_fetch, fe_fetch_out;   
assign fe_fetch   = input_fe_fetch_i;
assign fe_fetch_o = fe_fetch_out;
   

logic unaligned_n, unaligned_q;
logic [15:0] unaligned_instr_n, unaligned_instr_q;
logic compressed_n, compressed_q;
logic [63:0] unaligned_address_n, unaligned_address_q;
logic jump_unaligned_half_word;


logic kill_upper_16_bit;
assign kill_upper_16_bit = fe_fetch.valid_branch_taken;//[0];


always_comb begin : realign_instr
   unaligned_n          = unaligned_q;
   unaligned_instr_n    = unaligned_instr_q;
   compressed_n         = compressed_q;
   unaligned_address_n  = unaligned_address_q;
          
   fe_fetch_out.pc                  = fe_fetch.pc;
   fe_fetch_out.instr               = fe_fetch.instr;
   fe_fetch_out.branch_metadata_fwd = fe_fetch.branch_metadata_fwd;
   fe_fetch_out.valid_branch_taken  = fe_fetch.valid_branch_taken;
   fe_fetch_out.iscompressed        = 0;
   aligner_ready_o                  = fe_queue_v_i;
   fe_queue_v_o                     = fe_queue_v_i;
   jump_unaligned_half_word = 1'b0;

   if (fe_queue_v_i && !compressed_q) begin
      if (fe_fetch.pc[1] == 1'b0) begin
         if (!unaligned_q) begin
            unaligned_n = 1'b0;
            if (fe_fetch.instr[1:0] != 2'b11) begin
               fe_fetch_out.instr = {15'b0, fe_fetch.instr[15:0]};
               fe_fetch_out.iscompressed = 1'b1;
               if (!fe_fetch.valid_branch_taken/*[0]*/)
                 fe_fetch_out.valid_branch_taken = 1'b0;
               if (!kill_upper_16_bit) begin
                  if (fe_fetch.instr[17:16] != 2'b11) begin
                     compressed_n = 1'b1;
                     aligner_ready_o = 1'b0;
                  end else begin
                     unaligned_instr_n = fe_fetch.instr[31:16];
                     unaligned_address_n = {fe_fetch.pc[63:2], 2'b10};
                     unaligned_n = 1'b1;
                  end
               end
            end
         end//!unaligned_q       
         else if (unaligned_q) begin
            fe_fetch_out.pc = unaligned_address_q;
            fe_fetch_out.instr = {fe_fetch.instr[15:0], unaligned_instr_q};
            fe_fetch_out.iscompressed = 1'b0;
            if (!kill_upper_16_bit) begin
               if (fe_fetch.instr[17:16] != 2'b11) begin
                  compressed_n  = 1'b1;
                  aligner_ready_o = 1'b0;
                  unaligned_n = 1'b0;
                  if (!fe_fetch.valid_branch_taken/*[0]*/)
                    fe_fetch_out.valid_branch_taken = 1'b0;
               end else if (!kill_upper_16_bit) begin // if (fetch_entry_i.instruction[17:16] != 2'b11)
                  unaligned_instr_n = fe_fetch.instr[31:16];
                  unaligned_address_n = {fe_fetch.pc[63:2], 2'b10};
                  unaligned_n = 1'b1;
               end // if (!kill_upper_16_bit)
            end // if (!kill_upper_16_bit)
            else if (fe_fetch.valid_branch_taken) begin
               unaligned_n = 1'b0;
            end
         end   
      end // if (fe_fetch.pc[1] == 1'b0)
      else if (fe_fetch.pc[1] == 1'b1) begin // address was a half word access
         unaligned_n = 1'b0;
         if (fe_fetch.instr[17:16] != 2'b11) begin
            fe_fetch_out.instr= {15'b0, fe_fetch.instr[31:16]};
            fe_fetch_out.iscompressed = 1'b1;
         end else begin
            unaligned_instr_n = fe_fetch.instr[31:16];
            unaligned_n = 1'b1;
            unaligned_address_n = {fe_fetch.pc[63:2], 2'b10};
            aligner_ready_o = 1'b1;
            fe_queue_v_o = 1'b0;
            jump_unaligned_half_word = 1'b1;
         end // else: !if(fe_fetch.instr[17:16] != 2'b11)
      end // if (fe_fetch.pc[1] == 1'b1)
   end // if (fe_queue_v_i && !compressed_q)
   

   if (compressed_q) begin
      aligner_ready_o = fe_queue_v_i;
      compressed_n  = 1'b0;
      fe_fetch_out.instr = {16'b0, fe_fetch.instr[31:16]};
      fe_fetch_out.iscompressed = 1'b1;
      fe_fetch_out.pc = {fe_fetch.pc[63:2], 2'b10};
      fe_queue_v_o = 1'b1;
   end // if (compressed_q)
   

   if (!fe_queue_v_i && !jump_unaligned_half_word) begin
      unaligned_n         = unaligned_q;
      unaligned_instr_n   = unaligned_instr_q;
      compressed_n        = compressed_q;
      unaligned_address_n = unaligned_address_q;
   end

end // block: realign_instr
   
   
always_ff @(posedge clk_i) begin
   if (reset_i || pc_redirect_i /*|| ~fe_queue_v_i*/) begin
      unaligned_q         <= 1'b0;
      unaligned_instr_q   <= 16'b0;
      unaligned_address_q <= 64'b0;
      compressed_q        <= 1'b0;
   end else begin
      unaligned_q         <= unaligned_n;
      unaligned_instr_q   <= unaligned_instr_n;
      unaligned_address_q <= unaligned_address_n;
      compressed_q        <= compressed_n;
   end
end    
    
endmodule : aligner
/*
 * bp_fe_pc_gen.v
 *
 * pc_gen.v provides the interfaces for the pc_gen logics and also interfacing
 * other modules in the frontend. PC_gen provides the pc for the itlb and icache.
 * PC_gen also provides the BTB, BHT and RAS indexes for the backend (the queue
 * between the frontend and the backend, i.e. the frontend queue).
*/

module bp_fe_pc_gen
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter eaddr_width_p="inv"
   , parameter btb_indx_width_p="inv"
   , parameter bht_indx_width_p="inv"
   , parameter ras_addr_width_p="inv"
   , parameter instr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter bp_first_pc_p="inv"
   , localparam instr_scan_width_lp=`bp_fe_instr_scan_width
   , localparam branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p
   , localparam bp_fe_pc_gen_icache_width_lp=eaddr_width_p
   , localparam bp_fe_icache_pc_gen_width_lp=`bp_fe_icache_pc_gen_width(eaddr_width_p)
   , localparam bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(eaddr_width_p)
   , localparam bp_fe_pc_gen_width_i_lp=`bp_fe_pc_gen_cmd_width(vaddr_width_p,branch_metadata_fwd_width_lp)
   , localparam bp_fe_pc_gen_width_o_lp=`bp_fe_pc_gen_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp)
   , parameter prediction_on_p=1
   , parameter branch_predictor_p="inv"
   )
  (input                                             clk_i
   , input                                           reset_i
   , input                                           v_i
    
   , output logic [bp_fe_pc_gen_icache_width_lp-1:0] pc_gen_icache_o
   , output logic                                    pc_gen_icache_v_o
   , input                                           pc_gen_icache_ready_i

   , input [bp_fe_icache_pc_gen_width_lp-1:0]        icache_pc_gen_i
   , input                                           icache_pc_gen_v_i
   , output logic                                    icache_pc_gen_ready_o
   , input                                           icache_miss_i

   , output logic [bp_fe_pc_gen_itlb_width_lp-1:0]   pc_gen_itlb_o
   , output logic                                    pc_gen_itlb_v_o
   , input                                           pc_gen_itlb_ready_i
     
   , output logic [bp_fe_pc_gen_width_o_lp-1:0]      pc_gen_fe_o
   , output logic                                    pc_gen_fe_v_o
   , input                                           pc_gen_fe_ready_i

   , input [bp_fe_pc_gen_width_i_lp-1:0]             fe_pc_gen_i
   , input                                           fe_pc_gen_v_i
   , output logic                                    fe_pc_gen_ready_o
   );

// Suppress unused signal warnings
wire unused0 = v_i;
wire unused1 = pc_gen_itlb_ready_i;

assign icache_pc_gen_ready_o = '0;
assign pc_gen_itlb_v_o = '0;

//the first level of structs
`declare_bp_fe_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
//fe to pc_gen
`declare_bp_fe_pc_gen_cmd_s(branch_metadata_fwd_width_lp);
//pc_gen to icache
`declare_bp_fe_pc_gen_icache_s(eaddr_width_p);
//pc_gen to itlb
`declare_bp_fe_pc_gen_itlb_s(eaddr_width_p);
//icache to pc_gen
`declare_bp_fe_icache_pc_gen_s(eaddr_width_p);
//the second level structs definitions
`declare_bp_fe_branch_metadata_fwd_s(btb_indx_width_p,bht_indx_width_p,ras_addr_width_p);

   
//the first level structs instatiations
bp_fe_pc_gen_queue_s        pc_gen_queue;
bp_fe_pc_gen_cmd_s          fe_pc_gen_cmd;
bp_fe_pc_gen_icache_s       pc_gen_icache;
bp_fe_pc_gen_itlb_s         pc_gen_itlb;
bp_fe_branch_metadata_fwd_s branch_metadata_fwd_o;
bp_fe_icache_pc_gen_s       icache_pc_gen;


   
//the second level structs instatiations
bp_fe_fetch_s            pc_gen_fetch;
bp_fe_exception_s        pc_gen_exception;
bp_fe_instr_scan_s       scan_instr;
   
   
// save last pc
logic [eaddr_width_p-1:0]       icache_miss_pc;
logic [eaddr_width_p-1:0]       last_pc;
logic [eaddr_width_p-1:0]       pc;
logic [eaddr_width_p-1:0]       next_pc;
logic [eaddr_width_p-1:0]       pc_redirect;

logic [eaddr_width_p-1:0]       btb_target;
logic [instr_width_p-1:0]       next_instr;
logic [instr_width_p-1:0]       instr;
logic [instr_width_p-1:0]       last_instr;
logic [instr_width_p-1:0]       instr_out;

//control signals
logic                          misalignment;
logic                          predict;
logic                          pc_redirect_after_icache_miss;
logic                          stalled_pc_redirect;
logic                          bht_r_v_branch_jalr_inst;
logic                          branch_inst;
   
//connect pc_gen to the rest of the FE submodules as well as FE top module   
assign pc_gen_icache_o = pc_gen_icache;
assign pc_gen_itlb_o   = pc_gen_itlb;
assign pc_gen_fe_o     = pc_gen_queue;
assign fe_pc_gen_cmd   = fe_pc_gen_i;
assign icache_pc_gen   = icache_pc_gen_i;

assign misalignment          = fe_pc_gen_v_i
                               && fe_pc_gen_cmd.pc_redirect_valid 
                               && ~fe_pc_gen_cmd.pc[3:0] == 4'h0 
                               && ~fe_pc_gen_cmd.pc[3:0] == 4'h4
                               && ~fe_pc_gen_cmd.pc[3:0] == 4'h8
                               && ~fe_pc_gen_cmd.pc[3:0] == 4'hC;
   
/* output wiring */
// there should be fixes to the pc signal sent out according to the valid/ready signal pairs
always_comb 
  begin
    pc_gen_queue.msg_type            = (misalignment) ?  e_fe_exception : e_fe_fetch;
    pc_gen_exception.exception_code  = (misalignment) ? e_instr_addr_misaligned : e_illegal_instruction;
    pc_gen_fetch.pc                  = icache_pc_gen.addr;
    pc_gen_fetch.instr               = icache_pc_gen.instr;
    pc_gen_fetch.branch_metadata_fwd = branch_metadata_fwd_o;
    pc_gen_fetch.padding             = '0;
    pc_gen_exception.padding         = '0;
    pc_gen_queue.msg                 = (pc_gen_queue.msg_type == e_fe_fetch) ? pc_gen_fetch : pc_gen_exception;
    pc_gen_icache.virt_addr          = pc;
    pc_gen_itlb.virt_addr            = pc;
  end
   
//valid-ready signals assignments
always_comb 
  begin
    if (reset_i) 
      begin
        pc_gen_fe_v_o     = 1'b0;
        fe_pc_gen_ready_o = 1'b0;
        pc_gen_icache_v_o = 1'b0;
      end 
    else 
      begin
        fe_pc_gen_ready_o = fe_pc_gen_v_i;
        pc_gen_fe_v_o     = pc_gen_fe_ready_i && icache_pc_gen_v_i && ~icache_miss_i;
        pc_gen_icache_v_o = pc_gen_fe_ready_i && ~icache_miss_i;
      end
  end

   
//next_pc
always_comb begin
  if (icache_miss_i) 
    begin
      next_pc = icache_miss_pc;
    end
  else if (fe_pc_gen_cmd.pc_redirect_valid && fe_pc_gen_v_i) 
    begin
      next_pc = fe_pc_gen_cmd.pc;
    end
  else if (prediction_on_p && predict && icache_pc_gen_v_i && (scan_instr.instr_scan_class == e_rvi_jalr)) 
    begin
      next_pc = btb_target;
    end
  else if (prediction_on_p && predict && icache_pc_gen_v_i && (scan_instr.instr_scan_class == e_rvi_branch))
    begin
      next_pc = icache_pc_gen.addr + scan_instr.imm; 
    end
  else if (icache_pc_gen_v_i && (scan_instr.instr_scan_class == e_rvi_jal))
    begin
       next_pc = icache_pc_gen.addr + scan_instr.imm;
    end
  else 
    begin 
      next_pc = pc + 4;
    end
end 

   
always_ff @(posedge clk_i) 
  begin
    if (reset_i) 
      begin
       pc <= eaddr_width_p'(bp_first_pc_p);
       last_pc <= '0;
       icache_miss_pc <= '0;
      end
    else if (stalled_pc_redirect && icache_miss_i) 
      begin
        pc                  <= pc_redirect;
        last_pc             <= pc;
        icache_miss_pc      <= last_pc;
      end 
      else if (pc_gen_icache_ready_i && pc_gen_fe_ready_i) 
        begin
          pc                  <= next_pc;
          last_pc             <= pc;
          icache_miss_pc      <= last_pc;
        end 
      else if (icache_miss_i && ~pc_gen_icache_ready_i) 
        begin
          pc             <= icache_miss_pc;
          last_pc        <= pc;
          icache_miss_pc <= last_pc;
        end
  end

// PC redirect register
always_ff @(posedge clk_i) 
  begin
    if (fe_pc_gen_v_i && fe_pc_gen_cmd.pc_redirect_valid) 
      begin
        pc_redirect <= fe_pc_gen_cmd.pc;
      end
  end

//Keep track of stalled PC_redirect due to icache miss (icache is not ready). 
wire stalled_pc_redirect_n = (fe_pc_gen_v_i & fe_pc_gen_cmd.pc_redirect_valid)
                             | (stalled_pc_redirect & (pc_gen_fetch.pc != pc_redirect))
                             | (stalled_pc_redirect & (pc_gen_fetch.pc == pc_redirect) & ~pc_gen_fe_v_o);

always_ff @(posedge clk_i) 
  begin
    if (reset_i)
      stalled_pc_redirect <= 1'b0;
    else
      stalled_pc_redirect <= stalled_pc_redirect_n;
  end

instr_scan 
  #(.eaddr_width_p(eaddr_width_p)
    ,.instr_width_p(instr_width_p)
   ) 
  instr_scan_1 
    (.instr_i(icache_pc_gen.instr)
     ,.scan_o(scan_instr)
    );

assign bht_r_v_branch_jalr_inst = (icache_pc_gen_v_i & (scan_instr.instr_scan_class == e_rvi_jalr
                                                        | scan_instr.instr_scan_class == e_rvi_branch));
   
//select among 2 available branch predictor implementations
generate
  if (branch_predictor_p) 
    begin //select bht_btb implementation for branch predictor
      bp_fe_branch_predictor 
        #(.eaddr_width_p(eaddr_width_p)
          ,.btb_indx_width_p(btb_indx_width_p)
          ,.bht_indx_width_p(bht_indx_width_p)
          ,.ras_addr_width_p(ras_addr_width_p)
          ) 
        branch_prediction_1 
         (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.attaboy_i(fe_pc_gen_cmd.attaboy_valid)
          ,.r_v_i(bht_r_v_branch_jalr_inst)
          ,.w_v_i(fe_pc_gen_v_i)
          ,.pc_queue_i(last_pc)
          ,.pc_cmd_i(fe_pc_gen_cmd.pc)
          ,.pc_fwd_i(icache_pc_gen.addr)
          ,.branch_metadata_fwd_i(fe_pc_gen_cmd.branch_metadata_fwd)
          ,.predict_o(predict)
          ,.pc_o(btb_target)
          ,.branch_metadata_fwd_o(branch_metadata_fwd_o)
          );
    end 
  else 
    begin //seselct Pc+4 as branch predictor
      branch_prediction_pc_plus_4 
       #(.eaddr_width_p(eaddr_width_p)
         ,.btb_indx_width_p(btb_indx_width_p)
         ,.bht_indx_width_p(bht_indx_width_p)
         ,.ras_addr_width_p(ras_addr_width_p)
        ) 
       branch_prediction_1 
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.attaboy_i(fe_pc_gen_cmd.attaboy_valid)
         ,.r_v_i(bht_r_v_branch_jalr_inst)
         ,.w_v_i(fe_pc_gen_v_i)
         ,.pc_queue_i(last_pc)
         ,.pc_cmd_i(fe_pc_gen_cmd.pc)
         ,.pc_fwd_i(icache_pc_gen.addr)
         ,.branch_metadata_fwd_i(fe_pc_gen_cmd.branch_metadata_fwd)
         ,.predict_o(predict)
         ,.pc_o(btb_target)
         ,.branch_metadata_fwd_o(branch_metadata_fwd_o)
         );
    end
  endgenerate

endmodule

module bp_be_nonsynth_tracer
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)

   // Default parameters
   , parameter calc_trace_file_p = "debug"

   // Calculated parameters
   , localparam mhartid_width_lp      = `BSG_SAFE_CLOG2(num_core_p)
   , localparam proc_cfg_width_lp     = `bp_proc_cfg_width(num_core_p, num_cce_p, num_lce_p)
   , localparam issue_pkt_width_lp    = `bp_be_issue_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam dispatch_pkt_width_lp = `bp_be_dispatch_pkt_width(vaddr_width_p, branch_metadata_fwd_width_p)
   , localparam exception_width_lp    = `bp_be_exception_width
   , localparam ecode_dec_width_lp    = `bp_be_ecode_dec_width

   // Constants
   , localparam pipe_stage_els_lp = 5

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                                                   clk_i
   , input                                                 reset_i

   , input [mhartid_width_lp-1:0]                          mhartid_i

   , input [issue_pkt_width_lp-1:0]                        issue_pkt_i
   , input                                                 issue_pkt_v_i

   , input [dispatch_pkt_width_lp-1:0]                     dispatch_pkt_i
   , input                                                 fe_nop_v_i
   , input                                                 be_nop_v_i
   , input                                                 me_nop_v_i

   , input [vaddr_width_p-1:0]                             ex1_br_tgt_i
   , input                                                 ex1_btaken_i
   , input [reg_data_width_lp-1:0]                         iwb_result_i
   , input [reg_data_width_lp-1:0]                         fwb_result_i

   , input [pipe_stage_els_lp-1:0][exception_width_lp-1:0] cmt_trace_exc_i 

   , input                                                 trap_v_i
   , input [vaddr_width_p-1:0]                             mtvec_i
   , input [vaddr_width_p-1:0]                             mtval_i
   , input                                                 ret_v_i
   , input [vaddr_width_p-1:0]                             mepc_i
   , input [5-1:0]                                         mcause_i

   , input [1:0]                                           priv_mode_i
   , input [1:0]                                           mpp_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );
// Cast input and output ports
bp_be_issue_pkt_s             issue_pkt;
bp_be_dispatch_pkt_s          dispatch_pkt;
bp_be_exception_s [pipe_stage_els_lp-1:0]             cmt_trace_exc;

assign issue_pkt = issue_pkt_i;
assign dispatch_pkt = dispatch_pkt_i;

assign cmt_trace_exc       = cmt_trace_exc_i;

wire unused = &{ex1_btaken_i, fwb_result_i, trap_v_i, mtvec_i, mtval_i, ret_v_i, mepc_i, mcause_i};

    bp_be_dispatch_pkt_s [pipe_stage_els_lp-1:0] dbg_stage_r;

    bsg_dff 
     #(.width_p(dispatch_pkt_width_lp*pipe_stage_els_lp))
     dbg_stage_reg
      (.clk_i(clk_i)
       ,.data_i({dbg_stage_r[0+:pipe_stage_els_lp-1], dispatch_pkt})
       ,.data_o(dbg_stage_r)
       );
     
    logic [vaddr_width_p-1:0] iwb_br_tgt_r;
    bsg_shift_reg
     #(.width_p(vaddr_width_p)
       ,.stages_p(2)
       )
     dbg_shift_reg
      (.clk(clk_i)
       ,.reset_i(reset_i)
       ,.valid_i(1'b1)
       ,.valid_o(/* We don't care */)
       ,.data_i(ex1_br_tgt_i)
       ,.data_o(iwb_br_tgt_r)
       );

    integer file;
    string file_name;


//Shared logic 
logic booted_r;

bsg_dff_reset_en
 #(.width_p(1))
 boot_reg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(issue_pkt_v_i)
   ,.data_i(1'b1)
   ,.data_o(booted_r)
   );


initial 
  begin
    file_name = $sformatf("%s_%x.log", calc_trace_file_p, mhartid_i);
    file      = $fopen(file_name, "w");
  end

logic [4:0][2:0][7:0] stage_aliases;
assign stage_aliases = {"FWB", "IWB", "EX2", "EX1"};
always_ff @(posedge clk_i) begin

    if(booted_r) begin
            $fwrite(file, "-----\n");
            if (issue_pkt_v_i)
              $fwrite(file, "[ISS] core: %x pc: %x\n", mhartid_i, issue_pkt.pc);

            if (fe_nop_v_i)
              $fwrite(file, "[ISD] core: %x bub (fe)\n", mhartid_i);
            else if (be_nop_v_i)
              $fwrite(file, "[ISD] core: %x bub (be)\n", mhartid_i);
            else if (me_nop_v_i)
              $fwrite(file, "[ISD] core: %x bub (me)\n", mhartid_i);
            else 
              $fwrite(file, "[ISD] core: %x pc: %x\n", mhartid_i, dispatch_pkt.pc);

for (integer i = 0; i < 4; i++)
begin
            if (cmt_trace_exc[i].roll_v)
              $fwrite(file, "[%s] core: %x rolled\n", stage_aliases[i], mhartid_i);
            else if (cmt_trace_exc[i].poison_v)
              $fwrite(file, "[%s] core: %x poisoned\n", stage_aliases[i], mhartid_i);
            else if (~dbg_stage_r[i].decode.instr_v)
              $fwrite(file, "[%s] core: %x nop\n", stage_aliases[i], mhartid_i);
            else
              $fwrite(file, "[%s] core: %x pc: %x\n", stage_aliases[i], mhartid_i, dbg_stage_r[i].pc);
end

            if (trap_v_i) begin
              $fwrite(file, "[TRP] core: %x pc: %x", mhartid_i, dbg_stage_r[2].pc);
                $fwrite(file, "\n\ninfo: priv: %x mpp: %x mcause: %x mtvec: %x mtval: %x\n", priv_mode_i, mpp_i, mcause_i, mtvec_i, mtval_i);
            end
            if (ret_v_i) begin
              $fwrite(file, "[RET] core: %x pc: %x", mhartid_i, dbg_stage_r[2].pc);
                $fwrite(file, "\n\ninfo: priv: %x mpp: %x\n", priv_mode_i, mpp_i);
            end
            if(dbg_stage_r[2].decode.instr_v & ~cmt_trace_exc[2].poison_v) begin
                $fwrite(file, "[CMT] core: %x pc: %x instr: %x\n"
                         ,mhartid_i
                         ,dbg_stage_r[2].pc
                         ,dbg_stage_r[2].instr
                         );
                $fwrite(file, "\t\tinfo: rs1: %d {%x}, rs2: %d {%x}, imm: %x\n"
                        ,dbg_stage_r[2].instr.fields.rtype.rs1_addr
                        ,dbg_stage_r[2].rs1
                        ,dbg_stage_r[2].instr.fields.rtype.rs2_addr
                        ,dbg_stage_r[2].rs2
                        ,dbg_stage_r[2].imm
                        );
                if(dbg_stage_r[2].decode.csr_v) begin
                     $fwrite(file, "\t\top: csr sem: r%d <- csr {%x}\n"
                             ,dbg_stage_r[2].instr.fields.rtype.rd_addr
                             ,iwb_result_i
                             );
                end else if(dbg_stage_r[2].decode.mem_v) begin
                  if(dbg_stage_r[2].decode.fu_op == e_lrd)
                    $fwrite(file, "\t\top: lr.d sem: r%d <- mem[%x] {%x}\n"
                             ,dbg_stage_r[2].instr.fields.rtype.rd_addr
                             ,dbg_stage_r[2].rs1 
                             ,iwb_result_i
                             );
                  else if(dbg_stage_r[2].decode.fu_op == e_scd)
                        $fwrite(file, "\t\top: sc.d sem: mem[%x] <- r%d {%x}, success: %d \n"
                                 ,dbg_stage_r[2].rs1 
                                 ,dbg_stage_r[2].instr.fields.rtype.rs2_addr
                                 ,dbg_stage_r[2].rs2
                                 ,iwb_result_i[0]
                                 );   
                  else
                    $fwrite(file, "\t\top: load sem: r%d <- mem[%x] {%x}\n"
                             ,dbg_stage_r[2].instr.fields.rtype.rd_addr
                             ,dbg_stage_r[2].rs1 
                              + dbg_stage_r[2].imm
                             ,iwb_result_i
                             );
                end else if(dbg_stage_r[2].decode.mem_v) begin
                    if(dbg_stage_r[2].decode.fu_op == e_scd)
                        $fwrite(file, "\t\top: sc.d sem: mem[%x] <- r%d {%x}, success: %d \n"
                                 ,dbg_stage_r[2].rs1 
                                 ,dbg_stage_r[2].instr.fields.rtype.rs2_addr
                                 ,dbg_stage_r[2].rs2
                                 ,iwb_result_i
                                 );   
                      else
                        $fwrite(file, "\t\top: store sem: mem[%x] <- r%d {%x}\n"
                                 ,dbg_stage_r[2].rs1 
                                  + dbg_stage_r[2].imm
                                 ,dbg_stage_r[2].instr.fields.rtype.rs2_addr
                                 ,dbg_stage_r[2].rs2
                                 );   
                end else if(dbg_stage_r[2].decode.jmp_v) begin
                    $fwrite(file, "\t\top: jump sem: pc <- {%x}, r%d <- {%x}\n"
                             ,iwb_br_tgt_r
                             ,dbg_stage_r[2].instr.fields.rtype.rd_addr
                             ,iwb_result_i
                             );
                end else if(dbg_stage_r[2].decode.br_v) begin
                    // TODO: Expand on this trace to have all branch instructions
                    $fwrite(file, "\t\top: branch sem: pc <- {%x} rs1: %x cmp rs2: %x taken: %x\n"
                             ,iwb_br_tgt_r
                             ,dbg_stage_r[2].rs1
                             ,dbg_stage_r[2].rs2
                             ,iwb_result_i[0]
                             );
                end else if(dbg_stage_r[2].decode.irf_w_v) begin
                    // TODO: Expand on this trace to have all integer instructions
                    $fwrite(file, "\t\top: integer sem: r%d <- {%x}\n"
                             ,dbg_stage_r[2].instr.fields.rtype.rd_addr
                             ,iwb_result_i
                             );
                end
            end
        end
    end


endmodule : bp_be_nonsynth_tracer


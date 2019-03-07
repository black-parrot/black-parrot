module bp_be_nonsynth_tracer
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter branch_metadata_fwd_width_p="inv"

   , parameter core_els_p="inv"
   , parameter num_lce_p="inv"

   , localparam proc_cfg_width_lp = `bp_proc_cfg_width(core_els_p, num_lce_p)

   , localparam pipe_stage_reg_width_lp=`bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp=`bp_be_calc_result_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp=`bp_be_exception_width
   )
  (input logic                                 clk_i
   , input logic                               reset_i

   , input logic [proc_cfg_width_lp-1:0] proc_cfg_i

   , input logic [pipe_stage_reg_width_lp-1:0] cmt_trace_stage_reg_i
   , input logic [calc_result_width_lp-1:0]    cmt_trace_result_i
   , input logic [exception_width_lp-1:0]      cmt_trace_exc_i 
   );

`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports
bp_proc_cfg_s proc_cfg;

bp_be_pipe_stage_reg_s cmt_trace_stage_reg;
bp_be_calc_result_s    cmt_trace_result;
bp_be_exception_s      cmt_trace_exc;

assign proc_cfg = proc_cfg_i;

assign cmt_trace_stage_reg = cmt_trace_stage_reg_i;
assign cmt_trace_result    = cmt_trace_result_i;
assign cmt_trace_exc       = cmt_trace_exc_i;


logic[1:0] reset_complete;
logic      booted;

always_ff @(posedge clk_i) begin
    if(reset_i) begin
        reset_complete  <= 2'b00;
        booted          <= 1'b0;
    end else if(~reset_i & (reset_complete != 2'b11)) begin
        reset_complete <= reset_complete + 2'b01;
    end

    if(reset_complete == 2'b11) begin
        if(cmt_trace_stage_reg.decode.fe_nop_v) begin
            if(booted) begin
                $display("[CORE%0x BUB] cause: FE"
                         ,proc_cfg.mhartid
                         );
            end
        end else if(cmt_trace_stage_reg.decode.be_nop_v) begin
            if(booted) begin
                $display("[CORE%0x BUB] cause: BE"
                         ,proc_cfg.mhartid
                         );
            end
        end else if(cmt_trace_stage_reg.decode.me_nop_v) begin
            if(booted) begin
                $display("[CORE%0x BUB] cause: ME"
                         ,proc_cfg.mhartid
                         );
            end
        end else begin
            booted <= 1'b1;
            if(cmt_trace_exc.cache_miss_v) begin
                $display("[CORE%0x MIS] itag: %x pc: %x instr: %x"
                         ,proc_cfg.mhartid
                         ,cmt_trace_stage_reg.instr_metadata.itag
                         ,cmt_trace_stage_reg.instr_metadata.pc
                         ,cmt_trace_stage_reg.instr
                         );
            end else if(cmt_trace_exc.roll_v) begin
                $display("[CORE%0x ROL] itag: %x pc: %x instr: %x"
                         ,proc_cfg.mhartid
                         ,cmt_trace_stage_reg.instr_metadata.itag
                         ,cmt_trace_stage_reg.instr_metadata.pc
                         ,cmt_trace_stage_reg.instr
                         );
            end else if(cmt_trace_exc.poison_v) begin
                $display("[CORE%0x PSN] itag: %x pc: %x instr: %x"
                         ,proc_cfg.mhartid
                         ,cmt_trace_stage_reg.instr_metadata.itag
                         ,cmt_trace_stage_reg.instr_metadata.pc
                         ,cmt_trace_stage_reg.instr
                         );
            /* 
             * TODO: Get exceptions from exception pipe 
            end else if(cmt_trace_stage_reg.decode.exception_v) begin
                $display("[CORE%0x EXC] itag: %x pc: %x instr: %x"
                         ,proc_cfg.mhartid
                         ,cmt_trace_stage_reg.instr_metadata.itag
                         ,cmt_trace_stage_reg.instr_metadata.pc
                         ,cmt_trace_stage_reg.instr
                         );
            */
            end else begin
                $display("[CORE%0x CMT] itag: %x pc: %x instr: %x"
                         ,proc_cfg.mhartid
                         ,cmt_trace_stage_reg.instr_metadata.itag
                         ,cmt_trace_stage_reg.instr_metadata.pc
                         ,cmt_trace_stage_reg.instr
                         );
                if(cmt_trace_stage_reg.decode.mhartid_r_v) begin
                    $display("\t\t\top: csr sem: r%d <- mhartid {%x}"
                             ,cmt_trace_stage_reg.decode.rd_addr
                             ,cmt_trace_result.result
                             );
                end else if(cmt_trace_stage_reg.decode.dcache_r_v) begin
                    $display("\t\t\top: load sem: r%d <- mem[%x] {%x}"
                             ,cmt_trace_stage_reg.decode.rd_addr
                             ,cmt_trace_stage_reg.instr_operands.rs1 
                              + cmt_trace_stage_reg.instr_operands.imm
                             ,cmt_trace_result.result
                             );
                end else if(cmt_trace_stage_reg.decode.dcache_w_v) begin
                    if(cmt_trace_stage_reg.instr_operands.rs1
                       +cmt_trace_stage_reg.instr_operands.imm==64'hc00dead0) begin
                        if(cmt_trace_stage_reg.instr_operands.rs2[31:16]==16'h0000) begin
                            $display("[CORE%0x PAS] TEST_NUM=%x"
                                     ,proc_cfg.mhartid
                                     ,cmt_trace_stage_reg.instr_operands.rs2[15:0]
                                     );
                        end else if(cmt_trace_stage_reg.instr_operands.rs2[31:16]==16'hFFFF) begin
                            $display("[CORE%0x FAL] TEST_NUM=%x"
                                     ,proc_cfg.mhartid
                                     ,cmt_trace_stage_reg.instr_operands.rs2[15:0]
                                     );
                        end else begin
                            $display("[CORE%0x ERR] STORE TO 0xC00DEAD0, change test address"
                                     ,proc_cfg.mhartid
                                     );
                        end
                        $finish();
                    end else if(cmt_trace_stage_reg.instr_operands.rs1
                                +cmt_trace_stage_reg.instr_operands.imm==64'h8FFF_FFFF) begin
                        $display("[CORE%0x PRT] %d"
                                 ,proc_cfg.mhartid
                                 ,cmt_trace_stage_reg.instr_operands.rs2[0+:8]
                                 );
                    end else if(cmt_trace_stage_reg.instr_operands.rs1
                                +cmt_trace_stage_reg.instr_operands.imm==64'h8FFF_EFFF) begin
                        $display("[CORE%0x PRT] %c"
                                 ,proc_cfg.mhartid
                                 ,cmt_trace_stage_reg.instr_operands.rs2[0+:8]
                                 );
                    end else begin
                        $display("\t\t\top: store sem: mem[%x] <- r%d {%x}"
                                 ,cmt_trace_stage_reg.instr_operands.rs1 
                                  + cmt_trace_stage_reg.instr_operands.imm
                                 ,cmt_trace_stage_reg.decode.rs2_addr
                                 ,cmt_trace_stage_reg.instr_operands.rs2
                                 );   
                    end
                end else if(cmt_trace_stage_reg.decode.jmp_v) begin
                    $display("\t\t\top: jump sem: pc <- {%x}, r%d <- {%x}"
                             ,cmt_trace_result.br_tgt
                             ,cmt_trace_stage_reg.decode.rd_addr
                             ,cmt_trace_result.result
                             );
                end else if(cmt_trace_stage_reg.decode.br_v) begin
                    /* TODO: Expand on this trace to have all branch instructions */
                    $display("\t\t\top: branch sem: pc <- {%x} rs1: %x cmp rs2: %x taken: %x"
                             ,cmt_trace_result.br_tgt
                             ,cmt_trace_stage_reg.instr_operands.rs1
                             ,cmt_trace_stage_reg.instr_operands.rs2
                             ,cmt_trace_result.result[0]
                             );
                end else if(cmt_trace_stage_reg.decode.irf_w_v) begin
                    /* TODO: Expand on this trace to have all integer instructions */
                    $display("\t\t\top: integer sem: r%d <- {%x}"
                             ,cmt_trace_stage_reg.decode.rd_addr
                             ,cmt_trace_result.result
                             );
                end
            end
        end
    end
end
endmodule : bp_be_nonsynth_tracer

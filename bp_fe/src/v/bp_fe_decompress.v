// "c" extension riscv-spec-v2.2
// This file is hardcoded without any version adaptation !!!!

`ifndef BP_COMMON_FE_BE_IF_VH
`define BP_COMMON_FE_BE_IF_VH
`include "bp_common_fe_be_if.vh"
`endif

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH
`include "bp_fe_pc_gen.vh"
`endif

`ifndef BP_FE_ITLB_VH
`define BP_FE_ITLB_VH
`include "bp_fe_itlb.vh"
`endif

`ifndef BP_FE_ICACHE_VH
`define BP_FE_ICACHE_VH
`include "bp_fe_icache.vh"
`endif

`ifndef BSG_DEFINES_V
`define BSG_DEFINES_V
`include "bsg_defines.v"
`endif

`ifndef BP_FE_DECOMPRESS_VH
`define BP_FE_DECOMPRESS_VH
`include "bp_fe_decompress.vh"
`endif

module decompress 
#(
    parameter branch_metadata_fwd_width_lp="inv"
    ,parameter instr_width_lp="inv"
    ,parameter compressed_instr_width_lp="inv"
    ,parameter bp_fe_decompress_width_i_lp=`fe_decompress_width(bp_vaddr_width_gp, branch_metadata_fwd_width_lp)
    ,parameter bp_fe_decompress_width_o_lp=`fe_decompress_width(bp_vaddr_width_gp, branch_metadata_fwd_width_lp)
) (
    input logic clk_i
    ,input logic reset_i
    
    ,input logic [bp_fe_decompress_width_i_lp-1:0]          fe_decompress_i,
    ,input logic                                            fe_decompress_v_i
    ,output logic                                           fe_decompress_ready_o

    ,output logic [bp_fe_decompres_width_o_lp-1:0]          decompress_fe_o
    ,output logic                                           decompress_fe_v_o
    ,input logic                                            decompress_fe_ready_i

);

`fe_decompress_s fe_decompress;
`decompress_fe_s decompress_fe;

decompress_states_e                                         decompress_state;

logic [instr_width_lp-1:0]                                  icache_instr;
logic [instr_width_lp-1:0]                                  instr_ibuf_a;
logic [instr_width_lp-1:0]                                  instr_ibuf_b;
logic [instr_width_lp-1:0]                                  decompress_fifo;
logic [instr_width_lp-1:0]                                  fifo_fe;

logic                                                       decompress_fifo_v;
logic                                                       decompress_fifo_ready;

format_cr_s                                                 format_cr;
format_ci_s                                                 format_ci;
format_css_s                                                format_css;
format_ciw_s                                                format_ciwr;
format_cl_s                                                 format_cl;
format_cs_s                                                 format_cs;
format_cb_s                                                 format_cb;
format_cj_s                                                 format_cj;

format_r_s                                                  format_r;
format_i_s                                                  format_i;
format_s_s                                                  format_s;

// input wiring

assign fe_decompress      = fe_decompress_i;
assign decompress_fe_o    = decompress_fe;

assign icache_instr       = fe_decompress.msg.fetch.instr;

task decompress(instr_d, instr_c);
    input [15:0]    instr_c;
    output [31:0]   instr_d;

    // reformatting compressed instruction
    case ({instr_c[15:13],instr_c[1:0]})
         `C_LWSP,`C_LDSP,`C_LQSP,`C_FLWSP,`FLDSP: 
                  begin
                      format_ci          = instr_c;
                      instr_d            = format_i;
                  end
         `C_SWSP,`C_SDSP,`C_SQSP,`C_FSWSP,`FSDSP: 
                  begin
                      format_css         = instr_c;
                      instr_d            = format_;
                  end
         `C_LW,`C_LD,`C_LQ,`C_FLW,`C_FLD:
                  begin
                      format_ci          = instr_c;
                      instr_d            = format_;
                  end 
         `C_SW,`C_SD,`C_SQ,`C_FSW,`C_FSD:
                  begin
                      format_cs          = instr_c;
                      instr_d            = format_;
                  end 
         `C_J,`C_JAL:
                  begin
                      format_cj          = instr_c;
                      instr_d            = format_;
                  end 
         `C_JR,`C_JALR:
                  begin 
                      format_cr          = instr_c;
                      format_d           = format_;
                  end
         `C_BEQZ,`C_BNEZ:
                  begin
                      format_cb          = instr_c;
                      format_d           = format_;
                  end
         `C_LI,`C_LUI:
                  begin
                      format_ci          = instr_c;
                      format_d           = format_;
                  end
         `C_ADDI,`C_ADDIW,`C_ADDI16SP:
                  begin
                      format_ci          = instr_c;
                      format_d           = format_;
                  end
         `C_ADDI4SPN:
                  begin
                      format_ciw         = instr_c;
                      format_d           = format_;
                  end
         `C_SLLI:
                  begin
                      format_ci          = instr_c;
                      format_d           = format_;
                  end
         `C_SRLI,`C_SRAI,`C_ANDI:
                  begin
                      format_cb          = instr_c;
                      format_d           = format_;
                  end
         `C_MV,`C_ADD:
                  begin
                      format_cr          = instr_c;
                      format_d           = format_;
                  end
         `C_AND,`_C_OR,`C_XOR,`C_SUB,`C_ADDW,`C_SUBW:
                  begin
                      format_cs          = instr_c; 
                      format_d           = format_;
                  end
         `C_NOP: 
                  begin
                      format_ci          = instr_c; 
                      format_d           = format_;
                  end
    endcase

    
    case ({instr_c[15:13],instr_c[1:0]})
         `C_LWSP: begin 
                      format_i.imm[7:6]  = format_ci.imm2[3:2];
                      format_i.imm[4:2]  = format_ci.imm2[6:4];
                      format_i.imm[5]    = format_ci.imm1;
                      format_i.imm[1:0]  = 2'b00;
                      format_i.imm[11:8] = 3'b000;
                      format_i.rs1       = `x2;
                      format_i.funct3    = 3'b010
                      format_i.rd        = format_ci.rd;
                      format_i.op        = 7'b0000011;
                  end
         `C_LDSP: begin 
                      format_i.imm[8:6]  = format_ci.imm2[4:2];
                      format_i.imm[4:3]  = format_ci.imm2[6:5];
                      format_i.imm[5]    = format_ci.imm1;
                      format_i.imm[1:0]  = 2'b00;
                      format_i.imm[11:8] = 3'b000;
                      format_i.rs1       = `x2;
                      format_i.funct3    = 3'b011
                      format_i.rd        = format_ci.rd;
                      format_i.op        = 7'b0000011;
                  end
         `C_LQSP: begin
                  end

    endcase
endtask

// state indicator, inclusive cases, which assumes that if the case is
// satisfied, it won't go for another case
always_comb begin
    case ({reset_i, decompress_state, icache_instr[17:16], icache_instr[1:0]})
        8'b1???????:      decompress_states = e_rvc_aligned; 
        8'b0?????11:      decompress_states = e_rvi_aligned;
        8'b0???11??:      decompress_states = e_rvi_rvc_misaligned;
        // only if previous state is e_rvi_misaligned or e_rvi_rvc_misaligned
        8'b001111??, 8'b10011??:      decompress_states = e_rvi_misaligned; 
        // only if previous state is e_rvi_misaligned or e_rvi_rvc_misaligned
        8'b0011????, 8'b100????:      decompress_states = e_rvc_rvi_misaligned;
        default:          decompress_state  = e_rvc_aligned;
    endcase
    case (decompress_state) 
        e_rvi_aligned:    decompress_fifo   = icache_instr;
        e_rvc_aligned:     
        

    endcase
end


always_ff @(posedge clk_i) begin
    
end

bsg_two_fifo 
#(
    .width_p(instr_width_lp)
) obuf (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    
    ,.ready_o(decompress_fifo_ready)
    ,.data_i(decompress_fifo)
    ,.v_i(decompress_fifo_v)

    ,.v_o(decompress_fe_o)
    ,.data_o(fifo_fe)
    ,.yumi_i(decompress_fe_ready_i)

)
endmodule



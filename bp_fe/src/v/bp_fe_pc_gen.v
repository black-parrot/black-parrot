/*
 * pc_gen.v
 *
 * pc_gen.v provides the interfaces for the pc_gen logics and also interfacing
 * other modules in the frontend. PC gen provides the pc for the itlb and icache.
 * PC gen also provides the BTB, BHT and RAS indexes for the backend (the queue
 * between the frontend and the backend, i.e. the frontend queue).
*/

/*
 * The header includes the pc_gen.vh and bsg_defines.v
*/
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

module bp_fe_pc_gen
#(
    parameter vaddr_width_p="inv"
    ,parameter paddr_width_p="inv"
    ,parameter eaddr_width_p="inv"
    ,parameter btb_indx_width_p="inv"
    ,parameter bht_indx_width_p="inv"
    ,parameter ras_addr_width_p="inv"
    ,parameter instr_width_p="inv"
    ,parameter asid_width_p="inv"
    ,parameter bp_first_pc_p="inv"
    ,parameter instr_scan_width_lp=`bp_fe_instr_scan_width
    ,parameter branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p
    ,parameter bp_fe_pc_gen_icache_width_lp=eaddr_width_p
    ,parameter bp_fe_icache_pc_gen_width_lp=`bp_fe_icache_pc_gen_width(eaddr_width_p)
    ,parameter bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(eaddr_width_p)
    ,parameter bp_fe_pc_gen_width_i_lp=`bp_fe_pc_gen_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
    ,parameter bp_fe_pc_gen_width_o_lp=`bp_fe_pc_gen_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp)
    ,parameter prediction_on=0
    
)(
    input logic clk_i
    ,input logic reset_i
    ,input logic v_i
    
    ,output logic [bp_fe_pc_gen_icache_width_lp-1:0]      pc_gen_icache_o
    ,output logic                                         pc_gen_icache_v_o
    ,input  logic                                         pc_gen_icache_ready_i

    ,input  logic [bp_fe_icache_pc_gen_width_lp-1:0]      icache_pc_gen_i
    ,input  logic                                         icache_pc_gen_v_i
    ,output logic                                         icache_pc_gen_ready_o
    ,input  logic                                         icache_miss_i

    ,output logic [bp_fe_pc_gen_itlb_width_lp-1:0]        pc_gen_itlb_o
    ,output logic                                         pc_gen_itlb_v_o
    ,input  logic                                         pc_gen_itlb_ready_i
     
    ,output logic [bp_fe_pc_gen_width_o_lp-1:0]           pc_gen_fe_o
    ,output logic                                         pc_gen_fe_v_o
    ,input  logic                                         pc_gen_fe_ready_i

    ,input  logic [bp_fe_pc_gen_width_i_lp-1:0]           fe_pc_gen_i
    ,input  logic                                         fe_pc_gen_v_i
    ,output logic                                         fe_pc_gen_ready_o
);
    // the first level of structs
    // be fe interface udpate (not sure if this is needed)
    localparam branch_metadata_fwd_width_p = branch_metadata_fwd_width_lp;
    `declare_bp_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp)
    // pc_gen to fe
    `declare_bp_fe_pc_gen_queue_s;
    // fe to pc_gen
    `declare_bp_fe_pc_gen_cmd_s;
    // pc_gen to icache
    `declare_bp_fe_pc_gen_icache_s(eaddr_width_p);
    // pc_gen to itlb
    `declare_bp_fe_pc_gen_itlb_s(eaddr_width_p);
    // icache to pc_gen
    `declare_bp_fe_icache_pc_gen_s(eaddr_width_p);

    // the second level structs definitions
    `declare_bp_fe_branch_metadata_fwd_s(btb_indx_width_p,bht_indx_width_p,ras_addr_width_p);

    // the first level structs instatiations
    bp_fe_pc_gen_queue_s                                  pc_gen_queue;
    bp_fe_pc_gen_cmd_s                                    fe_pc_gen_cmd;
    bp_fe_pc_gen_icache_s                                 pc_gen_icache;
    bp_fe_pc_gen_itlb_s                                   pc_gen_itlb;
    bp_fe_icache_pc_gen_s                                 next_icache_pc_gen;

    bp_fe_branch_metadata_fwd_s                           branch_metadata_fwd_i;
    bp_fe_branch_metadata_fwd_s                           branch_metadata_fwd_o;
    bp_fe_icache_pc_gen_s                                 icache_pc_gen;
    bp_fe_icache_pc_gen_s                                 last_icache_pc_gen;

    // the second level structs instatiations
    `bp_fe_pc_gen_fetch_s                                 pc_gen_fetch;
    `bp_fe_pc_gen_exception_s                             pc_gen_exception;
    
    logic [instr_scan_width_lp-1:0]                       scan_instr;
    // save last pc
    logic [eaddr_width_p-1:0]                             icache_pc;
    logic [eaddr_width_p-1:0]                             last_pc;
    logic [eaddr_width_p-1:0]                             pc;
    logic [eaddr_width_p-1:0]                             next_pc;
    logic [eaddr_width_p-1:0]                             redirect_pc;

    logic [eaddr_width_p-1:0]                             btb_target;
    logic [instr_width_p-1:0]                            next_instr;
    logic [instr_width_p-1:0]                            instr;
    logic [instr_width_p-1:0]                            last_instr;
    logic [instr_width_p-1:0]                            instr_out;

    logic                                                 predict;
    // extra info
    logic [31:0]                                          predict_times;
    logic [31:0]                                          pc_redirect_times;

    // control signals
    logic                                                 state_reset;
    logic                                                 interrupt;
    logic                                                 branch_misprediction;
    logic                                                 attaboy;
    logic                                                 misalignment;
    logic                                                 pc_redirect_after_icache_miss;
    
    logic                                                 first_reset;
    logic                                                 speculative;
    pc_gen_state_e                                        pc_gen_state;
    pc_gen_state_e                                        prev_pc_gen_state;
    pc_gen_state_e                                        prev2_pc_gen_state;

    assign pc_gen_icache_o                                = pc_gen_icache;
    assign pc_gen_itlb_o                                  = pc_gen_itlb;
    assign pc_gen_fe_o                                    = pc_gen_queue;
    assign next_icache_pc_gen                             = icache_pc_gen_i;
    assign fe_pc_gen_cmd                                  = fe_pc_gen_i;

    /* input wiring */
    assign state_reset          = fe_pc_gen_cmd.command_queue_opcodes == e_op_state_reset ;
    assign interrupt            = fe_pc_gen_cmd.command_queue_opcodes == e_op_interrupt ;
    assign branch_misprediction = (fe_pc_gen_cmd.command_queue_opcodes == e_op_pc_redirection)
                                && (fe_pc_gen_cmd.operands.pc_redirect_operands.subopcode 
                                == e_subop_branch_mispredict) ;
    assign attaboy              =  fe_pc_gen_cmd.command_queue_opcodes == e_op_attaboy ;

    assign branch_metadata_fwd_i = (fe_pc_gen_cmd.command_queue_opcodes  == e_op_attaboy) ? 
                                   fe_pc_gen_cmd.operands.attaboy.branch_metadata_fwd :
                                 (fe_pc_gen_cmd.command_queue_opcodes  == e_op_pc_redirection) ?
                                   fe_pc_gen_cmd.operands.pc_redirect_operands.branch_metadata_fwd :
                                  '{default:'0};

    assign next_instr           = next_icache_pc_gen.instr;
    assign misalignment         = fe_pc_gen_v_i && 
                                  ~fe_pc_gen_cmd.operands.pc_redirect_operands.pc[3:0] == 4'h0 
                                  && ~fe_pc_gen_cmd.operands.pc_redirect_operands.pc[3:0] == 4'h4
                                  && ~fe_pc_gen_cmd.operands.pc_redirect_operands.pc[3:0] == 4'h8
                                  && ~fe_pc_gen_cmd.operands.pc_redirect_operands.pc[3:0] == 4'hC;

    /* output wiring */
    // there should be fixes to the pc signal sent out according to the valid/ready signal pairs
    assign pc_gen_queue.msg_type              = (misalignment) ?  e_fe_exception: e_fe_fetch;
    assign pc_gen_exception.exception_code    = (misalignment) ? e_instr_addr_misaligned : e_illegal_instruction;
    assign pc_gen_queue.scan_instr            = scan_instr;
    assign pc_gen_queue.msg                   = (pc_gen_queue.msg_type == e_fe_fetch) ? pc_gen_fetch : pc_gen_exception;
    assign pc_gen_fetch.pc                    = last_pc;
    assign pc_gen_fetch.instr                 = (pc_gen_state == e_state_not_ready
                                                || pc_gen_state == e_state_always_not_ready) 
                                                ? icache_pc_gen.instr : next_instr; 
    assign pc_gen_icache.virt_addr            = next_pc;
    //assign pc_gen_icache.speculative          = speculative;
    assign pc_gen_itlb.virt_addr              = next_pc;
    assign pc_gen_fetch.branch_metadata_fwd   = branch_metadata_fwd_o;
    assign pc_gen_fetch.padding               = '0;
    assign pc_gen_exception.padding           = '0;


    always_comb begin

        if (pc_gen_state == e_state_reset) begin
            pc_gen_fe_v_o                     = 1'b0;
            fe_pc_gen_ready_o                 = 1'b0;

            pc_gen_icache_v_o                 = 1'b0;

        end else begin
            fe_pc_gen_ready_o                 = fe_pc_gen_v_i;
        end

        if  (pc_gen_state == e_state_first_start_icache) begin
            pc_gen_fe_v_o                     = pc_gen_fe_ready_i && icache_pc_gen_v_i;

            pc_gen_icache_v_o                 = 1'b1;
        end

        if (pc_gen_state == e_state_pc_redirect ) begin

            pc_gen_fe_v_o                     = pc_gen_fe_ready_i && icache_pc_gen_v_i;

        end

        if (pc_gen_state == e_state_after_pc_redirect) begin

            pc_gen_fe_v_o                     = 1'b0;

        end

        if (pc_gen_state == e_state_invalid_cmd) begin

            pc_gen_icache_v_o                 = pc_gen_fe_ready_i; 

        end
        
        if (pc_gen_state == e_state_not_ready) begin
            pc_gen_fe_v_o                     = pc_gen_fe_ready_i && icache_pc_gen_v_i;

            pc_gen_icache_v_o                 = pc_gen_fe_ready_i;
        end

        if (pc_gen_state == e_state_always_not_ready) begin
            pc_gen_icache_v_o                 = pc_gen_fe_ready_i;
        end

        if (pc_gen_state == e_state_icache_miss) begin

            pc_gen_fe_v_o                     = 1'b0;

            pc_gen_icache_v_o                 = 1'b0;
        end

        if (pc_gen_state == e_state_after_icache_miss) begin
            pc_gen_fe_v_o                     = pc_gen_fe_ready_i && icache_pc_gen_v_i;

            pc_gen_icache_v_o                 = pc_gen_fe_ready_i;
        end
        
        if (pc_gen_state == e_state_no_cmd) begin

            pc_gen_fe_v_o                     = pc_gen_fe_ready_i && (icache_pc_gen_v_i || prev_pc_gen_state == e_state_not_ready)
                                                && ~(prev_pc_gen_state == e_state_after_pc_redirect) ;

            pc_gen_icache_v_o                 = pc_gen_fe_ready_i; 

        end

    end

    // state machine
    always_ff @ (posedge clk_i) begin
        prev_pc_gen_state                     <= pc_gen_state;

        if (reset_i) begin
            pc_gen_state                      <= e_state_reset;

            next_pc                           <= bp_first_pc_p;
            pc                                <= next_pc;
            last_pc                           <= pc;
            icache_pc                         <= last_pc;

            first_reset                       <= 1'b1;

            pc_redirect_after_icache_miss     <= 1'b0;

            speculative                       <= 1'b0;
            predict_times                     <= 1'b0;
            pc_redirect_times                 <= 1'b0;

        end else if (~pc_gen_icache_ready_i && first_reset) begin

            pc_gen_state                      <= e_state_first_reset_icache;

            pc_redirect_after_icache_miss     <= 1'b0;

            speculative                       <= 1'b0;
        end else if (pc_gen_icache_ready_i && first_reset) begin

            pc_gen_state                      <= e_state_first_start_icache;
 

            first_reset                       <= 1'b0;

            pc_redirect_after_icache_miss     <= 1'b0;

            speculative                       <= 1'b0;
        end else if (fe_pc_gen_v_i) begin

            pc_redirect_after_icache_miss     <= 1'b0;


            if (fe_pc_gen_cmd.command_queue_opcodes == e_op_state_reset) begin
                pc_gen_state                  <= e_state_reset;

                next_pc                       <= bp_first_pc_p;
                pc                            <= next_pc;
                last_pc                       <= pc;
                icache_pc                     <= last_pc;
                
                first_reset                   <= 1'b1;
  
                speculative                   <= 1'b0;
            end else if (fe_pc_gen_cmd.command_queue_opcodes == e_op_pc_redirection) begin
                pc_gen_state                  <= e_state_pc_redirect;
                next_pc                       <= fe_pc_gen_cmd.operands.pc_redirect_operands.pc;
                redirect_pc                   <= fe_pc_gen_cmd.operands.pc_redirect_operands.pc;
                // fifo is always ready, since the fifo is flushed every time there is a request.
                pc                            <= next_pc;
                last_pc                       <= pc;
                pc_redirect_times             <= pc_redirect_times + 'd1;

                speculative                   <= 1'b0;
            end else begin
                pc_gen_state                  <= e_state_invalid_cmd;
                
                pc_redirect_after_icache_miss     <= 1'b0;

                if (prediction_on) begin
                    next_pc                           <= (predict) ? btb_target : next_pc + 'h4;
                    speculative                       <= (predict);
                    if (predict) begin
                        predict_times                     <= predict_times + 'd1; 
                    end
                end else
                    next_pc                           <= next_pc + 'h4;

                pc                                <= next_pc;
                last_pc                           <= pc;

                instr                             <= next_instr;
  
                first_reset                       <= 1'b0;

            end 

        end else if (pc_gen_state == e_state_pc_redirect) begin
            pc_gen_state                      <= e_state_after_pc_redirect;

            pc                                <= next_pc;
            last_pc                           <= pc;

            speculative                       <= 1'b0;
        end else if (icache_miss_i) begin
            pc_gen_state                      <= e_state_icache_miss;


            if (pc_gen_state == e_state_pc_redirect) 
                last_pc                       <= next_pc; 

            if (prev_pc_gen_state == e_state_pc_redirect) begin
                pc_redirect_after_icache_miss <= 1'b1;
            end

            speculative                       <= 1'b0;
        end else if (pc_gen_state == e_state_icache_miss) begin
            pc_redirect_after_icache_miss     <= 1'b0;

            pc_gen_state                      <= e_state_after_icache_miss;
            
            if (pc_redirect_after_icache_miss)  begin
                last_pc                           <= redirect_pc;
            end else
                next_pc                           <= last_pc;

            speculative                       <= 1'b0;
        end else if (~pc_gen_fe_ready_i && pc_gen_state == e_state_no_cmd) begin
            pc_gen_state                      <= e_state_not_ready;

            icache_pc_gen                     <= next_icache_pc_gen;
            last_icache_pc_gen                <= icache_pc_gen;
          
            speculative                       <= 1'b0;
        end else if (~pc_gen_fe_ready_i && (pc_gen_state == e_state_not_ready || pc_gen_state == e_state_always_not_ready)) begin
            pc_gen_state                      <= e_state_always_not_ready;

            next_pc                           <= last_pc;

            speculative                       <= 1'b0;
        end else begin
            pc_redirect_after_icache_miss     <= 1'b0;

            pc_gen_state                      <= e_state_no_cmd;

            if (prediction_on) begin
                next_pc                           <= (predict) ? btb_target : next_pc + 'h4;
                speculative                       <= (predict);
                if (predict) begin
                    predict_times                     <= predict_times + 'd1; 
                end
            end else
                next_pc                           <= next_pc + 'h4;

            pc                                <= next_pc;
            last_pc                           <= pc;

            instr                             <= next_instr;
  
            first_reset                       <= 1'b0;

        end
    end

branch_prediction
#(
    .eaddr_width_p(eaddr_width_p)
    ,.btb_indx_width_p(btb_indx_width_p)
    ,.bht_indx_width_p(bht_indx_width_p)
    ,.ras_addr_width_p(ras_addr_width_p)
) branch_prediction_1 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.attaboy(attaboy)
    ,.bp_r_i(pc_gen_state == e_state_no_cmd)
    ,.bp_w_i(fe_pc_gen_v_i)
    ,.pc_queue_i(next_pc)
    ,.pc_cmd_i(fe_pc_gen_cmd.operands.pc_redirect_operands.pc)
    ,.pc_fwd_i(last_pc)
    ,.branch_metadata_fwd_i(branch_metadata_fwd_i)
    ,.predict_o(predict)
    ,.pc_o(btb_target)
    ,.branch_metadata_fwd_o(branch_metadata_fwd_o)

);

instr_scan #(
    .eaddr_width_p(eaddr_width_p)
    ,.bp_fe_instr_scan_width_lp(`bp_fe_instr_scan_width)
    ,.instr_width_p(instr_width_p)
) instr_scan_1 (
    .instr_i(next_instr)
    ,.scan_o(scan_instr)
);

//final begin
//    $display("%s  PREDICTION ACCURACY %.2f", 
//            __DEBUG__MSG__,$itor(predict_times)/$itor((predict_times)+$itor(pc_redirect_times)));
//end

/* assertion for checking the valid/ready signals */
/*
cmd_msg_check: assert property (@(posedge clk_i) 
~reset_i || ~fe_pc_gen_v_i
|| attaboy != interrupt
&& attaboy != branch_misprediction
&& interrupt != branch_misprediction
) else $error("Only one of the following can happen attaboy, branch micprediction, interrupt");
*/
endmodule

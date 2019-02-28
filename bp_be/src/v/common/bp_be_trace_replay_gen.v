
module bp_be_trace_replay_gen
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter branch_metadata_fwd_width_p="inv"   
   , parameter trace_ring_width_p="inv"

   , localparam pipe_stage_reg_width_lp=`bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp=`bp_be_calc_result_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp=`bp_be_exception_width
   )
  (input logic                                 clk_i
   , input logic                               reset_i

   , input logic [pipe_stage_reg_width_lp-1:0] cmt_trace_stage_reg_i
   , input logic [calc_result_width_lp-1:0]    cmt_trace_result_i
   , input logic [exception_width_lp-1:0]      cmt_trace_exc_i 
   
   , output logic [trace_ring_width_p-1:0]	data_o
   , output logic 							v_o
   , input logic 							ready_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Cast input and output ports

bp_be_pipe_stage_reg_s cmt_trace_stage_reg;
bp_be_calc_result_s    cmt_trace_result;
bp_be_exception_s      cmt_trace_exc;

assign cmt_trace_stage_reg = cmt_trace_stage_reg_i;
assign cmt_trace_result    = cmt_trace_result_i;
assign cmt_trace_exc       = cmt_trace_exc_i;


logic[1:0] reset_complete;
logic      booted;

assign booted = (reset_complete == 2'b11) & ~(cmt_trace_stage_reg.decode.fe_nop_v |
												cmt_trace_stage_reg.decode.be_nop_v |
												cmt_trace_stage_reg.decode.me_nop_v);

logic[rv64_reg_data_width_gp-1:0] mem_data;

always_comb begin
    if (cmt_trace_stage_reg.decode.dcache_w_v) begin
        // get size of the memory operation
        case (cmt_trace_stage_reg.decode.fu_op[1:0])
            // byte
            2'b00: begin
                mem_data = {{(rv64_reg_data_width_gp - 8){1'b0}}, cmt_trace_stage_reg.instr_operands.rs2[7:0]};
            end
            // halfword
            2'b01: begin
                mem_data = {{(rv64_reg_data_width_gp - 16){1'b0}}, cmt_trace_stage_reg.instr_operands.rs2[15:0]};
            end
            // word
            2'b10: begin
                mem_data = {{(rv64_reg_data_width_gp - 32){1'b0}}, cmt_trace_stage_reg.instr_operands.rs2[31:0]};
            end
            // doubleword
            2'b11: begin
                mem_data = cmt_trace_stage_reg.instr_operands.rs2;
            end
            default: begin
                mem_data = 'x;
            end
        endcase
    end
end

always_ff @(posedge clk_i) begin
	v_o <= 1'b0;
    if(reset_i) begin
        reset_complete  <= 2'b00;
    end else if(~reset_i & (reset_complete != 2'b11)) begin
        reset_complete <= reset_complete + 2'b01;
    end

    if(reset_complete == 2'b11) begin
        if(booted) begin
            if(!(cmt_trace_exc.cache_miss_v || cmt_trace_exc.roll_v || cmt_trace_exc.poison_v)) begin //TODO: Add other possible exceptions
                if(cmt_trace_stage_reg.decode.mhartid_r_v) begin
					// csr sem: r%d <- mhartid {%x}"
					if(cmt_trace_stage_reg.decode.rd_addr != 5'b0) begin
						v_o <= 1'b1;
						data_o <= {60'b0, cmt_trace_stage_reg.decode.rd_addr, cmt_trace_result.result};
					end	
                end else if(cmt_trace_stage_reg.decode.dcache_r_v) begin
					// load sem: r%d <- mem[%x] {%x}"
					if(cmt_trace_stage_reg.decode.rd_addr != 5'b0) begin
						v_o <= 1'b1;
						data_o <= {60'b0, cmt_trace_stage_reg.decode.rd_addr, cmt_trace_result.result};
					end			 
                end else if(cmt_trace_stage_reg.decode.dcache_w_v) begin
					// store sem: mem[%x] <- r%d {%x}" 
					v_o <= 1'b1;
					data_o <= {1'b1, cmt_trace_stage_reg.instr_operands.rs1 + cmt_trace_stage_reg.instr_operands.imm, mem_data};
                end else if(cmt_trace_stage_reg.decode.jmp_v) begin
					// jump sem: pc <- {%x}, r%d <- {%x}"
					if(cmt_trace_stage_reg.decode.rd_addr != 5'b0) begin
						v_o <= 1'b1;
						data_o <= {60'b0, cmt_trace_stage_reg.decode.rd_addr, cmt_trace_result.result};
					end
                end else if(cmt_trace_stage_reg.decode.irf_w_v) begin
                    /* TODO: Expand on this trace to have all integer instructions */
					// integer sem: r%d <- {%x}"
					if(cmt_trace_stage_reg.decode.rd_addr != 5'b0) begin
						v_o <= 1'b1;
						data_o <= {60'b0, cmt_trace_stage_reg.decode.rd_addr, cmt_trace_result.result};
					end
                end
            end
        end
    end
end

endmodule : bp_be_trace_replay_gen


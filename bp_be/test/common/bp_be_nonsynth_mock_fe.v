/**
 *
 * bp_be_nonsynth_mock_fe.v
 *
 */

`include "bp_common_fe_be_if.vh"

`include "bp_be_rv64_defines.vh"

module bp_be_nonsynth_mock_fe
 /* TODO: Get rid of this */
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"
 
   ,parameter boot_rom_els_p="inv"
   ,parameter boot_rom_width_p="inv"

   ,localparam lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)
   ,localparam boot_rom_bytes_lp=boot_rom_els_p*boot_rom_width_p/rv64_byte_width_gp
   ,localparam lg_boot_rom_bytes_lp=`BSG_SAFE_CLOG2(boot_rom_bytes_lp)
   
   ,localparam bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p     			
                        							   ,branch_metadata_fwd_width_p
                                                       )   
   										
   ,localparam bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p    				
                    							   ,paddr_width_p   				
                    							   ,asid_width_p    				
                    							   ,branch_metadata_fwd_width_p
                                                   )
 
   ,localparam instr_width_lp=rv64_instr_width_gp
   ,localparam eaddr_width_lp=rv64_eaddr_width_gp
   ,localparam byte_width_lp=rv64_byte_width_gp
   ,localparam reg_data_width_lp=rv64_reg_data_width_gp
   ,localparam pc_entry_point_lp=bp_pc_entry_point_gp
   )
  (input logic                              clk_i
   ,input logic                             reset_i

   ,input logic [bp_fe_cmd_width_lp-1:0]    fe_cmd_i
   ,input logic                             fe_cmd_v_i
   ,output logic                            fe_cmd_rdy_o

   ,output logic [bp_fe_queue_width_lp-1:0] fe_queue_o
   ,output logic                            fe_queue_v_o
   ,input logic                             fe_queue_rdy_i

   ,output logic [lg_boot_rom_els_lp-1:0]   boot_rom_addr_o
   ,input logic  [boot_rom_width_p-1:0]     boot_rom_data_i
  );
	
`declare_bp_common_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                             ,branch_metadata_fwd_width_p);
    
// Cast input and output ports
bp_fe_cmd_s	  fe_cmd;
bp_fe_queue_s fe_queue;

assign fe_cmd 	  = fe_cmd_i;
assign fe_queue_o = fe_queue;

// Internal signals
logic [eaddr_width_lp-1:0]       pc_n, pc_r;
logic [lg_boot_rom_bytes_lp-1:0] imem_addr;
logic [instr_width_lp-1:0]       imem_data;

logic [byte_width_lp-1:0] mem [0:boot_rom_bytes_lp-1];
logic [lg_boot_rom_els_lp:0] boot_count; 
logic booting;

assign imem_addr = pc_r[0+:lg_boot_rom_bytes_lp];
assign imem_data = {mem[imem_addr+3], mem[imem_addr+2], mem[imem_addr+1], mem[imem_addr]};

always_comb begin : fe_cmd_gen
    fe_cmd_rdy_o 	= fe_cmd_v_i;

    pc_n = pc_r + 'd4;
    if(fe_cmd_v_i & fe_cmd_rdy_o) begin
        case(fe_cmd.opcode)
            e_op_state_reset    : pc_n = pc_entry_point_lp;
            e_op_pc_redirection : pc_n = fe_cmd.operands.pc_redirect_operands.pc;
        endcase
    end
end

always_comb begin : fe_queue_gen
    fe_queue_v_o = ~booting & fe_queue_rdy_i & ~fe_cmd_v_i;

    fe_queue.msg_type 					    = e_fe_fetch;
    fe_queue.msg.fetch.pc 					= pc_r;
    fe_queue.msg.fetch.instr 				= imem_data;
    fe_queue.msg.fetch.branch_metadata_fwd 	= '0;
end

assign booting = (boot_count != boot_rom_els_p);
always_ff @(posedge clk_i) begin
    if(reset_i) begin
        pc_r <= pc_entry_point_lp;
        boot_count <= 'b0;
    end else if(booting) begin
        /* Boot RAM from ROM */
        for(integer i=0;i<boot_rom_width_p/byte_width_lp;i=i+1) begin : rom_load
            mem[boot_rom_width_p/byte_width_lp*boot_count+i] 
                           <= boot_rom_data_i[i*byte_width_lp+:byte_width_lp];
        end

        boot_rom_addr_o    <= boot_count + 'd1;
        boot_count         <= boot_count + 'd1;
    end else if((fe_cmd_v_i & fe_cmd_rdy_o) | (fe_queue_v_o & fe_queue_rdy_i)) begin
        pc_r <= pc_n;
    end
end

endmodule


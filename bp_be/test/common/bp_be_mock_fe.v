/**
 *
 * bp_be_mock_fe.v
 *
 */

module bp_be_mock_fe
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
 
   , parameter boot_rom_els_p        = "inv"
   , parameter boot_rom_width_p      = "inv"

   , localparam lg_boot_rom_els_lp   = `BSG_SAFE_CLOG2(boot_rom_els_p)
   , localparam boot_rom_bytes_lp    = boot_rom_els_p*boot_rom_width_p/rv64_byte_width_gp
   , localparam lg_boot_rom_bytes_lp =`BSG_SAFE_CLOG2(boot_rom_bytes_lp)
   
   , localparam bp_fe_queue_width_lp = `bp_fe_queue_width(vaddr_width_p           
                                                          , branch_metadata_fwd_width_p
                                                          )   
                       
   , localparam bp_fe_cmd_width_lp   = `bp_fe_cmd_width(vaddr_width_p            
                                                        , paddr_width_p           
                                                        , asid_width_p            
                                                        , branch_metadata_fwd_width_p
                                                        )
 
   , localparam instr_width_lp     = rv64_instr_width_gp
   , localparam eaddr_width_lp     = rv64_eaddr_width_gp
   , localparam byte_width_lp      = rv64_byte_width_gp
   , localparam reg_data_width_lp  = rv64_reg_data_width_gp
   , localparam pc_entry_point_lp  = bp_pc_entry_point_gp
   )
  (input                               clk_i
   , input                             reset_i

   , input [bp_fe_cmd_width_lp-1:0]    fe_cmd_i
   , input                             fe_cmd_v_i
   , output                            fe_cmd_rdy_o

   , output [bp_fe_queue_width_lp-1:0] fe_queue_o
   , output                            fe_queue_v_o
   , input                             fe_queue_rdy_i

   , output [lg_boot_rom_els_lp-1:0]   boot_rom_addr_o
   , input [boot_rom_width_p-1:0]      boot_rom_data_i
  );
  
`declare_bp_fe_be_if(vaddr_width_p
                                    , paddr_width_p
                                    , asid_width_p
                                    , branch_metadata_fwd_width_p
                                    );
    
// Cast input and output ports
bp_fe_cmd_s    fe_cmd;
bp_fe_queue_s fe_queue;

assign fe_cmd     = fe_cmd_i;
assign fe_queue_o = fe_queue;

// Internal signals
logic [eaddr_width_lp-1:0]       pc_n, pc_r;
logic [lg_boot_rom_bytes_lp-1:0] imem_addr;
logic [instr_width_lp-1:0]       imem_data;

logic [byte_width_lp-1:0] mem [0:boot_rom_bytes_lp-1];
logic [lg_boot_rom_els_lp:0] boot_count; 
logic [lg_boot_rom_els_lp-1:0] boot_rom_addr_r;
logic booting;

assign boot_rom_addr_o = boot_rom_addr_r;
assign imem_addr = pc_r[0+:lg_boot_rom_bytes_lp]; // Truncate imem_addr to the size of the scratchpad
assign imem_data = {mem[imem_addr+3], mem[imem_addr+2], mem[imem_addr+1], mem[imem_addr]};

assign fe_cmd_rdy_o   = fe_cmd_v_i;
always_comb 
  begin : fe_cmd_gen
    pc_n = pc_r + 'd4;
    if(fe_cmd_v_i & fe_cmd_rdy_o) 
      case(fe_cmd.opcode)
        e_op_state_reset    : pc_n = pc_entry_point_lp;
        e_op_pc_redirection : pc_n = fe_cmd.operands.pc_redirect_operands.pc;
      endcase
  end

assign fe_queue_v_o = ~booting & fe_queue_rdy_i & ~fe_cmd_v_i;
always_comb 
  begin : fe_queue_gen
    fe_queue.msg_type                       = e_fe_fetch;
    fe_queue.msg.fetch.pc                   = pc_r;
    fe_queue.msg.fetch.instr                = imem_data;
    fe_queue.msg.fetch.branch_metadata_fwd  = '0;
  end

assign booting = (boot_count != boot_rom_els_p);
always_ff @(posedge clk_i) 
  begin
    if(reset_i) 
      begin
        pc_r <= pc_entry_point_lp;
        boot_count <= 'b0;
      end 
    else 
      if(booting) 
        begin
          /* Boot RAM from ROM */
          integer current_byte;
          for(integer i = 0; i < boot_rom_width_p/byte_width_lp; i++) 
            begin : rom_load
              current_byte = boot_rom_width_p / byte_width_lp * boot_count + i;
              mem[current_byte] <= boot_rom_data_i[i*byte_width_lp+:byte_width_lp];
            end
          boot_rom_addr_r    <= boot_count + 'd1;
          boot_count         <= boot_count + 'd1;
        end
      else 
        begin
          if(fe_cmd_v_i | fe_queue_rdy_i) 
            pc_r <= pc_n;
        end
  end

endmodule


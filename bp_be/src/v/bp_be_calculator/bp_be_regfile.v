/**
 *
 * Name:
 *   bp_be_regfile.v
 * 
 * Description:
 *   Synchronous register file wrapper for integer and floating point RISC-V registers. Inlcudes
 *     logic to maintain the source register values during pipeline stalls.
 *
 * Parameters:
 *   w_to_r_fwd_p     - Whether write to read forwarding is enabled. Without, reads in the same 
 *                        cycle as writes will get old register value.
 *
 * Inputs:
 *   clk_i            -
 *   reset_i          -
 *
 *   issue_v_i        - A new instruction is being issued this cycle. Regfile should start new 
 *                        synchronous read
 *   dispatch_v_i     - A new instruction is being dispatched this cycle. Regfile is no longer 
 *                        responsible for holding the value of the last issued instruction
 *   
 *   rd_w_v_i          - 
 *   rd_addr_i         - Committing destination register address
 *   rd_data_i         - Committing destination register data
 *
 *   rs1_r_v_i         -
 *   rs1_addr_i        - Issued source register address
 *
 *   rs2_r_v_i         -
 *   rs2_addr_i        - Issued source register address
 *
 * Outputs:
 *   rs1_data_o        - Source register data from synchronous read
 *   rs2_data_o        - Source register data from synchronous read
 *   
 * Keywords:
 *   calculator, register, regfile
 *
 * Notes:
 *   - Is it okay to continuously read on stalls? There's no switching, so energy may not 
 *       be an issue.  An alternative would be to save the read data, but that's more flops / power
 *   - Should we read the regfile at all for x0? The memory will be a power of 2 size, so it comes 
 *       down to if writing / reading x0 and then muxing is less power than checking x == 0 on input.
 */

module bp_be_regfile 
 import bp_be_rv64_pkg::*;
 #(// Default parameters
   parameter w_to_r_fwd_p = 0
   
   // Generated parameters
   // From RISC-V specifications
   , localparam rf_els_lp         = rv64_rf_els_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                            clk_i
   , input                          reset_i

   // Pipeline control signals
   , input                          issue_v_i
   , input                          dispatch_v_i

   // rd write bus
   , input                          rd_w_v_i
   , input [reg_addr_width_lp-1:0]  rd_addr_i
   , input [reg_data_width_lp-1:0]  rd_data_i

   // rs1 read bus
   , input                          rs1_r_v_i
   , input  [reg_addr_width_lp-1:0] rs1_addr_i
   , output [reg_data_width_lp-1:0] rs1_data_o
   
   // rs2 read bus
   , input                          rs2_r_v_i
   , input  [reg_addr_width_lp-1:0] rs2_addr_i
   , output [reg_data_width_lp-1:0] rs2_data_o
   );

initial 
  begin : parameter_validation
    assert (w_to_r_fwd_p == 0)
      else $error("Write to read forwarding is not yet supported.");
  end

// Intermediate connections
logic                         rs1_read_v     , rs2_read_v;
logic                         rs1_issue_v    , rs2_issue_v;
logic [reg_data_width_lp-1:0] rs1_reg_data   , rs2_reg_data;
logic [reg_addr_width_lp-1:0] rs1_addr_r     , rs2_addr_r;
logic [reg_addr_width_lp-1:0] rs1_reread_addr, rs2_reread_addr;

// Datapath
/*
bsg_mem_2r1w_sync 
 #(.width_p(reg_data_width_lp)
   ,.els_p(rf_els_lp)
   ,.read_write_same_addr_p(1) // We can't actually read/write the same address, but this should 
                               //   be taken care of by forwarding and otherwise the assertion is
                               //   annoying
   )
 rf
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.w_v_i(rd_w_v_i)
   ,.w_addr_i(rd_addr_i)
   ,.w_data_i(rd_data_i)

   ,.r0_v_i(rs1_read_v)
   ,.r0_addr_i(rs1_reread_addr)
   ,.r0_data_o(rs1_reg_data)

   ,.r1_v_i(rs2_read_v)
   ,.r1_addr_i(rs2_reread_addr)
   ,.r1_data_o(rs2_reg_data)
   );

*/

bsg_mem_1r1w_sync 
 #(.width_p(reg_data_width_lp)
   ,.els_p(rf_els_lp)
   ,.read_write_same_addr_p(1) // We can't actually read/write the same address, but this should 
                               //   be taken care of by forwarding and otherwise the assertion is
                               //   annoying
   )
 rf1
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.w_v_i(rd_w_v_i)
   ,.w_addr_i(rd_addr_i)
   ,.w_data_i(rd_data_i)

   ,.r_v_i(rs1_read_v)
   ,.r_addr_i(rs1_reread_addr)
   ,.r_data_o(rs1_reg_data)
   );


bsg_mem_1r1w_sync 
 #(.width_p(reg_data_width_lp)
   ,.els_p(rf_els_lp)
   ,.read_write_same_addr_p(1) // We can't actually read/write the same address, but this should 
                               //   be taken care of by forwarding and otherwise the assertion is
                               //   annoying
   )
 rf2
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.w_v_i(rd_w_v_i)
   ,.w_addr_i(rd_addr_i)
   ,.w_data_i(rd_data_i)

   ,.r_v_i(rs2_read_v)
   ,.r_addr_i(rs2_reread_addr)
   ,.r_data_o(rs2_reg_data)
   );


// Save the last issued register addresses
bsg_dff_en 
 #(.width_p(reg_addr_width_lp)
   )
 rs1_addr
  (.clk_i(clk_i)
   ,.en_i(rs1_issue_v)
   ,.data_i(rs1_addr_i)
   ,.data_o(rs1_addr_r)
   );

bsg_dff_en 
 #(.width_p(reg_addr_width_lp)
   )
 rs2_addr
  (.clk_i(clk_i)
   ,.en_i(rs2_issue_v)
   ,.data_i(rs2_addr_i)
   ,.data_o(rs2_addr_r)
   );

always_comb 
  begin
    // Instruction has been issued, don't bother reading if the register data is not used
    rs1_issue_v = (issue_v_i & rs1_r_v_i);
    rs2_issue_v = (issue_v_i & rs2_r_v_i);
  
    // We need to read from the regfile if we have issued a new request, or if we have stalled
    rs1_read_v = rs1_issue_v | ~dispatch_v_i;
    rs2_read_v = rs2_issue_v | ~dispatch_v_i;
  
    // If we have issued a new instruction, use input address to read, 
    //   else use last request address to read
    rs1_reread_addr = rs1_issue_v ? rs1_addr_i : rs1_addr_r;
    rs2_reread_addr = rs2_issue_v ? rs2_addr_i : rs2_addr_r;
  
end

// RISC-V defines x0 as 0. Else, pass out the register data
assign rs1_data_o = (rs1_addr_r == '0) ? '0 : rs1_reg_data;
assign rs2_data_o = (rs2_addr_r == '0) ? '0 : rs2_reg_data;

endmodule : bp_be_regfile


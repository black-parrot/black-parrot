/**
 *
 * Name:
 *   bp_be_regfile.v
 * 
 * Description:
 *   Synchronous register file wrapper for integer and floating point RISC-V registers. Inlcudes
 *     logic to maintain the source register values during pipeline stalls.
 *
 * Notes:
 *   - Is it okay to continuously read on stalls? There's no switching, so energy may not 
 *       be an issue.  An alternative would be to save the read data, but that's more flops / power
 *   - Should we read the regfile at all for x0? The memory will be a power of 2 size, so it comes 
 *       down to if writing / reading x0 and then muxing is less power than checking x == 0 on input.
 */

module bp_be_regfile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)
   )
  (input                           clk_i
   , input                         reset_i

   // Pipeline control signals
   , input                         issue_v_i
   , input                         dispatch_v_i

   // rd write bus
   , input                         rd_w_v_i
   , input [reg_addr_width_p-1:0]  rd_addr_i
   , input [dword_width_p-1:0]     rd_data_i

   // rs1 read bus
   , input                         rs1_r_v_i
   , input  [reg_addr_width_p-1:0] rs1_addr_i
   , output [dword_width_p-1:0]    rs1_data_o
   
   // rs2 read bus
   , input                         rs2_r_v_i
   , input  [reg_addr_width_p-1:0] rs2_addr_i
   , output [dword_width_p-1:0]    rs2_data_o
   );

// Intermediate connections
logic                        rs1_read_v     , rs2_read_v;
logic                        rs1_issue_v    , rs2_issue_v;
logic [dword_width_p-1:0]    rs1_reg_data   , rs2_reg_data;
logic [reg_addr_width_p-1:0] rs1_addr_r     , rs2_addr_r,      rd_addr_r;
logic [reg_addr_width_p-1:0] rs1_reread_addr, rs2_reread_addr;
logic [dword_width_p-1:0]    rd_data_r;

localparam rf_els_lp = 2**reg_addr_width_p;
bsg_mem_2r1w_sync 
 #(.width_p(dword_width_p), .els_p(rf_els_lp))
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

// Save the last issued register addresses
bsg_dff_reset_en 
 #(.width_p(2*reg_addr_width_p))
 rs1_addr
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.en_i(rs1_issue_v | rs2_issue_v)

   ,.data_i({rs1_addr_i, rs2_addr_i})
   ,.data_o({rs1_addr_r, rs2_addr_r})
   );

logic zero_rs1_r, zero_rs2_r, fwd_rs1_r, fwd_rs2_r;
wire fwd_rs1  = rd_w_v_i & (rd_addr_i == rs1_reread_addr);
wire fwd_rs2  = rd_w_v_i & (rd_addr_i == rs2_reread_addr);
wire zero_rs1 = (rs1_reread_addr == '0);
wire zero_rs2 = (rs2_reread_addr == '0);
bsg_dff
 #(.width_p(4+dword_width_p))
 rw_fwd_reg
  (.clk_i(clk_i)
   ,.data_i({zero_rs1, zero_rs2, fwd_rs1, fwd_rs2, rd_data_i})
   ,.data_o({zero_rs1_r, zero_rs2_r, fwd_rs1_r, fwd_rs2_r, rd_data_r})
   );

always_comb 
  begin
    // Instruction has been issued, don't bother reading if the register data is not used
    rs1_issue_v = (issue_v_i & rs1_r_v_i);
    rs2_issue_v = (issue_v_i & rs2_r_v_i);
  
    // We need to read from the regfile if we have issued a new request, or if we have stalled
    rs1_read_v = (rs1_issue_v | ~dispatch_v_i) & ~fwd_rs1;
    rs2_read_v = (rs2_issue_v | ~dispatch_v_i) & ~fwd_rs2;
  
    // If we have issued a new instruction, use input address to read, 
    //   else use last request address to read
    rs1_reread_addr = rs1_issue_v ? rs1_addr_i : rs1_addr_r;
    rs2_reread_addr = rs2_issue_v ? rs2_addr_i : rs2_addr_r;
end

// RISC-V defines x0 as 0. Else, forward if we read/wrote, else pass out the register data
assign rs1_data_o = zero_rs1_r ? '0 : fwd_rs1_r ? rd_data_r : rs1_reg_data;
assign rs2_data_o = zero_rs2_r ? '0 : fwd_rs2_r ? rd_data_r : rs2_reg_data;

endmodule 


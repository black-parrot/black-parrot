
module bp_be_trace_replay_gen
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter vaddr_width_p="inv"
   , parameter paddr_width_p="inv"
   , parameter asid_width_p="inv"
   , parameter branch_metadata_fwd_width_p="inv"   
   , parameter trace_ring_width_p="inv"

   , localparam fu_op_width_lp=`bp_be_fu_op_width

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   , localparam reg_addr_width_lp = rv64_reg_addr_width_gp
   , localparam eaddr_width_lp    = rv64_eaddr_width_gp
   )
  (input logic                              clk_i
   , input logic                            reset_i

   , input                                  cmt_rd_w_v_i
   , input [reg_addr_width_lp-1:0]          cmt_rd_addr_i
   , input                                  cmt_mem_w_v_i
   , input [fu_op_width_lp-1:0]             cmt_mem_op_i
   , input [eaddr_width_lp-1:0]             cmt_mem_addr_i
   , input [reg_data_width_lp-1:0]          cmt_data_i

   , output logic [trace_ring_width_p-1:0]  data_o
   , output logic                           v_o
   , input logic                            ready_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

logic [reg_data_width_lp-1:0] mem_data;

wire unused0 = clk_i;
wire unused1 = reset_i;
wire unused2 = ready_i;

always_comb 
  begin
    // get size of the memory operation
    case (cmt_mem_op_i)
      // byte
      e_sb: 
          mem_data = rv64_reg_data_width_gp'(cmt_data_i[7:0]);
      // halfword
      e_sh: 
          mem_data = rv64_reg_data_width_gp'(cmt_data_i[15:0]);
      // word
      e_sw:
          mem_data = rv64_reg_data_width_gp'(cmt_data_i[31:0]);
      // doubleword
      e_sd: 
          mem_data = cmt_data_i;
      default: 
          mem_data = '0;
    endcase
  end

logic [reg_data_width_lp-1:0] data_payload;
logic [eaddr_width_lp-1:0]    addr_payload;

assign data_payload = cmt_mem_w_v_i ? mem_data : cmt_data_i;
assign addr_payload = cmt_mem_w_v_i ? cmt_mem_addr_i : eaddr_width_lp'(cmt_rd_addr_i);
assign data_o       = {cmt_mem_w_v_i, addr_payload, data_payload};
assign v_o          = cmt_mem_w_v_i | (cmt_rd_w_v_i & cmt_rd_addr_i != '0);

endmodule : bp_be_trace_replay_gen


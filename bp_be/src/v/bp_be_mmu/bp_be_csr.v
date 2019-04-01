module bp_be_csr
  import bp_be_rv64_pkg::*;
  import bp_be_pkg::*;
  #(localparam fu_op_width_lp = `bp_be_fu_op_width

    , localparam reg_data_width_lp = rv64_reg_data_width_gp
    , localparam csr_addr_width_lp = 12
    )
   (input                            clk_i
    , input                          reset_i

    , input [fu_op_width_lp-1:0]     csr_op_i

    , input [csr_addr_width_lp-1:0]  csr_addr_i

    , input  [reg_data_width_lp-1:0] csr_data_i
    , output [reg_data_width_lp-1:0] csr_data_o

    , output                         illegal_csr_o
    );

always_comb 
  begin
    
  end

endmodule : bp_be_csr


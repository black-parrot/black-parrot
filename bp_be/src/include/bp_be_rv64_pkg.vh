
package bp_be_rv64_pkg;

  `include "bp_be_rv64_defines.vh"

  localparam rv64_rf_els_gp         = 32;
  localparam rv64_instr_width_gp    = 32;
  localparam rv64_eaddr_width_gp    = 64;
  localparam rv64_byte_width_gp     = 8;
  localparam rv64_hword_width_gp    = 16;
  localparam rv64_word_width_gp     = 32;
  localparam rv64_dword_width_gp    = 64;
  localparam rv64_reg_data_width_gp = 64;
  localparam rv64_reg_addr_width_gp = 5;
  localparam rv64_shamt_width_gp    = 6;
  localparam rv64_shamtw_width_gp   = 5;
  localparam rv64_opcode_width_gp   = 7;
  localparam rv64_funct3_width_gp   = 3;
  localparam rv64_funct7_width_gp   = 7;

  typedef struct packed                                                                           
  {                                                                                               
    logic[rv64_funct7_width_gp-1:0]   funct7;                                                     
    logic[rv64_reg_addr_width_gp-1:0] rs2_addr;                                                    
    logic[rv64_reg_addr_width_gp-1:0] rs1_addr;                                                    
    logic[rv64_funct3_width_gp-1:0]   funct3;                                                      
    logic[rv64_reg_addr_width_gp-1:0] rd_addr;                                                     
    logic[rv64_opcode_width_gp-1:0]   opcode;                                                      
  }  bp_be_instr_s;

  `define bp_be_instr_width                                                                        \
    (rv64_funct7_width_gp                                                                          \
     + rv64_reg_addr_width_gp                                                                      \
     + rv64_reg_addr_width_gp                                                                      \
     + rv64_funct3_width_gp                                                                        \
     + rv64_reg_addr_width_gp                                                                      \
     + rv64_opcode_width_gp                                                                        \
     )                                                                                             \

endpackage : bp_be_rv64_pkg


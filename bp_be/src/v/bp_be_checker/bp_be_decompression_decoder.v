`define C_LWSP     5'b01010
`define C_LDSP     5'b01110
`define C_LQSP     5'b00110
`define C_FLWSP    5'b01110
`define C_FLDSP    5'b00110 

`define C_SWSP     5'b11010
`define C_SDSP     5'b11110
`define C_SQSP     5'b10110
`define C_FSWSP    5'b11110
`define C_FSDSP    5'b10110

`define C_LW       5'b01000
`define C_LD       5'b01100
`define C_LQ       5'b00100
`define C_FLW      5'b01100
`define C_FLD      5'b00100 

`define C_SW       5'b11000
`define C_SD       5'b11100
`define C_SQ       5'b10100
`define C_FSW      5'b11100
`define C_FSD      5'b10100

`define C_J        5'b10101
`define C_JAL      5'b00101

`define C_JR       5'b10010
`define C_JALR     5'b10010

`define C_BEQZ     5'b11001
`define C_BNEZ     5'b11101
`define C_LI       5'b01001
`define C_LUI      5'b01101
`define C_ADDI     5'b00001
`define C_ADDIW    5'b00101
`define C_ADDI16SP 5'b01101

`define C_ADDI4SPN 5'b00000

`define C_SLLI     5'b00010
`define C_SLLI64   5'b00010

`define C_SRLI     5'b10001
`define C_SRAI     5'b10001

`define C_ANDI     5'b10001

`define C_MV       5'b10010
`define C_ADD      5'b10010

`define C_EBREAK   5'b10010

`define C_AND      5'b10001
`define C_OR       5'b10001
`define C_XOR      5'b10001
`define C_SUB      5'b10001
`define C_ADDW     5'b10001
`define C_SUBW     5'b10001

`define C_NOP      5'b00001
`define C_ILLEGAL  5'b00000

// register name
`define x0         5'd0
`define x1         5'd1
`define x2         5'd2
`define x3         5'd3
`define x4         5'd4
`define x5         5'd5
`define x6         5'd6
`define x7         5'd7
`define x8         5'd8
`define x9         5'd9
`define x10        5'd10
`define x11        5'd11
`define x12        5'd12
`define x13        5'd13
`define x14        5'd14
`define x15        5'd15
`define x16        5'd16
`define x17        5'd17
`define x18        5'd18
`define x19        5'd19
`define x20        5'd20
`define x21        5'd21
`define x22        5'd22
`define x23        5'd23
`define x24        5'd24
`define x25        5'd25
`define x26        5'd26
`define x27        5'd27
`define x28        5'd28
`define x29        5'd29
`define x30        5'd30
`define x31        5'd31

//rvc format
`define funct4_width_p    4
`define funct3_width_p    3
`define rd_rs1_width_p    5
`define rs2_width_p       5
`define op_width_p        2
`define ci_imm2_width_p   5
`define css_imm_width_p   6
`define ciw_imm_width_p   8
`define rd_prime_width_p  3
`define cl_imm1_width_p   3
`define rs1_prime_width_p 3
`define cl_imm2_width_p   2
`define cs_imm1_width_p   3
`define cs_imm2_width_p   2
`define rs2_prime_width_p 3
`define offset1_width_p   3
`define offset2_width_p   5
`define jump_width_p     11
`define instr_width_lp   32


typedef struct packed{
    logic [`funct4_width_p-1:0]     funct4;
    logic [`rd_rs1_width_p-1:0]     rd_rs1;
    logic [`rs2_width_p-1:0]        rs2;
    logic [`op_width_p-1:0]         op;
} format_cr_s;

typedef struct packed{
    logic [`funct3_width_p-1:0]     funct3;
    logic                          imm1;
    logic [`rd_rs1_width_p-1:0]     rd_rs1;
    logic [`ci_imm2_width_p-1:0]    imm2;
    logic [`op_width_p-1:0]         op;
} format_ci_s;

typedef struct packed{
    logic [`funct3_width_p-1:0]     funct3;
    logic [`css_imm_width_p-1:0]    imm;
    logic [`rs2_width_p-1:0]        rs2;
    logic [`op_width_p-1:0]         op;
} format_css_s;

typedef struct packed{
    logic [`funct3_width_p-1:0]     funct3;
    logic [`ciw_imm_width_p-1:0]    imm;
    logic [`rd_prime_width_p-1:0]   rd;
    logic [`op_width_p-1:0]         op;
} format_ciw_s;

typedef struct packed{
    logic [`funct3_width_p-1:0]     funct3;
    logic [`cl_imm1_width_p-1:0]    imm1;
    logic [`rs1_prime_width_p-1:0]  rs1;
    logic [`cl_imm2_width_p-1:0]    imm2;
    logic [`rd_prime_width_p-1:0]   rd;
    logic [`op_width_p-1:0]         op;
} format_cl_s;

typedef struct packed{
    logic [`funct3_width_p-1:0]     funct3;
    logic [`cs_imm1_width_p-1:0]    imm1;
    logic [`rs1_prime_width_p-1:0]  rs1;
    logic [`cs_imm2_width_p-1:0]    imm2;
    logic [`rs2_prime_width_p-1:0]  rs2;
    logic [`op_width_p-1:0]         op;
} format_cs_s;

typedef struct packed{
    logic [`funct3_width_p-1:0]     funct3;
    logic [`offset1_width_p-1:0]    offset1;
    logic [`rs1_prime_width_p-1:0]  rs1;
    logic [`offset2_width_p-1:0]    offset2;
    logic [`op_width_p-1:0]         op;
} format_cb_s;

typedef struct packed{
    logic [`funct3_width_p-1:0]     funct3;
    logic [`jump_width_p-1:0]       jump_target;
    logic [`op_width_p-1:0]         op;
} format_cj_s;

// rvi format
`define funct7_width_p 7
`define rs1_width_p    5
`define funct3_width_p 3
`define rd_width_p     5
`define i_imm_width_p  12
`define s_imm1_width_p 7
`define s_imm2_width_p 5
`define op_ris_width_p 7
`define j_imm2_width_p 10
`define j_imm4_width_p 8
`define b_imm2_width_p 6
`define b_imm3_width_p 4
`define u_imm_width_p  20

typedef struct packed{
    logic [`funct7_width_p-1:0]     funct7;
    logic [`rs2_width_p-1:0]        rs2;
    logic [`rs1_width_p-1:0]        rs1;
    logic [`funct3_width_p-1:0]     funct3;
    logic [`rd_width_p-1:0]         rd;
    logic [`op_ris_width_p-1:0]     op;
} format_r_s;

typedef struct packed{
    logic [`i_imm_width_p-1:0]      imm;
    logic [`rs1_width_p-1:0]        rs1;
    logic [`funct3_width_p-1:0]     funct3;
    logic [`rd_width_p-1:0]         rd;
    logic [`op_ris_width_p-1:0]     op;
} format_i_s;

typedef struct packed{
    logic [`s_imm1_width_p-1:0]     imm1;
    logic [`rs2_width_p-1:0]        rs2;
    logic [`rs1_width_p-1:0]        rs1;
    logic [`funct3_width_p-1:0]     funct3;
    logic [`s_imm2_width_p-1:0]     imm2;
    logic [`op_ris_width_p-1:0]     op;
} format_s_s;

typedef struct packed{
    logic                           imm1;
    logic [`j_imm2_width_p-1:0]     imm2;
    logic                           imm3;
    logic [`j_imm4_width_p-1:0]     imm4;
    logic [`rd_width_p-1:0]         rd;
    logic [`op_ris_width_p-1:0]     op;
} format_j_s;


typedef struct packed{
    logic                          imm1;
    logic [`b_imm2_width_p-1:0]     imm2;
    logic [`rs2_width_p-1:0]        rs2;
    logic [`rs1_width_p-1:0]        rs1;
    logic [`funct3_width_p-1:0]     funct3;
    logic [`b_imm3_width_p-1:0]     imm3;
    logic                          imm4;
    logic [`op_ris_width_p-1:0]     op;
} format_b_s;

typedef struct packed{
    logic [`u_imm_width_p-1:0]      imm;
    logic [`rd_width_p-1:0]         rd;
    logic [`op_ris_width_p-1:0]     op;
} format_u_s;



///////////////////////////////////////////////////////////////////////////////////////////////////////
module expander (
    input logic clk_i
    ,input logic reset_i
    
    ,input  logic [31:0]        inst_inp
    ,output logic [31:0]        inst_out
   
);
   


logic [32:0]                                                instr_c;
logic [31:0]                                                instr_d;
logic [31:0]                                                instr_d_jal;
logic [31:0]                                                instr_d_j;
   
logic [2:0]                                                 s1_compressed_reg;
logic [4:0]                                                 s1_decompressed_reg;
logic [2:0]                                                 d_compressed_reg;
logic [4:0]                                                 d_decompressed_reg;
logic [2:0]                                                 s2_compressed_reg;
logic [4:0]                                                 s2_decompressed_reg;
   
format_cr_s                                                 format_cr;
format_ci_s                                                 format_ci;
format_css_s                                                format_css;
format_ciw_s                                                format_ciw;
format_cl_s                                                 format_cl;
format_cs_s                                                 format_cs;
format_cb_s                                                 format_cb;
format_cj_s                                                 format_cj;

format_r_s                                                  format_r;
format_i_s                                                  format_i;
format_s_s                                                  format_s;
format_j_s                                                  format_j;
format_b_s                                                  format_b;
format_u_s                                                  format_u;

assign instr_c = inst_inp;  
   
always_comb begin  
 // reformatting compressed instruction
    casez ({instr_c[15:13],instr_c[1:0]})
         `C_LWSP,`C_LDSP,`C_LQSP,`C_FLWSP,`C_FLDSP: 
                  begin
                      format_ci          = instr_c;
                      instr_d            = format_i;
                  end
         `C_SWSP,`C_SDSP,`C_SQSP,`C_FSWSP,`C_FSDSP: 
                  begin
                      format_css         = instr_c;
                      instr_d            = format_s;
                  end
         `C_LW,`C_LD,`C_LQ,`C_FLW,`C_FLD:
                  begin
                      format_cl          = instr_c;
                      instr_d            = format_i;
                  end 
         `C_SW,`C_SD,`C_SQ,`C_FSW,`C_FSD:
                  begin
                      format_cs          = instr_c;
                      instr_d            = format_s;
                  end 
         `C_J:
                  begin
                      format_cj          = instr_c;
                      instr_d_j          = format_j;
                      instr_d            = format_j;
             
                  end
         `C_JAL:
                  begin
                      format_cj          = instr_c;
                      instr_d_jal        = format_j;
                      instr_d            = format_j;
                  end 
         `C_JR,`C_JALR,`C_MV,`C_ADD :
                  begin
                     if      (instr_c[12] == 1'b0 && instr_c[11:7] != 5'd0 && instr_c[6:2] == 5'd0) //JR
                       begin
                          format_cr         = instr_c;
                          instr_d           = format_i;
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:7] != 5'd0 && instr_c[6:2] != 5'd0) //MV
                       begin
                          format_cr          = instr_c;
                          instr_d            = format_r;
                       end
                     else if (instr_c[12] == 1'b1 && instr_c[11:7] != 5'd0 && instr_c[6:2] == 5'd0) //JALR
                       begin
                          format_cr          = instr_c;
                          instr_d            = format_i;
                       end
                     else if (instr_c[12] == 1'b1 && instr_c[11:7] != 5'd0 && instr_c[6:2] == 5'd0) //ADD
                       begin
                          format_cr          = instr_c;
                          instr_d            = format_r;
                       end
                  end
         `C_BEQZ,`C_BNEZ:
                  begin
                      format_cb          = instr_c;
                      instr_d            = format_b;
                  end
         `C_LI:
                  begin
                      format_ci          = instr_c;
                      instr_d            = format_i;
                  end
         `C_LUI:
                  begin
                      format_ci          = instr_c;
                      instr_d            = format_u;
                  end
         `C_ADDI,`C_ADDIW,`C_ADDI16SP:
                  begin
                      format_ci          = instr_c;
                      instr_d            = format_i;
                  end
         `C_ADDI4SPN:
                  begin
                      format_ciw         = instr_c;
                      instr_d            = format_i;
                  end
         `C_SLLI:
                  begin
                      format_ci         = instr_c;
                      instr_d           = format_i;
                  end
         `C_SRLI,`C_SRAI,`C_ANDI,`C_AND,`C_OR,`C_XOR,`C_SUB,`C_ADDW,`C_SUBW:
                  begin
                     if      (instr_c[12] != 1'b0 && instr_c[11:10] == 2'b00 && instr_c[6:2] != 5'd0) //SRLI
                       begin
                          format_cb          = instr_c;
                          instr_d            = format_i;
                       end
                     else if (instr_c[12] != 1'b0 && instr_c[11:10] == 2'b01 && instr_c[6:2] != 5'd0) //SRAI
                       begin
                          format_cb          = instr_c;
                          instr_d            = format_i;
                       end
                     else if (instr_c[11:10] == 2'b10) //ANDI
                       begin
                          format_cb          = instr_c;
                          instr_d            = format_i;
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b00) //SUB
                       begin
                          format_cs          = instr_c; 
                          instr_d            = format_r;
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b01) //XOR
                       begin
                          format_cs          = instr_c; 
                          instr_d            = format_r;
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b10) //OR
                       begin
                          format_cs          = instr_c; 
                          instr_d            = format_r;
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b11) //AND
                       begin
                          format_cs          = instr_c; 
                          instr_d            = format_r;
                       end
                     else if (instr_c[12] == 1'b1 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b00) //SUBW
                       begin
                          format_cs          = instr_c; 
                          instr_d            = format_r;
                       end
                     else if (instr_c[12] == 1'b1 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b01) //ADDW
                       begin
                          format_cs          = instr_c; 
                          instr_d            = format_r;
                       end
                  end
         `C_NOP: 
                  begin
                      format_ci          = instr_c; 
                      instr_d            = format_i;
                  end
         default: begin
            instr_d = {2{instr_c}} ;
            
         end
    endcase
end // always_comb begin
   
always_comb begin
    case ({instr_c[15:13],instr_c[1:0]})
         `C_LWSP: begin 
                      format_i.imm[7:6]  = format_ci.imm2[1:0];
                      format_i.imm[4:2]  = format_ci.imm2[4:2];
                      format_i.imm[5]    = format_ci.imm1;
                      format_i.imm[1:0]  = 2'b00;
                      format_i.imm[11:8] = 4'h0;
                      format_i.rs1       = `x2;
                      format_i.funct3    = 3'b010;
                      format_i.rd        = format_ci.rd_rs1;
                      format_i.op        = 7'b0000011;
         end // case: `C_LWSP
         `C_LDSP: begin 
                      format_i.imm[8:6]  = format_ci.imm2[2:0];
                      format_i.imm[4:3]  = format_ci.imm2[4:3];
                      format_i.imm[5]    = format_ci.imm1;
                      format_i.imm[2:0]  = 3'b000;
                      format_i.imm[11:9] = 3'b000;
                      format_i.rs1       = `x2;
                      format_i.funct3    = 3'b011;
                      format_i.rd        = format_ci.rd_rs1;
                      format_i.op        = 7'b0000011;
         end // case: `C_LDSP
         `C_FLWSP: begin
                      format_i.imm[7:6]  = format_ci.imm2[3:2];
                      format_i.imm[4:2]  = format_ci.imm2[6:4];
                      format_i.imm[5]    = format_ci.imm1;
                      format_i.imm[2:0]  = 2'b00;
                      format_i.imm[11:8] = 4'b0000;
                      format_i.rs1       = `x2;
                      format_i.funct3    = 3'b010;
                      format_i.rd        = format_ci.rd_rs1;
                      format_i.op        = 7'b0000111;
         end // case: `C_FLWSP
         `C_FLDSP: begin
                      format_i.imm[8:6]  = format_ci.imm2[4:2];
                      format_i.imm[4:3]  = format_ci.imm2[6:5];
                      format_i.imm[5]    = format_ci.imm1;
                      format_i.imm[2:0]  = 3'b000;
                      format_i.imm[11:9] = 3'b000;
                      format_i.rs1       = `x2;
                      format_i.funct3    = 3'b011;
                      format_i.rd        = format_ci.rd_rs1;
                      format_i.op        = 7'b0000111;
         end // case: `C_FLDSP 
         `C_SWSP: begin
                      format_s.imm1[0]    = format_css.imm[5];
                      format_s.imm1[2:1]  = format_css.imm[1:0];
                      format_s.imm1[6:3]  = 4'b0000;
                      format_s.rs2        = format_css.rs2;
                      format_s.rs1        = `x2;
                      format_s.funct3      = 3'b010; 
                      format_s.imm2[1:0]  = 2'b00;
                      format_s.imm2[4:2]  = format_css.imm[4:2];
                      format_s.op         = 7'b0100011;
         end // case: `C_SWSP
         `C_SDSP: begin
                      format_s.imm1[0]    = format_css.imm[5];
                      format_s.imm1[3:1]  = format_css.imm[2:0];
                      format_s.imm1[6:4]  = 3'b000;
                      format_s.rs2        = format_css.rs2;
                      format_s.rs1        = `x2;
                      format_s.funct3      = 3'b011; 
                      format_s.imm2[1:0]  = 2'b00;
                      format_s.imm2[4:3]  = format_css.imm[4:3];
                      format_s.op         = 7'b0100011;
         end // case: `C_SDSP
         `C_FSWSP: begin
                      format_s.imm1[0]    = format_css.imm[5];
                      format_s.imm1[2:1]  = format_css.imm[1:0];
                      format_s.imm1[6:3]  = 4'b0000;
                      format_s.rs2        = format_css.rs2;
                      format_s.rs1        = `x2;
                      format_s.funct3     = 3'b010; 
                      format_s.imm2[1:0]  = 2'b00;
                      format_s.imm2[4:2]  = format_css.imm[4:2];
                      format_s.op         = 7'b0100111;
         end // case: `C_FSWSP
         `C_FSDSP:  begin
                      format_s.imm1[0]    = format_css.imm[5];
                      format_s.imm1[3:1]  = format_css.imm[2:0];
                      format_s.imm1[6:4]  = 3'b000;
                      format_s.rs2        = format_css.rs2;
                      format_s.rs1        = `x2;
                      format_s.funct3      = 3'b011; 
                      format_s.imm2[1:0]  = 2'b00;
                      format_s.imm2[4:3]  = format_css.imm[4:3];
                      format_s.op         = 7'b0100111;
         end // case: `C_FSDSP
         `C_LW: begin
                      format_i.imm[1:0]  = 2'b00;
                      format_i.imm[2]    = format_cl.imm2[1];
                      format_i.imm[5:3]  = format_cl.imm1;
                      format_i.imm[6]    = format_cl.imm2[0];
                      format_i.imm[11:7] = 5'b00000;
                      s1_compressed_reg  = format_cl.rs1;
                      format_i.rs1       = s1_decompressed_reg;
                      format_i.funct3    = 3'b010;
                      d_compressed_reg   = format_cl.rd;
                      format_i.rd        = d_decompressed_reg;
                      format_i.op        = 7'b0000011;
         end // case: `C_LW
         `C_LD: begin
                      format_i.imm[2:0]  = 3'b000;
                      format_i.imm[7]    = format_cl.imm2[1];
                      format_i.imm[5:3]  = format_cl.imm1;
                      format_i.imm[6]    = format_cl.imm2[0];
                      format_i.imm[11:8] = 4'h0;
                      s1_compressed_reg  = format_cl.rs1;
                      format_i.rs1       = s1_decompressed_reg;
                      format_i.funct3    = 3'b011;
                      d_compressed_reg   = format_cl.rd;
                      format_i.rd        = d_decompressed_reg;
                      format_i.op        = 7'b0000011;
         end // case: `C_LD
         `C_FLW: begin
                      format_i.imm[1:0]  = 2'b00;
                      format_i.imm[2]    = format_cl.imm2[1];
                      format_i.imm[5:3]  = format_cl.imm1;
                      format_i.imm[6]    = format_cl.imm2[0];
                      format_i.imm[11:7] = 5'b00000;
                      s1_compressed_reg  = format_cl.rs1;
                      format_i.rs1       = s1_decompressed_reg;
                      format_i.funct3    = 3'b010;
                      d_compressed_reg   = format_cl.rd;
                      format_i.rd        = d_decompressed_reg;
                      format_i.op        = 7'b0000111;
         end // case: `C_FLW
         `C_FLD: begin
                      format_i.imm[2:0]  = 3'b000;
                      format_i.imm[7]    = format_cl.imm2[1];
                      format_i.imm[5:3]  = format_cl.imm1;
                      format_i.imm[6]    = format_cl.imm2[0];
                      format_i.imm[11:8] = 4'h0;
                      s1_compressed_reg  = format_cl.rs1;
                      format_i.rs1       = s1_decompressed_reg;
                      format_i.funct3    = 3'b011;
                      d_compressed_reg   = format_cl.rd;
                      format_i.rd        = d_decompressed_reg;
                      format_i.op        = 7'b0000111;
         end // case: `C_FLD
         `C_SW: begin
                      format_s.imm1[1]    = format_cs.imm2[0];
                      format_s.imm1[0]    = format_cs.imm1[2];
                      format_s.imm1[6:2]  = 5'b00000;
                      format_s.imm2[2]    = format_cs.imm2[1];
                      format_s.imm2[4:3]  = format_cs.imm1[1:0];
                      format_s.imm2[1:0]  = 2'b00;
                      s1_compressed_reg   = format_cs.rs1;
                      format_s.rs1        = s1_decompressed_reg;
                      s2_compressed_reg   = format_cs.rs2;
                      format_s.rs2        = s2_decompressed_reg;
                      format_s.funct3     = 3'b010; 
                      format_s.op         = 7'b0100011;
         end // case: `C_SW
         `C_SD: begin
                      format_s.imm1[2:1]  = format_cs.imm2[1:0];
                      format_s.imm1[0]    = format_cs.imm1[2];
                      format_s.imm1[6:2]  = 5'b00000;
                      format_s.imm2[4:3]  = format_cs.imm1[1:0];
                      format_s.imm2[1:0]  = 2'b00;
                      s1_compressed_reg   = format_cs.rs1;
                      format_s.rs1        = s1_decompressed_reg;
                      s2_compressed_reg   = format_cs.rs2;
                      format_s.rs2        = s2_decompressed_reg;
                      format_s.funct3     = 3'b011; 
                      format_s.op         = 7'b0100011;
         end // case: `C_SD
         `C_FSW: begin
                      format_s.imm1[1]    = format_cs.imm2[0];
                      format_s.imm1[0]    = format_cs.imm1[2];
                      format_s.imm1[6:2]  = 5'b00000;
                      format_s.imm2[2]    = format_cs.imm2[1];
                      format_s.imm2[4:3]  = format_cs.imm1[1:0];
                      format_s.imm2[1:0]  = 2'b00;
                      s1_compressed_reg   = format_cs.rs1;
                      format_s.rs1        = s1_decompressed_reg;
                      s2_compressed_reg   = format_cs.rs2;
                      format_s.rs2        = s2_decompressed_reg;
                      format_s.funct3     = 3'b010; 
                      format_s.op         = 7'b0100111;
         end // case: `C_FSW
         `C_FSD:begin
                      format_s.imm1[2:1]  = format_cs.imm2[1:0];
                      format_s.imm1[0]    = format_cs.imm1[2];
                      format_s.imm1[6:2]  = 5'b00000;
                      format_s.imm2[4:3]  = format_cs.imm1[1:0];
                      format_s.imm2[1:0]  = 2'b00;
                      s1_compressed_reg   = format_cs.rs1;
                      format_s.rs1        = s1_decompressed_reg;
                      s2_compressed_reg   = format_cs.rs2;
                      format_s.rs2        = s2_decompressed_reg;
                      format_s.funct3     = 3'b011; 
                      format_s.op         = 7'b0100111;
         end // case: `C_FSD
         `C_J: begin
                      format_j.imm1       = 1'b0;
                      format_j.imm2[0]    = format_cj.jump_target[6];
                      format_j.imm2[1]    = format_cj.jump_target[10];
                      format_j.imm2[9:2]  = 8'h00;
                      format_j.imm3       = format_cj.jump_target[8];
                      format_j.imm4[2:0]  = format_cj.jump_target[3:1];
                      format_j.imm4[3]    = format_cj.jump_target[9];
                      format_j.imm4[4]    = format_cj.jump_target[0];
                      format_j.imm4[5]    = format_cj.jump_target[5];
                      format_j.imm4[6]    = format_cj.jump_target[4];
                      format_j.imm4[7]    = format_cj.jump_target[7];
                      format_j.rd         = `x0;
                      format_j.op         = 7'b1101111;
         end // case: `C_J
         `C_JAL: begin
                      format_j.imm1       = 1'b0;
                      format_j.imm2[0]    = format_cj.jump_target[6];
                      format_j.imm2[1]    = format_cj.jump_target[10];
                      format_j.imm2[9:2]  = 8'h00;
                      format_j.imm3       = format_cj.jump_target[8];
                      format_j.imm4[2:0]  = format_cj.jump_target[3:1];
                      format_j.imm4[3]    = format_cj.jump_target[9];
                      format_j.imm4[4]    = format_cj.jump_target[0];
                      format_j.imm4[5]    = format_cj.jump_target[5];
                      format_j.imm4[6]    = format_cj.jump_target[4];
                      format_j.imm4[7]    = format_cj.jump_target[7];
                      format_j.rd         = `x1;
                      format_j.op         = 7'b1101111;
         end // case: `C_JAL
//         `C_JR, `C_JALR: begin

         `C_JR,`C_JALR,`C_MV,`C_ADD : begin
                      if      (instr_c[12] == 1'b0 && instr_c[11:7] != 5'd0 && instr_c[6:2] == 5'd0) //JR
                        begin
                           format_i.imm[11:0]  = 12'h000;
                           format_i.rs1        = format_cr.rd_rs1;
                           format_i.funct3     = 3'b000;
                           format_i.rd         = `x0;
                           format_i.op         = 7'b1100111;
                        end
                      else if (instr_c[12] == 1'b0 && instr_c[11:7] != 5'd0 && instr_c[6:2] != 5'd0) //MV
                        begin
                           format_r.funct7       = 7'd0;
                           format_r.rs2          = format_cr.rs2;
                           format_r.rs1          = `x0;
                           format_r.funct3       = 3'b000;
                           format_r.rd           = format_cr.rd_rs1;          
                           format_r.op           = 7'b0110011;          
                        end
                      else if (instr_c[12] == 1'b1 && instr_c[11:7] != 5'd0 && instr_c[6:2] == 5'd0) //JALR
                        begin
                           format_i.imm[11:0]  = 12'h000;
                           format_i.rs1        = format_cr.rd_rs1;
                           format_i.funct3     = 3'b000;
                           format_i.rd         = `x0;
                           format_i.op         = 7'b1100111;
                        end
                      else if (instr_c[12] == 1'b1 && instr_c[11:7] != 5'd0 && instr_c[6:2] == 5'd0) //ADD
                        begin
                           format_r.funct7       = 7'd0;
                           format_r.rs2          = format_cr.rs2;
                           format_r.rs1          = format_cr.rd_rs1;          
                           format_r.funct3       = 3'b000;
                           format_r.rd           = format_cr.rd_rs1;          
                           format_r.op           = 7'b0110011;          
                        end
         end
         `C_BEQZ: begin
                      format_b.imm1       = 1'b0;
                      format_b.imm2[0]    = format_cb.offset2[0];
                      format_b.imm2[2:1]  = format_cb.offset2[4:3];
                      format_b.imm2[3]    = format_cb.offset1[2];
                      format_b.imm2[5:4]  = 2'b00;
                      format_b.rs2        = `x0;
                      s1_compressed_reg   = format_cb.rs1;
                      format_b.rs1        = s1_decompressed_reg;
                      format_b.funct3     = 3'b000;
                      format_b.imm3[1:0]  = format_cb.offset2[2:1];
                      format_b.imm3[3:2]  = format_cb.offset1[1:0];
                      format_b.imm4       = 1'b0;
                      format_b.op         = 7'b1100011;      
         end // case: `C_BEQZ
         `C_BNEZ: begin
                      format_b.imm1       = 1'b0;
                      format_b.imm2[0]    = format_cb.offset2[0];
                      format_b.imm2[2:1]  = format_cb.offset2[4:3];
                      format_b.imm2[3]    = format_cb.offset1[2];
                      format_b.imm2[5:4]  = 2'b00;
                      format_b.rs2        = `x0;
                      s1_compressed_reg   = format_cb.rs1;
                      format_b.rs1        = s1_decompressed_reg;
                      format_b.funct3     = 3'b001;
                      format_b.imm3[1:0]  = format_cb.offset2[2:1];
                      format_b.imm3[3:2]  = format_cb.offset1[1:0];
                      format_b.imm4       = 1'b0;
                      format_b.op         = 7'b1100011;      
         end // case: `C_BNEZ
         `C_LI: begin
                      format_i.imm[11:6]  = 6'd0;
                      format_i.imm[5]     = format_ci.imm1;
                      format_i.imm[4:0]   = format_ci.imm2;
                      format_i.rs1        = `x0;
                      format_i.funct3     = 3'b000;
                      format_i.rd         = format_ci.rd_rs1;
                      format_i.op         = 7'b0010011;
         end 
         `C_LUI: begin
                      format_u.imm[4:0]   = format_ci.imm2[4:0];
                      format_u.imm[5]     = format_ci.imm1;
                      format_u.imm[19:6]  = 14'd0;
                      format_u.rd         = format_ci.rd_rs1;
                      format_i.op         = 7'b0110111;
         end
         `C_ADDI: begin
                      format_i.imm[11:6]  = 6'd0;
                      format_i.imm[5]     = format_ci.imm1;
                      format_i.imm[4:0]   = format_ci.imm2[4:0];
                      format_i.rs1        = format_ci.rd_rs1;
                      format_i.funct3     = 3'b000;
                      format_i.rd         = format_ci.rd_rs1;
                      format_i.op         = 7'b0010011;
         end
         `C_ADDIW: begin
                      format_i.imm[11:6]  = 6'd0;
                      format_i.imm[5]     = format_ci.imm1;
                      format_i.imm[4:0]   = format_ci.imm2[4:0];
                      format_i.rs1        = format_ci.rd_rs1;
                      format_i.funct3     = 3'b000;
                      format_i.rd         = format_ci.rd_rs1;
                      format_i.op         = 7'b0011011;
         end
         `C_ADDI16SP: begin
                      format_i.imm[5]     = format_ci.imm2[0];
                      format_i.imm[8:7]   = format_ci.imm2[2:1];
                      format_i.imm[9]     = format_ci.imm1;
                      format_i.imm[6]     = format_ci.imm2[3];
                      format_i.imm[4]     = format_ci.imm2[4];
                      format_i.imm[3:0]   = 4'b000;
                      format_i.imm[11:10] = 2'b00;
                      format_i.rs1        = `x2;
                      format_i.funct3     = 3'b000;
                      format_i.rd         = `x2;
                      format_i.op         = 7'b0010011;
         end // case: `C_ADDI16SP
         `C_ADDI4SPN: begin
                      format_i.imm[3]     = format_ciw.imm[0];
                      format_i.imm[2]     = format_ciw.imm[1];
                      format_i.imm[9:6]   = format_ciw.imm[5:2];
                      format_i.imm[5:4]   = format_ciw.imm[7:6];
                      format_i.imm[1:0]   = 2'b00;
                      format_i.imm[11:10] = 2'b00;
                      format_i.rs1        = `x2;
                      format_i.funct3     = 3'b000;
                      d_compressed_reg    = format_ciw.rd;
                      format_i.rd         = d_decompressed_reg;
                      format_i.op         = 7'b0010011;
         end // case: `C_ADDI4SPN
         `C_SLLI: begin
                      format_i.imm[11:5]  = 7'd0;
                      format_i.imm[4:0]   = format_ci.imm2[4:0];
                      format_i.rs1        = format_ci.rd_rs1;
                      format_i.funct3     = 3'b001;
                      format_i.rd         = format_ci.rd_rs1;
                      format_i.op         = 7'b0010011;
         end // case: `C_SLLI
         `C_SRLI,`C_SRAI,`C_ANDI,`C_AND,`C_SUB,`C_XOR, `C_OR,`C_ADDW,`C_SUBW: begin
                     if      (instr_c[12] != 1'b0 && instr_c[11:10] == 2'b00 && instr_c[6:2] != 5'd0) //SRLI
                       begin
                          format_i.imm[11:5]  = 7'd0;
                          format_i.imm[4:0]   = format_cb.offset2[4:0];
                          s1_compressed_reg   = format_cb.rs1;
                          format_i.rd         = s1_decompressed_reg;
                          format_i.rs1        = s1_decompressed_reg;
                          format_i.funct3     = 3'b101;
                          format_i.op         = 7'b0010011;
                       end
                     else if (instr_c[12] != 1'b0 && instr_c[11:10] == 2'b01 && instr_c[6:2] != 5'd0) //SRAI
                       begin
                          format_i.imm[11:5]  = 7'b0100000;
                          format_i.imm[4:0]   = format_cb.offset2[4:0];
                          s1_compressed_reg   = format_cb.rs1;
                          format_i.rd         = s1_decompressed_reg;
                          format_i.rs1        = s1_decompressed_reg;
                          format_i.funct3     = 3'b101;
                          format_i.op         = 7'b0010011;
                       end
                     else if (instr_c[11:10] == 2'b10) //ANDI
                       begin
                          format_i.imm[11:6]  = 6'd0;
                          format_i.imm[5]     = format_cb.offset1[2];
                          format_i.imm[4:0]   = format_cb.offset2[4:0];
                          s1_compressed_reg   = format_cb.rs1;
                          format_i.rd         = s1_decompressed_reg;
                          format_i.rs1        = s1_decompressed_reg;
                          format_i.funct3     = 3'b111;
                          format_i.op         = 7'b0010011;
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b00) //SUB
                       begin
                          format_r.funct7       = 7'b0100000;
                          s2_compressed_reg     = format_cs.rs2;
                          format_r.rs2          = s2_decompressed_reg;
                          s1_compressed_reg     = format_cs.rs1;
                          format_r.rd           = s1_decompressed_reg;
                          format_r.rs1          = s1_decompressed_reg;          
                          format_r.funct3       = 3'b000;  
                          format_r.op           = 7'b0110011;          
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b01) //XOR
                       begin
                          format_r.funct7       = 7'd0;
                          s2_compressed_reg     = format_cs.rs2;
                          format_r.rs2          = s2_decompressed_reg;
                          s1_compressed_reg     = format_cs.rs1;
                          format_r.rd           = s1_decompressed_reg;
                          format_r.rs1          = s1_decompressed_reg;          
                          format_r.funct3       = 3'b100;  
                          format_r.op           = 7'b0110011;          
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b10) //OR
                       begin
                          format_r.funct7       = 7'd0;
                          s2_compressed_reg     = format_cs.rs2;
                          format_r.rs2          = s2_decompressed_reg;
                          s1_compressed_reg     = format_cs.rs1;
                          format_r.rd           = s1_decompressed_reg;
                          format_r.rs1          = s1_decompressed_reg;          
                          format_r.funct3       = 3'b110;  
                          format_r.op           = 7'b0110011;          
                       end
                     else if (instr_c[12] == 1'b0 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b11) //AND
                       begin
                          format_r.funct7       = 7'd0;
                          s2_compressed_reg     = format_cs.rs2;
                          format_r.rs2          = s2_decompressed_reg;
                          s1_compressed_reg     = format_cs.rs1;
                          format_r.rd           = s1_decompressed_reg;
                          format_r.rs1          = s1_decompressed_reg;          
                          format_r.funct3       = 3'b111;  
                          format_r.op           = 7'b0110011;          
                       end
                     else if (instr_c[12] == 1'b1 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b00) //SUBW
                       begin
                          format_r.funct7       = 7'b0100000;
                          s2_compressed_reg     = format_cs.rs2;
                          format_r.rs2          = s2_decompressed_reg;
                          s1_compressed_reg     = format_cs.rs1;
                          format_r.rd           = s1_decompressed_reg;
                          format_r.rs1          = s1_decompressed_reg;          
                          format_r.funct3       = 3'b000;  
                          format_r.op           = 7'b0111011;          
                       end
                     else if (instr_c[12] == 1'b1 && instr_c[11:10] == 2'b11 && instr_c[6:5] != 2'b01) //ADDW
                       begin
                          format_r.funct7       = 7'b0100000;
                          s2_compressed_reg     = format_cs.rs2;
                          format_r.rs2          = s2_decompressed_reg;
                          s1_compressed_reg     = format_cs.rs1;
                          format_r.rd           = s1_decompressed_reg;
                          format_r.rs1          = s1_decompressed_reg;          
                          format_r.funct3       = 3'b000;  
                          format_r.op           = 7'b0111011;          
                       end
         end
         `C_NOP: begin
                      format_i.imm[11:6]  = 6'd0;
                      format_i.imm[5]     = format_ci.imm1;
                      format_i.imm[4:0]   = format_ci.imm2[4:0];
                      format_i.rd         = `x0;
                      format_i.rs1        = `x0;
                      format_i.funct3     = 3'b000;
                      format_i.op         = 7'b0010011;
          end
    endcase // case ({instr_c[15:13],instr_c[1:0]})
end // always_comb begin
//endtask

//decoding registers for CIW, CL, CS, and CB formats
//change it to task
always_comb begin
   case (s1_compressed_reg)
        3'b000:  s1_decompressed_reg = `x8;
        3'b001:  s1_decompressed_reg = `x9;
        3'b010:  s1_decompressed_reg = `x10;
        3'b011:  s1_decompressed_reg = `x11;
        3'b100:  s1_decompressed_reg = `x12;
        3'b101:  s1_decompressed_reg = `x13;
        3'b110:  s1_decompressed_reg = `x14;
        3'b111:  s1_decompressed_reg = `x15;
        default: s1_decompressed_reg = `x0;
   endcase // case (s_compressed_reg)
   case (s2_compressed_reg)
        3'b000:  s2_decompressed_reg = `x8;
        3'b001:  s2_decompressed_reg = `x9;
        3'b010:  s2_decompressed_reg = `x10;
        3'b011:  s2_decompressed_reg = `x11;
        3'b100:  s2_decompressed_reg = `x12;
        3'b101:  s2_decompressed_reg = `x13;
        3'b110:  s2_decompressed_reg = `x14;
        3'b111:  s2_decompressed_reg = `x15;
        default: s2_decompressed_reg = `x0;
   endcase // case (s_compressed_reg)
   case (d_compressed_reg)
        3'b000:  d_decompressed_reg = `x8;
        3'b001:  d_decompressed_reg = `x9;
        3'b010:  d_decompressed_reg = `x10;
        3'b011:  d_decompressed_reg = `x11;
        3'b100:  d_decompressed_reg = `x12;
        3'b101:  d_decompressed_reg = `x13;
        3'b110:  d_decompressed_reg = `x14;
        3'b111:  d_decompressed_reg = `x15;
        default: d_decompressed_reg = `x0;
   endcase // case (d_compressed_reg)
end       

assign inst_out = (inst_inp[1:0] != 2'b11) ? instr_d : inst_inp;
   

endmodule



`ifndef BP_FE_DECOMPRESS_SVH
`define BP_FE_DECOMPRESS_SVH

// DISCLAIMER: Decompression will be changed in the future.

/*`define fe_decompress_s bp_fe_queue_s
* `define decompress_fe_s bp_fe_queue_s
*
* `define fe_decompress_width(vaddr_width_p,branch_metadata_fwd_width_p) \
*     (`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p))
*
* `define decompress_fe_width(vaddr_width_p,branch_metadata_fwd_width_p) \
*     (`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p))
*
* typedef enum {
*   e_rvi_aligned          = 3'b000
*   ,e_rvc_aligned         = 3'b001
*   ,e_rvc_rvi_misaligned  = 3'b010
*   ,e_rvi_rvc_misaligned  = 3'b011
*   ,e_rvi_misaligned      = 3'b100
* } decompress_states_e;
*
* `define C_LWSP     5'b01010
* `define C_LDSP     5'b01110
* `define C_LQSP     5'b00110
* `define C_FLWSP    5'b01110
* `define C_FLDSP    5'b00110
*
* `define C_SWSP     5'b11010
* `define C_SDSP     5'b11110
* `define C_SQSP     5'b10110
* `define C_FSWSP    5'b11110
* `define C_FSDSP    5'b10110
*
* `define C_LW       5'b01000
* `define C_LD       5'b01100
* `define C_LQ       5'b00100
* `define C_FLW      5'b01100
* `define C_FLD      5'b00100
*
* `define C_SW       5'b11000
* `define C_SD       5'b11100
* `define C_SQ       5'b10100
* `define C_FSW      5'b11100
* `define C_FSD      5'b10100
*
* `define C_J        5'b10101
* `define C_JAL      5'b00101
*
* `define C_JR       5'b10010
* `define C_JALR     5'b10010
*
* `define C_BEQZ     5'b11001
* `define C_BNEZ     5'b11101
*
* `define C_LI       5'b01001
* `define C_LUI      5'b01101
*
* `define C_ADDI     5'b00001
* `define C_ADDIW    5'b00101
* `define C_ADDI16SP 5'b01101
*
* `define C_ADDI4SPN 5'b00000
*
* `define C_SLLI     5'b00010
* `define C_SLLI64   5'b00010
*
* `define C_SRLI     5'b10001
* `define C_SRAI     5'b10001
*
* `define C_ANDI     5'b10001
*
* `define C_MV       5'b10010
* `define C_ADD      5'b10010
*
* `define C_EBREAK   5'b10010
*
* `define C_AND      5'b10001
* `define C_OR       5'b10001
* `define C_XOR      5'b10001
* `define C_SUB      5'b10001
* `define C_ADDW     5'b10001
* `define C_SUBW     5'b10001
*
* `define C_NOP      5'b00001
* `define C_ILLEGAL  5'b00000
*
* // register name
* `define x0         5'0
* `define x1         5'1
* `define x2         5'2
* `define x3         5'3
* `define x4         5'4
* `define x5         5'5
* `define x6         5'6
* `define x7         5'7
* `define x8         5'8
* `define x9         5'9
* `define x10        5'10
* `define x11        5'11
* `define x12        5'12
* `define x13        5'13
* `define x14        5'14
* `define x15        5'15
* `define x16        5'16
* `define x17        5'17
* `define x18        5'18
* `define x19        5'19
* `define x20        5'20
* `define x21        5'21
* `define x22        5'22
* `define x23        5'23
* `define x24        5'24
* `define x25        5'25
* `define x26        5'26
* `define x27        5'27
* `define x28        5'28
* `define x29        5'29
* `define x30        5'30
* `define x31        5'31
*
* //rvc format
* `define funct4_width_p    4
* `define funct3_width_p    3
* `define rd_rs1_width_p    5
* `define rs2_width_p       5
* `define op_width_p        2
* `define ci_imm2_width_p   5
* `define css_imm_width_p   6
* `define ciw_imm_width_p   8
* `define rd_prime_width_p  3
* `define cl_imm1_width_p   3
* `define rs1_prime_width_p 3
* `define cl_imm2_width_p   2
* `define cs_imm1_width_p   3
* `define cs_imm2_width_p   2
* `define rs2_prime_width_p 3
* `define offset1_width_p   3
* `define offset2_width_p   5
* `define jump_width_p     11
*
* typedef struct packed {
*   logic [funct4_width_p-1:0]     funct4;
*   logic [rd_rs1_width_p-1:0]     rd_rs1;
*   logic [rs2_width_p-1:0]        rs2;
*   logic [op_width_p-1:0]         op;
* } format_cr_s;

* typedef struct packed {
*   logic [funct3_width_p-1:0]     funct3;
*   logic                          imm1;
*   logic [rd_rs1_width_p-1:0]     rd_rs1;
*   logic [ci_imm2_width_p-1:0]    imm2;
*   logic [op_width_p-1:0]         op;
* } format_ci_s;
*
* typedef struct packed {
*   logic [funct3_width_p-1:0]     funct3;
*   logic [css_imm_width_p-1:0]    imm;
*   logic [rs2_width_p-1:0]        rs2;
*   logic [op_width_p-1:0]         op;
* } format_css_s;
*
* typedef struct packed {
*   logic [funct3_width_p-1:0]     funct3;
*   logic [ciw_imm_width_p-1:0]    imm;
*   logic [rd_prime_width_p-1:0]   rd;
*   logic [op_width_p-1:0]         op;
* } format_ciw_s;
*
* typedef struct packed {
*   logic [funct3_width_p-1:0]     funct3;
*   logic [cl_imm1_width_p-1:0]    imm1;
*   logic [rs1_prime_width_p-1:0]  rs1;
*   logic [cl_imm2_width_p-1:0]    imm2;
*   logic [rd_prime_width_p-1:0]   rd;
*   logic [op_width_p-1:0]         op;
* } format_cl_s;
*
* typedef struct packed {
*   logic [funct3_width_p-1:0]     funct3;
*   logic [cs_imm1_width_p-1:0]    imm1;
*   logic [rs1_prime_width_p-1:0]  rs1;
*   logic [cs_imm2_width_p-1:0]    imm2;
*   logic [rs2_prime_width_p-1:0]  rs2;
*   logic [op_width_p-1:0]         op;
* } format_cs_s;
*
* typedef struct packed {
*   logic [funct3_width_p-1:0]     funct3;
*   logic [offset1_width_p-1:0]    offset1;
*   logic [rs1_prime_width_p-1:0]  rs1;
*   logic [offset2_width_p-1:0]    offset2;
*   logic [op_width_p-1:0]         op;
* } format_cb_s;
*
* typedef struct packed {
*   logic [funct3_width_p-1:0]     funct3;
*   logic [jump_width_p-1:0]       jump_target;
*   logic [op_width_p-1:0]         op;
* } format_cj_s;
*
* // rvi format
*
* `define funct7_width_p 7
* `define rs1_width_p    5
* `define funct3_width_p 3
* `define rd_width_p     5
* `define i_imm1_width_p 12
* `define s_imm1_width_p 7
* `define s_imm2_width_p 5
*
* typedef struct packed {
*   logic [funct7_width_p-1:0]     funct7;
*   logic [rs2_width_p-1:0]        rs2;
*   logic [rs1_width_p-1:0]        rs1;
*   logic [funct3_width_p-1:0]     funct3;
*   logic [rd_width_p-1:0]         rd;
*   logic [op_width_p-1:0]         op;
* } format_r_s;
*
* typedef struct packed {
*   logic [i_imm_width_p-1:0]      imm;
*   logic [rs1_width_p-1:0]        rs1;
*   logic [funct3_width_p-1:0]     funct3;
*   logic [rd_width_p-1:0]         rd;
*   logic [op_width_p-1:0]         op;
* } format_i_s;
*
* typedef struct packed {
*   logic [s_imm1_width_p-1:0]     imm1;
*   logic [rs2_width_p-1:0]        rs2;
*   logic [rs1_width_p-1:0]        rs1;
*   logic [funct3_width_p-1:0]     funct3;
*   logic [s_imm2_width_p-1:0]     imm2;
*   logic [op_width_p-1:0]         op;
* } format_s_s;
*/
`endif

/*
 * pc_gen.vh
 *
 * pc_gen.vh provides the structs for PC generation logics. PC generation use
 * previous PCs to determine the next PC. PC generation also inspects instrcutions
 * and flag RVC if the instruction is compressed.  
 * 
 * PC generation consists of instruction scanning and Branch Prediction (BP). The
 * instruction scanning first scans the control flow instructions, to determines
 * whether the instruction is compressed or not. If the instruction is compressed,
 * the pc_gen will flag the categories of the instruction to other modules in
 * backend.  BP uses the previous PC to look up the corresponding entry in the
 * Branch History Table (BHT).  If the BHT entry predicts taken, BP find the
 * correpsonding entry in the Branch Target Buffer (BTB) as the next PC.  In the
 * case of call-ret pairs, BP pushes the call target to Return Address Stack
 * (RAS) and pops the address in the ret instruction.
*/

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH

`include "bsg_defines.v"
`include "bp_common_fe_be_if.vh"

// import bp_common_pkg::*;
import pc_gen_pkg::*;


// this part is modified to accomodate the instr output
`define declare_bp_fe_pc_gen_queue_s                  \
  typedef struct packed {                             \
    bp_fe_queue_type_e                  msg_type;     \
    logic [`bp_fe_instr_scan_width-1:0] scan_instr;   \
    union packed {                                    \
      bp_fe_fetch_s                     fetch;        \
      bp_fe_exception_s                 exception;    \
    } msg;                                            \
  }  bp_fe_pc_gen_queue_s

`define bp_fe_pc_gen_queue_width(vaddr_width_p,branch_metadata_fwd_width_p) \
     (`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)+`bp_fe_instr_scan_width)


/*
 * The pc_gen logic recieves the commands from the backend if there is any
 * exceptions.  pc_gen inherets the interfaces from the frontend that uses the
 * exception codes to notify if any exception happens.
*/
`define declare_bp_fe_pc_gen_cmd_s                               \
  typedef struct packed {                                        \
    bp_fe_command_queue_opcodes_e        command_queue_opcodes;  \
    union packed {                                               \
      bp_fe_cmd_pc_redirect_operands_s   pc_redirect_operands;   \
      bp_fe_cmd_attaboy_s                attaboy;                \
    } operands;                                                  \
  }  bp_fe_pc_gen_cmd_s


`define bp_fe_pc_gen_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p) \
    (`bp_fe_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_p))


/*
 * bp_fe_pc_gen_s is provided to the backend, which consists of pc, BTB entry
 * index, and ras address.
*/
`define bp_fe_pc_gen_fetch_s bp_fe_fetch_s

/*
 * bp_fe_pc_gen_width provides the width of bp_fe_pc_gen_s. All the width
 * informations are parameterized.
*/
`define bp_fe_pc_gen_fetch_width(vaddr_width_p,branch_metadata_fwd_width_p) \
    (`bp_fe_fetch_width(vaddr_width_p,branch_metadata_fwd_width_p))


`define bp_fe_pc_gen_exception_s bp_fe_exception_s

`define bp_fe_pc_gen_exception_width(vaddr_width_p,branch_metadata_fwd_width_p) \
     `bp_fe_exception_width(vaddr_width_p,branch_metadata_fwd_width_p)

/*
 * bp_fe_pc_gen_icache_s defines the interface between pc_gen and icache.
 * pc_gen informs the icache of the pc value.
*/
`define declare_bp_fe_pc_gen_icache_s(eaddr_wdith_p)  \
  typedef struct packed{                              \
    logic [eaddr_width_p-1:0] virt_addr;              \
    }  bp_fe_pc_gen_icache_s

`define bp_fe_pc_gen_icache_width(eaddr_width_p) \
         (eaddr_width_p)

/*
 * bp_fe_pc_gen_icache_s defines the interface between pc_gen and itlb.
 * The pc_gen informs the itlb of the pc address.
*/
`define declare_bp_fe_pc_gen_itlb_s(eaddr_width_p)  \
  typedef struct packed {                           \
    logic [eaddr_width_p-1:0] virt_addr;            \
  }  bp_fe_pc_gen_itlb_s

`define bp_fe_pc_gen_itlb_width(eaddr_width_p) (eaddr_width_p)

/*
 * bp_fe_instr_scan_class_e specifies the type of the current instruction,
 * including whether the instruction is compressed or not.
*/
typedef enum {
  e_rvc_beqz    
  , e_rvc_bnez   
  , e_rvc_call   
  , e_rvc_imm     
  , e_rvc_jalr     
  , e_rvc_jal     
  , e_rvc_jr     
  , e_rvc_return     
  , e_rvi_branch     
  , e_rvi_call     
  , e_rvi_imm     
  , e_rvi_jalr      
  , e_rvi_jal       
  , e_rvi_return      
  , e_default    
} bp_fe_instr_scan_class_e;

`define bp_fe_instr_scan_class_width \
     ($bits(bp_fe_instr_scan_class_e))

/*
 * bp_fe_instr_scan_s flags the category of the instruction. The control
 * flow instruction under the inspections are branch, call, immediate call, jump
 * and link, jump register, jump and return. If any of these instructions are
 * compressed, the PC gen will use one of the instr_scan_class enum types to
 * inform the other blocks. bp_fe_instr_scan_s consists of 1) whether pc is
 * compressed or not and 2) what class pc instruction is.
*/
`define declare_bp_fe_instr_scan_s                                   \
  typedef struct packed {                                            \
    logic                                       is_compressed;       \
    logic [`bp_fe_instr_scan_class_width-1:0]   instr_scan_class;    \
  } bp_fe_instr_scan_s


/*
 *  All the opcode macros for the control flow instructions.  These opcodes are
 * used in the Frontend for scanning compressed instructions.
*/
`define opcode_rvc_beqz     4'h6
`define opcode_rvc_bnez     4'h7
`define opcode_rvc_call     16'h9082
`define opcode_rvc_imm      3'h5
`define opcode_rvc_jalr     4'h9
`define opcode_rvc_jal      3'h1
`define opcode_rvc_jr       4'h8
`define opcode_rvc_return   16'h9002
`define opcode_rvi_branch   7'h63
`define opcode_rvi_call     8'he7
`define opcode_rvi_imm      12'h06F
`define opcode_rvi_jalr     7'h67
`define opcode_rvi_jal      7'h6F
`define opcode_rvi_return   16'h8067

/*
 * bp_fe_is_rvc_e determine whether the control flow instructions are compressed
 * or not.
*/
`define bp_fe_is_compressed  1
`define bp_fe_not_compressed 0

`define bp_fe_instr_scan_width (1+`bp_fe_instr_scan_class_width)

`define declare_bp_fe_branch_metadata_fwd_s(btb_idx_width_p,bht_idx_width_p,ras_addr_width_p) \
  typedef struct packed {                                                                     \
    logic [btb_idx_width_p-1:0]    btb_indx;                                                  \
    logic [bht_idx_width_p-1:0]    bht_indx;                                                  \
    logic [ras_addr_width_p-1:0]   ras_addr;                                                  \
  } bp_fe_branch_metadata_fwd_s

`define bp_fe_branch_metadata_fwd_width(btb_idx_width_p,bht_idx_width_p,ras_addr_width_p) \
     (btb_idx_width_p+bht_idx_width_p+ras_addr_width_p)

`endif

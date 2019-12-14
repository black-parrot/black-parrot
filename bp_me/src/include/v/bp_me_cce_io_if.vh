/**
 * bp_me_cce_io_if.vh
 *
 * This file defines the interface between the CCE and I/O.
 *
 */

`ifndef BP_ME_CCE_IO_IF_VH
`define BP_ME_CCE_IO_IF_VH

`include "bsg_defines.v"

/*
 *
 * CCE-IO Interface
 *
 */

/*
 * bp_cce_io_cmd_type_e specifies the I/O command from the CCE
 */
typedef enum bit
{
  e_cce_io_rd       = 1'b0  // I/O load
  ,e_cce_io_wr      = 1'b1  // I/O store
} bp_cce_io_cmd_type_e;

typedef enum bit [1:0]
{
  e_io_size_1     = 2'b00  // 1 byte
  ,e_io_size_2    = 2'b01  // 2 bytes
  ,e_io_size_4    = 2'b10  // 4 bytes
  ,e_io_size_8    = 2'b11  // 8 bytes
} bp_cce_io_req_size_e;

/*
 *
 * CCE to Mem Command
 *
 */

/*
 * bp_cce_io_msg_payload_s defines a payload that is sent to the memory system by the CCE as part
 * of bp_cce_io_msg_s and returned by the mem to the CCE. This data
 * is not required by the memory system to complete the request.
 *
 * lce_id is the LCE that sent the initial request
 */

`define declare_bp_cce_io_msg_payload_s(lce_id_width_mp) \
  typedef struct packed                                       \
  {                                                           \
    logic [lce_id_width_mp-1:0]                  lce_id;      \
  }  bp_cce_io_msg_payload_s


/*
 * bp_cce_io_msg_s is the message struct for messages between the CCE and I/O
 * msg_type gives the command or response type (interpretation depends on direction of message)
 * addr is the physical address for the command/response
 * size is typically the size, in bytes, the command/response acts on
 * payload is data sent to I/O and returned to cce unmodified
 */
`define declare_bp_cce_io_msg_s(addr_width_mp, data_width_mp)  \
  typedef struct packed                                        \
  {                                                            \
    logic [data_width_mp-1:0]                   data;          \
    bp_cce_io_msg_payload_s                     payload;       \
    bp_cce_io_req_size_e                        size;          \
    logic [addr_width_mp-1:0]                   addr;          \
    bp_cce_io_cmd_type_e                        msg_type;      \
  }  bp_cce_io_msg_s

/*
 * Width Macros
 */

// CCE-MEM Interface
`define bp_cce_io_msg_payload_width(lce_id_width_mp) \
  (lce_id_width_mp)

`define bp_cce_io_msg_width(addr_width_mp, data_width_mp, lce_id_width_mp) \
  ($bits(bp_cce_io_cmd_type_e)+addr_width_mp+data_width_mp \
   +`bp_cce_io_msg_payload_width(lce_id_width_mp) \
   +$bits(bp_cce_io_req_size_e))

/*
 *
 * Memory End Interface Macro
 *
 * This macro defines all of the memory end interface struct and port widths at once as localparams
 *
 */

`define declare_bp_io_if(paddr_width_mp, data_width_mp, lce_id_width_mp) \
  `declare_bp_cce_io_msg_payload_s(lce_id_width_mp);                     \
  `declare_bp_cce_io_msg_s(paddr_width_mp, data_width_mp);               \

`define declare_bp_io_if_widths(paddr_width_mp, data_width_mp, lce_id_width_mp) \
  , localparam cce_io_msg_width_lp=`bp_cce_io_msg_width(paddr_width_mp, data_width_mp, lce_id_width_mp)


`endif


module bp_l15_decoder
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
   )
  (input clk_i
   , input reset_i

   // BP -> L1.5 
   , input [cce_mem_cmd_width_lp-1:0]                  mem_cmd_i
   , input                                             mem_cmd_v_i
   , output                                            mem_cmd_ready_o

   , input [cce_mem_data_cmd_width_lp-1:0]             mem_data_cmd_i
   , input                                             mem_data_cmd_v_i
   , output                                            mem_data_cmd_ready_o

   // OpenPiton side
   , output [4:0]                                      transducer_l15_rqtype
   , output [2:0]                                      transducer_l15_size
   , output [paddr_width_p-1:0]                        transducer_l15_address
   , output [63:0]                                     transducer_l15_data
   , output                                            transducer_l15_nc
   , output                                            transducer_l15_val
   , input                                             l15_transducer_ack
   , input                                             l15_transducer_header_ack

   // Unused OpenPiton side connections
   , output [3:0]                                      transducer_l15_amo_op
   , output [0:0]                                      transducer_l15_threadid
   , output                                            transducer_l15_prefetch
   , output                                            transducer_l15_invalidate_cacheline
   , output                                            transducer_l15_blockstore
   , output                                            transducer_l15_blockinitstore
   , output                                            transducer_l15_l1rplway
   , output                                            transducer_l15_data_next_entry
   , output                                            transducer_l15_csm_data
   );

`define PCX_SZ_1B    3'b000  // encoding for 1B access
`define PCX_SZ_2B    3'b001  // encoding for 2B access
`define PCX_SZ_4B    3'b010  // encoding for 4B access
`define PCX_SZ_8B    3'b011  // encoding for 8B access
`define PCX_SZ_16B   3'b111  // encoding for 16B access

`define LOAD_RQ         5'b00000
`define IMISS_RQ        5'b10000
`define STORE_RQ        5'b00001
`define CAS1_RQ         5'b00010
`define CAS2_RQ         5'b00011
`define SWAP_RQ         5'b00110
`define STRLOAD_RQ      5'b00100
`define STRST_RQ        5'b00101
`define STQ_RQ          5'b00111
`define INT_RQ          5'b01001
`define FWD_RQ          5'b01101
`define FWD_RPY         5'b01110
`define RSVD_RQ         5'b11111

`define LOAD_RET        4'b0000
`define INV_RET         4'b0011
`define ST_ACK          4'b0100
`define AT_ACK          4'b0011
`define INT_RET         4'b0111
`define TEST_RET        4'b0101
`define FP_RET          4'b1000
`define IFILL_RET       4'b0001
`define EVICT_REQ       4'b0011
`define ERR_RET         4'b1100
`define STRLOAD_RET     4'b0010
`define STRST_ACK       4'b0110
`define FWD_RQ_RET      4'b1010
`define FWD_RPY_RET     4'b1011
`define RSVD_RET        4'b1111

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)
  
  wire unused = &{l15_transducer_header_ack};
  
  bp_cce_mem_cmd_s mem_cmd_lo;
  logic mem_cmd_v_lo, mem_cmd_yumi_li;
  bsg_one_fifo
   #(.width_p(cce_mem_cmd_width_lp)
     ,.ready_THEN_valid_p(1)
     )
   mem_cmd_buf
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.data_i(mem_cmd_i)
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_o)
  
     ,.data_o(mem_cmd_lo)
     ,.v_o(mem_cmd_v_lo)
     ,.yumi_i(mem_cmd_yumi_li)
     );
  
  bp_cce_mem_data_cmd_s mem_data_cmd_lo;
  logic mem_data_cmd_v_lo, mem_data_cmd_yumi_li;
  bsg_one_fifo
   #(.width_p(cce_mem_data_cmd_width_lp)
     ,.ready_THEN_valid_p(1)
     )
   mem_data_cmd_buf
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.data_i(mem_data_cmd_i)
     ,.v_i(mem_data_cmd_v_i)
     ,.ready_o(mem_data_cmd_ready_o)
  
     ,.data_o(mem_data_cmd_lo)
     ,.v_o(mem_data_cmd_v_lo)
     ,.yumi_i(mem_data_cmd_yumi_li)
     );
  
  always_comb
    begin
      if (mem_cmd_v_lo)
        begin
          transducer_l15_rqtype  = (mem_cmd_lo.msg_type == e_lce_req_type_rd) ? `LOAD_RQ : `STORE_RQ;
          case (mem_cmd_lo.nc_size)
            e_lce_nc_req_1: transducer_l15_size = `PCX_SZ_1B;
            e_lce_nc_req_2: transducer_l15_size = `PCX_SZ_2B;
            e_lce_nc_req_4: transducer_l15_size = `PCX_SZ_4B;
            e_lce_nc_req_8: transducer_l15_size = `PCX_SZ_8B;
            default: transducer_l15_size = '0;
          endcase
          transducer_l15_address = mem_cmd_lo.addr;
          transducer_l15_data    = '0;
          transducer_l15_nc      = '0; // Always cache in OpenPiton for now
        end
      else
        begin
          transducer_l15_rqtype  = (mem_data_cmd_lo.msg_type == e_lce_req_type_rd) ? `LOAD_RQ : `STORE_RQ;
          case (mem_data_cmd_lo.nc_size)
            e_lce_nc_req_1: transducer_l15_size = `PCX_SZ_1B;
            e_lce_nc_req_2: transducer_l15_size = `PCX_SZ_2B;
            e_lce_nc_req_4: transducer_l15_size = `PCX_SZ_4B;
            e_lce_nc_req_8: transducer_l15_size = `PCX_SZ_8B;
            default: transducer_l15_size = '0;
          endcase
          transducer_l15_address = mem_data_cmd_lo.addr;
          transducer_l15_data    = mem_data_cmd_lo.data;
          transducer_l15_nc      = '0; // Always cache in OpenPiton for now
        end
    end
  
  // Assume that we will always service cmd over data_cmd
  assign transducer_l15_val    = mem_cmd_v_lo | mem_data_cmd_v_lo;
  assign mem_cmd_yumi_li       = l15_transducer_ack & mem_cmd_v_lo;
  assign mem_data_cmd_yumi_li  = l15_transducer_ack & ~mem_cmd_v_lo;
  
  // Tie off unused signals
  assign transducer_l15_amo_op                 = '0;
  assign transducer_l15_threadid               = '0;
  assign transducer_l15_prefetch               = '0;
  assign transducer_l15_invalidate_cacheline   = '0;
  assign transducer_l15_blockstore             = '0;
  assign transducer_l15_blockinitstore         = '0;
  assign transducer_l15_l1rplway               = '0;
  assign transducer_l15_data_next_entry        = '0;
  assign transducer_l15_csm_data               = '0;

endmodule 
  

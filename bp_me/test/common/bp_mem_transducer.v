/**
 * bp_mem_transducer.v
 */

module bp_mem_transducer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , parameter [paddr_width_p-1:0] dram_offset_p = '0

   , localparam num_block_words_lp   = cce_block_width_p / 64
   , localparam num_block_bytes_lp   = cce_block_width_p / 8
   , localparam num_word_bytes_lp    = dword_width_p / 8
   , localparam block_offset_bits_lp = `BSG_SAFE_CLOG2(num_block_bytes_lp)
   , localparam word_offset_bits_lp  = `BSG_SAFE_CLOG2(num_block_words_lp)
   , localparam byte_offset_bits_lp  = `BSG_SAFE_CLOG2(num_word_bytes_lp)
   )
  (input                                 clk_i
   , input                               reset_i

   // BP side
   // ready->valid
   , input [cce_mem_msg_width_lp-1:0]    mem_cmd_i
   , input                               mem_cmd_v_i
   , output                              mem_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]   mem_resp_o
   , output                              mem_resp_v_o
   , input                               mem_resp_yumi_i

   // Mem side
   , input                               ready_i
   , output                              v_o
   , output                              w_o

   , output [paddr_width_p-1:0]          addr_o
   , output [cce_block_width_p-1:0]      data_o
   , output [num_block_bytes_lp-1:0]     write_mask_o

   , input [cce_block_width_p-1:0]       data_i
   , input                               v_i
   , output                              yumi_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

  bp_cce_mem_msg_s mem_cmd_cast_i, mem_resp_cast_o;

  assign mem_resp_o = mem_resp_cast_o;
  assign mem_cmd_cast_i  = mem_cmd_i;

  bp_cce_mem_msg_s mem_cmd_r;
  bsg_dff_reset_en
   #(.width_p(cce_mem_msg_width_lp))
   mshr_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(v_o)

     ,.data_i(mem_cmd_i)
     ,.data_o(mem_cmd_r)
     );

  // Only handle word aligned accesses
  wire [cce_block_width_p-1:0]  wr_word_offset = mem_cmd_cast_i.header.addr[byte_offset_bits_lp+:word_offset_bits_lp];
  wire [cce_block_width_p-1:0]  wr_byte_offset = mem_cmd_cast_i.header.addr[0+:byte_offset_bits_lp];
  wire [cce_block_width_p-1:0]    wr_bit_shift = wr_word_offset*dword_width_p + wr_byte_offset*8;
  wire [cce_block_width_p-1:0]   wr_byte_shift = wr_word_offset*num_word_bytes_lp + wr_byte_offset;
  wire [cce_block_width_p-1:0]  rd_word_offset = mem_cmd_r.header.addr[byte_offset_bits_lp+:word_offset_bits_lp];
  wire [cce_block_width_p-1:0]  rd_byte_offset = mem_cmd_r.header.addr[0+:byte_offset_bits_lp];
  wire [cce_block_width_p-1:0]    rd_bit_shift = rd_word_offset*dword_width_p; // We rely on receiver to adjust bits
  wire [cce_block_width_p-1:0]   rd_byte_shift = rd_word_offset*num_word_bytes_lp;

  assign v_o = mem_cmd_v_i;
  assign w_o = v_o & (mem_cmd_cast_i.header.msg_type inside {e_cce_mem_uc_wr, e_cce_mem_wr});
  assign addr_o = (((mem_cmd_cast_i.header.addr - dram_offset_p) >> block_offset_bits_lp) << block_offset_bits_lp);
  assign data_o = mem_cmd_cast_i.data << wr_bit_shift;
  assign write_mask_o = ((1 << (1 << mem_cmd_cast_i.header.size)) - 1) << wr_byte_shift;

  wire [cce_block_width_p-1:0] data_li = (mem_cmd_r.header.msg_type == e_cce_mem_uc_rd)
                                         ? data_i >> rd_bit_shift
                                         : data_i;

  assign mem_resp_cast_o = '{data     : data_li
                             ,header  : '{payload : mem_cmd_r.header.payload
                                          ,size    : mem_cmd_r.header.size
                                          ,addr    : mem_cmd_r.header.addr
                                          ,msg_type: mem_cmd_r.header.msg_type
                                         }
                             };

  assign mem_cmd_ready_o = ready_i;
  assign mem_resp_v_o = v_i;
  assign yumi_o = mem_resp_yumi_i;

endmodule


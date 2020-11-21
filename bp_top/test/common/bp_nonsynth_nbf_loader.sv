/**
 *  bp_nonsynth_nbf_loader.v
 *
 */

module bp_nonsynth_nbf_loader

  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_me_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)

  ,parameter nbf_filename_p = "prog.nbf"
  ,parameter nbf_opcode_width_p = 8
  ,parameter nbf_addr_width_p = paddr_width_p
  ,parameter nbf_data_width_p = dword_width_p

  ,localparam nbf_width_lp = nbf_opcode_width_p + nbf_addr_width_p + nbf_data_width_p
  ,localparam max_nbf_index_lp = 2**26
  ,localparam nbf_index_width_lp = `BSG_SAFE_CLOG2(max_nbf_index_lp)
  )

  (input  clk_i
  ,input  reset_i
  
  ,input [lce_id_width_p-1:0]              lce_id_i

  ,output [cce_mem_msg_width_lp-1:0]       io_cmd_o
  ,output                                  io_cmd_v_o
  ,input                                   io_cmd_yumi_i
  
  ,input  [cce_mem_msg_width_lp-1:0]       io_resp_i
  ,input                                   io_resp_v_i
  ,output                                  io_resp_ready_o
  );
  
  enum logic [1:0] {
    RESET
    ,SEND_NBF
    ,FENCE
    ,DONE
  } state_n, state_r;
  
  // response network not used
  wire unused_resp = &{io_resp_i, io_resp_v_i};
  assign io_resp_ready_o = 1'b1;

  logic [`BSG_WIDTH(io_noc_max_credits_p)-1:0] credit_count_lo;
  bsg_flow_counter
   #(.els_p(io_noc_max_credits_p))
   nbf_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(io_cmd_yumi_i)
     ,.ready_i(1'b1)

     ,.yumi_i(io_resp_v_i)
     ,.count_o(credit_count_lo)
     );
  wire credits_full_lo = (credit_count_lo == io_noc_max_credits_p);
  wire credits_empty_lo = (credit_count_lo == '0);

  // bp_nbf packet
  typedef struct packed {
    logic [nbf_opcode_width_p-1:0] opcode;
    logic [nbf_addr_width_p-1:0] addr;
    logic [nbf_data_width_p-1:0] data;
  } bp_nbf_s;

  // bp_cce packet
  `declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
  bp_bedrock_cce_mem_msg_s io_cmd, io_resp;
  bp_bedrock_cce_mem_payload_s io_cmd_payload;
  
  assign io_cmd_o = io_cmd;
  assign io_resp = io_resp_i;

  // read nbf file.
  logic [nbf_width_lp-1:0] nbf [max_nbf_index_lp-1:0];
  logic [nbf_index_width_lp-1:0] nbf_index_r, nbf_index_n;
  bp_nbf_s curr_nbf;
  assign curr_nbf = nbf[nbf_index_r];
  
  // assemble cce cmd packet
  always_comb
  begin
    io_cmd.data = curr_nbf.data;
    io_cmd_payload = '0;
    io_cmd_payload.lce_id = lce_id_i;
    io_cmd.header.payload = io_cmd_payload;
    io_cmd.header.addr = curr_nbf.addr;
    io_cmd.header.msg_type.mem = e_bedrock_mem_uc_wr;
    
    case (curr_nbf.opcode)
      2: io_cmd.header.size = e_bedrock_msg_size_4;
      3: io_cmd.header.size = e_bedrock_msg_size_8;
      default: io_cmd.header.size = e_bedrock_msg_size_4;
    endcase
  end
  wire is_fence_packet = (curr_nbf.opcode == 8'hFE);
  wire is_finish_packet = (curr_nbf.opcode == 8'hFF);
  wire is_store_packet = ~is_fence_packet & ~is_finish_packet;

  assign io_cmd_v_o = ~credits_full_lo & (state_r == SEND_NBF) & ~is_fence_packet & ~is_finish_packet;

  // read nbf file
  initial $readmemh(nbf_filename_p, nbf);

  assign nbf_index_n = nbf_index_r + (state_r == SEND_NBF && (io_cmd_yumi_i || is_fence_packet || is_finish_packet));
   // combinational
  always_comb 
  begin
    unique casez (state_r)
      RESET       : state_n = reset_i ? RESET : SEND_NBF;
      SEND_NBF    : state_n = is_fence_packet ? FENCE: is_finish_packet ? DONE : SEND_NBF;
      FENCE       : state_n = credits_empty_lo ? SEND_NBF : FENCE;
      DONE        : state_n = DONE;
      default : state_n = RESET;
    endcase
  end
  
  always_ff @(posedge clk_i)
  begin
    if (reset_i)
      begin
        nbf_index_r <= '0;
        state_r <= RESET;
      end
    else 
      begin
        nbf_index_r <= nbf_index_n;
        state_r <= state_n;
      end
  end

endmodule

/**
 *  bp_nonsynth_nbf_loader.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_nonsynth_nbf_loader
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , parameter nbf_filename_p = "prog.nbf"
   , parameter verbose_p = 1
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [lce_id_width_p-1:0]                     lce_id_i
   , input [did_width_p-1:0]                        did_i

   , output logic [mem_fwd_header_width_lp-1:0]     mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_fwd_data_o
   , output logic                                   mem_fwd_v_o
   , input                                          mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]            mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]               mem_rev_data_i
   , input                                          mem_rev_v_i
   , output logic                                   mem_rev_ready_and_o

   , output logic                                   done_o
   );

  // all messages are single beat
  wire unused = &{mem_rev_data_i};

  enum logic [2:0] { e_reset, e_send, e_fence, e_read, e_done} state_n, state_r;
  wire is_reset    = (state_r == e_reset);
  wire is_send_nbf = (state_r == e_send);
  wire is_fence    = (state_r == e_fence);
  wire is_read     = (state_r == e_read);
  wire is_done     = (state_r == e_done);

  localparam max_nbf_index_lp = 2**25;
  localparam nbf_index_width_lp = `BSG_SAFE_CLOG2(max_nbf_index_lp);
  localparam nbf_data_width_lp = 64;
  localparam nbf_addr_width_lp = nbf_data_width_lp;
  localparam nbf_opcode_width_lp = 8;
  typedef struct packed
  {
    logic [nbf_opcode_width_lp-1:0] opcode;
    logic [nbf_addr_width_lp-1:0] addr;
    logic [nbf_data_width_lp-1:0] data;
  } bp_nbf_s;

  // read nbf file
  bp_nbf_s nbf [max_nbf_index_lp-1:0];
  initial $readmemh(nbf_filename_p, nbf);

  bp_nbf_s curr_nbf;
  logic [nbf_index_width_lp-1:0] nbf_index_r, nbf_index_n;
  assign curr_nbf = nbf[nbf_index_r];

  wire is_fence_packet  = (curr_nbf.opcode == 8'hFE);
  wire is_finish_packet = (curr_nbf.opcode == 8'hFF);
  wire is_read_packet   = (curr_nbf.opcode[5] == 1'b1) & ~is_fence_packet & ~is_finish_packet;
  wire is_store_packet  = (curr_nbf.opcode[5] == 1'b0) & ~is_fence_packet & ~is_finish_packet;

  wire next_nbf = (is_send_nbf && ((mem_fwd_ready_and_i & mem_fwd_v_o) || is_fence_packet || is_finish_packet));
  bsg_counter_clear_up
   #(.max_val_p(max_nbf_index_lp-1), .init_val_p(0))
   nbf_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i(1'b0)
     ,.up_i(next_nbf)
     ,.count_o(nbf_index_r)
     );

  localparam heartbeat_lp = 1000;
  always_ff @(negedge clk_i)
    begin
      if (verbose_p && next_nbf && is_fence_packet)
        $display("NBF fence packet  : %d [%x] (%p)", nbf_index_r, curr_nbf, curr_nbf);
      if (verbose_p && next_nbf && is_finish_packet)
        $display("NBF finish packet : %d [%x] (%p)", nbf_index_r, curr_nbf, curr_nbf);
      if (verbose_p && next_nbf && (nbf_index_r % heartbeat_lp == 0))
        $display("NBF heartbeat     : %d [%x] (%p)", nbf_index_r, curr_nbf, curr_nbf);
    end

  logic [dword_width_gp-1:0] read_data_r;
  bsg_dff_reset_en
   #(.width_p(dword_width_gp))
   read_data_expected
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(is_read_packet)
     ,.data_i(curr_nbf.data[0+:dword_width_gp])
     ,.data_o(read_data_r)
     );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  logic [`BSG_WIDTH(mem_noc_max_credits_p)-1:0] credit_count_lo;
  bsg_flow_counter
   #(.els_p(mem_noc_max_credits_p))
   nbf_fc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.v_i(mem_fwd_v_o)
     ,.ready_param_i(mem_fwd_ready_and_i)

     ,.yumi_i(mem_rev_v_i)
     ,.count_o(credit_count_lo)
     );
  wire credits_full_lo = (credit_count_lo == mem_noc_max_credits_p);
  wire credits_empty_lo = (credit_count_lo == '0);
  assign mem_rev_ready_and_o = 1'b1;

  localparam sel_width_lp = `BSG_SAFE_CLOG2(nbf_data_width_lp>>3);
  localparam size_width_lp = `BSG_SAFE_CLOG2(sel_width_lp);
  bsg_bus_pack
   #(.in_width_p(nbf_data_width_lp), .out_width_p(bedrock_fill_width_p))
   fwd_bus_pack
    (.data_i(curr_nbf.data)
     ,.sel_i('0) // We are aligned
     ,.size_i(mem_fwd_header_cast_o.size[0+:size_width_lp])
     ,.data_o(mem_fwd_data_o)
     );

  always_comb
    begin
      mem_fwd_header_cast_o = '0;
      mem_fwd_header_cast_o.payload.lce_id = lce_id_i;
      mem_fwd_header_cast_o.payload.src_did = did_i;
      mem_fwd_header_cast_o.addr = curr_nbf.addr;
      mem_fwd_header_cast_o.msg_type.fwd = curr_nbf.opcode[5] ? e_bedrock_mem_rd : e_bedrock_mem_wr;
      mem_fwd_header_cast_o.subop = e_bedrock_store;
      case (curr_nbf.opcode[1:0])
        2'b00: mem_fwd_header_cast_o.size = e_bedrock_msg_size_1;
        2'b01: mem_fwd_header_cast_o.size = e_bedrock_msg_size_2;
        2'b10: mem_fwd_header_cast_o.size = e_bedrock_msg_size_4;
        2'b11: mem_fwd_header_cast_o.size = e_bedrock_msg_size_8;
        default: mem_fwd_header_cast_o.size = e_bedrock_msg_size_4;
      endcase
    end

  assign mem_fwd_v_o = ~credits_full_lo & is_send_nbf & ~is_fence_packet & ~is_finish_packet;

  wire read_return = is_read & mem_rev_v_i & (mem_rev_header_cast_i.msg_type == e_bedrock_mem_rd);
  always_comb
    unique casez (state_r)
      e_reset       : state_n = reset_i ? e_reset : e_send;
      e_send        : state_n = is_fence_packet
                                ? e_fence
                                : is_finish_packet
                                  ? e_done
                                  : (is_read_packet & mem_fwd_ready_and_i & mem_fwd_v_o)
                                    ? e_read
                                    : e_send;
      e_read        : state_n = read_return ? e_send : e_read;
      e_fence       : state_n = credits_empty_lo ? e_send : e_fence;
      e_done        : state_n = e_done;
      default : state_n = e_reset;
    endcase
  assign done_o = is_done;

  // synopsys sync_set_reset "reset_i"
  always_ff @(posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

  // synopsys translate_off
  always_ff @(negedge clk_i)
    begin
      if (state_r != e_done && state_n == e_done)
        $display("NBF loader done!");
      assert(reset_i !== '0 || ~read_return || read_data_r == mem_rev_data_i[0+:dword_width_gp])
        else $error("Validation mismatch: addr: %d %d %d", mem_rev_header_cast_i.addr, mem_rev_data_i, read_data_r);
    end
  // synopsys translate_on


  if (nbf_data_width_lp != dword_width_gp)
    $error("NBF data width must be same as dword_width_gp");
  if (dword_width_gp < nbf_data_width_lp)
    $error("NBF IO data width must be as large as NBF data width");

endmodule


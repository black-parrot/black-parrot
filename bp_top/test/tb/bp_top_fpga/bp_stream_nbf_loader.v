/**
 *  bp_stream_nbf_loader.v
 *
 */

module bp_stream_nbf_loader

  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_be_pkg::*;
  import bp_be_dcache_pkg::*;
  import bp_me_pkg::*;
  
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  
  ,parameter stream_data_width_p = 32

  ,parameter nbf_opcode_width_p = 8
  ,parameter nbf_addr_width_p = paddr_width_p
  ,parameter nbf_data_width_p = dword_width_p
  
  ,localparam nbf_width_lp = nbf_opcode_width_p + nbf_addr_width_p + nbf_data_width_p
  ,localparam nbf_num_flits_lp = `BSG_CDIV(nbf_width_lp, stream_data_width_p)
  )

  (input  clk_i
  ,input  reset_i
  ,output done_o
  
  ,output [cce_mem_msg_width_lp-1:0]        io_cmd_o
  ,output                                   io_cmd_v_o
  ,input                                    io_cmd_ready_i
  
  ,input  [cce_mem_msg_width_lp-1:0]        io_resp_i
  ,input                                    io_resp_v_i
  ,output                                   io_resp_yumi_o
  
  ,input                                    stream_v_i
  ,input  [stream_data_width_p-1:0]         stream_data_i
  ,output                                   stream_ready_o
  );
  
  // response network not used
  wire unused_resp = &{io_resp_i, io_resp_v_i};
  assign io_resp_yumi_o = io_resp_v_i;
  
  // nbf credit counter
  logic [`BSG_WIDTH(io_noc_max_credits_p)-1:0] credit_count_lo;
  wire credits_full_lo  = (credit_count_lo == io_noc_max_credits_p);
  wire credits_empty_lo = (credit_count_lo == '0);
  
  bsg_flow_counter
 #(.els_p  (io_noc_max_credits_p)
  ) nbf_counter
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (io_cmd_v_o & io_cmd_ready_i)
  ,.ready_i(1'b1)
  ,.yumi_i (io_resp_yumi_o)
  ,.count_o(credit_count_lo)
  );

  // bp_nbf packet
  typedef struct packed {
    logic [nbf_opcode_width_p-1:0] opcode;
    logic [nbf_addr_width_p-1:0]   addr;
    logic [nbf_data_width_p-1:0]   data;
  } bp_nbf_s;

  // bp_cce packet
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  bp_cce_mem_msg_s io_cmd, io_resp;
  logic io_cmd_v_lo;
  
  assign io_cmd_o = io_cmd;
  assign io_resp = io_resp_i;
  assign io_cmd_v_o = io_cmd_v_lo;

  // read nbf file
  logic incoming_nbf_v_lo, incoming_nbf_yumi_li;
  logic [nbf_num_flits_lp-1:0][stream_data_width_p-1:0] incoming_nbf;
  
  bsg_serial_in_parallel_out_full
 #(.width_p(stream_data_width_p)
  ,.els_p  (nbf_num_flits_lp)
  ) sipo
  (.clk_i  (clk_i)
  ,.reset_i(reset_i)
  ,.v_i    (stream_v_i)
  ,.ready_o(stream_ready_o)
  ,.data_i (stream_data_i)
  ,.data_o (incoming_nbf)
  ,.v_o    (incoming_nbf_v_lo)
  ,.yumi_i (incoming_nbf_yumi_li)
  );
  
  bp_nbf_s curr_nbf;
  assign curr_nbf = nbf_width_lp'(incoming_nbf);
  
  // assemble cce cmd packet
  always_comb
  begin

  end

  logic done_r, done_n;
  assign done_o = done_r & credits_empty_lo;
  
  logic [31:0] counter_r, counter_n;
  logic [1:0] state_r, state_n;
 
 // combinational
  always_comb 
  begin
  
    io_cmd.data = curr_nbf.data;
    io_cmd.payload = '0;
    io_cmd.addr = curr_nbf.addr;
    io_cmd.msg_type = e_cce_mem_uc_wr;
    
    case (curr_nbf.opcode)
      2: io_cmd.size = e_mem_size_4;
      3: io_cmd.size = e_mem_size_8;
      default: io_cmd.size = e_mem_size_4;
    endcase
  
    state_n = state_r;
    counter_n = counter_r;
    done_n = done_r;
    io_cmd_v_lo = 1'b0;
    incoming_nbf_yumi_li = 1'b0;
    
    if (state_r == 0)
      begin
        if (~reset_i)
          begin
            io_cmd_v_lo = 1'b1;
            io_cmd.data = '0;
            io_cmd.addr = counter_r;
            io_cmd.size = e_mem_size_8;
            if (io_cmd_ready_i)
              begin
                counter_n = counter_r + 32'h8;
                if (counter_r == 32'h84000000)
                  begin
                    counter_n = '0;
                    state_n = 1;
                  end
              end
          end
      end
    else if (state_r == 1)
      begin
        if (incoming_nbf_v_lo) 
          begin
            if (curr_nbf.opcode == 8'hFF)
              begin
                done_n = 1'b1;
                state_n = 2;
              end
            else 
              begin
                if (~credits_full_lo)
                  begin
                    io_cmd_v_lo = 1'b1;
                    if (io_cmd_ready_i)
                      begin
                        incoming_nbf_yumi_li = 1'b1;
                      end
                  end
              end
          end
      end
  end

  // sequential
  always_ff @(posedge clk_i)
    if (reset_i) 
      begin
        done_r <= 1'b0;
        state_r <= '0;
        counter_r <= 32'h80000000;
      end
    else 
      begin
        done_r <= done_n;
        state_r <= state_n;
        counter_r <= counter_n;
      end

endmodule

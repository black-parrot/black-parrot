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

 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

  ,parameter nbf_filename_p = "prog.nbf"
  ,parameter nbf_opcode_width_p = 8
  ,parameter nbf_addr_width_p = paddr_width_p
  ,parameter nbf_data_width_p = cce_block_width_p
  
  ,localparam nbf_width_lp = nbf_opcode_width_p + nbf_addr_width_p + nbf_data_width_p
  ,localparam max_nbf_index_lp = 2**20
  ,localparam nbf_index_width_lp = `BSG_SAFE_CLOG2(max_nbf_index_lp)
  )

  (input  clk_i
  ,input  reset_i
  ,output done_o
  
  ,output [cce_mem_msg_width_lp-1:0]        mem_cmd_o
  ,output                                   mem_cmd_v_o
  ,input                                    mem_cmd_ready_i
  
  ,input  [cce_mem_msg_width_lp-1:0]        mem_resp_i
  ,input                                    mem_resp_v_i
  ,output                                   mem_resp_yumi_o
  );
  
  // response network not used
  wire unused_resp = &{mem_resp_i, mem_resp_v_i};
  assign mem_resp_yumi_o = mem_resp_v_i;

  // bp_nbf packet
  typedef struct packed {
    logic [nbf_opcode_width_p-1:0] opcode;
    logic [nbf_addr_width_p-1:0]   addr;
    logic [nbf_data_width_p-1:0]   data;
  } bp_nbf_s;

  // bp_cce packet
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  bp_cce_mem_msg_s mem_cmd;
  logic mem_cmd_v_lo;
  
  assign mem_cmd_o = mem_cmd;
  assign mem_cmd_v_o = mem_cmd_v_lo;

  // read nbf file.
  logic [nbf_width_lp-1:0] nbf [max_nbf_index_lp-1:0];
  logic [nbf_index_width_lp-1:0] nbf_index_r, nbf_index_n;
  bp_nbf_s curr_nbf;
  assign curr_nbf = nbf[nbf_index_r];
  
  // assemble cce cmd packet
  always_comb
  begin
    mem_cmd.data = curr_nbf.data;
    mem_cmd.payload = '0;
    mem_cmd.addr = curr_nbf.addr;
    mem_cmd.msg_type = e_cce_mem_wb;
    
    case (curr_nbf.opcode)
      2: mem_cmd.size = e_mem_size_4;
      3: mem_cmd.size = e_mem_size_8;
      4: mem_cmd.size = e_mem_size_16;
      5: mem_cmd.size = e_mem_size_32;
      6: mem_cmd.size = e_mem_size_64;
      default: mem_cmd.size = e_mem_size_4;
    endcase
  end

  // read nbf file
  initial $readmemh(nbf_filename_p, nbf);

  logic done_r, done_n;
  assign done_o = done_r;
 
 // combinational
  always_comb 
  begin
    mem_cmd_v_lo = 1'b0;
    nbf_index_n = nbf_index_r;
    done_n = 1'b0;
    if (~reset_i) 
      begin
        if (curr_nbf.opcode == 8'hFF)
          begin
            done_n = 1'b1;
          end
        else 
          begin
            mem_cmd_v_lo = 1'b1;
            if (mem_cmd_ready_i)
              begin
                nbf_index_n = nbf_index_r + 1;
              end
          end
      end
  end

  // sequential
  always_ff @(posedge clk_i)
  begin
    if (reset_i)
      begin
        nbf_index_r <= '0;
        done_r <= 1'b0;
      end
    else 
      begin
        nbf_index_r <= nbf_index_n;
        done_r <= done_n;
      end
  end

endmodule

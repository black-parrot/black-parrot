
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_nonsynth_host
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_noc_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [mem_fwd_header_width_lp-1:0]            mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]               mem_fwd_data_i
   , input                                          mem_fwd_v_i
   , output logic                                   mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]     mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]        mem_rev_data_o
   , output logic                                   mem_rev_v_o
   , input                                          mem_rev_ready_and_i
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  localparam bedrock_reg_els_lp = 8;
  logic putint_r_v_li, signature_r_v_li, paramrom_r_v_li, bootrom_r_v_li, finish_r_v_li, getchar_r_v_li, putchar_r_v_li, putch_core_r_v_li;
  logic putint_w_v_li, signature_w_v_li, paramrom_w_v_li, bootrom_w_v_li, finish_w_v_li, getchar_w_v_li, putchar_w_v_li, putch_core_w_v_li;
  logic [dev_addr_width_gp-1:0] addr_lo;
  logic [`BSG_WIDTH(`BSG_SAFE_CLOG2(dword_width_gp/8))-1:0] size_lo;
  logic [dword_width_gp-1:0] data_lo;
  logic [bedrock_reg_els_lp-1:0][dword_width_gp-1:0] data_li;
  bp_me_bedrock_register
   #(.bp_params_p(bp_params_p)
     ,.reg_data_width_p(dword_width_gp)
     ,.reg_addr_width_p(dev_addr_width_gp)
     ,.els_p(bedrock_reg_els_lp)
     ,.base_addr_p({putint_match_addr_gp, signature_match_addr_gp, paramrom_match_addr_gp, bootrom_match_addr_gp, finish_match_addr_gp, getchar_match_addr_gp, putchar_match_addr_gp, putch_core_match_addr_gp})
     )
   register
    (.*
     ,.r_v_o({putint_r_v_li, signature_r_v_li, paramrom_r_v_li, bootrom_r_v_li, finish_r_v_li, getchar_r_v_li, putchar_r_v_li, putch_core_r_v_li})
     ,.w_v_o({putint_w_v_li, signature_w_v_li, paramrom_w_v_li, bootrom_w_v_li, finish_w_v_li, getchar_w_v_li, putchar_w_v_li, putch_core_w_v_li})
     ,.addr_o(addr_lo)
     ,.size_o(size_lo)
     ,.data_o(data_lo)
     ,.data_i(data_li)
     );
  localparam byte_offset_width_lp = 3;
  wire [core_id_width_p-1:0] addr_core_enc = addr_lo[byte_offset_width_lp+:core_id_width_p];

  localparam param_els_lp = `BSG_CDIV($bits(proc_param_lp),word_width_gp);
  localparam lg_param_els_lp = `BSG_SAFE_CLOG2(param_els_lp);
  logic [lg_param_els_lp-1:0] paramrom_addr_li;
  logic [word_width_gp-1:0] paramrom_data_lo;
  // Reverse address to index in reverse struct order
  assign paramrom_addr_li = param_els_lp-1'b1-addr_lo[2+:lg_param_els_lp];
  bsg_rom_param
   #(.data_p(proc_param_lp)
     ,.data_width_p($bits(proc_param_lp))
     ,.width_p(word_width_gp)
     ,.els_p(param_els_lp)
     )
   param_rom
    (.addr_i(paramrom_addr_li)
     ,.data_o(paramrom_data_lo)
     );
  wire [bedrock_block_width_p-1:0] paramrom_final_lo = {bedrock_block_width_p/word_width_gp{paramrom_data_lo}};

  int stdout[num_core_p];
  int stdout_global;
  int signature;

  initial
    begin
      for (int j = 0; j < num_core_p; j++)
        stdout[j] = $fopen($sformatf("stdout_%0x.txt", j), "w");
      stdout_global = $fopen("stdout_global.txt", "w");
      signature = $fopen("DUT-blackparrot.signature", "w");
    end

  always_ff @(negedge clk_i)
    if (putint_w_v_li)
      begin
        $write("%x", data_lo[0+:dword_width_gp]);
        $fwrite(stdout_global, "%x", data_lo[0+:dword_width_gp]);
      end
    else if (putchar_w_v_li)
      begin
        $write("%c", data_lo[0+:byte_width_gp]);
        $fwrite(stdout_global, "%c", data_lo[0+:byte_width_gp]);
      end
    else if (putch_core_w_v_li)
      begin
        $write("%c", data_lo[0+:byte_width_gp]);
        $fwrite(stdout[addr_core_enc], "%c", data_lo[0+:byte_width_gp]);
      end
    else if (signature_w_v_li)
      begin
        $write("%8x", data_lo[0+:word_width_gp]);
        $fwrite(signature, "%8x\n", data_lo[0+:word_width_gp]);
      end
    else if (finish_w_v_li && ~|data_lo[0+:byte_width_gp])
      begin
        $display("[CORE FSH] PASS\n\tterminating...");
        $display("[BSG-PASS]");
        $finish;
      end
    else if (finish_w_v_li && |data_lo[0+:byte_width_gp])
      begin
        $display("[CORE FSH] FAIL\n\tterminating...");
        $display("[BSG-FAIL]");
        $finish;
      end

  final
    begin
      $fclose(signature);
      $fclose(stdout_global);
      for (int j = 0; j < num_core_p; j++)
        $fclose(stdout[j]);
    end

  assign data_li[0] = '0;
  assign data_li[1] = '0;
  assign data_li[2] = '0;
  assign data_li[3] = '0;
  assign data_li[4] = '0;
  assign data_li[5] = paramrom_final_lo;

endmodule


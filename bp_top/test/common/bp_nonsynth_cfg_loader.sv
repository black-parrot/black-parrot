
`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"

module bp_nonsynth_cfg_loader
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , parameter ucode_str_p = "ucode_mem"
   )
  (input                                        clk_i
   , input                                      reset_i

   , input [lce_id_width_p-1:0]                 lce_id_i
   , input [did_width_p-1:0]                    did_i

   , output logic [mem_fwd_header_width_lp-1:0] mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]    mem_fwd_data_o
   , output logic                               mem_fwd_v_o
   , input                                      mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]        mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]           mem_rev_data_i
   , input                                      mem_rev_v_i
   , output logic                               mem_rev_ready_and_o

   , output logic                               done_o
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
  `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

  task automatic write_register(
      input longint core,
      input longint base_addr,
      input longint offset,
      input longint data
  );
  longint addr = cfg_base_addr_gp + (core << core_offset_width_gp) + base_addr + (offset << 3);
    begin
      mem_fwd_header_cast_o.payload.lce_id = lce_id_i;
      mem_fwd_header_cast_o.payload.src_did = did_i;
      mem_fwd_header_cast_o.addr = addr;
      mem_fwd_header_cast_o.msg_type.fwd = e_bedrock_mem_wr;
      mem_fwd_header_cast_o.subop = e_bedrock_store;
      mem_fwd_header_cast_o.size = e_bedrock_msg_size_8;
      mem_fwd_data_o = data;
      mem_fwd_v_o = 1'b1;
      do @(posedge clk_i); while (!mem_fwd_ready_and_i);
      mem_fwd_v_o = 1'b0;
    end
  endtask

  string ucode_file;
  logic [dword_width_gp-1:0] ucode_mem [0:num_cce_instr_ram_els_p-1];
  initial
    if ($value$plusargs({ucode_str_p,"=%s"}, ucode_file))
      begin
        $display("BSG-INFO: Initalizing ucode with ucode_str=%s", ucode_file);
        $readmemb(ucode_file, ucode_mem);
      end

  assign mem_rev_ready_and_o = 1'b1;
  initial
    begin
      mem_fwd_header_cast_o = '0;
      mem_fwd_data_o = '0;
      mem_fwd_v_o = 1'b0;
      done_o = 1'b0;

      for (int i = 0; i < 5; i++) @(posedge clk_i);
      @(negedge reset_i);
      for (int i = 0; i < 5; i++) @(posedge clk_i);
      for (int j = 0; j < num_core_p; j++) write_register(j, cfg_reg_freeze_gp, 0, e_core_status_freeze);
      for (int i = 0; i < 5; i++) @(posedge clk_i);
      for (int j = 0; j < num_core_p; j++)
        begin
          if (cce_type_p == e_cce_ucode) for (int k = 0; k < num_cce_instr_ram_els_p; k++)
            write_register(j, cfg_mem_cce_ucode_base_gp, k, ucode_mem[k]);
          if (cce_type_p != e_cce_uce)
            write_register(j, cfg_reg_cce_mode_gp, 0, e_cce_mode_normal);
          write_register(j, cfg_reg_icache_mode_gp, 0, e_lce_mode_normal);
          write_register(j, cfg_reg_dcache_mode_gp, 0, e_lce_mode_normal);
          write_register(j, cfg_reg_npc_gp, 0, dram_base_addr_gp);
        end
      for (int i = 0; i < 5; i++) @(posedge clk_i);
      for (int j = 0; j < num_core_p; j++) write_register(j, cfg_reg_freeze_gp, 0, e_core_status_run);

      for (int i = 0; i < 5; i++) @(posedge clk_i);
      done_o = 1'b1;
    end

endmodule


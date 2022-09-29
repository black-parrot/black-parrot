
`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_fe_nonsynth_icache_tracer
 import bp_common_pkg::*;
 import bp_fe_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   , parameter assoc_p = 8
   , parameter sets_p = 64
   , parameter block_width_p = 512
   , parameter fill_width_p = 512
   , parameter trace_file_p = "icache"
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)

   // Calculated parameters
   , localparam mhartid_width_lp = `BSG_SAFE_CLOG2(num_core_p)
   , localparam bank_width_lp = block_width_p / assoc_p
   , localparam icache_pkt_width_lp = `bp_fe_icache_pkt_width(vaddr_width_p)
   )
  (input                                                  clk_i
   , input                                                reset_i
   , input                                                freeze_i
   , input [mhartid_width_lp-1:0]                         mhartid_i

   , input [icache_pkt_width_lp-1:0]                      icache_pkt_i
   , input                                                v_i
   , input                                                force_i
   , input                                                yumi_o

   , input [instr_width_gp-1:0]                           data_o
   , input                                                data_v_o
   , input                                                spec_v_o

   , input [cache_req_width_lp-1:0]                       cache_req_o
   , input                                                cache_req_v_o
   , input                                                cache_req_ready_and_i
   , input                                                cache_req_busy_i
   , input [cache_req_metadata_width_lp-1:0]              cache_req_metadata_o
   , input                                                cache_req_metadata_v_o
   , input                                                cache_req_critical_tag_i
   , input                                                cache_req_critical_data_i
   , input                                                cache_req_complete_i
   // Unused
   , input                                                cache_req_credits_full_i
   , input                                                cache_req_credits_empty_i

   , input                                                data_mem_pkt_v_i
   , input [cache_data_mem_pkt_width_lp-1:0]              data_mem_pkt_i
   , input                                                data_mem_pkt_yumi_o
   , input [block_width_p-1:0]                            data_mem_o

   , input                                                tag_mem_pkt_v_i
   , input [cache_tag_mem_pkt_width_lp-1:0]               tag_mem_pkt_i
   , input                                                tag_mem_pkt_yumi_o
   , input [cache_tag_info_width_lp-1:0]                  tag_mem_o

   , input                                                stat_mem_pkt_v_i
   , input [cache_stat_mem_pkt_width_lp-1:0]              stat_mem_pkt_i
   , input                                                stat_mem_pkt_yumi_o
   , input [cache_stat_info_width_lp-1:0]                 stat_mem_o

   , input [paddr_width_p-1:0]                            paddr_tv_r
   );

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `declare_bp_fe_icache_pkt_s(vaddr_width_p);
  bp_fe_icache_pkt_s icache_pkt_cast_i;
  assign icache_pkt_cast_i = icache_pkt_i;

  bp_cache_req_s cache_req_cast_o;
  bp_cache_req_metadata_s cache_req_metadata_cast_o;
  assign cache_req_cast_o = cache_req_o;
  assign cache_req_metadata_cast_o = cache_req_metadata_o;

  bp_cache_data_mem_pkt_s data_mem_pkt_cast_i;
  bp_cache_tag_mem_pkt_s tag_mem_pkt_cast_i;
  bp_cache_stat_mem_pkt_s stat_mem_pkt_cast_i;
  assign data_mem_pkt_cast_i = data_mem_pkt_i;
  assign tag_mem_pkt_cast_i = tag_mem_pkt_i;
  assign stat_mem_pkt_cast_i = stat_mem_pkt_i;

  logic [assoc_p-1:0][bank_width_lp-1:0] data_mem_cast_o;
  bp_cache_tag_info_s tag_mem_info_cast_o;
  bp_cache_tag_info_s stat_mem_info_cast_o;
  assign data_mem_cast_o = data_mem_o;
  assign tag_mem_info_cast_o = tag_mem_o;
  assign stat_mem_info_cast_o = stat_mem_o;

  integer file;
  string file_name;
  wire delay_li = reset_i | freeze_i;
  always_ff @(negedge delay_li)
   begin
     file_name = $sformatf("%s_%x.trace", trace_file_p, mhartid_i);
     file      = $fopen(file_name, "w");
     $fwrite(file, "Coherent L1: %x\n", icache_coherent_p);
   end

  logic data_mem_read_r, tag_mem_read_r, stat_mem_read_r;
  always_ff @(posedge clk_i)
    if (reset_i)
      begin
        data_mem_read_r <= '0;
        tag_mem_read_r <= '0;
        stat_mem_read_r <= '0;
      end
    else
      begin
        data_mem_read_r <= data_mem_pkt_yumi_o & (data_mem_pkt_cast_i.opcode == e_cache_data_mem_read);
        tag_mem_read_r <= tag_mem_pkt_yumi_o & (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_read);
        stat_mem_read_r <= stat_mem_pkt_yumi_o & (stat_mem_pkt_cast_i.opcode == e_cache_stat_mem_read);
      end

  always_ff @(posedge clk_i)
    begin
      if (yumi_o)
        $fwrite(file, "%12t | access: %p\n", $time, icache_pkt_cast_i);

      if (data_mem_pkt_yumi_o)
        $fwrite(file, "%12t | data_mem_pkt: %p\n", $time, data_mem_pkt_cast_i);
      if (data_mem_read_r)
        $fwrite(file, "%12t | data_mem_read: %x\n", $time, data_mem_cast_o);

      if (tag_mem_pkt_yumi_o)
        $fwrite(file, "%12t | tag_mem_pkt: %p\n", $time, tag_mem_pkt_cast_i);
      if (tag_mem_read_r)
        $fwrite(file, "%12t | tag_mem_read: %x\n", $time, tag_mem_info_cast_o);

      if (stat_mem_pkt_yumi_o)
        $fwrite(file, "%12t | stat_mem_pkt: %p\n", $time, stat_mem_pkt_cast_i);
      if (stat_mem_read_r)
        $fwrite(file, "%12t | stat_mem_read: %x\n", $time, stat_mem_info_cast_o);

      if (data_v_o)
        $fwrite(file, "%12t | fetch: [%x]->%x\n", $time, paddr_tv_r, data_o);
      if (spec_v_o)
        $fwrite(file, "%12t | spec miss: [%x]\n", $time, paddr_tv_r);

      if (cache_req_ready_and_i & cache_req_v_o)
        $fwrite(file, "%12t | cache_req: %p\n", $time, cache_req_cast_o);

      if (cache_req_metadata_v_o)
        $fwrite(file, "%12t | cache_req_metadata: %p\n", $time, cache_req_metadata_cast_o);

      if (cache_req_critical_tag_i)
        $fwrite(file, "%12t | cache_req_critical_tag_i raised\n", $time);

      if (cache_req_critical_data_i)
        $fwrite(file, "%12t | cache_req_critical_data_i raised\n", $time);

      if (cache_req_complete_i)
        $fwrite(file, "%12t | cache_req_complete_i raised\n", $time);
    end

endmodule


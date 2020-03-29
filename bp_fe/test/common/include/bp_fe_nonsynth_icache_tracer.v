module bp_fe_nonsynth_icache_tracer
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_fe_pkg::*;
  import bp_fe_icache_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  
  , parameter icache_trace_file_p = "icache"
  // I-Cache Widths
  , localparam bp_be_icache_stat_width_lp = `bp_be_dcache_stat_info_width(icache_assoc_p)
  
  , localparam mhartid_width_lp      = `BSG_SAFE_CLOG2(num_core_p)
  , localparam block_size_in_words_lp=icache_assoc_p
  , localparam cache_block_multiplier_width_lp = 2**(3-`BSG_SAFE_CLOG2(dcache_assoc_p))
  , localparam cache_block_width_lp = dword_width_p * cache_block_multiplier_width_lp
  , localparam data_mem_mask_width_lp=(cache_block_width_lp>>3)
  , localparam bypass_data_width_lp = (dword_width_p >> 3)
  , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(cache_block_width_lp>>3)
  , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
  , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
  , localparam index_width_lp=`BSG_SAFE_CLOG2(lce_sets_p)
  , localparam tag_width_lp=(paddr_width_p-block_offset_width_lp-index_width_lp)
  , localparam way_id_width_lp=`BSG_SAFE_CLOG2(lce_assoc_p)

  , localparam lce_data_width_lp=(lce_assoc_p*dword_width_p)
  `declare_bp_icache_widths(vaddr_width_p, tag_width_lp, icache_assoc_p) 
  `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, lce_sets_p, icache_assoc_p, dword_width_p, cce_block_width_p, icache)

  )
  ( input                                    clk_i
  , input                                    reset_i
  , input 				     freeze_i
	
  , input [instr_width_p-1:0]                data_o
  , input                                    data_v_o
  , input				     miss_o

  , input				     v_tl_r
  , input				     v_tv_r

  , input                                    cache_req_ready_i
  , input [icache_req_width_lp-1:0]          cache_req_o
  , input                                    cache_req_v_o
  , input [icache_req_metadata_width_lp-1:0] cache_req_metadata_o
  , input				     cache_req_metadata_v_o

  , input				     cache_req_complete_i

  , input 			             data_mem_pkt_v_i
  , input [icache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
  , input [cce_block_width_p-1:0]            data_mem_o
  , input 			             data_mem_pkt_ready_o

  , input 			             tag_mem_pkt_v_i
  , input [icache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_i
  , input [tag_width_lp-1:0]                 tag_mem_o
  , input 				     tag_mem_pkt_ready_o

  , input 				     stat_mem_pkt_v_i
  , input [icache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
  , input [bp_be_icache_stat_width_lp-1:0]   stat_mem_o
  , input 				     stat_mem_pkt_ready_o
  );

`declare_bp_cache_service_if(paddr_width_p, ptag_width_p, lce_sets_p, icache_assoc_p, dword_width_p, cce_block_width_p, icache);
bp_icache_req_s cache_req_cast_lo;
bp_icache_req_metadata_s cache_req_metadata_cast_lo;
assign cache_req_cast_lo = cache_req_o;
assign cache_req_metadata_cast_lo = cache_req_metadata_o;

bp_icache_data_mem_pkt_s data_mem_pkt_cast_i;
bp_icache_tag_mem_pkt_s tag_mem_pkt_cast_i;
bp_icache_stat_mem_pkt_s stat_mem_pkt_cast_i;
assign data_mem_pkt_cast_i = data_mem_pkt_i;
assign tag_mem_pkt_cast_i = tag_mem_pkt_i;
assign stat_mem_pkt_cast_i = stat_mem_pkt_i;

integer file;
string file_name;

always_ff @(negedge reset_i | freeze_i)
  begin
    file_name = $sformatf("%s.trace", icache_trace_file_p);
    file      = $fopen(file_name, "w");
  end

always_ff @(posedge clk_i)
	begin

		if(v_tl_r) 
			begin
				$fwrite(file, "Tag Lookup stage activated at time [%t]\n", $time);
			end

		if(v_tv_r)
			begin
				$fwrite(file, "Tag Verify stage activated at time [%t]\n", $time);
			end


		if(cache_req_v_o)
			begin
				$fwrite(file, "Cache request sent at time [%t]\n", $time);
				$fwrite(file, "LCE Ready to accept cache miss? %x\n", cache_req_ready_i);
				$fwrite(file, "Is the system coherent? %x\n", coherent_l1_p);
				$fwrite(file, "Address = %x\n Data = %x\n Message Type = %x\n", cache_req_cast_lo.addr, cache_req_cast_lo.data, cache_req_cast_lo.msg_type);
				$fwrite(file, "\n");
			end

		if(cache_req_metadata_v_o)
			begin
				$fwrite(file, "Cache request metadata sent at time [%t]\n", $time);
				$fwrite(file, "Replacement way = %x\n Dirty = %x\n", cache_req_metadata_cast_lo.repl_way, cache_req_metadata_cast_lo.dirty);
			end

		if(~miss_o)
			begin
				$fwrite(file, "Is the miss resolved? - %x\n", miss_o);
			end

		if(data_v_o)
			begin
				$fwrite(file, "Instruction sent to the processor at time [%t]\n", $time);
				$fwrite(file, "Instruction sent - %x\n", data_o);
			end

		if(data_mem_pkt_v_i)
			begin
				$fwrite(file, "LCE Data Pkt Received at time [%t]\n", $time);
				$fwrite(file, "Index = %x\n Way ID = %x\n Data = %x\n Opcode = %x\n", data_mem_pkt_cast_i.index, data_mem_pkt_cast_i.way_id, data_mem_pkt_cast_i.data, data_mem_pkt_cast_i.opcode);
				$fwrite(file, "\n");
			end

		if(tag_mem_pkt_v_i)
			begin
				$fwrite(file, "LCE Tag Pkt Received at time [%t]\n", $time);
				$fwrite(file, "Index = %x\n Way ID = %x\n State = %x\n Tag = %x\n", tag_mem_pkt_cast_i.index, tag_mem_pkt_cast_i.way_id, tag_mem_pkt_cast_i.tag, tag_mem_pkt_cast_i.state);
        			$fwrite(file, "Cache Ready - Tag? %x\n", tag_mem_pkt_ready_o);
				$fwrite(file, "\n");
			end

		if(stat_mem_pkt_v_i)
			begin
				$fwrite(file, "LCE Stat Pkt Received at time [%t]\n", $time);
				$fwrite(file, "Index = %x\n Way ID = %x\n Opcode = %x\n", stat_mem_pkt_cast_i.index, stat_mem_pkt_cast_i.way_id, stat_mem_pkt_cast_i.opcode);
        			$fwrite(file, "Cache Ready - Stat? %x\n", tag_mem_pkt_ready_o);
				$fwrite(file, "\n");
			end

	end
endmodule

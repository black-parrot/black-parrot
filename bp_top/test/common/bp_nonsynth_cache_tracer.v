
module bp_nonsynth_cache_tracer
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 #( parameter bp_params_e bp_params_p = e_bp_inv_cfg
  , parameter assoc_p = 8
  , parameter sets_p = 64
  , parameter block_width_p = 512 
  , parameter trace_file_p = "dcache"
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, cache)

   // Calculated parameters
   , localparam mhartid_width_lp = `BSG_SAFE_CLOG2(num_core_p)
   , localparam block_size_in_words_lp=assoc_p
   , localparam bank_width_lp = block_width_p / assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam data_mem_mask_width_lp=(bank_width_lp>>3)
   , localparam bypass_data_width_lp = (dword_width_p >> 3)
   , localparam byte_offset_width_lp=`BSG_SAFE_CLOG2(bank_width_lp>>3)
   , localparam word_offset_width_lp=`BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam block_offset_width_lp=(word_offset_width_lp+byte_offset_width_lp)
   , localparam index_width_lp=`BSG_SAFE_CLOG2(sets_p)
   , localparam ptag_width_lp=(paddr_width_p-bp_page_offset_width_gp)
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(assoc_p)
  
   )
  (  input                                                 clk_i
   , input                                                 reset_i
   
   , input                                                 freeze_i
   , input [mhartid_width_lp-1:0]                          mhartid_i
      
   // Tag lookup
   , input                                                 v_tl_r
   
   // Tag Verify
   , input                                                 v_tv_r
   , input [paddr_width_p-1:0]                             addr_tv_r
   , input                                                 lr_miss_tv
   , input                                                 sc_op_tv_r
   , input                                                 sc_success

   // Miss Packet
   , input                                                 cache_req_v_o
   , input [cache_req_width_lp-1:0]                        cache_req_o

   // Cache Metadata
   , input [cache_req_metadata_width_lp-1:0]               cache_req_metadata_o 
   , input                                                 cache_req_metadata_v_o

   , input                                                 cache_req_complete_i

   // Cache data
   , input                                                 v_o
   , input [dword_width_p-1:0]                             load_data
   , input                                                 cache_miss_o
   , input [dword_width_p-1:0]                             store_data

   // Fill Packets
   , input                                                 data_mem_pkt_v_i
   , input [cache_data_mem_pkt_width_lp-1:0]               data_mem_pkt_i
   , input                                                 data_mem_pkt_ready_o

   , input                                                 tag_mem_pkt_v_i
   , input [cache_tag_mem_pkt_width_lp-1:0]                tag_mem_pkt_i
   , input                                                 tag_mem_pkt_ready_o

   , input                                                 stat_mem_pkt_v_i
   , input [cache_stat_mem_pkt_width_lp-1:0]               stat_mem_pkt_i
   , input                                                 stat_mem_pkt_ready_o
   );

  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, sets_p, assoc_p, dword_width_p, block_width_p, cache);

  // Input Casting  
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

  integer file;
  string file_name;
  
  wire delay_li = reset_i | freeze_i;
  always_ff @(negedge delay_li)
   begin
     file_name = $sformatf("%s_%x.trace", trace_file_p, mhartid_i);
     file      = $fopen(file_name, "w");
     $fwrite(file, "Coherent L1: %x\n", coherent_l1_p);
   end

  string op, data_op, tag_op, stat_op;

  always_comb begin
    if (lr_miss_tv & cache_req_v_o)
      op = "[lr]";
    else if(sc_op_tv_r)
      op = "[sc]";
    else if (cache_req_v_o & cache_req_cast_o.msg_type == e_miss_store)
      op = "[store]";
    else if (cache_req_v_o & cache_req_cast_o.msg_type == e_miss_load)
      op = "[load]";
    else if (cache_req_v_o & cache_req_cast_o.msg_type == e_uc_load)
      op = "[uncached load]";
    else if (cache_req_v_o & cache_req_cast_o.msg_type == e_uc_store)
      op = "[uncached store]";
    else if (cache_req_v_o & cache_req_cast_o.msg_type == e_cache_flush)
      op = "[fencei req]";
    else if (cache_req_v_o & cache_req_cast_o.msg_type == e_cache_clear)
      op = "[fencei req]";
    else
      op = "[null]";
  end

  always_comb begin
    if (data_mem_pkt_cast_i.opcode == e_cache_data_mem_read)
      data_op = "[read]";
    else if (data_mem_pkt_cast_i.opcode == e_cache_data_mem_uncached)
      data_op = "[uncached]";
    else if (data_mem_pkt_cast_i.opcode == e_cache_data_mem_write)
      data_op = "[write]";
    else
      data_op = "[null]";
    
    if (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_set_clear)
      tag_op = "[set clear]";
    else if (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_set_tag)
      tag_op = "[set tag]";
    else if (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_invalidate)
      tag_op = "[invalidate]";
    else if (tag_mem_pkt_cast_i.opcode == e_cache_tag_mem_read)
      tag_op = "[read]";
    else
      tag_op = "[null]";
    
    if (stat_mem_pkt_cast_i.opcode == e_cache_stat_mem_read)
      stat_op = "[read]";
    else if (stat_mem_pkt_cast_i.opcode == e_cache_stat_mem_set_clear)
      stat_op = "[set clear]";
    else if (stat_mem_pkt_cast_i.opcode == e_cache_stat_mem_clear_dirty)
      stat_op = "[clear dirty]";
    else
      stat_op = "[null]";
  end

  always_ff @(posedge clk_i) begin
 
      if(v_tl_r) 
        $fwrite(file, "[%t] tag_lookup: %x \n", $time, v_tl_r);
      
      if(v_tv_r) begin
        $fwrite(file, "[%t] tag_verify: %x \n", $time, v_tv_r);
        $fwrite(file, "[%t] addr: %x \n", $time, addr_tv_r);
      end
      
      if(sc_success)
        $fwrite(file, "SC SUCCESS! \n");
      
      if (cache_req_v_o) begin
        $fwrite(file, "[%t] valid cache_req: %x \n", $time, cache_req_v_o);
        $fwrite(file, "[%t] %s addr: %x data: %x cache_miss: %x \n", $time, op, cache_req_cast_o.addr, cache_req_cast_o.data, cache_miss_o);
      end

      if (cache_req_metadata_v_o)
        $fwrite(file, "[%t] lru_way: %x dirty: %x \n", $time, cache_req_metadata_cast_o.repl_way, cache_req_metadata_cast_o.dirty);
      
      if (cache_req_complete_i)
        $fwrite(file, "[%t] Cache request completed \n", $time);

      if (data_mem_pkt_v_i)
        $fwrite(file, "[%t] Data Mem: op: %s index: %x way: %x  data: %x \n", $time, data_op, data_mem_pkt_cast_i.index, data_mem_pkt_cast_i.way_id, data_mem_pkt_cast_i.data);

      if (tag_mem_pkt_v_i)
        $fwrite(file, "[%t] Tag Mem: op: %s index: %x way: %x tag: %x state: %x \n", $time, tag_op, tag_mem_pkt_cast_i.index, tag_mem_pkt_cast_i.way_id, tag_mem_pkt_cast_i.tag, tag_mem_pkt_cast_i.state);

      if (stat_mem_pkt_v_i)
        $fwrite(file, "[%t] Stat Mem: op: %s, index: %x way: %x\n", $time, stat_op, stat_mem_pkt_cast_i.index, stat_mem_pkt_cast_i.way_id);

      if (v_o)
        $fwrite(file, "[%t] load data: %x \n", $time, load_data);

      if (cache_req_v_o & (cache_req_cast_o.msg_type == e_miss_store || cache_req_cast_o.msg_type == e_uc_store))
        $fwrite(file, "[%t] store data: %x \n", $time, store_data);
    end

endmodule

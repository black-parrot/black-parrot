/**
 *
 *  Name:
 *    bp_be_mem_top.v
 *
 *  Description:
 *    memory management unit.
 *
 */

module bp_be_mem_top
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_be_pkg::*;
  import bp_common_rv64_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache)

   // Generated parameters
   // D$
   , localparam bank_width_lp = dcache_block_width_p / dcache_assoc_p
   , localparam num_dwords_per_bank_lp = bank_width_lp / dword_width_p
   , localparam data_mem_mask_width_lp = (bank_width_lp >> 3) // Byte mask
   , localparam bypass_data_mask_width_lp = (dword_width_p >> 3)
   , localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(bank_width_lp >> 3)
   , localparam bank_offset_width_lp   = `BSG_SAFE_CLOG2(dcache_assoc_p)
   , localparam block_offset_width_lp  = (bank_offset_width_lp + byte_offset_width_lp)
   , localparam index_width_lp         = `BSG_SAFE_CLOG2(dcache_sets_p)
   , localparam page_offset_width_lp   = (block_offset_width_lp + index_width_lp)
   , localparam way_id_width_lp=`BSG_SAFE_CLOG2(dcache_assoc_p)

   , localparam stat_info_width_lp = `bp_cache_stat_info_width(dcache_assoc_p)

   , localparam cfg_bus_width_lp      = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)

   , localparam trap_pkt_width_lp      = `bp_be_trap_pkt_width(vaddr_width_p)
   , localparam ptw_miss_pkt_width_lp  = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp  = `bp_be_ptw_fill_pkt_width(vaddr_width_p)

   // MMU
   , localparam mem_cmd_width_lp  = `bp_be_mem_cmd_width(vaddr_width_p)
   , localparam mem_resp_width_lp = `bp_be_mem_resp_width(vaddr_width_p)

   // VM
   , localparam tlb_entry_width_lp = `bp_pte_entry_leaf_width(paddr_width_p)
   )
  (input                                     clk_i
   , input                                   reset_i

   , input [cfg_bus_width_lp-1:0]            cfg_bus_i

   , input [mem_cmd_width_lp-1:0]            mem_cmd_i
   , input                                   mem_cmd_v_i
   , output                                  mem_cmd_ready_o

   , input                                   chk_poison_ex_i

   , output [mem_resp_width_lp-1:0]          mem_resp_o
   , output                                  mem_resp_v_o

   , input [ptw_miss_pkt_width_lp-1:0]       ptw_miss_pkt_i
   , output [ptw_fill_pkt_width_lp-1:0]      ptw_fill_pkt_o

   , input [rv64_priv_width_gp-1:0]          priv_mode_i
   , input [ptag_width_p-1:0]                satp_ppn_i
   , input                                   translation_en_i
   , input                                   mstatus_sum_i
   , input                                   mstatus_mxr_i
   , input                                   sfence_i

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]         cache_req_o
   , output logic                                   cache_req_v_o
   , input                                          cache_req_ready_i
   , output logic [dcache_req_metadata_width_lp-1:0]cache_req_metadata_o
   , output logic                                   cache_req_metadata_v_o

   , input cache_req_complete_i
   , input cache_req_critical_i

   // data_mem
   , input data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
   , output logic data_mem_pkt_yumi_o
   , output logic [dcache_block_width_p-1:0] data_mem_o

   // tag_mem
   , input tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_i
   , output logic tag_mem_pkt_yumi_o
   , output logic [ptag_width_p-1:0] tag_mem_o

   // stat_mem
   , input stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
   , output logic stat_mem_pkt_yumi_o
   , output logic [stat_info_width_lp-1:0] stat_mem_o
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
// Not sure if this is right.
`declare_bp_be_mem_structs(vaddr_width_p, ptag_width_p, dcache_sets_p, dcache_block_width_p/8)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, dword_width_p);
`declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache);
  bp_dcache_req_s cache_req_cast_o;

  assign cache_req_o = cache_req_cast_o;

// Cast input and output ports
bp_cfg_bus_s           cfg_bus;
bp_be_mem_cmd_s        mem_cmd;
bp_be_mem_resp_s       mem_resp;
bp_be_mem_vaddr_s      mem_cmd_vaddr;
bp_be_commit_pkt_s     commit_pkt;
bp_be_trap_pkt_s       trap_pkt;
bp_be_ptw_miss_pkt_s   ptw_miss_pkt;
bp_be_ptw_fill_pkt_s   ptw_fill_pkt;

assign cfg_bus = cfg_bus_i;
assign mem_cmd = mem_cmd_i;

assign mem_resp_o = mem_resp;

assign ptw_miss_pkt = ptw_miss_pkt_i;
assign ptw_fill_pkt_o = ptw_fill_pkt;

/* Internal connections */
/* TLB ports */
logic                    dtlb_en, dtlb_miss_v, dtlb_w_v, dtlb_r_v, dtlb_r_v_lo;
logic [vtag_width_p-1:0] dtlb_r_vtag, dtlb_w_vtag;
bp_pte_entry_leaf_s      dtlb_r_entry, dtlb_w_entry;


/* PTW ports */
logic [ptag_width_p-1:0]  ptw_dcache_ptag;
logic                     ptw_dcache_ptag_v;
logic                     ptw_dcache_v, ptw_busy;
bp_be_dcache_pkt_s        ptw_dcache_pkt;

/* D-Cache ports */
bp_be_dcache_pkt_s        dcache_pkt;
logic [dword_width_p-1:0] dcache_data;
logic [ptag_width_p-1:0]  dcache_ptag;
logic                     dcache_v, dcache_fencei_v, dcache_pkt_v;
logic                     dcache_ptag_v;
logic                     dcache_uncached;
logic                     dcache_ready_lo;
logic                     dcache_miss_lo;

logic load_access_fault_v, load_access_fault_mem3, store_access_fault_v, store_access_fault_mem3;
logic load_page_fault_v, load_page_fault_mem3, store_page_fault_v, store_page_fault_mem3;

/* Control signals */
logic dcache_cmd_v;
logic fencei_cmd_v;
logic itlb_not_dtlb_resp;
logic is_store_r;
logic is_fencei_r, is_fencei_rr;
logic mem_cmd_v_r, mem_cmd_v_rr, dtlb_miss_r;
bp_be_mem_vaddr_s vaddr_mem3;

wire is_store  = mem_cmd_v_i & mem_cmd.mem_op inside {e_sb, e_sh, e_sw, e_sd, e_scw, e_scd};
wire is_fencei = mem_cmd_v_i & mem_cmd.mem_op inside {e_fencei};

bsg_dff_chain
 #(.width_p(vaddr_width_p)
   ,.num_stages_p(2)
   )
 vaddr_pipe
  (.clk_i(clk_i)

   ,.data_i(mem_cmd.vaddr)
   ,.data_o(vaddr_mem3)
   );

bp_tlb
  #(.bp_params_p(bp_params_p)
    ,.tlb_els_p(dtlb_els_p)
  )
  dtlb
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.flush_i(sfence_i)
   ,.translation_en_i(translation_en_i)

   ,.v_i(dtlb_r_v | dtlb_w_v)
   ,.w_i(dtlb_w_v)
   ,.vtag_i((dtlb_w_v)? dtlb_w_vtag : dtlb_r_vtag)
   ,.entry_i(dtlb_w_entry)

   ,.entry_o(dtlb_r_entry)
   ,.v_o(dtlb_r_v_lo)
   ,.miss_v_o(dtlb_miss_v)
  );

bp_pma
 #(.bp_params_p(bp_params_p))
 pma
  (.ptag_v_i(dtlb_r_v_lo)
   ,.ptag_i(dtlb_r_entry.ptag)

   ,.uncached_o(dcache_uncached)
   );

bp_be_ptw
  #(.bp_params_p(bp_params_p))
  ptw
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.base_ppn_i(satp_ppn_i)
   ,.priv_mode_i(priv_mode_i)
   ,.mstatus_sum_i(mstatus_sum_i)
   ,.mstatus_mxr_i(mstatus_mxr_i)
   ,.busy_o(ptw_busy)

   ,.ptw_miss_pkt_i(ptw_miss_pkt)
   ,.ptw_fill_pkt_o(ptw_fill_pkt)

   ,.dcache_v_i(dcache_v)
   ,.dcache_data_i(dcache_data)

   ,.dcache_v_o(ptw_dcache_v)
   ,.dcache_pkt_o(ptw_dcache_pkt)
   ,.dcache_ptag_o(ptw_dcache_ptag)
   ,.dcache_ptag_v_o(ptw_dcache_ptag_v)
   ,.dcache_rdy_i(dcache_ready_lo) 
   ,.dcache_miss_i(dcache_miss_lo)
  );

bp_be_dcache
  #(.bp_params_p(bp_params_p))
  dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.cfg_bus_i(cfg_bus_i)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(dcache_pkt_v)
    ,.ready_o(dcache_ready_lo)

    ,.v_o(dcache_v)
    ,.data_o(dcache_data)

    ,.ptag_i(dcache_ptag)
    ,.ptag_v_i(dcache_ptag_v)
    ,.uncached_i(dcache_uncached)

    ,.poison_i(chk_poison_ex_i)

    // D$-LCE Interface
    ,.dcache_miss_o(dcache_miss_lo)
    ,.cache_req_complete_i(cache_req_complete_i)
    ,.cache_req_critical_i(cache_req_critical_i)
    ,.cache_req_o(cache_req_cast_o)
    ,.cache_req_v_o(cache_req_v_o)
    ,.cache_req_ready_i(cache_req_ready_i)
    ,.cache_req_metadata_o(cache_req_metadata_o)
    ,.cache_req_metadata_v_o(cache_req_metadata_v_o)

    ,.data_mem_pkt_v_i(data_mem_pkt_v_i)
    ,.data_mem_pkt_i(data_mem_pkt_i)
    ,.data_mem_o(data_mem_o)
    ,.data_mem_pkt_yumi_o(data_mem_pkt_yumi_o)
    ,.tag_mem_pkt_v_i(tag_mem_pkt_v_i)
    ,.tag_mem_pkt_i(tag_mem_pkt_i)
    ,.tag_mem_o(tag_mem_o)
    ,.tag_mem_pkt_yumi_o(tag_mem_pkt_yumi_o)
    ,.stat_mem_pkt_v_i(stat_mem_pkt_v_i)
    ,.stat_mem_pkt_i(stat_mem_pkt_i)
    ,.stat_mem_o(stat_mem_o)
    ,.stat_mem_pkt_yumi_o(stat_mem_pkt_yumi_o)
    );

// We delay the tlb miss signal by one cycle to synchronize with cache miss signal
// We latch the dcache miss signal
always_ff @(posedge clk_i) begin
  if(reset_i) begin
    dtlb_miss_r  <= '0;
    mem_cmd_v_r  <= '0;
    mem_cmd_v_rr <= '0;
    is_store_r   <= '0;
    is_fencei_r  <= '0;
    is_fencei_rr <= '0;
    load_page_fault_mem3    <= '0;
    store_page_fault_mem3   <= '0;
    load_access_fault_mem3  <= '0;
    store_access_fault_mem3 <= '0;
  end
  else begin
    dtlb_miss_r  <= dtlb_miss_v & ~chk_poison_ex_i;
    mem_cmd_v_r  <= mem_cmd_v_i;
    mem_cmd_v_rr <= mem_cmd_v_r & ~chk_poison_ex_i;
    is_store_r   <= is_store;
    is_fencei_r  <= is_fencei;
    is_fencei_rr <= is_fencei_r;
    load_page_fault_mem3    <= load_page_fault_v & ~chk_poison_ex_i;
    store_page_fault_mem3   <= store_page_fault_v & ~chk_poison_ex_i;
    load_access_fault_mem3  <= load_access_fault_v & ~chk_poison_ex_i;
    store_access_fault_mem3 <= store_access_fault_v & ~chk_poison_ex_i;
  end
end

// Check instruction accesses
wire data_priv_page_fault = ((priv_mode_i == `PRIV_MODE_S) & ~mstatus_sum_i & dtlb_r_entry.u)
                              | ((priv_mode_i == `PRIV_MODE_U) & ~dtlb_r_entry.u);
wire data_write_page_fault = is_store_r & (~dtlb_r_entry.w | ~dtlb_r_entry.d);

assign load_page_fault_v  = mem_cmd_v_r & dtlb_r_v_lo & translation_en_i & ~is_store_r & data_priv_page_fault;
assign store_page_fault_v = mem_cmd_v_r & dtlb_r_v_lo & translation_en_i & is_store_r & (data_priv_page_fault | data_write_page_fault);

// Decode cmd type
assign dcache_cmd_v    = mem_cmd_v_i;
assign fencei_cmd_v    = mem_cmd_v_i & (mem_cmd.mem_op == e_fencei);

// D-Cache connections
always_comb
  begin
    if(ptw_busy) begin
      dcache_pkt_v    = ptw_dcache_v;
      dcache_pkt      = ptw_dcache_pkt;
      dcache_ptag     = ptw_dcache_ptag;
      dcache_ptag_v   = ptw_dcache_ptag_v;
    end
    else begin
      dcache_pkt_v = dcache_cmd_v;
      // We assume that mem op == dcache op
      dcache_pkt.opcode      = bp_be_dcache_opcode_e'(mem_cmd.mem_op);
      dcache_pkt.page_offset = {mem_cmd.vaddr.index, mem_cmd.vaddr.offset};
      dcache_pkt.data        = mem_cmd.data;
      dcache_ptag = dtlb_r_entry.ptag;
      dcache_ptag_v = dtlb_r_v_lo
                      & ~(load_page_fault_v | store_page_fault_v)
                      & ~(load_access_fault_v | store_access_fault_v);
    end
end

// Fault if in uncached mode but access is not for an uncached address
wire is_uncached_mode = (cfg_bus.dcache_mode == e_lce_mode_uncached);
wire mode_fault_v = (is_uncached_mode & ~dcache_uncached);
  // TODO: Enable other domains by setting enabled dids with cfg_bus
wire did_fault_v = (dcache_ptag[ptag_width_p-1-:io_noc_did_width_p] != '0) &
                   ~((dcache_ptag[ptag_width_p-1-:io_noc_did_width_p] == 1) & sac_x_dim_p > 0);

assign load_access_fault_v  = mem_cmd_v_r & dtlb_r_v_lo & ~is_store_r & (mode_fault_v | did_fault_v);
assign store_access_fault_v = mem_cmd_v_r & dtlb_r_v_lo & is_store_r & (mode_fault_v | did_fault_v);

// D-TLB connections
assign dtlb_r_v     = dcache_cmd_v & ~fencei_cmd_v;
assign dtlb_r_vtag  = mem_cmd.vaddr.tag;
assign dtlb_w_v     = ptw_fill_pkt.dtlb_fill_v;
assign dtlb_w_vtag  = ptw_fill_pkt.vaddr[vaddr_width_p-1-:vtag_width_p];
assign dtlb_w_entry = ptw_fill_pkt.entry;

// MMU response connections
assign mem_resp.cache_miss_v       = mem_cmd_v_rr & ~dtlb_miss_r & dcache_miss_lo;
assign mem_resp.tlb_miss_v         = mem_cmd_v_rr &  dtlb_miss_r;
assign mem_resp.fencei_v           = mem_cmd_v_rr & dcache_v & is_fencei_rr;
assign mem_resp.store_page_fault   = store_page_fault_mem3;
assign mem_resp.load_page_fault    = load_page_fault_mem3;
assign mem_resp.store_access_fault = store_access_fault_mem3;
assign mem_resp.store_misaligned   = 1'b0; // TODO: detect
assign mem_resp.load_access_fault  = load_access_fault_mem3;
assign mem_resp.load_misaligned    = 1'b0; // TODO: detect
assign mem_resp.data   = dcache_data;
assign mem_resp.vaddr  = vaddr_mem3;

assign mem_resp_v_o    = ptw_busy ? 1'b0 : mem_cmd_v_rr;
assign mem_cmd_ready_o = dcache_ready_lo & ~ptw_busy;

// synopsys translate_off
bp_be_mem_cmd_s mem_cmd_r;
always_ff @(posedge clk_i)
  mem_cmd_r <= mem_cmd;

always_ff @(negedge clk_i)
  begin
    assert ((reset_i !== 1'b0) || ~(mem_cmd_v_r & dtlb_r_v_lo & dcache_uncached & (mem_cmd_r.mem_op inside {e_lrw, e_lrd, e_scw, e_scd})))
      else $warning("LR/SC to uncached memory not supported");
  end

// synopsys translate_on
//
endmodule

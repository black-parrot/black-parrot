/**
 *
 * Name:
 *   bp_be_pipe_mem.v
 *
 * Description:
 *   Pipeline for RISC-V memory instructions. This includes both int + float loads + stores.
 *
 * Notes:
 *
 */

module bp_be_pipe_mem
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_be_pkg::*;
 import bp_be_dcache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache)
   // Generated parameters
   , localparam cfg_bus_width_lp       = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam dispatch_pkt_width_lp  = `bp_be_dispatch_pkt_width(vaddr_width_p)
   , localparam ptw_miss_pkt_width_lp  = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp  = `bp_be_ptw_fill_pkt_width(vaddr_width_p)
   , localparam trans_info_width_lp    = `bp_be_trans_info_width(ptag_width_p)

   // From RISC-V specifications
   , localparam eaddr_pad_lp = rv64_eaddr_width_gp - vaddr_width_p
   )
  (input                                  clk_i
   , input                                reset_i

   , input [cfg_bus_width_lp-1:0]         cfg_bus_i
   , input                                flush_i
   , input                                sfence_i

   , output logic                         ready_o

   , input [dispatch_pkt_width_lp-1:0]    reservation_i

   , input [ptw_miss_pkt_width_lp-1:0]    ptw_miss_pkt_i
   , output [ptw_fill_pkt_width_lp-1:0]   ptw_fill_pkt_o

   , output logic                         tlb_miss_v_o
   , output logic                         cache_miss_v_o
   , output logic                         fencei_v_o
   , output logic                         load_misaligned_v_o
   , output logic                         load_access_fault_v_o
   , output logic                         load_page_fault_v_o
   , output logic                         store_misaligned_v_o
   , output logic                         store_access_fault_v_o
   , output logic                         store_page_fault_v_o

   , output logic [dpath_width_p-1:0]     early_data_o
   , output logic                         early_v_o
   , output logic [dpath_width_p-1:0]     final_data_o
   , output logic                         final_v_o
   , output logic [vaddr_width_p-1:0]     final_vaddr_o

   , input [trans_info_width_lp-1:0]      trans_info_i

   // D$-LCE Interface
   // signals to LCE
   , output logic [dcache_req_width_lp-1:0]          cache_req_o
   , output logic                                    cache_req_v_o
   , input                                           cache_req_ready_i
   , output logic [dcache_req_metadata_width_lp-1:0] cache_req_metadata_o
   , output logic                                    cache_req_metadata_v_o
   , input                                           cache_req_critical_i
   , input                                           cache_req_complete_i

   // data_mem
   , input data_mem_pkt_v_i
   , input [dcache_data_mem_pkt_width_lp-1:0] data_mem_pkt_i
   , output logic data_mem_pkt_yumi_o
   , output logic [dcache_block_width_p-1:0] data_mem_o

   // tag_mem
   , input tag_mem_pkt_v_i
   , input [dcache_tag_mem_pkt_width_lp-1:0] tag_mem_pkt_i
   , output logic tag_mem_pkt_yumi_o
   , output logic [dcache_tag_info_width_lp-1:0] tag_mem_o

   // stat_mem
   , input stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
   , output logic stat_mem_pkt_yumi_o
   , output logic [dcache_stat_info_width_lp-1:0] stat_mem_o
   );

  `declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
  `declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_be_mem_structs(vaddr_width_p, ptag_width_p, dcache_sets_p, dword_width_p)
  `declare_bp_be_dcache_pkt_s(page_offset_width_p, dpath_width_p);
  `declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_fill_width_p, dcache);

  // Cast input and output ports
  bp_be_dispatch_pkt_s   reservation;
  bp_be_decode_s         decode;
  rv64_instr_s           instr;
  bp_cfg_bus_s           cfg_bus;
  bp_be_ptw_miss_pkt_s   ptw_miss_pkt;
  bp_be_ptw_fill_pkt_s   ptw_fill_pkt;
  bp_be_trans_info_s     trans_info;
  bp_dcache_req_s        cache_req_cast_o;

  assign cfg_bus = cfg_bus_i;
  assign ptw_miss_pkt = ptw_miss_pkt_i;
  assign ptw_fill_pkt_o = ptw_fill_pkt;
  assign trans_info = trans_info_i;
  assign cache_req_o = cache_req_cast_o;

  assign reservation = reservation_i;
  assign decode = reservation.decode;
  assign instr = reservation.instr;
  wire [vaddr_width_p-1:0] pc  = reservation.pc[0+:vaddr_width_p];
  wire [dpath_width_p-1:0] rs1 = reservation.rs1[0+:dpath_width_p];
  wire [dpath_width_p-1:0] rs2 = reservation.rs2[0+:dpath_width_p];
  wire [dpath_width_p-1:0] imm = reservation.imm[0+:dpath_width_p];

  /* Internal connections */
  /* TLB ports */
  logic                    dtlb_en, dtlb_miss_v, dtlb_w_v, dtlb_r_v, dtlb_r_v_lo, dtlb_v_lo;
  logic [vtag_width_p-1:0] dtlb_r_vtag, dtlb_w_vtag;
  bp_pte_entry_leaf_s      dtlb_r_entry, dtlb_w_entry, passthrough_entry, entry_lo;

  /* PTW ports */
  logic [ptag_width_p-1:0]  ptw_dcache_ptag;
  logic                     ptw_dcache_ptag_v;
  logic                     ptw_dcache_v, ptw_busy;
  bp_be_dcache_pkt_s        ptw_dcache_pkt;

  /* D-Cache ports */
  bp_be_dcache_pkt_s        dcache_pkt;
  logic [dpath_width_p-1:0] dcache_early_data, dcache_final_data;
  logic [ptag_width_p-1:0]  dcache_ptag;
  logic                     dcache_early_v, dcache_final_v, dcache_pkt_v;
  logic                     dcache_ptag_v;
  logic                     dcache_uncached;
  logic                     dcache_ready_lo;

  logic load_access_fault_v, store_access_fault_v;
  logic load_page_fault_v, store_page_fault_v;
  logic load_misaligned_v, store_misaligned_v;

  logic load_access_fault_mem2, store_access_fault_mem2;
  logic load_page_fault_mem2, store_page_fault_mem2;
  logic load_misaligned_mem2, store_misaligned_mem2;

  /* Control signals */
  logic is_req_mem1, is_req_mem2;
  logic is_store_mem1;
  logic is_fencei_mem1, is_fencei_mem2;
  logic [rv64_eaddr_width_gp-1:0] eaddr_mem1, eaddr_mem2, eaddr_mem3;

  wire is_store  = (decode.pipe_mem_early_v | decode.pipe_mem_final_v) & decode.dcache_w_v;
  wire is_load   = (decode.pipe_mem_early_v | decode.pipe_mem_final_v) & decode.dcache_r_v;
  wire is_fencei = (decode.pipe_mem_early_v | decode.pipe_mem_final_v) & decode.fu_op inside {e_dcache_op_fencei};
  wire is_req    = is_store | is_load | is_fencei;

  // Calculate cache access eaddr
  wire [rv64_eaddr_width_gp-1:0] eaddr = rs1 + imm;

  logic eaddr_fault, eaddr_fault_r;

  bsg_dff_reset
   #(.width_p(1))
    eaddr_fault_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i((decode.pipe_mem_early_v | decode.pipe_mem_final_v) & eaddr_fault)
     ,.data_o(eaddr_fault_r)
     );

  // D-TLB connections
  assign dtlb_r_v     = (decode.pipe_mem_early_v | decode.pipe_mem_final_v) & trans_info.translation_en & ~eaddr_fault & ~is_fencei;
  assign dtlb_r_vtag  = eaddr[bp_page_offset_width_gp+:vtag_width_p];
  assign dtlb_w_v     = ptw_fill_pkt.dtlb_fill_v;
  assign dtlb_w_vtag  = ptw_fill_pkt.vaddr[vaddr_width_p-1-:vtag_width_p];
  assign dtlb_w_entry = ptw_fill_pkt.entry;

  bp_tlb
   #(.bp_params_p(bp_params_p)
     ,.tlb_els_p(dtlb_els_p)
     )
   dtlb
    (.clk_i(~clk_i)
     ,.reset_i(reset_i)
     ,.flush_i(sfence_i)

     ,.v_i(dtlb_r_v | dtlb_w_v)
     ,.w_i(dtlb_w_v)
     ,.vtag_i((dtlb_w_v)? dtlb_w_vtag : dtlb_r_vtag)
     ,.entry_i(dtlb_w_entry)

     ,.entry_o(entry_lo)
     ,.v_o(dtlb_v_lo)
     ,.miss_v_o(dtlb_miss_v)
     );

  assign passthrough_entry = '{ptag: eaddr_mem1[bp_page_offset_width_gp+:ptag_width_p], default: '0};
  wire passthrough_v_lo = is_req_mem1;
  assign dtlb_r_entry = trans_info.translation_en ? entry_lo : passthrough_entry;
  assign dtlb_r_v_lo = trans_info.translation_en ? dtlb_v_lo : passthrough_v_lo;

  bp_pma
   #(.bp_params_p(bp_params_p))
   pma
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.ptag_v_i(dtlb_r_v_lo)
     ,.ptag_i(dtlb_r_entry.ptag)

     ,.uncached_o(dcache_uncached)
     );

  bp_be_ptw
    #(.bp_params_p(bp_params_p))
    ptw
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.base_ppn_i(trans_info.satp_ppn)
     ,.priv_mode_i(trans_info.priv_mode)
     ,.mstatus_sum_i(trans_info.mstatus_sum)
     ,.mstatus_mxr_i(trans_info.mstatus_mxr)
     ,.busy_o(ptw_busy)

     ,.ptw_miss_pkt_i(ptw_miss_pkt)
     ,.ptw_fill_pkt_o(ptw_fill_pkt)

     ,.dcache_v_i(dcache_early_v)
     ,.dcache_data_i(dcache_early_data)

     ,.dcache_v_o(ptw_dcache_v)
     ,.dcache_pkt_o(ptw_dcache_pkt)
     ,.dcache_ptag_o(ptw_dcache_ptag)
     ,.dcache_ptag_v_o(ptw_dcache_ptag_v)
     ,.dcache_rdy_i(dcache_ready_lo)
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

      ,.ptag_i(dcache_ptag)
      ,.ptag_v_i(dcache_ptag_v)
      ,.uncached_i(dcache_uncached)

      ,.early_v_o(dcache_early_v)
      ,.early_data_o(dcache_early_data)
      ,.final_data_o(dcache_final_data)
      ,.final_v_o(dcache_final_v)

      ,.flush_i(flush_i)

      // D$-LCE Interface
      ,.cache_req_o(cache_req_cast_o)
      ,.cache_req_v_o(cache_req_v_o)
      ,.cache_req_ready_i(cache_req_ready_i)
      ,.cache_req_metadata_o(cache_req_metadata_o)
      ,.cache_req_metadata_v_o(cache_req_metadata_v_o)
      ,.cache_req_critical_i(cache_req_critical_i)
      ,.cache_req_complete_i(cache_req_complete_i)

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
  always_ff @(negedge clk_i) begin
    if (reset_i) begin
      is_req_mem1 <= '0;
      is_req_mem2 <= '0;
      is_store_mem1 <= '0;
      eaddr_mem1 <= '0;
      eaddr_mem2 <= '0;
      is_fencei_mem1 <= '0;
      is_fencei_mem2 <= '0;
      load_access_fault_mem2 <= '0;
      store_access_fault_mem2 <= '0;
      load_page_fault_mem2 <= '0;
      store_page_fault_mem2 <= '0;
      load_misaligned_mem2 <= '0;
      store_misaligned_mem2 <= '0;
    end
    else begin
      is_req_mem1 <= is_req;
      is_req_mem2 <= is_req_mem1;
      is_store_mem1 <= is_store;
      eaddr_mem1 <= eaddr;
      eaddr_mem2 <= eaddr_mem1;
      is_fencei_mem1 <= is_fencei;
      is_fencei_mem2 <= is_fencei_mem1;
      load_access_fault_mem2 <= load_access_fault_v;
      store_access_fault_mem2 <= store_access_fault_v;
      load_page_fault_mem2 <= load_page_fault_v;
      store_page_fault_mem2 <= store_page_fault_v;
      load_misaligned_mem2 <= load_misaligned_v;
      store_misaligned_mem2 <= store_misaligned_v;
    end
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      eaddr_mem3 <= '0;
    end else begin
      eaddr_mem3 <= eaddr_mem2;
    end
  end

  // Check instruction accesses
  wire data_priv_page_fault = ((trans_info.priv_mode == `PRIV_MODE_S) & ~trans_info.mstatus_sum & dtlb_r_entry.u)
                                | ((trans_info.priv_mode == `PRIV_MODE_U) & ~dtlb_r_entry.u);
  wire data_write_page_fault = is_store_mem1 & (~dtlb_r_entry.w | ~dtlb_r_entry.d);

  assign eaddr_fault = (eaddr[rv64_eaddr_width_gp-1:vaddr_width_p] != {eaddr_pad_lp{eaddr[vaddr_width_p-1]}});
  assign load_page_fault_v  = ((trans_info.translation_en & ~is_store_mem1) & ((dtlb_r_v_lo & data_priv_page_fault) | eaddr_fault_r));
  assign store_page_fault_v = ((trans_info.translation_en & is_store_mem1) & ((dtlb_r_v_lo & (data_priv_page_fault | data_write_page_fault)) | eaddr_fault_r));
  assign load_misaligned_v = 1'b0; // TODO: detect
  assign store_misaligned_v = 1'b0; // TODO: detect

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
        dcache_pkt_v = reservation.v & ~reservation.poison & (decode.pipe_mem_early_v | decode.pipe_mem_final_v);
        // TODO: Use dcache opcode directly
        dcache_pkt.opcode      = bp_be_dcache_fu_op_e'(decode.fu_op);
        dcache_pkt.page_offset = eaddr[0+:page_offset_width_p];
        dcache_pkt.data        = rs2;
        dcache_ptag = dtlb_r_entry.ptag;
        dcache_ptag_v = dtlb_r_v_lo
                        & ~(load_page_fault_v | store_page_fault_v)
                        & ~(load_access_fault_v | store_access_fault_v)
                        & ~(load_misaligned_v | store_misaligned_v);
      end
  end

  // Fault if in uncached mode but access is not for an uncached address
  wire is_uncached_mode = (cfg_bus.dcache_mode == e_lce_mode_uncached);
  wire mode_fault_v = (is_uncached_mode & ~dcache_uncached);

  wire did_fault_v = (cfg_bus.domain[dcache_ptag[ptag_width_p-1-:io_noc_did_width_p]] != 1'b1);
  wire sac_fault_v = ((dcache_ptag[ptag_width_p-1-:(io_noc_did_width_p+1)] == 1) & ~cfg_bus.sac);

  assign load_access_fault_v  = dtlb_r_v_lo & ~is_store_mem1 & (mode_fault_v | did_fault_v | sac_fault_v);
  assign store_access_fault_v = dtlb_r_v_lo & is_store_mem1 & (mode_fault_v | did_fault_v | sac_fault_v);

  assign tlb_miss_v_o           = dtlb_miss_v;
  assign cache_miss_v_o         = is_req_mem2 & ~dcache_early_v;
  assign fencei_v_o             = is_fencei_mem2 & dcache_early_v;
  assign store_page_fault_v_o   = store_page_fault_mem2;
  assign load_page_fault_v_o    = load_page_fault_mem2;
  assign store_access_fault_v_o = store_access_fault_mem2;
  assign load_access_fault_v_o  = load_access_fault_mem2;
  assign store_misaligned_v_o   = store_misaligned_mem2;
  assign load_misaligned_v_o    = load_misaligned_mem2;

  assign ready_o                = dcache_ready_lo & ~ptw_busy;
  assign early_data_o           = dcache_early_data;
  assign final_data_o           = dcache_final_data;
  assign final_vaddr_o          = eaddr_mem3[0+:vaddr_width_p];

  wire early_v_li = reservation.v & ~reservation.poison & reservation.decode.pipe_mem_early_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(1))
   early_chain
    (.clk_i(clk_i)

     ,.data_i(early_v_li)
     ,.data_o(early_v_o)
     );

  wire final_v_li = reservation.v & ~reservation.poison & reservation.decode.pipe_mem_final_v;
  bsg_dff_chain
   #(.width_p(1), .num_stages_p(2))
   final_chain
    (.clk_i(clk_i)

     ,.data_i(final_v_li)
     ,.data_o(final_v_o)
     );

endmodule


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
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_cache_service_if_widths(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_block_width_p, dcache)
   // Generated parameters
   , localparam decode_width_lp        = `bp_be_decode_width
   , localparam cfg_bus_width_lp       = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   , localparam ptw_miss_pkt_width_lp  = `bp_be_ptw_miss_pkt_width(vaddr_width_p)
   , localparam ptw_fill_pkt_width_lp  = `bp_be_ptw_fill_pkt_width(vaddr_width_p)
   , localparam trans_info_width_lp    = `bp_be_trans_info_width(ptag_width_p)

   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp
   )
  (input                                  clk_i
   , input                                reset_i

   , input [cfg_bus_width_lp-1:0]         cfg_bus_i
   , input                                kill_ex1_i
   , input                                flush_i
   , input                                sfence_i

   , output logic                         ready_o

   , input [decode_width_lp-1:0]          decode_i
   , input [vaddr_width_p-1:0]            pc_i
   , input [rv64_instr_width_gp-1:0]      instr_i
   , input [reg_data_width_lp-1:0]        rs1_i
   , input [reg_data_width_lp-1:0]        rs2_i
   , input [reg_data_width_lp-1:0]        imm_i

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

   , output logic [vaddr_width_p-1:0]     vaddr_o
   , output logic [reg_data_width_lp-1:0] data_o

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
   , output logic [ptag_width_p-1:0] tag_mem_o

   // stat_mem
   , input stat_mem_pkt_v_i
   , input [dcache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_i
   , output logic stat_mem_pkt_yumi_o
   , output logic [dcache_stat_info_width_lp-1:0] stat_mem_o
   );

`declare_bp_fe_be_if(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p, paddr_width_p, asid_width_p, branch_metadata_fwd_width_p);

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
// Not sure if this is right.
`declare_bp_be_mem_structs(vaddr_width_p, ptag_width_p, dcache_sets_p, dcache_block_width_p/8)
`declare_bp_be_dcache_pkt_s(page_offset_width_p, dword_width_p);
`declare_bp_cache_service_if(paddr_width_p, ptag_width_p, dcache_sets_p, dcache_assoc_p, dword_width_p, dcache_block_width_p, dcache_block_width_p, dcache);
  bp_dcache_req_s cache_req_cast_o;

  assign cache_req_o = cache_req_cast_o;

// Cast input and output ports
bp_be_decode_s         decode;
bp_cfg_bus_s           cfg_bus;
bp_be_ptw_miss_pkt_s   ptw_miss_pkt;
bp_be_ptw_fill_pkt_s   ptw_fill_pkt;
bp_be_trans_info_s     trans_info;

assign decode = decode_i;
assign cfg_bus = cfg_bus_i;

assign ptw_miss_pkt = ptw_miss_pkt_i;
assign ptw_fill_pkt_o = ptw_fill_pkt;
assign trans_info = trans_info_i;

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
logic [vaddr_width_p-1:0] vaddr_mem1, vaddr_mem2;

wire is_req    = decode.pipe_mem_v;
wire is_store  = decode.pipe_mem_v & decode.fu_op inside {e_sb, e_sh, e_sw, e_sd, e_scw, e_scd};
wire is_fencei = decode.pipe_mem_v & decode.fu_op inside {e_fencei};

// Calculate cache access vaddr
wire [vaddr_width_p-1:0] offset = decode.offset_sel ? '0 : imm_i[0+:vaddr_width_p];
wire [vaddr_width_p-1:0] vaddr = rs1_i + offset;

// D-TLB connections
assign dtlb_r_v     = decode.pipe_mem_v & ~is_fencei;
assign dtlb_r_vtag  = vaddr[vaddr_width_p-1-:vtag_width_p];
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
   ,.translation_en_i(trans_info.translation_en)

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
   ,.base_ppn_i(trans_info.satp_ppn)
   ,.priv_mode_i(trans_info.priv_mode)
   ,.mstatus_sum_i(trans_info.mstatus_sum)
   ,.mstatus_mxr_i(trans_info.mstatus_mxr)
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

    ,.poison_i(flush_i)

    ,.dcache_miss_o(dcache_miss_lo)
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
    vaddr_mem1 <= '0;
    vaddr_mem2 <= '0;
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
    vaddr_mem1 <= vaddr;
    vaddr_mem2 <= vaddr_mem1;
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

// Check instruction accesses
wire data_priv_page_fault = ((trans_info.priv_mode == `PRIV_MODE_S) & ~trans_info.mstatus_sum & dtlb_r_entry.u)
                              | ((trans_info.priv_mode == `PRIV_MODE_U) & ~dtlb_r_entry.u);
wire data_write_page_fault = is_store_mem1 & (~dtlb_r_entry.w | ~dtlb_r_entry.d);

assign load_page_fault_v  = dtlb_r_v_lo & trans_info.translation_en & ~is_store_mem1 & data_priv_page_fault;
assign store_page_fault_v = dtlb_r_v_lo & trans_info.translation_en & is_store_mem1 & (data_priv_page_fault | data_write_page_fault);
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
      dcache_pkt_v = decode.pipe_mem_v & ~kill_ex1_i;
      // TODO: Use dcache opcode directly
      dcache_pkt.opcode      = bp_be_dcache_opcode_e'(decode.fu_op);
      dcache_pkt.page_offset = vaddr[0+:page_offset_width_p];
      dcache_pkt.data        = rs2_i;
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
  // TODO: Enable other domains by setting enabled dids with cfg_bus
wire did_fault_v = (dcache_ptag[ptag_width_p-1-:io_noc_did_width_p] != '0) &
                   ~((dcache_ptag[ptag_width_p-1-:io_noc_did_width_p] == 1) & sac_x_dim_p > 0);

assign load_access_fault_v  = dtlb_r_v_lo & ~is_store_mem1 & (mode_fault_v | did_fault_v);
assign store_access_fault_v = dtlb_r_v_lo & is_store_mem1 & (mode_fault_v | did_fault_v);


assign tlb_miss_v_o           = dtlb_miss_v;
assign cache_miss_v_o         = is_req_mem2 & ~dcache_v;
assign fencei_v_o             = is_fencei_mem2 & dcache_v;
assign store_page_fault_v_o   = store_page_fault_mem2;
assign load_page_fault_v_o    = load_page_fault_mem2;
assign store_access_fault_v_o = store_access_fault_mem2;
assign load_access_fault_v_o  = load_access_fault_mem2;
assign store_misaligned_v_o   = store_misaligned_mem2;
assign load_misaligned_v_o    = load_misaligned_mem2;

assign ready_o                = dcache_ready_lo & ~ptw_busy;
assign vaddr_o                = vaddr_mem2;
assign data_o                 = dcache_data;

//// synopsys translate_off
//bp_be_mem_cmd_s mem_cmd_r;
//always_ff @(posedge clk_i)
//  mem_cmd_r <= mem_cmd;
//
//always_ff @(negedge clk_i)
//  begin
//    assert ((reset_i !== 1'b0) || ~(mem_cmd_v_r & dtlb_r_v_lo & dcache_uncached & (mem_cmd_r.mem_op inside {e_lrw, e_lrd, e_scw, e_scd})))
//      else $warning("LR/SC to uncached memory not supported");
//  end
//
//// synopsys translate_on

endmodule


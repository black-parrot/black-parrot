/**
 *
 * Name:
 *   bp_mmu_top.v
 * 
 * Description:
 *
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''
 *
 *   num_cce_p                   - 
 *   num_lce_p                   - 
 *   num_mem_p                   - 
 *   lce_assoc_p                 - 
 *   lce_sets_p                  - 
 *   cce_block_size_in_bytes_p   - 
 * 
 * Inputs:
 *   clk_i                       -
 *   reset_i                     -
 *
 *   mmu_resp_i                  -
 *   mmu_resp_v_i                -
 *   mmu_resp_ready_o            -
 *
 *   cce_lce_cmd_i               -
 *   cce_lce_cmd_v_i             -
 *   cce_lce_cmd_ready_o         -
 *
 *   cce_lce_data_cmd_i          -
 *   cce_lce_data_cmd_v_i        -
 *   cce_lce_data_cmd_ready_o    -
 * 
 *   lce_lce_tr_resp_i           - 
 *   lce_lce_tr_resp_v_i         -
 *   lce_lce_tr_resp_ready_o     -
 * 
 *   proc_cfg_i                  -
 *
 * Outputs:
 *   mmu_cmd_o                   -
 *   mmu_cmd_v_o                 -
 *   mmu_cmd_ready_i             -
 *
 *   lce_cce_req_o               -
 *   lce_cce_req_v_o             -
 *   lce_cce_req_ready_i         -
 *
 *   lce_cce_resp_o              -
 *   lce_cce_resp_v_o            -
 *   lce_cce_resp_ready_i        -
 *
 *   lce_cce_data_resp_o         -
 *   lce_cce_data_resp_v_o       -
 *   lce_cce_data_resp_ready_i   -
 *
 *   lce_lce_tr_resp_o           -
 *   lce_lce_tr_resp_v_o         -
 *   lce_lce_tr_resp_ready_i     -
 *
 *   dcache_id_i                 -
 *
 * Keywords:
 *   mmu, top, dcache, d$, mem
 * 
 * Notes:
 *
 */

module bp_be_mmu_top 
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_be_rv64_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"

   ,parameter num_cce_p="inv"
   ,parameter num_lce_p="inv"
   ,parameter num_mem_p="inv"
   ,parameter cce_block_size_in_bytes_p="inv"
   ,parameter lce_assoc_p="inv"
   ,parameter lce_sets_p="inv"

   ,localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
 
   ,localparam data_mask_width_lp=(cce_block_size_in_bytes_p>>3)
   ,localparam vindex_width_lp=10 /* TODO: Generalize */
   ,localparam vtag_width_lp=12   /* TODO: Generalize */
   ,localparam ptag_width_lp=12   /* TODO: Generalize */

   ,localparam mmu_cmd_width_lp=`bp_be_mmu_cmd_width
   ,localparam mmu_resp_width_lp=`bp_be_mmu_resp_width

   ,localparam reg_data_width_lp=rv64_reg_data_width_gp

   ,localparam dcache_pkt_width_lp=`bp_be_dcache_pkt_width(vindex_width_lp, reg_data_width_lp)

   ,localparam lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                          ,num_lce_p
                                                          ,paddr_width_p
                                                          ,lce_assoc_p
                                                          )
   ,localparam lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                            ,num_lce_p
                                                            ,paddr_width_p
                                                            )
   ,localparam lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                      ,num_lce_p
                                                                      ,paddr_width_p
                                                                      ,cce_block_size_in_bits_lp
                                                                      )
   ,localparam cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                          ,num_lce_p
                                                          ,paddr_width_p
                                                          ,lce_assoc_p
                                                          )
   ,localparam cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                    ,num_lce_p
                                                                    ,paddr_width_p
                                                                    ,cce_block_size_in_bits_lp
                                                                    ,lce_assoc_p
                                                                    )
   ,localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                  ,paddr_width_p
                                                                  ,cce_block_size_in_bits_lp
                                                                  ,lce_assoc_p
                                                                  )
   ,localparam lce_id_width_lp=4 // TODO: parameterize proc_cfg based on width
   )
  (input clk_i
   ,input reset_i


   ,input [mmu_cmd_width_lp-1:0]            mmu_cmd_i
   ,input mmu_cmd_v_i
   ,output logic                                  mmu_cmd_ready_o

   ,input logic                                   chk_psn_ex_i

   ,output logic [mmu_resp_width_lp-1:0]          mmu_resp_o
   ,output logic                                  mmu_resp_v_o
   ,input mmu_resp_ready_i

   ,output logic [lce_cce_req_width_lp-1:0]       lce_req_o
   ,output logic                                  lce_req_v_o
   ,input lce_req_ready_i

   ,output logic [lce_cce_resp_width_lp-1:0]      lce_resp_o
   ,output logic                                  lce_resp_v_o
   ,input lce_resp_ready_i                                 

   ,output logic [lce_cce_data_resp_width_lp-1:0] lce_data_resp_o
   ,output logic                                  lce_data_resp_v_o
   ,input lce_data_resp_ready_i

   ,input [cce_lce_cmd_width_lp-1:0]        lce_cmd_i
   ,input lce_cmd_v_i
   ,output logic                                  lce_cmd_ready_o

   ,input [cce_lce_data_cmd_width_lp-1:0]   lce_data_cmd_i
   ,input lce_data_cmd_v_i
   ,output logic                                  lce_data_cmd_ready_o

   ,input [lce_lce_tr_resp_width_lp-1:0]    lce_tr_resp_i
   ,input lce_tr_resp_v_i
   ,output logic                                  lce_tr_resp_ready_o

   ,output logic [lce_lce_tr_resp_width_lp-1:0]   lce_tr_resp_o
   ,output logic                                  lce_tr_resp_v_o
   ,input lce_tr_resp_ready_i

   ,input [lce_id_width_lp-1:0]             dcache_id_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);

/* TODO: Change to monolithic declare in bp_common */
`declare_bp_be_dcache_pkt_s(vindex_width_lp, reg_data_width_lp);

// Cast input and output ports 
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_mmu_resp_s       mmu_resp;

assign mmu_cmd    = mmu_cmd_i;
assign mmu_resp_o = mmu_resp;

/* Internal connections */
logic tlb_miss;
logic [ptag_width_lp-1:0] ptag;

bp_be_dcache_pkt_s dcache_pkt;
logic dcache_ready, dcache_miss_v, dcache_v;

logic [cce_lce_cmd_width_lp-1:0] cce_lce_cmd_buf;
logic cce_lce_cmd_v_buf, cce_lce_cmd_yumi_buf;

logic [cce_lce_data_cmd_width_lp-1:0] cce_lce_data_cmd_buf;
logic cce_lce_data_cmd_v_buf, cce_lce_data_cmd_yumi_buf;

logic [lce_lce_tr_resp_width_lp-1:0] lce_lce_tr_resp_buf;
    logic lce_lce_tr_resp_v_buf, lce_lce_tr_resp_yumi_buf;

/* Suppress warnings */
logic unused0;
assign unused0 = mmu_resp_ready_i;

/* TODO: Should pass through vtag->ptag width */
mock_tlb #(.tag_width_p(12)
           )
       tlb(.clk_i(clk_i)
    
           ,.v_i(mmu_cmd_v_i)
           ,.tag_i(mmu_cmd.addr[vindex_width_lp+:vtag_width_lp])

           ,.tag_o(ptag)
           ,.tlb_miss_o(tlb_miss)
           );

bp_be_dcache #(
            .data_width_p(64) 
            ,.sets_p(lce_sets_p)
            ,.ways_p(lce_assoc_p)
            ,.paddr_width_p(56)
            ,.num_cce_p(num_cce_p)
            ,.num_lce_p(num_lce_p)
            )
     dcache(.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.lce_id_i(dcache_id_i)

            ,.dcache_pkt_i(dcache_pkt)
            ,.v_i(mmu_cmd_v_i)
            ,.ready_o(dcache_ready)

            ,.v_o(dcache_v)
            ,.data_o(mmu_resp.data)

            ,.tlb_miss_i(tlb_miss)
            ,.ptag_i(ptag)

            /* TODO: Also assign tlb miss to exception */
            ,.cache_miss_o(dcache_miss_v)
            ,.poison_i(chk_psn_ex_i)

            // LCE-CCE interface
            ,.lce_req_o(lce_req_o)
            ,.lce_req_v_o(lce_req_v_o)
            ,.lce_req_ready_i(lce_req_ready_i)

            ,.lce_resp_o(lce_resp_o)
            ,.lce_resp_v_o(lce_resp_v_o)
            ,.lce_resp_ready_i(lce_resp_ready_i)

            ,.lce_data_resp_o(lce_data_resp_o)
            ,.lce_data_resp_v_o(lce_data_resp_v_o)
            ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

            // CCE-LCE interface
            ,.lce_cmd_i(lce_cmd_i)
            ,.lce_cmd_v_i(lce_cmd_v_i)
            ,.lce_cmd_ready_o(lce_cmd_ready_o)

            ,.lce_data_cmd_i(lce_data_cmd_i)
            ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
            ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

            // LCE-LCE interface
            ,.lce_tr_resp_i(lce_tr_resp_i)
            ,.lce_tr_resp_v_i(lce_tr_resp_v_i)
            ,.lce_tr_resp_ready_o(lce_tr_resp_ready_o)

            ,.lce_tr_resp_o(lce_tr_resp_o)
            ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
            ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)
            );

always_comb begin
    /* TODO: Make vaddr a struct to cast to (avoids having to manually pick offsets ERROR PRONE */
    dcache_pkt.opcode = bp_be_dcache_opcode_e'(mmu_cmd.mem_op);
    // TODO: make localparam page_offset_width_lp. look at bp_be_dcache.v
    dcache_pkt.page_offset = mmu_cmd.addr[0+:vindex_width_lp];
    dcache_pkt.data  = mmu_cmd.data;

    mmu_resp.exception.cache_miss_v = dcache_miss_v;
    mmu_resp_v_o = dcache_v;

    mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v;
end

endmodule : bp_be_mmu_top


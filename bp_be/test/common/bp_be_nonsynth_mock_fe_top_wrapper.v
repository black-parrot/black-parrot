/**
 *
 * bp_be_nonsynth_mock_fe_top_wrapper.v
 *
 */

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"
`include "bp_common_me_if.vh"

`include "bp_be_internal_if_defines.vh"

module bp_be_nonsynth_mock_fe_top_wrapper
 /* TODO: Get rid of this */
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 #(parameter mhartid_p="inv"
   ,parameter vaddr_width_p="inv"
   ,parameter paddr_width_p="inv"
   ,parameter asid_width_p="inv"
   ,parameter branch_metadata_fwd_width_p="inv"
   ,parameter num_cce_p="inv"
   ,parameter num_lce_p="inv"
   ,parameter num_mem_p="inv"
   ,parameter coh_states_p="inv"
   ,parameter lce_assoc_p="inv"
   ,parameter lce_sets_p="inv"
   ,parameter cce_block_size_in_bytes_p="inv"
   ,parameter cce_num_inst_ram_els_p="inv"
 
   ,parameter boot_rom_els_p="inv"
   ,parameter boot_rom_width_p="inv"
   ,localparam lg_boot_rom_els_lp=`BSG_SAFE_CLOG2(boot_rom_els_p)

   ,localparam cce_block_size_in_bits_lp=8*cce_block_size_in_bytes_p
   ,localparam fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_p)
   ,localparam fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p
                                                  , paddr_width_p
                                                  , asid_width_p
                                                  , branch_metadata_fwd_width_p
                                                  )

   ,localparam dcache_lce_id_lp=0

   ,localparam reg_data_width_lp=rv64_reg_data_width_gp
   )
  (input logic  clk_i
   ,input logic reset_i
  );

`declare_bp_common_fe_be_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);
`declare_bp_be_internal_if_structs(vaddr_width_p,paddr_width_p,asid_width_p
                                   ,branch_metadata_fwd_width_p);

/* TODO: Change to monolithic declare in bp_common */
/* TODO: Converge 'addr_width' and 'paddr_width', etc. */
`declare_bp_lce_cce_req_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p);
`declare_bp_lce_cce_resp_s(num_cce_p, num_lce_p, paddr_width_p);
`declare_bp_lce_cce_data_resp_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp);
`declare_bp_cce_lce_cmd_s(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, coh_states_p);
`declare_bp_cce_lce_data_cmd_s(num_cce_p, num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);
`declare_bp_lce_lce_tr_resp_s(num_lce_p, paddr_width_p, cce_block_size_in_bits_lp, lce_assoc_p);

// Top-level interface connections
bp_fe_queue_s fe_fe_queue, be_fe_queue;
logic fe_fe_queue_v, be_fe_queue_v, fe_fe_queue_rdy, be_fe_queue_rdy;

logic fe_queue_clr, fe_queue_ckpt_inc, fe_queue_rollback;

bp_fe_cmd_s fe_fe_cmd, be_fe_cmd;
logic fe_fe_cmd_v, be_fe_cmd_v, fe_fe_cmd_rdy, be_fe_cmd_rdy;

bp_lce_cce_req_s [num_lce_p-1:0] lce_req, lce_cce_req;
logic [num_lce_p-1:0] lce_cce_req_v, lce_cce_req_rdy;

bp_lce_cce_resp_s [num_lce_p-1:0] lce_cce_resp;
logic [num_lce_p-1:0] lce_cce_resp_v, lce_cce_resp_rdy;

bp_lce_cce_data_resp_s [num_lce_p-1:0] lce_cce_data_resp;
logic [num_lce_p-1:0] lce_cce_data_resp_v, lce_cce_data_resp_rdy;

bp_cce_lce_cmd_s [num_lce_p-1:0] cce_lce_cmd;
logic [num_lce_p-1:0] cce_lce_cmd_v, cce_lce_cmd_rdy;

bp_cce_lce_data_cmd_s [num_lce_p-1:0] cce_lce_data_cmd;
logic [num_lce_p-1:0] cce_lce_data_cmd_v, cce_lce_data_cmd_rdy;

bp_lce_lce_tr_resp_s [num_lce_p-1:0] local_lce_tr_resp, remote_lce_tr_resp;
logic [num_lce_p-1:0] local_lce_tr_resp_v, local_lce_tr_resp_rdy;
logic [num_lce_p-1:0] remote_lce_tr_resp_v, remote_lce_tr_resp_rdy;

logic [lg_boot_rom_els_lp-1:0] irom_addr;
logic [boot_rom_width_p-1:0]   irom_data;

// Module instantiations
bp_be_nonsynth_mock_fe #(.vaddr_width_p(vaddr_width_p)
                         ,.paddr_width_p(paddr_width_p)
                         ,.asid_width_p(asid_width_p)
                         ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

                         ,.boot_rom_width_p(boot_rom_width_p)
                         ,.boot_rom_els_p(boot_rom_els_p)
                         )
                 mock_fe(.clk_i(clk_i)
                         ,.reset_i(reset_i)

                         ,.fe_queue_o(fe_fe_queue)
                         ,.fe_queue_v_o(fe_fe_queue_v)
                         ,.fe_queue_rdy_i(fe_fe_queue_rdy)

                         ,.fe_cmd_i(fe_fe_cmd)
                         ,.fe_cmd_v_i(fe_fe_cmd_v)
                         ,.fe_cmd_rdy_o(fe_fe_cmd_rdy)

                         ,.boot_rom_addr_o(irom_addr)
                         ,.boot_rom_data_i(irom_data)
                         );

bsg_fifo_1r1w_rolly #(.width_p(fe_queue_width_lp)
                      ,.els_p(32)
                      ,.ready_THEN_valid_p(1)
                      )
        fe_queue_fifo(.clk_i(clk_i)
                      ,.reset_i(reset_i)

                      ,.clr_v_i(fe_queue_clr)
                      ,.ckpt_v_i(fe_queue_ckpt_inc)
                      ,.roll_v_i(fe_queue_rollback)

                      ,.data_i(fe_fe_queue)
                      ,.v_i(fe_fe_queue_v)
                      ,.ready_o(fe_fe_queue_rdy)

                      ,.data_o(be_fe_queue)
                      ,.v_o(be_fe_queue_v)
                      ,.yumi_i(be_fe_queue_rdy & be_fe_queue_v)
                      );

bsg_fifo_1r1w_small #(.width_p(fe_cmd_width_lp) 
                      ,.els_p(8)   
                      ,.ready_THEN_valid_p(1)
                      )
          fe_cmd_fifo(.clk_i(clk_i)
                      ,.reset_i(reset_i)
                      
                      ,.data_i(be_fe_cmd)
                      ,.v_i(be_fe_cmd_v)
                      ,.ready_o(be_fe_cmd_rdy)
                
                      ,.data_o(fe_fe_cmd)
                      ,.v_o(fe_fe_cmd_v)
                      ,.yumi_i(fe_fe_cmd_rdy & fe_fe_cmd_v)
                      );

bp_be_top #(.mhartid_p(mhartid_p)
            ,.vaddr_width_p(vaddr_width_p)
            ,.paddr_width_p(paddr_width_p)
            ,.asid_width_p(asid_width_p)
            ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
            ,.num_cce_p(num_cce_p)
            ,.num_lce_p(num_lce_p)
            ,.num_mem_p(num_mem_p)
            ,.coh_states_p(coh_states_p)
            ,.lce_assoc_p(lce_assoc_p)
            ,.lce_sets_p(lce_sets_p)
            ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)

            ,.dcache_id_p(dcache_lce_id_lp)
            )
         be(.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.fe_queue_i(be_fe_queue)
            ,.fe_queue_v_i(be_fe_queue_v)
            ,.fe_queue_rdy_o(be_fe_queue_rdy)

            ,.fe_queue_clr_o(fe_queue_clr)
            ,.fe_queue_ckpt_inc_o(fe_queue_ckpt_inc)
            ,.fe_queue_rollback_o(fe_queue_rollback)

            ,.fe_cmd_o(be_fe_cmd)
            ,.fe_cmd_v_o(be_fe_cmd_v)
            ,.fe_cmd_rdy_i(be_fe_cmd_rdy)

            ,.lce_cce_req_o(lce_cce_req[dcache_lce_id_lp])
            ,.lce_cce_req_v_o(lce_cce_req_v[dcache_lce_id_lp])
            ,.lce_cce_req_rdy_i(lce_cce_req_rdy[dcache_lce_id_lp])

            ,.lce_cce_resp_o(lce_cce_resp[dcache_lce_id_lp])
            ,.lce_cce_resp_v_o(lce_cce_resp_v[dcache_lce_id_lp])
            ,.lce_cce_resp_rdy_i(lce_cce_resp_rdy[dcache_lce_id_lp])

            ,.lce_cce_data_resp_o(lce_cce_data_resp[dcache_lce_id_lp])
            ,.lce_cce_data_resp_v_o(lce_cce_data_resp_v[dcache_lce_id_lp])
            ,.lce_cce_data_resp_rdy_i(lce_cce_data_resp_rdy[dcache_lce_id_lp])

            ,.cce_lce_cmd_i(cce_lce_cmd[dcache_lce_id_lp])
            ,.cce_lce_cmd_v_i(cce_lce_cmd_v[dcache_lce_id_lp])
            ,.cce_lce_cmd_rdy_o(cce_lce_cmd_rdy[dcache_lce_id_lp])

            ,.cce_lce_data_cmd_i(cce_lce_data_cmd[dcache_lce_id_lp])
            ,.cce_lce_data_cmd_v_i(cce_lce_data_cmd_v[dcache_lce_id_lp])
            ,.cce_lce_data_cmd_rdy_o(cce_lce_data_cmd_rdy[dcache_lce_id_lp])

            ,.lce_lce_tr_resp_i(local_lce_tr_resp[dcache_lce_id_lp])
            ,.lce_lce_tr_resp_v_i(local_lce_tr_resp_v[dcache_lce_id_lp])
            ,.lce_lce_tr_resp_rdy_o(local_lce_tr_resp_rdy[dcache_lce_id_lp])

            ,.lce_lce_tr_resp_o(remote_lce_tr_resp[dcache_lce_id_lp])
            ,.lce_lce_tr_resp_v_o(remote_lce_tr_resp_v[dcache_lce_id_lp])
            ,.lce_lce_tr_resp_rdy_i(remote_lce_tr_resp_rdy[dcache_lce_id_lp])
            );

bp_me_top #(.num_lce_p(num_lce_p)
            ,.num_cce_p(num_cce_p)
            ,.num_mem_p(num_mem_p)
            ,.addr_width_p(paddr_width_p)
            ,.lce_assoc_p(lce_assoc_p)
            ,.lce_sets_p(lce_sets_p)
            ,.coh_states_p(coh_states_p)
            ,.block_size_in_bytes_p(cce_block_size_in_bytes_p)
            ,.num_inst_ram_els_p(cce_num_inst_ram_els_p)

            ,.boot_rom_els_p(boot_rom_els_p)
            ,.boot_rom_width_p(boot_rom_width_p)
            )
         me(.clk_i(clk_i)
            ,.reset_i(reset_i)

            ,.lce_req_i(lce_cce_req)
            ,.lce_req_v_i(lce_cce_req_v)
            ,.lce_req_ready_o(lce_cce_req_rdy)

            ,.lce_resp_i(lce_cce_resp)
            ,.lce_resp_v_i(lce_cce_resp_v)
            ,.lce_resp_ready_o(lce_cce_resp_rdy)        

            ,.lce_data_resp_i(lce_cce_data_resp)
            ,.lce_data_resp_v_i(lce_cce_data_resp_v)
            ,.lce_data_resp_ready_o(lce_cce_data_resp_rdy)

            ,.lce_cmd_o(cce_lce_cmd)
            ,.lce_cmd_v_o(cce_lce_cmd_v)
            ,.lce_cmd_ready_i(cce_lce_cmd_rdy)

            ,.lce_data_cmd_o(cce_lce_data_cmd)
            ,.lce_data_cmd_v_o(cce_lce_data_cmd_v)
            ,.lce_data_cmd_ready_i(cce_lce_data_cmd_rdy)

            ,.lce_tr_resp_i(remote_lce_tr_resp)
            ,.lce_tr_resp_v_i(remote_lce_tr_resp_v)
            ,.lce_tr_resp_ready_o(remote_lce_tr_resp_rdy)

            ,.lce_tr_resp_o(local_lce_tr_resp)
            ,.lce_tr_resp_v_o(local_lce_tr_resp_v)
            ,.lce_tr_resp_ready_i(local_lce_tr_resp_rdy)
            );

bp_be_boot_rom #(.width_p(boot_rom_width_p)
                 ,.addr_width_p(lg_boot_rom_els_lp)
                 )
          irom  (.addr_i(irom_addr)
                 ,.data_o(irom_data)
                 );

endmodule : bp_be_nonsynth_mock_fe_top_wrapper


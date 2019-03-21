/**
  *
 *  * testbench.v
 *  *
 *  */

module testbench
  import bp_common_pkg::*;

   import bp_be_pkg::*;

   import bp_be_rv64_pkg::*;

   import bp_cce_pkg::*;

    #(parameter vaddr_width_p                 = "inv"
         , parameter paddr_width_p               = "inv"
         , parameter asid_width_p                = "inv"
         , parameter branch_metadata_fwd_width_p = "inv"
         , parameter btb_indx_width_p            = "inv"
         , parameter bht_indx_width_p            = "inv"
         , parameter ras_addr_width_p            = "inv"
         , parameter core_els_p                  = "inv"
         , parameter num_cce_p                   = "inv"
         , parameter num_lce_p                   = "inv"
         , parameter lce_sets_p                  = "inv"
         , parameter lce_assoc_p                 = "inv"
         , parameter cce_block_size_in_bytes_p   = "inv"
         , parameter cce_num_inst_ram_els_p      = "inv"
         , parameter mem_els_p                   = "inv"

         , parameter boot_rom_width_p            = "inv"
         , parameter boot_rom_els_p              = "inv"
         , localparam lg_boot_rom_els_lp         = `BSG_SAFE_CLOG2(boot_rom_els_p)
         , localparam cce_inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(cce_num_inst_ram_els_p)

         // Trace replay parameters
         , parameter trace_ring_width_p          = "inv"
         , parameter trace_rom_addr_width_p      = "inv"
         , localparam trace_rom_data_width_lp    = trace_ring_width_p + 4

         // From RISC-V specifications
         , localparam reg_data_width_lp = rv64_reg_data_width_gp
         , localparam byte_width_lp     = rv64_byte_width_gp

         , localparam cce_block_size_in_bits_lp = 8*cce_block_size_in_bytes_p

         , localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p
								                                                                       ,num_lce_p
								                                                                       ,lce_assoc_p)

         , localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p
										                                                                           ,cce_block_size_in_bits_lp
										                                                                           ,num_lce_p
										                                                                           ,lce_assoc_p)

         , localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p
								                                                                   ,num_lce_p
								                                                                   ,lce_assoc_p)

         , localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p
									                                                                               ,cce_block_size_in_bits_lp
									                                                                               ,num_lce_p
									                                                                               ,lce_assoc_p)
         )
     (input clk_i
         , input reset_i
      );


   // Declare parameterized structs
   `declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
     `declare_bp_common_fe_be_if_structs(vaddr_width_p
					                                     , paddr_width_p
					                                     , asid_width_p
					                                     , branch_metadata_fwd_width_p
					 );

   `declare_bp_be_internal_if_structs(vaddr_width_p
				                                         , paddr_width_p
				                                         , asid_width_p
				                                         , branch_metadata_fwd_width_p
				      );


   logic [num_cce_p-1:0][lg_boot_rom_els_lp-1:0] boot_rom_addr;

   logic [num_cce_p-1:0][boot_rom_width_p-1:0] 	 boot_rom_data;


   logic [num_cce_p-1:0][cce_inst_ram_addr_width_lp-1:0] cce_inst_boot_rom_addr;

   logic [num_cce_p-1:0][`bp_cce_inst_width-1:0] 	 cce_inst_boot_rom_data;


   bp_be_pipe_stage_reg_s[core_els_p-1:0] cmt_trace_stage_reg;

   bp_be_calc_result_s   [core_els_p-1:0] cmt_trace_result;

   bp_be_exception_s     [core_els_p-1:0] cmt_trace_exc;


   logic [trace_ring_width_p-1:0] 			 tr_data_i;

   logic 						 tr_v_i, tr_ready_o;

   logic [trace_rom_addr_width_p-1:0] 			 tr_rom_addr_i;

   logic [trace_rom_data_width_lp-1:0] 			 tr_rom_data_o;

   logic 						 test_done;


   logic [num_cce_p-1:0][bp_mem_cce_resp_width_lp-1:0] 	 mem_resp;

   logic [num_cce_p-1:0] 				 mem_resp_v;

   logic [num_cce_p-1:0] 				 mem_resp_ready;


   logic [num_cce_p-1:0][bp_mem_cce_data_resp_width_lp-1:0] mem_data_resp;

   logic [num_cce_p-1:0] 				    mem_data_resp_v;

   logic [num_cce_p-1:0] 				    mem_data_resp_ready;


   logic [num_cce_p-1:0][bp_cce_mem_cmd_width_lp-1:0] 	    mem_cmd;

   logic [num_cce_p-1:0] 				    mem_cmd_v;

   logic [num_cce_p-1:0] 				    mem_cmd_yumi;


   logic [num_cce_p-1:0][bp_cce_mem_data_cmd_width_lp-1:0]  mem_data_cmd;

   logic [num_cce_p-1:0] 				    mem_data_cmd_v;

   logic [num_cce_p-1:0] 				    mem_data_cmd_yumi;



   bp_multi_top
      #(.vaddr_width_p(vaddr_width_p)
	   ,.paddr_width_p(paddr_width_p)
	   ,.asid_width_p(asid_width_p)
	   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
	   ,.btb_indx_width_p(btb_indx_width_p)
	   ,.bht_indx_width_p(bht_indx_width_p)
	   ,.ras_addr_width_p(ras_addr_width_p)
	   ,.core_els_p(core_els_p)
	   ,.num_cce_p(num_cce_p)
	   ,.num_lce_p(num_lce_p)
	   ,.lce_sets_p(lce_sets_p)
	   ,.lce_assoc_p(lce_assoc_p)
	   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
	   ,.cce_num_inst_ram_els_p(cce_num_inst_ram_els_p)
	   )
    dut
        (.clk_i(clk_i)
	    ,.reset_i(reset_i)

	    ,.cce_inst_boot_rom_addr_o(cce_inst_boot_rom_addr)
	    ,.cce_inst_boot_rom_data_i(cce_inst_boot_rom_data)

	    ,.cmt_trace_stage_reg_o(cmt_trace_stage_reg)
	    ,.cmt_trace_result_o(cmt_trace_result)
	    ,.cmt_trace_exc_o(cmt_trace_exc)


	    ,.mem_resp_i(mem_resp)
	    ,.mem_resp_v_i(mem_resp_v)
	    ,.mem_resp_ready_o(mem_resp_ready)

	    ,.mem_data_resp_i(mem_data_resp)
	    ,.mem_data_resp_v_i(mem_data_resp_v)
	    ,.mem_data_resp_ready_o(mem_data_resp_ready)

	    ,.mem_cmd_o(mem_cmd)
	    ,.mem_cmd_v_o(mem_cmd_v)
	    ,.mem_cmd_yumi_i(mem_cmd_yumi)

	    ,.mem_data_cmd_o(mem_data_cmd)
	    ,.mem_data_cmd_v_o(mem_data_cmd_v)
	    ,.mem_data_cmd_yumi_i(mem_data_cmd_yumi)
	 );


   for (genvar i = 0; i < num_cce_p; i++) begin
      bp_cce_inst_rom
	  #(.width_p(`bp_cce_inst_width)
	        ,.addr_width_p(cce_inst_ram_addr_width_lp)
	        )
        cce_inst_rom
	     (.addr_i(cce_inst_boot_rom_addr[i])
	          ,.data_o(cce_inst_boot_rom_data[i])
	      );


      bp_mem
	  #(.num_lce_p(num_lce_p)
	        ,.num_cce_p(num_cce_p)
	        ,.paddr_width_p(paddr_width_p)
	        ,.lce_assoc_p(lce_assoc_p)
	        ,.block_size_in_bytes_p(cce_block_size_in_bits_lp/8)
	        ,.lce_sets_p(lce_sets_p)
	        ,.mem_els_p(mem_els_p)
	        ,.boot_rom_width_p(cce_block_size_in_bits_lp)
	        ,.boot_rom_els_p(boot_rom_els_p)
	      )
        bp_mem
	    (.clk_i(clk_i)
	        ,.reset_i(reset_i)

	        ,.mem_cmd_i(mem_cmd[i])
	        ,.mem_cmd_v_i(mem_cmd_v[i])
	        ,.mem_cmd_yumi_o(mem_cmd_yumi[i])

	        ,.mem_data_cmd_i(mem_data_cmd[i])
	        ,.mem_data_cmd_v_i(mem_data_cmd_v[i])
	        ,.mem_data_cmd_yumi_o(mem_data_cmd_yumi[i])

	        ,.mem_resp_o(mem_resp[i])
	        ,.mem_resp_v_o(mem_resp_v[i])
	        ,.mem_resp_ready_i(mem_resp_ready[i])

	        ,.mem_data_resp_o(mem_data_resp[i])
	        ,.mem_data_resp_v_o(mem_data_resp_v[i])
	        ,.mem_data_resp_ready_i(mem_data_resp_ready[i])

	        ,.boot_rom_addr_o(boot_rom_addr[i])
	        ,.boot_rom_data_i(boot_rom_data[i])
	     );


   end // for (genvar i = 0; i < num_cce_p; i++)



   bp_be_trace_replay_gen
      #(.vaddr_width_p(vaddr_width_p)
	   ,.paddr_width_p(paddr_width_p)
	   ,.asid_width_p(asid_width_p)
	   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
	   ,.trace_ring_width_p(trace_ring_width_p)
	   )
    be_trace_gen
        (.clk_i(clk_i)
	    ,.reset_i(reset_i)

	    ,.cmt_trace_stage_reg_i(cmt_trace_stage_reg)
	    ,.cmt_trace_result_i(cmt_trace_result)
	    ,.cmt_trace_exc_i(cmt_trace_exc)

	    ,.data_o(tr_data_i)
	    ,.v_o(tr_v_i)
	    ,.ready_i(tr_ready_o)
	 );


   bsg_fsb_node_trace_replay
      #(.ring_width_p(trace_ring_width_p)
	   ,.rom_addr_width_p(trace_rom_addr_width_p)
	   )
    be_trace_replay
        (.clk_i(clk_i)
	    ,.reset_i(reset_i)
	    ,.en_i(1'b1)

	    ,.v_i(tr_v_i)
	    ,.data_i(tr_data_i)
	    ,.ready_o(tr_ready_o)

	    ,.v_o()
	    ,.data_o()
	    ,.yumi_i(1'b0)

	    ,.rom_addr_o(tr_rom_addr_i)
	    ,.rom_data_i(tr_rom_data_o)

	    ,.done_o(test_done)
	    ,.error_o()
	 );


   bp_trace_rom
      #(.width_p(trace_rom_data_width_lp)
	   ,.addr_width_p(trace_rom_addr_width_p)
	   )
    trace_rom
        (.addr_i(tr_rom_addr_i)
	    ,.data_o(tr_rom_data_o)
	 );


   for (genvar i = 0; i < num_cce_p; i++)
     begin : rof1
	    bp_boot_rom
	           #(.width_p(boot_rom_width_p)
		            ,.addr_width_p(lg_boot_rom_els_lp)
		            )
	     me_boot_rom
	             (.addr_i(boot_rom_addr[i])
		             ,.data_o(boot_rom_data[i])
		      );

	  end // rof1

   logic booted;


   localparam max_instr_cnt_lp    = 2**30-1;

   localparam lg_max_instr_cnt_lp = `BSG_SAFE_CLOG2(max_instr_cnt_lp);

   logic [lg_max_instr_cnt_lp-1:0] instr_cnt;


     bsg_counter_clear_up
          #(.max_val_p(max_instr_cnt_lp)
	         ,.init_val_p(0)
	         )
      instr_counter
	    (.clk_i(clk_i)
	          ,.reset_i(reset_i)

	          ,.clear_i(1'b0)
	          ,.up_i(~(|cmt_trace_exc[0]
			                 | cmt_trace_stage_reg[0].decode.fe_nop_v
			                 | cmt_trace_stage_reg[0].decode.be_nop_v
			                 | cmt_trace_stage_reg[0].decode.me_nop_v
			                 )
			             )

	          ,.count_o(instr_cnt)
	     );


   localparam max_clock_cnt_lp    = 2**30-1;

   localparam lg_max_clock_cnt_lp = `BSG_SAFE_CLOG2(max_clock_cnt_lp);

   logic [lg_max_clock_cnt_lp-1:0] clock_cnt;


     bsg_counter_clear_up
          #(.max_val_p(max_clock_cnt_lp)
	         ,.init_val_p(0)
	         )
      clock_counter
	    (.clk_i(clk_i)
	          ,.reset_i(reset_i)

	          ,.clear_i(~booted)
	          ,.up_i(1'b1)

	          ,.count_o(clock_cnt)
	     );


   always_ff @(posedge clk_i)
     begin
	    if (reset_i)
	      booted <= 1'b0;

	    else
	      begin
		 booted <= booted | boot_rom_addr[0] == lg_boot_rom_els_lp'(511);

	      end
     end // always_ff @ (posedge clk_i)

   always_ff @(posedge clk_i)
     begin
	    if (test_done)
	      begin
		 $display("Test PASSed! Clocks: %d Instr: %d mIPC: %d", clock_cnt, instr_cnt, (1000*instr_cnt) / clock_cnt);

		 $finish(0);

	      end
     end


endmodule : testbench

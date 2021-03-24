/**
  *
  * testbench.v
  *
  */

module testbench
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bp_me_nonsynth_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR // Replaced by the flow with a specific bp_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter cce_trace_p = 0
   , parameter cce_dir_trace_p = 0
   , parameter axe_trace_p = 0
   , parameter instr_count = 1
   , parameter skip_init_p = 0
   , parameter lce_trace_p = 0
   , parameter lce_tr_trace_p = 0
   , parameter dram_trace_p = 0
   , parameter dram_fixed_latency_p=0

   // DRAM parameters
   , parameter dram_type_p                 = BP_DRAM_FLOWVAR // Replaced by the flow with a specific dram_type
   
   // size of CCE-Memory buffers for cmd/resp messages
   // for this testbench (one LCE, one CCE, one memory) only need enough space to hold as many
   // cmds/responses can be generated for a single LCE request
   , parameter mem_buffer_els_lp         = 4

   // LCE Trace Replay Width
   , localparam lce_opcode_width_lp=$bits(bp_me_nonsynth_lce_opcode_e)
   , localparam tr_ring_width_lp=`bp_me_nonsynth_lce_tr_pkt_width(paddr_width_p, dword_width_gp)
   , localparam tr_rom_addr_width_p = 20

   )
  (input   bit clk_i
   , input bit reset_i
   , input bit dram_clk_i
   , input bit dram_reset_i
   );

export "DPI-C" function get_dram_period;
export "DPI-C" function get_sim_period;

function int get_dram_period();
  return (`dram_pkg::tck_ps);
endfunction

function int get_sim_period();
  return (`BP_SIM_CLK_PERIOD);
endfunction

`declare_bp_cfg_bus_s(domain_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p);
`declare_bp_bedrock_lce_if(paddr_width_p, cce_block_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
`declare_bp_bedrock_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce);
`declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);

// CFG IF
bp_cfg_bus_s             cfg_bus_lo;
bp_bedrock_cce_mem_msg_s cfg_mem_cmd_lo;
bp_bedrock_xce_mem_msg_s cfg_mem_cmd;
logic                    cfg_mem_cmd_v_lo, cfg_mem_cmd_ready_li;
assign cfg_mem_cmd = '{header: cfg_mem_cmd_lo.header
                      ,data: cfg_mem_cmd_lo.data[0+:dword_width_gp]
                      };

// CCE-MEM IF
bp_bedrock_cce_mem_msg_s mem_resp;
logic                    mem_resp_v, mem_resp_yumi;
bp_bedrock_cce_mem_msg_s mem_cmd;
logic                    mem_cmd_v, mem_cmd_ready;

// LCE-CCE IF
bp_bedrock_lce_req_msg_s  lce_req_lo, lce_req;
bp_bedrock_lce_resp_msg_s lce_resp, lce_resp_lo;
bp_bedrock_lce_cmd_msg_s  lce_cmd, lce_cmd_lo, lce_cmd_out_lo;
logic                  lce_req_v, lce_req_v_lo, lce_req_yumi, lce_req_ready_li;
logic                  lce_resp_v, lce_resp_v_lo, lce_resp_yumi, lce_resp_ready_li;
logic                  lce_cmd_v, lce_cmd_yumi;
logic                  lce_cmd_v_lo, lce_cmd_ready_li;
logic                  lce_cmd_out_v_lo, lce_cmd_out_ready_li;
// Single LCE setup - LCE should never send a Data Command
assign lce_cmd_out_ready_li = '0;

// Trace Replay for LCE
logic                        tr_v_li, tr_ready_lo;
logic [tr_ring_width_lp-1:0] tr_data_li;
logic                        tr_v_lo, tr_yumi_li;
logic [tr_ring_width_lp-1:0] tr_data_lo;
logic tr_done_lo;

bsg_trace_node_master #(
  .id_p('0)
  ,.ring_width_p(tr_ring_width_lp)
  ,.rom_addr_width_p(tr_rom_addr_width_p)
) trace_node_master (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.en_i(1'b1)

  ,.v_i(tr_v_li)
  ,.data_i(tr_data_li)
  ,.ready_o(tr_ready_lo)

  ,.v_o(tr_v_lo)
  ,.yumi_i(tr_yumi_li)
  ,.data_o(tr_data_lo)

  ,.done_o(tr_done_lo)
);


// LCE
bp_me_nonsynth_mock_lce #(
  .bp_params_p(bp_params_p)
  ,.axe_trace_p(axe_trace_p)
  ,.skip_init_p(skip_init_p)
) lce (
  .clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.freeze_i(cfg_bus_lo.freeze)

  ,.lce_id_i('0)

  ,.tr_pkt_i(tr_data_lo)
  ,.tr_pkt_v_i(tr_v_lo)
  ,.tr_pkt_yumi_o(tr_yumi_li)

  ,.tr_pkt_v_o(tr_v_li)
  ,.tr_pkt_o(tr_data_li)
  ,.tr_pkt_ready_i(tr_ready_lo)

  ,.lce_req_o(lce_req_lo)
  ,.lce_req_v_o(lce_req_v_lo)
  ,.lce_req_ready_i(lce_req_ready_li)

  ,.lce_resp_o(lce_resp_lo)
  ,.lce_resp_v_o(lce_resp_v_lo)
  ,.lce_resp_ready_i(lce_resp_ready_li)

  ,.lce_cmd_i(lce_cmd)
  ,.lce_cmd_v_i(lce_cmd_v)
  ,.lce_cmd_yumi_o(lce_cmd_yumi)

  ,.lce_cmd_o(lce_cmd_out_lo)
  ,.lce_cmd_v_o(lce_cmd_out_v_lo)
  ,.lce_cmd_ready_i(lce_cmd_out_ready_li)
);

bind bp_me_nonsynth_mock_lce
  bp_me_nonsynth_lce_tracer
    #(.bp_params_p(bp_params_p)
      ,.sets_p(sets_p)
      ,.assoc_p(assoc_p)
      ,.block_width_p(cce_block_width_p)
      )
    lce_tracer
     (.clk_i(clk_i & (testbench.lce_trace_p == 1))
      ,.reset_i(reset_i)
      ,.lce_id_i(lce_id_i)
      ,.lce_req_i(lce_req_o)
      ,.lce_req_v_i(lce_req_v_o)
      ,.lce_req_ready_i(lce_req_ready_i)
      ,.lce_resp_i(lce_resp_o)
      ,.lce_resp_v_i(lce_resp_v_o)
      ,.lce_resp_ready_i(lce_resp_ready_i)
      ,.lce_cmd_i(lce_cmd_i)
      ,.lce_cmd_v_i(lce_cmd_v_i)
      ,.lce_cmd_yumi_i(lce_cmd_yumi_o)
      ,.lce_cmd_o_i(lce_cmd_o)
      ,.lce_cmd_o_v_i(lce_cmd_v_o)
      ,.lce_cmd_o_ready_i(lce_cmd_ready_i)
      );

bind bp_me_nonsynth_mock_lce
  bp_me_nonsynth_lce_tr_tracer
    #(.bp_params_p(bp_params_p)
      ,.sets_p(sets_p)
      ,.block_width_p(cce_block_width_p)
      )
    lce_tr_tracer
     (.clk_i(clk_i & (testbench.lce_tr_trace_p == 1))
      ,.reset_i(reset_i)
      ,.lce_id_i(lce_id_i)
      ,.tr_pkt_i(tr_pkt_i)
      ,.tr_pkt_v_i(tr_pkt_v_i)
      ,.tr_pkt_yumi_i(tr_pkt_yumi_o)
      ,.tr_pkt_o_i(tr_pkt_o)
      ,.tr_pkt_v_o_i(tr_pkt_v_o)
      ,.tr_pkt_ready_i(tr_pkt_ready_i)
      );

bind bp_cce_wrapper
  bp_me_nonsynth_cce_tracer
    #(.bp_params_p(bp_params_p))
    cce_tracer
     (.clk_i(clk_i & (testbench.cce_trace_p == 1))
      ,.reset_i(reset_i)
      ,.freeze_i(cfg_bus_cast_i.freeze)

      ,.cce_id_i(cfg_bus_cast_i.cce_id)

      // To CCE
      ,.lce_req_i(lce_req_i)
      ,.lce_req_v_i(lce_req_v_i)
      ,.lce_req_yumi_i(lce_req_yumi_o)
      ,.lce_resp_i(lce_resp_i)
      ,.lce_resp_v_i(lce_resp_v_i)
      ,.lce_resp_yumi_i(lce_resp_yumi_o)

      // From CCE
      ,.lce_cmd_i(lce_cmd_o)
      ,.lce_cmd_v_i(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp_i)
      ,.mem_resp_v_i(mem_resp_v_i)
      ,.mem_resp_yumi_i(mem_resp_yumi_o)

      // From CCE
      ,.mem_cmd_i(mem_cmd_o)
      ,.mem_cmd_v_i(mem_cmd_v_o)
      ,.mem_cmd_ready_i(mem_cmd_ready_i)
      );

bind bp_cce_dir
  bp_me_nonsynth_cce_dir_tracer
    #(.bp_params_p(bp_params_p))
    cce_dir_tracer
     (.clk_i(clk_i & (testbench.cce_dir_trace_p == 1))
      ,.reset_i(reset_i)

      ,.cce_id_i(cce_id_i)
      ,.addr_i(addr_i)
      ,.addr_bypass_i(addr_bypass_i)
      ,.lce_i(lce_i)
      ,.way_i(way_i)
      ,.lru_way_i(lru_way_i)
      ,.coh_state_i(coh_state_i)
      ,.addr_dst_gpr_i(addr_dst_gpr_i)
      ,.cmd_i(cmd_i)
      ,.r_v_i(r_v_i)
      ,.w_v_i(w_v_i)
      ,.busy_i(busy_o)
      ,.sharers_v_i(sharers_v_o)
      ,.sharers_hits_i(sharers_hits_o)
      ,.sharers_ways_i(sharers_ways_o)
      ,.sharers_coh_states_i(sharers_coh_states_o)
      ,.lru_v_i(lru_v_o)
      ,.lru_coh_state_i(lru_coh_state_o)
      ,.lru_addr_i(lru_addr_o)
      ,.addr_v_i(addr_v_o)
      ,.addr_o_i(addr_o)
      ,.addr_dst_gpr_o_i(addr_dst_gpr_o)
      );


bsg_two_fifo
#(.width_p($bits(bp_bedrock_lce_req_msg_s))
  )
lce_req_buffer
 (.clk_i(clk_i)
  ,.reset_i(reset_i)
  // from LCE
  ,.v_i(lce_req_v_lo)
  ,.data_i(lce_req_lo)
  ,.ready_o(lce_req_ready_li)
  // to CCE
  ,.v_o(lce_req_v)
  ,.data_o(lce_req)
  ,.yumi_i(lce_req_yumi)
  );

bsg_two_fifo
#(.width_p($bits(bp_bedrock_lce_resp_msg_s))
  )
lce_resp_buffer
 (.clk_i(clk_i)
  ,.reset_i(reset_i)
  // from LCE
  ,.v_i(lce_resp_v_lo)
  ,.data_i(lce_resp_lo)
  ,.ready_o(lce_resp_ready_li)
  // to CCE
  ,.v_o(lce_resp_v)
  ,.data_o(lce_resp)
  ,.yumi_i(lce_resp_yumi)
  );

bsg_two_fifo
#(.width_p($bits(bp_bedrock_lce_cmd_msg_s))
  )
lce_cmd_buffer
 (.clk_i(clk_i)
  ,.reset_i(reset_i)
  // from CCE
  ,.v_i(lce_cmd_v_lo)
  ,.data_i(lce_cmd_lo)
  ,.ready_o(lce_cmd_ready_li)
  // to LCE
  ,.v_o(lce_cmd_v)
  ,.data_o(lce_cmd)
  ,.yumi_i(lce_cmd_yumi)
  );

logic cce_ucode_v_li;
logic cce_ucode_w_li;
logic [cce_pc_width_p-1:0] cce_ucode_addr_li;
logic [cce_instr_width_gp-1:0] cce_ucode_data_li;
logic [cce_instr_width_gp-1:0] cce_ucode_data_lo;

// CCE
wrapper
#(.bp_params_p(bp_params_p)
  ,.cce_trace_p(cce_trace_p)
 )
wrapper
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.cfg_bus_i(cfg_bus_lo)

  ,.ucode_v_i(cce_ucode_v_li)
  ,.ucode_w_i(cce_ucode_w_li)
  ,.ucode_addr_i(cce_ucode_addr_li)
  ,.ucode_data_i(cce_ucode_data_li)
  ,.ucode_data_o(cce_ucode_data_lo)

  ,.lce_cmd_o(lce_cmd_lo)
  ,.lce_cmd_v_o(lce_cmd_v_lo)
  ,.lce_cmd_ready_i(lce_cmd_ready_li)

  ,.lce_req_i(lce_req)
  ,.lce_req_v_i(lce_req_v)
  ,.lce_req_yumi_o(lce_req_yumi)

  ,.lce_resp_i(lce_resp)
  ,.lce_resp_v_i(lce_resp_v)
  ,.lce_resp_yumi_o(lce_resp_yumi)

  ,.mem_resp_i(mem_resp)
  ,.mem_resp_v_i(mem_resp_v)
  ,.mem_resp_yumi_o(mem_resp_yumi)

  ,.mem_cmd_o(mem_cmd)
  ,.mem_cmd_v_o(mem_cmd_v)
  ,.mem_cmd_ready_i(mem_cmd_ready)
);


// CCE-MEM Buffers
// Since bp_mem only processes one command at a time, and the response must be consumed
// before mem can process the next request, we need some buffering here. It is possible the
// CCE issues a speculative memory access and then issues a second command (e.g., a writeback)
// before resolving the speculation. This leads to a situation where the CCE can't consume the
// memory response and is trying to send a memory command, but bp_mem is already "full," a.k.a.,
// deadlock!

// Memory Command Buffer
bp_bedrock_cce_mem_msg_s mem_cmd_lo;
logic                    mem_cmd_v_lo, mem_cmd_ready_lo;
bsg_fifo_1r1w_small
#(.width_p($bits(bp_bedrock_cce_mem_msg_s))
  ,.els_p(mem_buffer_els_lp)
  )
mem_cmd_buffer
 (.clk_i(clk_i)
  ,.reset_i(reset_i)
  // from CCE
  ,.v_i(mem_cmd_v)
  ,.data_i(mem_cmd)
  ,.ready_o(mem_cmd_ready)
  // to memory
  ,.v_o(mem_cmd_v_lo)
  ,.data_o(mem_cmd_lo)
  ,.yumi_i(mem_cmd_ready_lo & mem_cmd_v_lo)
  );

// Memory Response Buffer
bp_bedrock_cce_mem_msg_s mem_resp_lo;
logic                    mem_resp_v_lo, mem_resp_ready_lo;
bsg_fifo_1r1w_small
#(.width_p($bits(bp_bedrock_cce_mem_msg_s))
  ,.els_p(mem_buffer_els_lp)
  )
mem_resp_buffer
 (.clk_i(clk_i)
  ,.reset_i(reset_i)
  // from memory
  ,.v_i(mem_resp_v_lo & mem_resp_ready_lo)
  ,.data_i(mem_resp_lo)
  ,.ready_o(mem_resp_ready_lo)
  // to CCE
  ,.v_o(mem_resp_v)
  ,.data_o(mem_resp)
  ,.yumi_i(mem_resp_yumi)
  );

// DRAM
bp_nonsynth_mem
#(.bp_params_p(bp_params_p)
  ,.dram_type_p(dram_type_p)
  ,.mem_els_p(2**20)
  ,.preload_mem_p(1)
  )
mem
 (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.mem_cmd_i(mem_cmd_lo)
  ,.mem_cmd_v_i(mem_cmd_v_lo & mem_cmd_ready_lo)
  ,.mem_cmd_ready_o(mem_cmd_ready_lo)

  ,.mem_resp_o(mem_resp_lo)
  ,.mem_resp_v_o(mem_resp_v_lo)
  ,.mem_resp_yumi_i(mem_resp_v_lo & mem_resp_ready_lo)

  ,.dram_clk_i(dram_clk_i)
  ,.dram_reset_i(dram_reset_i)
  );

bp_mem_nonsynth_tracer
 #(.bp_params_p(bp_params_p))
 bp_mem_tracer
  (.clk_i(clk_i & (testbench.dram_trace_p == 1))
   ,.reset_i(reset_i)

   ,.mem_cmd_i(mem_cmd)
   ,.mem_cmd_v_i(mem_cmd_v)
   ,.mem_cmd_ready_i(mem_cmd_ready)

   ,.mem_resp_i(mem_resp)
   ,.mem_resp_v_i(mem_resp_v)
   ,.mem_resp_yumi_i(mem_resp_yumi)
   );

logic [coh_noc_cord_width_p-1:0] cord_li = {{coh_noc_y_cord_width_p'(1'b1)}, {coh_noc_x_cord_width_p'('0)}};
logic cfg_resp_v_lo;
bp_cfg
 #(.bp_params_p(bp_params_p))
 cfg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(cfg_mem_cmd)
   ,.mem_cmd_v_i(cfg_mem_cmd_v_lo)
   ,.mem_cmd_ready_o(cfg_mem_cmd_ready_li)

   ,.mem_resp_o()
   ,.mem_resp_v_o(cfg_resp_v_lo)
   ,.mem_resp_yumi_i(cfg_resp_v_lo)

   ,.cfg_bus_o(cfg_bus_lo)
   ,.did_i('0)
   ,.host_did_i('0)
   ,.cord_i(cord_li)

   ,.cce_ucode_v_o(cce_ucode_v_li)
   ,.cce_ucode_w_o(cce_ucode_w_li)
   ,.cce_ucode_addr_o(cce_ucode_addr_li)
   ,.cce_ucode_data_o(cce_ucode_data_li)
   ,.cce_ucode_data_i(cce_ucode_data_lo)
   );

// CFG loader
localparam cce_instr_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_instr_ram_els_p);

logic cfg_loader_resp_v;
always_ff @(posedge clk_i) begin
  if (reset_i) begin
    cfg_loader_resp_v <= '0;
  end else begin
    cfg_loader_resp_v <= cfg_mem_cmd_v_lo & cfg_mem_cmd_ready_li;
  end
end

logic cfg_loader_done_lo;

bp_cce_mmio_cfg_loader
  #(.bp_params_p(bp_params_p)
    ,.inst_width_p($bits(bp_cce_inst_s))
    ,.inst_ram_addr_width_p(cce_instr_ram_addr_width_lp)
    ,.inst_ram_els_p(num_cce_instr_ram_els_p)
    ,.skip_ram_init_p(skip_init_p)
    ,.clear_freeze_p(1'b1)
  )
  cfg_loader
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.lce_id_i('0)

   ,.io_cmd_o(cfg_mem_cmd_lo)
   ,.io_cmd_v_o(cfg_mem_cmd_v_lo)
   ,.io_cmd_yumi_i(cfg_mem_cmd_ready_li & cfg_mem_cmd_v_lo)

   // Response port not used by module, except for flow control counter.
   // cfg_loader_resp_v is cfg_mem_cmd_yumi_li delayed one cycle through a
   // register. Every io_cmd sent out will be responded to the next cycle,
   // to keep the flow control counter correct.
   ,.io_resp_i('0)
   ,.io_resp_v_i(cfg_loader_resp_v)
   ,.io_resp_ready_o()

   ,.done_o(cfg_loader_done_lo)
  );

bp_nonsynth_if_verif
 #(.bp_params_p(bp_params_p))
 if_verif
  ();

// Program done info
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

   ,.clear_i(reset_i)
   ,.up_i(1'b1)

   ,.count_o(clock_cnt)
   );

always_ff @(negedge clk_i) begin
  if (tr_done_lo) begin
    $display("Bytes: %d Clocks: %d mBPC: %d "
             , instr_count*64
             , clock_cnt
             , (instr_count*64*1000) / clock_cnt
             );
    $display("Test PASSed");
    $finish(0);
  end
end

endmodule : testbench


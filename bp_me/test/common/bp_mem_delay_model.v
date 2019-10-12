
module bp_mem_delay_model
 #(parameter addr_width_p = "inv"

   , parameter use_max_latency_p      = 0
   , parameter use_random_latency_p   = 0
   , parameter use_dramsim2_latency_p = 0
   
   , parameter max_latency_p = "inv"

   , parameter dram_clock_period_in_ps_p = "inv"
   , parameter dram_bp_params_p                = "inv"
   , parameter dram_sys_bp_params_p            = "inv"
   , parameter dram_capacity_p           = "inv"
   )
  (input                      clk_i
   , input                    reset_i

   , input [addr_width_p-1:0] addr_i
   , input                    v_i
   , input                    w_i
   , output                   ready_o

   , output                   v_o
   , input                    yumi_i
   );

localparam latency_width_lp = `BSG_SAFE_CLOG2(max_latency_p+1);

enum bit {e_idle, e_service} state_n, state_r;

always_ff @(posedge clk_i)
  if (reset_i)
    state_r <= e_idle;
  else
    state_r <= state_n;

always_comb
  case (state_r)
    e_idle   : state_n = v_i ? e_service : e_idle;
    e_service: state_n = yumi_i ? e_idle : e_service;
    default  : state_n = e_idle;
  endcase

logic [latency_width_lp-1:0] current_latency;
logic [latency_width_lp-1:0] latency_cnt;

wire clr_counter = yumi_i;
wire inc_counter = (state_r == e_service) & (latency_cnt < current_latency);
bsg_counter_clear_up
 #(.max_val_p(max_latency_p)
   ,.init_val_p(0)
   )
 latency_counter
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.clear_i(clr_counter)
   ,.up_i(inc_counter)

   ,.count_o(latency_cnt)
   );

if (use_max_latency_p)
  begin : max_latency
    assign current_latency = max_latency_p;

    assign ready_o = (state_r == e_idle);
    assign v_o = (latency_cnt == current_latency);
  end
else if (use_random_latency_p)
  begin : random_latency
    logic [31:0] lfsr_reg;
    bsg_lfsr
     #(.width_p(32))
     latency_lfsr
      (.clk(clk_i)
       ,.reset_i(reset_i)

       ,.yumi_i(yumi_i)
       ,.o(lfsr_reg)
       );
    assign current_latency = lfsr_reg | 1'b1;

    assign ready_o = (state_r == e_idle);
    assign v_o = (latency_cnt == current_latency);
  end
else if (use_dramsim2_latency_p)
  begin : dramsim2
    `ifdef DRAMSIM2
      logic dramsim_valid, dramsim_accepted;
      logic pending_req_r, pending_req_w_r, pending_resp_r;
      bsg_dff_reset_en
       #(.width_p(1))
       pending_resp_reg
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.en_i(dramsim_valid | yumi_i)

         ,.data_i(dramsim_valid)
         ,.data_o(pending_resp_r)
         );

       logic w_r, v_r;
       bsg_dff_reset_en
        #(.width_p(2))
        pending_req_reg
         (.clk_i(clk_i)
          ,.reset_i(reset_i)
          ,.en_i(dramsim_accepted | v_i)

          ,.data_i({w_i, v_i})
          ,.data_o({pending_req_w_r, pending_req_r})
          );

      initial 
        init(dram_clock_period_in_ps_p, dram_bp_params_p, dram_sys_bp_params_p, dram_capacity_p);

      always_ff @(negedge clk_i)
        begin
          if (pending_req_r & ~pending_req_w_r)
            dramsim_accepted <= mem_read_req(addr_i);
          else if (pending_req_r & pending_req_w_r)
            dramsim_accepted <= mem_write_req(addr_i);

          dramsim_valid <= tick();
        end

      assign ready_o = (state_r == e_idle);
      assign v_o     = pending_resp_r;
    `else
      $fatal("DRAMSIM2 delay model selection, but DRAMSIM2 is not set");
    `endif
  end

  `ifdef DRAMSIM2
    import "DPI-C" context function void init(input longint clock_period
                                              , input string dram_cfg_name
                                              , input string system_cfg_name
                                              , input longint dram_capacity
                                              );

    import "DPI-C" context function bit tick();

    import "DPI-C" context function bit mem_read_req(input longint addr);
    import "DPI-C" context function bit mem_write_req(input longint addr);
  `endif

endmodule


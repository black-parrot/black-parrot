/**
 *
 * wrapper.v
 *
 */
 
`include "bsg_noc_links.vh"

module wrapper
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_me_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
   )
  (input                                               clk_i
   , input                                             reset_i

   // Outgoing I/O
   , output [cce_mem_msg_width_lp-1:0]                 io_cmd_o
   , output                                            io_cmd_v_o
   , input                                             io_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  io_resp_i
   , input                                             io_resp_v_i
   , output                                            io_resp_yumi_o

   // Incoming I/O
   , input [cce_mem_msg_width_lp-1:0]                  io_cmd_i
   , input                                             io_cmd_v_i
   , output                                            io_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]                 io_resp_o
   , output                                            io_resp_v_o
   , input                                             io_resp_ready_i

   // Memory Requests
   , output [cce_mem_msg_width_lp-1:0]                 mem_cmd_o
   , output                                            mem_cmd_v_o
   , input                                             mem_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                  mem_resp_i
   , input                                             mem_resp_v_i
   , output                                            mem_resp_yumi_o
   );

  if (bp_params_p == e_bp_softcore_cfg)
    begin : softcore
      bp_softcore
       #(.bp_params_p(bp_params_p))
       dut
        (.*);
    end
  else
    begin : processor
      `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
      `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);

      bp_io_noc_ral_link_s proc_cmd_link_li, proc_cmd_link_lo;
      bp_io_noc_ral_link_s proc_resp_link_li, proc_resp_link_lo;
      bp_mem_noc_ral_link_s dram_cmd_link_lo, dram_resp_link_li;
      bp_io_noc_ral_link_s stub_cmd_link_li, stub_resp_link_li;
      bp_io_noc_ral_link_s stub_cmd_link_lo, stub_resp_link_lo;

      wire [io_noc_did_width_p-1:0] proc_did_li = 1;
      wire [io_noc_did_width_p-1:0] dram_did_li = '1;

      assign stub_cmd_link_li  = '0;
      assign stub_resp_link_li = '0;

      bp_processor
       #(.bp_params_p(bp_params_p))
       dut
        (.core_clk_i(clk_i)
         ,.core_reset_i(reset_i)
      
         ,.coh_clk_i(clk_i)
         ,.coh_reset_i(reset_i)
      
         ,.io_clk_i(clk_i)
         ,.io_reset_i(reset_i)
      
         ,.mem_clk_i(clk_i)
         ,.mem_reset_i(reset_i)
      
         ,.my_did_i(proc_did_li)
         ,.host_did_i(dram_did_li)
      
         ,.io_cmd_link_i({proc_cmd_link_li, stub_cmd_link_li})
         ,.io_cmd_link_o({proc_cmd_link_lo, stub_cmd_link_lo})
      
         ,.io_resp_link_i({proc_resp_link_li, stub_resp_link_li})
         ,.io_resp_link_o({proc_resp_link_lo, stub_resp_link_lo})
      
         ,.dram_cmd_link_o(dram_cmd_link_lo)
         ,.dram_resp_link_i(dram_resp_link_li)
         );

      logic io_cmd_ready_lo, io_resp_ready_lo;
      assign io_cmd_yumi_o = io_cmd_ready_lo & io_cmd_v_i;
      assign io_resp_yumi_o = io_resp_ready_lo & io_resp_v_i;
      wire [io_noc_cord_width_p-1:0] dst_cord_lo = 1;
      bp_me_cce_to_mem_link_bidir
       #(.bp_params_p(bp_params_p)
         ,.num_outstanding_req_p(io_noc_max_credits_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.len_width_p(io_noc_len_width_p)
         )
       host_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.mem_cmd_i(io_cmd_i)
         ,.mem_cmd_v_i(io_cmd_v_i)
         ,.mem_cmd_ready_o(io_cmd_ready_lo)

         ,.mem_resp_o(io_resp_o)
         ,.mem_resp_v_o(io_resp_v_o)
         ,.mem_resp_yumi_i(io_resp_ready_i & io_resp_v_o)

         ,.my_cord_i(io_noc_cord_width_p'(dram_did_li))
         ,.my_cid_i('0)
         ,.dst_cord_i(dst_cord_lo)
         ,.dst_cid_i('0)

         ,.mem_cmd_o(io_cmd_o)
         ,.mem_cmd_v_o(io_cmd_v_o)
         ,.mem_cmd_yumi_i(io_cmd_ready_i & io_cmd_v_o)

         ,.mem_resp_i(io_resp_i)
         ,.mem_resp_v_i(io_resp_v_i)
         ,.mem_resp_ready_o(io_resp_ready_lo)

         ,.cmd_link_i(proc_cmd_link_lo)
         ,.cmd_link_o(proc_cmd_link_li)
         ,.resp_link_i(proc_resp_link_lo)
         ,.resp_link_o(proc_resp_link_li)
         );

      logic mem_resp_ready_lo;
      assign mem_resp_yumi_o = mem_resp_ready_lo & mem_resp_v_i;
      bp_me_cce_to_mem_link_client
       #(.bp_params_p(bp_params_p)
         ,.num_outstanding_req_p(mem_noc_max_credits_p)
         ,.flit_width_p(mem_noc_flit_width_p)
         ,.cord_width_p(mem_noc_cord_width_p)
         ,.cid_width_p(mem_noc_cid_width_p)
         ,.len_width_p(mem_noc_len_width_p)
         )
       dram_link
        (.clk_i(clk_i)

         ,.reset_i(reset_i)
      
         ,.mem_cmd_o(mem_cmd_o)
         ,.mem_cmd_v_o(mem_cmd_v_o)
         ,.mem_cmd_yumi_i(mem_cmd_ready_i & mem_cmd_v_o)
      
         ,.mem_resp_i(mem_resp_i)
         ,.mem_resp_v_i(mem_resp_v_i & mem_resp_ready_lo)
         ,.mem_resp_ready_o(mem_resp_ready_lo)
      
         ,.cmd_link_i(dram_cmd_link_lo)
         ,.resp_link_o(dram_resp_link_li)
         );
    end

endmodule


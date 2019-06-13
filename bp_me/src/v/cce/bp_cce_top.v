/**
 *
 * Name:
 *   bp_cce_top.v
 *
 * Description:
 *   This is the top level module for the CCE.
 *
 * Notes:
 *   All inputs from the LCE are buffered. LCE Responses require a FIFO that can hold up to
 *   N responses where N is the number of way groups managed per CCE. Future optimizations could
 *   lessen this requirement to a 1 or 2 element FIFO. All other inputs use 2-FIFOs.
 *
 *   All input and output between the CCE and Memory are buffered. 2-FIFOs are used except for
 *   the Mem Response network, where N entries are required (N defined same as above). N entries
 *   are required because there may be up to 1 outstanding memory transaction per way group
 *   from the CCE, and the CCE may not immediately sink the message. Sinking depends on the current
 *   state of the microcode (e.g., the CCE could be processing some other request). The response
 *   contains information that is needed to resume processing an LCE's request, so it can not be
 *   automatically sunk without requiring additional storage buffers in the CCE itself.
 *
 *   Currently, it is assumed that N is the same for all CCEs in the system.
 */

module bp_cce_top
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
    `declare_bp_proc_params(cfg_p)

    // Config channel
    , parameter cfg_link_addr_width_p = bp_cfg_link_addr_width_gp
    , parameter cfg_link_data_width_p = bp_cfg_link_data_width_gp

    , parameter cce_trace_p             = "inv"

    // Derived parameters
    , localparam block_size_in_bytes_lp = (cce_block_width_p/8)
    , localparam lg_num_cce_lp         = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam mshr_width_lp = `bp_cce_mshr_width(num_lce_p, lce_assoc_p, paddr_width_p)
    , localparam wg_per_cce_lp = (lce_sets_p / num_cce_p)

    // interface widths
    `declare_bp_lce_cce_if_widths(num_cce_p, num_lce_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
    `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mshr_width_lp)

  )
  (input                                                   clk_i
   , input                                                 reset_i
   , input                                                 freeze_i

   // Config channel
   , input [cfg_link_addr_width_p-2:0]                     config_addr_i
   , input [cfg_link_data_width_p-1:0]                     config_data_i
   , input                                                 config_v_i
   , input                                                 config_w_i
   , output logic                                          config_ready_o

   , output logic [cfg_link_data_width_p-1:0]              config_data_o
   , output logic                                          config_v_o
   , input                                                 config_ready_i

   // LCE-CCE Interface
   // inbound: ready&valid
   // Inputs to CCE from LCE are buffered by two element FIFOs
   , input [lce_cce_req_width_lp-1:0]                      lce_req_i
   , input                                                 lce_req_v_i
   , output logic                                          lce_req_ready_o

   , input [lce_cce_resp_width_lp-1:0]                     lce_resp_i
   , input                                                 lce_resp_v_i
   , output logic                                          lce_resp_ready_o

   , input [lce_cce_data_resp_width_lp-1:0]                lce_data_resp_i
   , input                                                 lce_data_resp_v_i
   , output logic                                          lce_data_resp_ready_o

   // outbound: ready&valid
   // messages are not buffered by the CCE, and connection is directly to ME network
   , output logic [cce_lce_cmd_width_lp-1:0]               lce_cmd_o
   , output logic                                          lce_cmd_v_o
   , input                                                 lce_cmd_ready_i

   , output logic [lce_data_cmd_width_lp-1:0]              lce_data_cmd_o
   , output logic                                          lce_data_cmd_v_o
   , input                                                 lce_data_cmd_ready_i

   // CCE-MEM Interface
   // inbound: ready&valid, helpful consumer from demanding producer
   // outbound: valid->yumi, helpful producer to demanding consumer
   // Both inbound and outbound messages are buffered by two element FIFOs
   , input [mem_cce_resp_width_lp-1:0]                     mem_resp_i
   , input                                                 mem_resp_v_i
   , output logic                                          mem_resp_ready_o

   , input [mem_cce_data_resp_width_lp-1:0]                mem_data_resp_i
   , input                                                 mem_data_resp_v_i
   , output logic                                          mem_data_resp_ready_o

   , output logic [cce_mem_cmd_width_lp-1:0]               mem_cmd_o
   , output logic                                          mem_cmd_v_o
   , input                                                 mem_cmd_yumi_i

   , output logic [cce_mem_data_cmd_width_lp-1:0]          mem_data_cmd_o
   , output logic                                          mem_data_cmd_v_o
   , input                                                 mem_data_cmd_yumi_i

   , input [lg_num_cce_lp-1:0]                             cce_id_i
  );

  logic [lce_cce_req_width_lp-1:0]               lce_req_to_cce;
  logic                                          lce_req_v_to_cce;
  logic                                          lce_req_yumi_from_cce;
  logic [lce_cce_resp_width_lp-1:0]              lce_resp_to_cce;
  logic                                          lce_resp_v_to_cce;
  logic                                          lce_resp_yumi_from_cce;
  logic [lce_cce_data_resp_width_lp-1:0]         lce_data_resp_to_cce;
  logic                                          lce_data_resp_v_to_cce;
  logic                                          lce_data_resp_yumi_from_cce;
  logic [mem_cce_resp_width_lp-1:0]              mem_resp_to_cce;
  logic                                          mem_resp_v_to_cce;
  logic                                          mem_resp_yumi_from_cce;
  logic [mem_cce_data_resp_width_lp-1:0]         mem_data_resp_to_cce;
  logic                                          mem_data_resp_v_to_cce;
  logic                                          mem_data_resp_yumi_from_cce;
  logic [cce_mem_cmd_width_lp-1:0]               mem_cmd_from_cce;
  logic                                          mem_cmd_v_from_cce;
  logic                                          mem_cmd_ready_to_cce;
  logic [cce_mem_data_cmd_width_lp-1:0]          mem_data_cmd_from_cce;
  logic                                          mem_data_cmd_v_from_cce;
  logic                                          mem_data_cmd_ready_to_cce;

  // Inbound LCE to CCE
  bsg_two_fifo
    #(.width_p(lce_cce_req_width_lp)
      )
    lce_cce_req_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(lce_req_v_i)
      ,.data_i(lce_req_i)
      ,.ready_o(lce_req_ready_o)
      ,.v_o(lce_req_v_to_cce)
      ,.data_o(lce_req_to_cce)
      ,.yumi_i(lce_req_yumi_from_cce)
      );

  bsg_fifo_1r1w_small
    #(.width_p(lce_cce_resp_width_lp)
      // See top comments about sizing
      ,.els_p(wg_per_cce_lp)
      )
    lce_cce_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(lce_resp_v_i)
      ,.data_i(lce_resp_i)
      ,.ready_o(lce_resp_ready_o)
      ,.v_o(lce_resp_v_to_cce)
      ,.data_o(lce_resp_to_cce)
      ,.yumi_i(lce_resp_yumi_from_cce)
      );

  bsg_two_fifo
    #(.width_p(lce_cce_data_resp_width_lp)
      )
    lce_cce_data_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(lce_data_resp_v_i)
      ,.data_i(lce_data_resp_i)
      ,.ready_o(lce_data_resp_ready_o)
      ,.v_o(lce_data_resp_v_to_cce)
      ,.data_o(lce_data_resp_to_cce)
      ,.yumi_i(lce_data_resp_yumi_from_cce)
      );

  // Inbound Mem to CCE
  bsg_fifo_1r1w_small
    #(.width_p(mem_cce_resp_width_lp)
      // See top comments about sizing
      ,.els_p(wg_per_cce_lp)
      )
    mem_cce_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(mem_resp_v_i)
      ,.data_i(mem_resp_i)
      ,.ready_o(mem_resp_ready_o)
      ,.v_o(mem_resp_v_to_cce)
      ,.data_o(mem_resp_to_cce)
      ,.yumi_i(mem_resp_yumi_from_cce)
      );

  bsg_two_fifo
    #(.width_p(mem_cce_data_resp_width_lp)
      )
    mem_cce_data_resp_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(mem_data_resp_v_i)
      ,.data_i(mem_data_resp_i)
      ,.ready_o(mem_data_resp_ready_o)
      ,.v_o(mem_data_resp_v_to_cce)
      ,.data_o(mem_data_resp_to_cce)
      ,.yumi_i(mem_data_resp_yumi_from_cce)
      );


  // Outbound CCE to Mem
  bsg_two_fifo
    #(.width_p(cce_mem_cmd_width_lp)
      )
    cce_mem_cmd_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(mem_cmd_v_from_cce)
      ,.data_i(mem_cmd_from_cce)
      ,.ready_o(mem_cmd_ready_to_cce)
      ,.v_o(mem_cmd_v_o)
      ,.data_o(mem_cmd_o)
      ,.yumi_i(mem_cmd_yumi_i)
      );

  bsg_two_fifo
    #(.width_p(cce_mem_data_cmd_width_lp)
      )
    cce_mem_data_cmd_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(mem_data_cmd_v_from_cce)
      ,.data_i(mem_data_cmd_from_cce)
      ,.ready_o(mem_data_cmd_ready_to_cce)
      ,.v_o(mem_data_cmd_v_o)
      ,.data_o(mem_data_cmd_o)
      ,.yumi_i(mem_data_cmd_yumi_i)
      );


  // CCE

  bp_cce
    #(.cfg_p(cfg_p)
      ,.cfg_link_addr_width_p(cfg_link_addr_width_p)
      ,.cfg_link_data_width_p(cfg_link_data_width_p)
      ,.cce_trace_p(cce_trace_p)
      )
    bp_cce
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.freeze_i(freeze_i)

      ,.cce_id_i(cce_id_i)

      ,.config_addr_i(config_addr_i)
      ,.config_data_i(config_data_i)
      ,.config_v_i(config_v_i)
      ,.config_w_i(config_w_i)
      ,.config_ready_o(config_ready_o)

      ,.config_data_o(config_data_o)
      ,.config_v_o(config_v_o)
      ,.config_ready_i(config_ready_i)

      // To CCE
      ,.lce_req_i(lce_req_to_cce)
      ,.lce_req_v_i(lce_req_v_to_cce)
      ,.lce_req_yumi_o(lce_req_yumi_from_cce)
      ,.lce_resp_i(lce_resp_to_cce)
      ,.lce_resp_v_i(lce_resp_v_to_cce)
      ,.lce_resp_yumi_o(lce_resp_yumi_from_cce)
      ,.lce_data_resp_i(lce_data_resp_to_cce)
      ,.lce_data_resp_v_i(lce_data_resp_v_to_cce)
      ,.lce_data_resp_yumi_o(lce_data_resp_yumi_from_cce)

      // From CCE
      ,.lce_cmd_o(lce_cmd_o)
      ,.lce_cmd_v_o(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      ,.lce_data_cmd_o(lce_data_cmd_o)
      ,.lce_data_cmd_v_o(lce_data_cmd_v_o)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp_to_cce)
      ,.mem_resp_v_i(mem_resp_v_to_cce)
      ,.mem_resp_yumi_o(mem_resp_yumi_from_cce)
      ,.mem_data_resp_i(mem_data_resp_to_cce)
      ,.mem_data_resp_v_i(mem_data_resp_v_to_cce)
      ,.mem_data_resp_yumi_o(mem_data_resp_yumi_from_cce)

      // From CCE
      ,.mem_cmd_o(mem_cmd_from_cce)
      ,.mem_cmd_v_o(mem_cmd_v_from_cce)
      ,.mem_cmd_ready_i(mem_cmd_ready_to_cce)
      ,.mem_data_cmd_o(mem_data_cmd_from_cce)
      ,.mem_data_cmd_v_o(mem_data_cmd_v_from_cce)
      ,.mem_data_cmd_ready_i(mem_data_cmd_ready_to_cce)
      );

if (cce_trace_p) begin : cce_tracer
  bp_cce_nonsynth_tracer
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_lp)
      ,.lce_req_data_width_p(dword_width_p)
      )
    bp_cce_tracer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cce_id_i(cce_id_i)

      // To CCE
      ,.lce_req_i(lce_req_to_cce)
      ,.lce_req_v_i(lce_req_v_to_cce)
      ,.lce_req_yumi_i(lce_req_yumi_from_cce)
      ,.lce_resp_i(lce_resp_to_cce)
      ,.lce_resp_v_i(lce_resp_v_to_cce)
      ,.lce_resp_yumi_i(lce_resp_yumi_from_cce)
      ,.lce_data_resp_i(lce_data_resp_to_cce)
      ,.lce_data_resp_v_i(lce_data_resp_v_to_cce)
      ,.lce_data_resp_yumi_i(lce_data_resp_yumi_from_cce)

      // From CCE
      ,.lce_cmd_i(lce_cmd_o)
      ,.lce_cmd_v_i(lce_cmd_v_o)
      ,.lce_cmd_ready_i(lce_cmd_ready_i)
      ,.lce_data_cmd_i(lce_data_cmd_o)
      ,.lce_data_cmd_v_i(lce_data_cmd_v_o)
      ,.lce_data_cmd_ready_i(lce_data_cmd_ready_i)

      // To CCE
      ,.mem_resp_i(mem_resp_to_cce)
      ,.mem_resp_v_i(mem_resp_v_to_cce)
      ,.mem_resp_yumi_i(mem_resp_yumi_from_cce)
      ,.mem_data_resp_i(mem_data_resp_to_cce)
      ,.mem_data_resp_v_i(mem_data_resp_v_to_cce)
      ,.mem_data_resp_yumi_i(mem_data_resp_yumi_from_cce)

      // From CCE
      ,.mem_cmd_i(mem_cmd_from_cce)
      ,.mem_cmd_v_i(mem_cmd_v_from_cce)
      ,.mem_cmd_ready_i(mem_cmd_ready_to_cce)
      ,.mem_data_cmd_i(mem_data_cmd_from_cce)
      ,.mem_data_cmd_v_i(mem_data_cmd_v_from_cce)
      ,.mem_data_cmd_ready_i(mem_data_cmd_ready_to_cce)
      );
end // cce_tracer

endmodule

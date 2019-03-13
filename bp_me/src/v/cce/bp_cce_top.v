/**
 *
 * Name:
 *   bp_cce_top.v
 *
 * Description:
 *   This is the top level module for the CCE.
 *
 */

module bp_cce_top
  import bp_common_pkg::*;
  import bp_cce_pkg::*;
  #(parameter num_lce_p                 = "inv"
    , parameter num_cce_p               = "inv"
    , parameter paddr_width_p           = "inv"
    , parameter lce_assoc_p             = "inv"
    , parameter lce_sets_p              = "inv"
    , parameter block_size_in_bytes_p   = "inv"
    , parameter num_cce_inst_ram_els_p  = "inv"

    // Derived parameters
    , localparam block_size_in_bits_lp  = (block_size_in_bytes_p*8)
    , localparam lg_num_cce_lp          = `BSG_SAFE_CLOG2(num_cce_p)
    , localparam inst_ram_addr_width_lp = `BSG_SAFE_CLOG2(num_cce_inst_ram_els_p)

    , localparam bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p
                                                               ,num_lce_p
                                                               ,paddr_width_p
                                                               ,lce_assoc_p)

    , localparam bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p
                                                                 ,num_lce_p
                                                                 ,paddr_width_p)

    , localparam bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p
                                                                           ,num_lce_p
                                                                           ,paddr_width_p
                                                                           ,block_size_in_bits_lp)

    , localparam bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                               ,num_lce_p
                                                               ,paddr_width_p
                                                               ,lce_assoc_p)

    , localparam bp_lce_data_cmd_width_lp=`bp_lce_data_cmd_width(num_lce_p
                                                                 ,block_size_in_bits_lp
                                                                 ,lce_assoc_p)

    , localparam bp_mem_cce_resp_width_lp=`bp_mem_cce_resp_width(paddr_width_p
                                                                 ,num_lce_p
                                                                 ,lce_assoc_p)

    , localparam bp_mem_cce_data_resp_width_lp=`bp_mem_cce_data_resp_width(paddr_width_p
                                                                           ,block_size_in_bits_lp
                                                                           ,num_lce_p
                                                                           ,lce_assoc_p)

    , localparam bp_cce_mem_cmd_width_lp=`bp_cce_mem_cmd_width(paddr_width_p
                                                               ,num_lce_p
                                                               ,lce_assoc_p)

    , localparam bp_cce_mem_data_cmd_width_lp=`bp_cce_mem_data_cmd_width(paddr_width_p
                                                                         ,block_size_in_bits_lp
                                                                         ,num_lce_p
                                                                         ,lce_assoc_p)
  )
  (input                                                   clk_i
   , input                                                 reset_i

   // LCE-CCE Interface
   // inbound: ready->valid, helpful consumer from demanding producer
   , input [bp_lce_cce_req_width_lp-1:0]                   lce_req_i
   , input                                                 lce_req_v_i
   , output logic                                          lce_req_ready_o

   , input [bp_lce_cce_resp_width_lp-1:0]                  lce_resp_i
   , input                                                 lce_resp_v_i
   , output logic                                          lce_resp_ready_o

   , input [bp_lce_cce_data_resp_width_lp-1:0]             lce_data_resp_i
   , input                                                 lce_data_resp_v_i
   , output logic                                          lce_data_resp_ready_o

   // outbound: ready->valid, demanding producer to helpful consumer
   , output logic [bp_cce_lce_cmd_width_lp-1:0]            lce_cmd_o
   , output logic                                          lce_cmd_v_o
   , input                                                 lce_cmd_ready_i

   , output logic [bp_lce_data_cmd_width_lp-1:0]           lce_data_cmd_o
   , output logic                                          lce_data_cmd_v_o
   , input                                                 lce_data_cmd_ready_i

   // CCE-MEM Interface
   // inbound: ready->valid, helpful consumer from demanding producer
   // outbound: valid->yumi, helpful producer to demanding consumer
   , input [bp_mem_cce_resp_width_lp-1:0]                  mem_resp_i
   , input                                                 mem_resp_v_i
   , output logic                                          mem_resp_ready_o

   , input [bp_mem_cce_data_resp_width_lp-1:0]             mem_data_resp_i
   , input                                                 mem_data_resp_v_i
   , output logic                                          mem_data_resp_ready_o

   , output logic [bp_cce_mem_cmd_width_lp-1:0]            mem_cmd_o
   , output logic                                          mem_cmd_v_o
   , input                                                 mem_cmd_yumi_i

   , output logic [bp_cce_mem_data_cmd_width_lp-1:0]       mem_data_cmd_o
   , output logic                                          mem_data_cmd_v_o
   , input                                                 mem_data_cmd_yumi_i

   , input [lg_num_cce_lp-1:0]                             cce_id_i

   , output logic [inst_ram_addr_width_lp-1:0]             boot_rom_addr_o
   , input [`bp_cce_inst_width-1:0]                        boot_rom_data_i
  );

  logic [bp_lce_cce_req_width_lp-1:0]            lce_req_to_cce;
  logic                                          lce_req_v_to_cce;
  logic                                          lce_req_yumi_from_cce;
  logic [bp_lce_cce_resp_width_lp-1:0]           lce_resp_to_cce;
  logic                                          lce_resp_v_to_cce;
  logic                                          lce_resp_yumi_from_cce;
  logic [bp_lce_cce_data_resp_width_lp-1:0]      lce_data_resp_to_cce;
  logic                                          lce_data_resp_v_to_cce;
  logic                                          lce_data_resp_yumi_from_cce;
  logic [bp_mem_cce_resp_width_lp-1:0]           mem_resp_to_cce;
  logic                                          mem_resp_v_to_cce;
  logic                                          mem_resp_yumi_from_cce;
  logic [bp_mem_cce_data_resp_width_lp-1:0]      mem_data_resp_to_cce;
  logic                                          mem_data_resp_v_to_cce;
  logic                                          mem_data_resp_yumi_from_cce;
  logic [bp_cce_mem_cmd_width_lp-1:0]            mem_cmd_from_cce;
  logic                                          mem_cmd_v_from_cce;
  logic                                          mem_cmd_ready_to_cce;
  logic [bp_cce_mem_data_cmd_width_lp-1:0]       mem_data_cmd_from_cce;
  logic                                          mem_data_cmd_v_from_cce;
  logic                                          mem_data_cmd_ready_to_cce;

  // Inbound LCE to CCE
  bsg_two_fifo
    #(.width_p(bp_lce_cce_req_width_lp)
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

  bsg_two_fifo
    #(.width_p(bp_lce_cce_resp_width_lp)
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
    #(.width_p(bp_lce_cce_data_resp_width_lp)
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
  bsg_two_fifo
    #(.width_p(bp_mem_cce_resp_width_lp)
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
    #(.width_p(bp_mem_cce_data_resp_width_lp)
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
    #(.width_p(bp_cce_mem_cmd_width_lp)
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
    #(.width_p(bp_cce_mem_data_cmd_width_lp)
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
    #(.num_lce_p(num_lce_p)
      ,.num_cce_p(num_cce_p)
      ,.paddr_width_p(paddr_width_p)
      ,.lce_assoc_p(lce_assoc_p)
      ,.lce_sets_p(lce_sets_p)
      ,.block_size_in_bytes_p(block_size_in_bytes_p)
      ,.num_cce_inst_ram_els_p(num_cce_inst_ram_els_p)
      )
    bp_cce
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cce_id_i(cce_id_i)

      ,.boot_rom_addr_o(boot_rom_addr_o)
      ,.boot_rom_data_i(boot_rom_data_i)

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

endmodule

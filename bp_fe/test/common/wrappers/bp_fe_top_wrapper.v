`timescale 1ps/1ps

`include "bsg_defines.v"

`include "bp_common_fe_be_if.vh"

`include "bp_fe_pc_gen.vh"

`include "bp_fe_itlb.vh"

`include "bp_fe_icache.vh"

//import bp_common_pkg::*;
//import itlb_pkg::*;
//import pc_gen_pkg::*;

module bp_fe_top_wrapper 
#(
parameter vaddr_width_p          ="inv"
,parameter paddr_width_p         ="inv"
,parameter eaddr_width_p         ="inv"
,parameter data_width_p          ="inv"
,parameter inst_width_p          ="inv"
,parameter lce_sets_p            ="inv"
,parameter lce_assoc_p           ="inv"
,parameter tag_width_p           ="inv"
,parameter coh_states_p          =4
,parameter num_cce_p             ="inv"
,parameter num_lce_p             ="inv"
,parameter lce_id_p              ="inv"
,parameter block_size_in_bytes_p ="inv"
,parameter btb_indx_width_p      ="inv"
,parameter bht_indx_width_p      ="inv"
,parameter ras_addr_width_p      ="inv"
,parameter asid_width_p          ="inv"
,parameter instr_width_p         ="inv"
,parameter bp_first_pc_lp        =64'h00000000
)(
input logic clk_i
,input logic reset_i
);

localparam lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p);
localparam lg_lce_sets_lp=`BSG_SAFE_CLOG2(lce_sets_p);
localparam lg_coh_states_lp=`BSG_SAFE_CLOG2(coh_states_p);
localparam block_size_in_bits_lp=block_size_in_bytes_p*8;
localparam lg_block_size_in_bytes_lp=`BSG_SAFE_CLOG2(block_size_in_bytes_p);
localparam entry_width_lp=tag_width_p+lg_coh_states_lp;
localparam tag_set_width_lp=(entry_width_lp*lce_assoc_p);
localparam way_group_width_lp=(tag_set_width_lp*num_lce_p);
localparam data_set_width_lp=(data_width_p*lce_assoc_p);
localparam metadata_set_width=(lg_lce_assoc_lp+lce_assoc_p);
localparam data_mask_width_lp=(data_width_p>>3);
localparam lg_data_mask_width_lp=`BSG_SAFE_CLOG2(data_mask_width_lp);
localparam lg_num_cce_lp=`BSG_SAFE_CLOG2(num_cce_p);
localparam lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p);
localparam vaddr_width_lp=(lg_lce_sets_lp+lg_lce_assoc_lp+lg_data_mask_width_lp);
localparam addr_width_lp=(vaddr_width_lp+tag_width_p);
localparam lce_data_width_lp=(lce_assoc_p*data_width_p);
localparam bp_fe_pc_gen_icache_width_lp=`bp_fe_pc_gen_icache_width(eaddr_width_p);
localparam bp_fe_itlb_icache_width_lp=44;
localparam bp_lce_cce_req_width_lp=`bp_lce_cce_req_width(num_cce_p, num_lce_p, addr_width_lp, lce_assoc_p);
localparam bp_lce_cce_resp_width_lp=`bp_lce_cce_resp_width(num_cce_p, num_lce_p, addr_width_lp);
localparam bp_lce_cce_data_resp_width_lp=`bp_lce_cce_data_resp_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp);
localparam bp_cce_lce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p, num_lce_p, addr_width_lp, lce_assoc_p);
localparam bp_cce_lce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p, num_lce_p, addr_width_lp, lce_data_width_lp, lce_assoc_p);
localparam bp_lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p, addr_width_lp, lce_data_width_lp, lce_assoc_p);
localparam bp_fe_icache_tag_set_width_lp=`bp_fe_icache_tag_set_width(tag_width_p, lce_assoc_p);
localparam bp_fe_icache_tag_state_width_lp=`bp_fe_icache_tag_state_width(tag_width_p);
localparam bp_fe_icache_metadata_width_lp=`bp_fe_icache_metadata_width(lce_assoc_p);
localparam bp_fe_icache_pc_gen_width_lp=`bp_fe_icache_pc_gen_width(eaddr_width_p);

// pc gen related parameters
localparam instr_scan_width_lp=`bp_fe_instr_scan_width;
localparam branch_metadata_fwd_width_lp=btb_indx_width_p+bht_indx_width_p+ras_addr_width_p;
localparam bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(eaddr_width_p);
localparam bp_fe_pc_gen_width_i_lp=`bp_fe_pc_gen_cmd_width(vaddr_width_p,branch_metadata_fwd_width_lp);
localparam bp_fe_pc_gen_width_o_lp=`bp_fe_pc_gen_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp);

// itlb related parameters 
localparam bp_fe_itlb_cmd_width_lp=`bp_fe_itlb_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp);
localparam bp_fe_itlb_queue_width_lp=`bp_fe_itlb_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp);

// be interfaces parameters
localparam bp_fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_p,paddr_width_p,asid_width_p,branch_metadata_fwd_width_lp);
localparam bp_fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_p,branch_metadata_fwd_width_lp);

// rom interface parameters
localparam rom_addr_width_lp=eaddr_width_p;
localparam rom_data_width_lp=lce_assoc_p*data_width_p;

            
              

logic [bp_fe_cmd_width_lp-1:0]              bp_fe_cmd_i;
logic                                       bp_fe_cmd_v_i;
logic                                       bp_fe_cmd_ready_o;

logic [bp_fe_cmd_width_lp-1:0]              bp_be_cmd_o;
logic                                       bp_be_cmd_v_o;
logic                                       bp_be_cmd_ready_i;

logic  [bp_fe_queue_width_lp-1:0]           bp_fe_queue_o;
logic                                       bp_fe_queue_v_o;
logic                                       bp_fe_queue_ready_i;

logic  [bp_fe_queue_width_lp-1:0]           bp_be_queue_i;
logic                                       bp_be_queue_v_i;
logic                                       bp_be_queue_ready_o;

logic  [bp_lce_cce_req_width_lp-1:0]        lce_cce_req_o;
logic                                       lce_cce_req_v_o;
logic                                       lce_cce_req_ready_i;

logic  [bp_lce_cce_resp_width_lp-1:0]       lce_cce_resp_o;
logic                                       lce_cce_resp_v_o;
logic                                       lce_cce_resp_ready_i;

logic  [bp_lce_cce_data_resp_width_lp-1:0]  lce_cce_data_resp_o     ;
logic                                       lce_cce_data_resp_v_o ;
logic                                       lce_cce_data_resp_ready_i;

logic  [bp_cce_lce_cmd_width_lp-1:0]        cce_lce_cmd_i;
logic                                       cce_lce_cmd_v_i;
logic                                       cce_lce_cmd_ready_o;

logic  [bp_cce_lce_data_cmd_width_lp-1:0]   cce_lce_data_cmd_i;
logic                                       cce_lce_data_cmd_v_i;
logic                                       cce_lce_data_cmd_ready_o;

logic  [bp_lce_lce_tr_resp_width_lp-1:0]    lce_lce_tr_resp_i;
logic                                       lce_lce_tr_resp_v_i;
logic                                       lce_lce_tr_resp_ready_o;

logic  [bp_lce_lce_tr_resp_width_lp-1:0]    lce_lce_tr_resp_o;
logic                                       lce_lce_tr_resp_v_o;
logic                                       lce_lce_tr_resp_ready_i;

logic [rom_addr_width_lp-1:0]               rom_addr;
logic [rom_data_width_lp-1:0]               rom_data;

// mock cce
logic                                cce_done_o;
logic                                lce_cce_resp_fifo_v_o;
logic                                lce_cce_resp_fifo_yumi_i;
logic [bp_lce_cce_resp_width_lp-1:0] lce_cce_resp_fifo_data_o;

bsg_two_fifo #(
  .width_p(bp_lce_cce_resp_width_lp)
) lce_cce_resp_fifo (
  .clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.v_i(lce_cce_resp_v_o)
  ,.ready_o(lce_cce_resp_ready_i)
  ,.data_i(lce_cce_resp_o)

  ,.v_o(lce_cce_resp_fifo_v_o)
  ,.yumi_i(lce_cce_resp_fifo_yumi_i & lce_cce_resp_fifo_v_o)
  ,.data_o(lce_cce_resp_fifo_data_o)
);

mock_cce #(
  .data_width_p(data_width_p)
  ,.sets_p(lce_sets_p)
  ,.ways_p(lce_assoc_p)
  ,.tag_width_p(tag_width_p)
  ,.num_cce_p(num_cce_p)
  ,.num_lce_p(num_lce_p)
  ,.eaddr_width_p(eaddr_width_p)
) cce (
  .clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.lce_req_i(lce_cce_req_o)
  ,.lce_req_v_i(lce_cce_req_v_o)
  ,.lce_req_ready_o(lce_cce_req_ready_i)

  ,.lce_resp_i(lce_cce_resp_fifo_data_o)
  ,.lce_resp_v_i(lce_cce_resp_fifo_v_o)
  ,.lce_resp_ready_o(lce_cce_resp_fifo_yumi_i)

  ,.lce_data_resp_i(lce_cce_data_resp_o)
  ,.lce_data_resp_v_i(lce_cce_data_resp_v_o)
  ,.lce_data_resp_ready_o(lce_cce_data_resp_ready_i)

  ,.lce_cmd_o(cce_lce_cmd_i)
  ,.lce_cmd_v_o(cce_lce_cmd_v_i)
  ,.lce_cmd_yumi_i(cce_lce_cmd_ready_o)

  ,.lce_data_cmd_o(cce_lce_data_cmd_i)
  ,.lce_data_cmd_v_o(cce_lce_data_cmd_v_i)
  ,.lce_data_cmd_yumi_i(cce_lce_data_cmd_ready_o) 

  ,.done_o(cce_done_o)

  ,.rom_addr_o(rom_addr)
  ,.rom_data_i(rom_data)
);

bp_boot_rom 
#(
  .addr_width_p(rom_addr_width_lp)
  ,.width_p(rom_data_width_lp)
) bp_fe_rom (
  .addr_i(rom_addr)
  ,.data_o(rom_data)
);


bsg_two_fifo 
#(
  .width_p(bp_fe_queue_width_lp)
) fe_be_queue_fifo (
  .clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(bp_fe_queue_ready_i)
  ,.data_i(bp_fe_queue_o)
  ,.v_i(bp_fe_queue_v_o)

  ,.v_o(bp_be_queue_v_i)
  ,.data_o(bp_be_queue_i)
  ,.yumi_i(bp_be_queue_ready_o)
);


bsg_two_fifo
#(
  .width_p(bp_fe_cmd_width_lp)
) fe_be_cmd_fifo (
  .clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.ready_o(bp_be_cmd_ready_i)
  ,.data_i(bp_be_cmd_o)
  ,.v_i(bp_be_cmd_v_o)

  ,.v_o(bp_fe_cmd_v_i)
  ,.data_o(bp_fe_cmd_i)
  ,.yumi_i(bp_fe_cmd_ready_o)
);

mock_be
#(

.vaddr_width_p(vaddr_width_p)
,.paddr_width_p(paddr_width_p)
,.eaddr_width_p(eaddr_width_p)
,.btb_indx_width_p(btb_indx_width_p)
,.bht_indx_width_p(bht_indx_width_p)
,.ras_addr_width_p(ras_addr_width_p)
,.asid_width_p(asid_width_p)
,.instr_width_p(instr_width_p)
) mock_be_1
(.clk_i(clk_i)
 ,.reset_i(reset_i)

 ,.bp_fe_cmd_o(bp_be_cmd_o)
 ,.bp_fe_cmd_v_o(bp_be_cmd_v_o)
 ,.bp_fe_cmd_ready_i(bp_be_cmd_ready_i)

 ,.bp_fe_queue_i(bp_be_queue_i)
 ,.bp_fe_queue_v_i(bp_be_queue_v_i)
 ,.bp_fe_queue_ready_o(bp_be_queue_ready_o)
);
 
bp_fe_top
#(
.vaddr_width_p(vaddr_width_p)
,.paddr_width_p(paddr_width_p)
,.eaddr_width_p(eaddr_width_p)
,.btb_indx_width_p(btb_indx_width_p)
,.bht_indx_width_p(bht_indx_width_p)
,.ras_addr_width_p(ras_addr_width_p)
,.asid_width_p(asid_width_p)
,.bp_first_pc_p(bp_first_pc_lp)
,.instr_width_p(instr_width_p)

,.data_width_p(data_width_p)
,.inst_width_p(inst_width_p)
,.lce_sets_p(lce_sets_p)
,.lce_assoc_p(lce_assoc_p)
,.tag_width_p(tag_width_p)
,.coh_states_p(coh_states_p)
,.num_cce_p(num_cce_p)
,.num_lce_p(num_lce_p)
,.lce_id_p(lce_id_p)
,.block_size_in_bytes_p(block_size_in_bytes_p)

) bp_fe_top_1 (.*);
endmodule
